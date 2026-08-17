-- ============================================================================
-- 033 - Protect privileged public.users columns and establish safe admins
-- ============================================================================
-- DRAFT: do not apply before completing the non-destructive preflight below.
-- This migration intentionally does not backfill admin_memberships from
-- users.is_admin and does not implement payments, boosts, ratings eligibility,
-- account deletion, or administrative mutation RPCs.
--
-- Required operator step before applying:
--   1. Run the PRE-FLIGHT queries at the end of this file and review the rows.
--   2. Audit the deployed Edge Functions that use service_role, especially
--      generate-embedding and delete-user.
--   3. Verify the live owners/bodies of rate_user, fn_sync_like_count,
--      fn_sync_connection_count, admin_list_users and admin_list_boosted.
--   4. Only after that review, uncomment the set_config call below.
--
-- ============================================================================

BEGIN;

-- SELECT set_config('mploya.privileged_audit_reviewed', 'yes', true);

-- Fail closed if the live schema does not match the versioned contracts.
DO $$
DECLARE
  v_missing TEXT[];
  v_connection_trigger RECORD;
BEGIN
  SELECT array_agg(required.column_name ORDER BY required.column_name)
    INTO v_missing
  FROM unnest(ARRAY[
    'is_admin', 'is_premium', 'is_verified', 'b2b_tokens', 'deleted_at',
    'boost_ends_at', 'boost_type', 'boost_target_city', 'boost_started_at',
    'profile_views', 'match_percentage', 'rating_stars', 'rating_count',
    'like_count', 'connections', 'employer_rating_stars',
    'employer_rating_count', 'profile_embedding'
  ]) AS required(column_name)
  WHERE NOT EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'users'
      AND c.column_name = required.column_name
  );

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION '033 precondition: missing public.users columns: %', v_missing;
  END IF;

  IF to_regprocedure('public.rate_user(uuid,double precision)') IS NULL
    OR to_regprocedure('public.fn_sync_like_count()') IS NULL
    OR to_regprocedure('public.fn_sync_connection_count()') IS NULL
    OR to_regprocedure('public.admin_list_users(text,integer)') IS NULL
    OR to_regprocedure('public.admin_list_boosted()') IS NULL
  THEN
    RAISE EXCEPTION '033 precondition: a versioned function contract is missing';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    WHERE p.oid IN (
      to_regprocedure('public.rate_user(uuid,double precision)')::oid,
      to_regprocedure('public.fn_sync_like_count()')::oid,
      to_regprocedure('public.fn_sync_connection_count()')::oid,
      to_regprocedure('public.admin_list_users(text,integer)')::oid,
      to_regprocedure('public.admin_list_boosted()')::oid
    )
      AND pg_get_userbyid(p.proowner) NOT IN (
        'postgres', 'service_role', 'supabase_admin'
      )
  ) THEN
    RAISE EXCEPTION '033 precondition: a versioned function has an unexpected owner';
  END IF;

  IF pg_get_functiondef(
      to_regprocedure('public.admin_list_users(text,integer)')::oid
    ) NOT LIKE '%public.is_admin()%'
    OR pg_get_functiondef(
      to_regprocedure('public.admin_list_boosted()')::oid
    ) NOT LIKE '%public.is_admin()%'
    OR pg_get_functiondef(
      to_regprocedure('public.rate_user(uuid,double precision)')::oid
    ) NOT LIKE '%public.user_ratings%'
  THEN
    RAISE EXCEPTION '033 precondition: a versioned function body differs from the audited contract';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_language l ON l.oid = p.prolang
    WHERE p.oid = to_regprocedure('public.fn_sync_connection_count()')::oid
      AND p.prorettype = 'pg_catalog.trigger'::regtype
      AND p.prosecdef
      AND l.lanname = 'plpgsql'
      AND pg_get_functiondef(p.oid) LIKE '%TG_OP = ''INSERT''%'
      AND pg_get_functiondef(p.oid) LIKE '%TG_OP = ''UPDATE''%'
      AND pg_get_functiondef(p.oid) LIKE '%TG_OP = ''DELETE''%'
      AND pg_get_functiondef(p.oid) LIKE '%NEW.status = ''accepted''%'
      AND pg_get_functiondef(p.oid) LIKE '%OLD.status <> ''accepted''%'
      AND pg_get_functiondef(p.oid) LIKE '%OLD.status = ''accepted''%'
      AND pg_get_functiondef(p.oid) LIKE '%NEW.status <> ''accepted''%'
      AND pg_get_functiondef(p.oid)
        LIKE '%id IN (NEW.requester_id, NEW.addressee_id)%'
      AND pg_get_functiondef(p.oid)
        LIKE '%id IN (OLD.requester_id, OLD.addressee_id)%'
      AND pg_get_functiondef(p.oid)
        LIKE '%GREATEST(0, connections - 1)%'
  ) THEN
    RAISE EXCEPTION
      '033 precondition: fn_sync_connection_count differs from versioned contract';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid = 'public.pitch_likes'::regclass
      AND tgname = 'trg_sync_like_count'
      AND tgfoid = to_regprocedure('public.fn_sync_like_count()')::oid
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION '033 precondition: versioned like aggregate trigger is missing';
  END IF;

  SELECT
    t.oid,
    t.tgfoid,
    t.tgtype,
    t.tgenabled,
    t.tgisinternal,
    t.tgnargs,
    t.tgattr,
    t.tgqual,
    t.tgoldtable,
    t.tgnewtable,
    t.tgparentid
  INTO v_connection_trigger
  FROM pg_trigger t
  WHERE t.tgrelid = 'public.connections'::regclass
    AND t.tgname = 'trg_sync_connection_count';

  IF v_connection_trigger.oid IS NULL THEN
    EXECUTE 'CREATE TRIGGER trg_sync_connection_count
      AFTER INSERT OR UPDATE OR DELETE ON public.connections
      FOR EACH ROW EXECUTE FUNCTION public.fn_sync_connection_count()';
  ELSIF v_connection_trigger.tgfoid
      <> to_regprocedure('public.fn_sync_connection_count()')::oid
    OR v_connection_trigger.tgtype <> 29
    OR v_connection_trigger.tgenabled <> 'O'
    OR v_connection_trigger.tgisinternal
    OR v_connection_trigger.tgnargs <> 0
    OR v_connection_trigger.tgattr::TEXT <> ''
    OR v_connection_trigger.tgqual IS NOT NULL
    OR v_connection_trigger.tgoldtable IS NOT NULL
    OR v_connection_trigger.tgnewtable IS NOT NULL
    OR v_connection_trigger.tgparentid <> 0
  THEN
    RAISE EXCEPTION
      '033 precondition: trg_sync_connection_count conflicts with versioned definition';
  END IF;

  IF current_setting('mploya.privileged_audit_reviewed', true) IS DISTINCT FROM 'yes' THEN
    RAISE EXCEPTION '033 precondition: historical privileged-data audit not confirmed';
  END IF;
END;
$$;

-- --------------------------------------------------------------------------
-- Safe administrative authority
-- --------------------------------------------------------------------------
CREATE TABLE public.admin_memberships (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  granted_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  reason TEXT NOT NULL CHECK (length(btrim(reason)) BETWEEN 1 AND 500),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_memberships FORCE ROW LEVEL SECURITY;

-- There are deliberately no client policies. postgres owns the table and the
-- service role is the only non-owner role allowed to maintain memberships.
REVOKE ALL ON TABLE public.admin_memberships
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.admin_memberships
  TO service_role;

CREATE OR REPLACE FUNCTION public.set_admin_membership_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.set_admin_membership_updated_at()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_admin_membership_updated_at
BEFORE UPDATE ON public.admin_memberships
FOR EACH ROW EXECUTE FUNCTION public.set_admin_membership_updated_at();

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.admin_memberships am
    WHERE am.user_id = auth.uid()
      AND am.active IS TRUE
  );
$$;

ALTER FUNCTION public.is_admin() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.is_admin()
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

COMMENT ON TABLE public.admin_memberships IS
  'Server-managed administrative authority. Never backfilled from users.is_admin.';
COMMENT ON FUNCTION public.is_admin() IS
  'Returns only the active membership of auth.uid(); accepts no client user id.';

-- Existing policies in admin_setup.sql call public.is_admin(), so replacing the
-- helper transitions them without recreating or broadening policy contracts.
ALTER FUNCTION public.admin_list_users(TEXT, INTEGER)
  SECURITY DEFINER SET search_path = public, pg_temp;
ALTER FUNCTION public.admin_list_users(TEXT, INTEGER) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.admin_list_users(TEXT, INTEGER)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_users(TEXT, INTEGER) TO authenticated;

ALTER FUNCTION public.admin_list_boosted()
  SECURITY DEFINER SET search_path = public, pg_temp;
ALTER FUNCTION public.admin_list_boosted() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.admin_list_boosted()
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_boosted() TO authenticated;

-- No policy may authorize administrators by reading users.is_admin directly.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_policies p
    WHERE p.schemaname = 'public'
      AND concat_ws(' ', p.qual, p.with_check) ~* '(users|u)[.]is_admin'
  ) THEN
    RAISE EXCEPTION '033 precondition: policy still trusts users.is_admin directly';
  END IF;
END;
$$;

-- --------------------------------------------------------------------------
-- Protected public.users columns
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_user_privileged_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  -- Effective SQL identities, never profile fields or JWT metadata.
  v_internal_role BOOLEAN := current_user IN (
    'postgres', 'service_role', 'supabase_admin'
  );
BEGIN
  IF v_internal_role THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF COALESCE(NEW.is_admin, false)
      OR COALESCE(NEW.is_premium, false)
      OR COALESCE(NEW.is_verified, false)
      OR COALESCE(NEW.b2b_tokens, 0) <> 0
      OR NEW.deleted_at IS NOT NULL
      OR NEW.boost_ends_at IS NOT NULL
      OR NEW.boost_type IS NOT NULL
      OR NEW.boost_target_city IS NOT NULL
      OR NEW.boost_started_at IS NOT NULL
      OR COALESCE(NEW.profile_views, 0) <> 0
      OR COALESCE(NEW.match_percentage, 0) <> 0
      OR COALESCE(NEW.rating_stars, 0) <> 0
      OR COALESCE(NEW.rating_count, 0) <> 0
      OR COALESCE(NEW.like_count, 0) <> 0
      OR COALESCE(NEW.connections, 0) <> 0
      OR COALESCE(NEW.employer_rating_stars, 0) <> 0
      OR COALESCE(NEW.employer_rating_count, 0) <> 0
      OR NEW.profile_embedding IS NOT NULL
    THEN
      RAISE EXCEPTION 'users: privileged columns are server-managed'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.is_admin IS DISTINCT FROM OLD.is_admin
    OR NEW.is_premium IS DISTINCT FROM OLD.is_premium
    OR NEW.is_verified IS DISTINCT FROM OLD.is_verified
    OR NEW.b2b_tokens IS DISTINCT FROM OLD.b2b_tokens
    OR NEW.deleted_at IS DISTINCT FROM OLD.deleted_at
    OR NEW.boost_ends_at IS DISTINCT FROM OLD.boost_ends_at
    OR NEW.boost_type IS DISTINCT FROM OLD.boost_type
    OR NEW.boost_target_city IS DISTINCT FROM OLD.boost_target_city
    OR NEW.boost_started_at IS DISTINCT FROM OLD.boost_started_at
    OR NEW.profile_views IS DISTINCT FROM OLD.profile_views
    OR NEW.match_percentage IS DISTINCT FROM OLD.match_percentage
    OR NEW.rating_stars IS DISTINCT FROM OLD.rating_stars
    OR NEW.rating_count IS DISTINCT FROM OLD.rating_count
    OR NEW.like_count IS DISTINCT FROM OLD.like_count
    OR NEW.connections IS DISTINCT FROM OLD.connections
    OR NEW.employer_rating_stars IS DISTINCT FROM OLD.employer_rating_stars
    OR NEW.employer_rating_count IS DISTINCT FROM OLD.employer_rating_count
    OR NEW.profile_embedding::TEXT IS DISTINCT FROM OLD.profile_embedding::TEXT
  THEN
    RAISE EXCEPTION 'users: privileged columns are server-managed'
      USING ERRCODE = '42501';
  END IF;

  -- Existing own-row RLS continues to govern ordinary profile fields.
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.protect_user_privileged_columns() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.protect_user_privileged_columns()
  FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_protect_user_privileged_columns ON public.users;
CREATE TRIGGER trg_protect_user_privileged_columns
BEFORE INSERT OR UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.protect_user_privileged_columns();

REVOKE TRUNCATE, TRIGGER, DELETE ON public.users
  FROM PUBLIC, anon, authenticated;

-- --------------------------------------------------------------------------
-- Versioned derived writers
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rate_user(p_target_id UUID, p_stars FLOAT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_avg FLOAT;
  v_count INTEGER;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;
  IF v_actor = p_target_id THEN
    RETURN jsonb_build_object('error', 'self_rate');
  END IF;
  IF p_stars IS NULL OR p_stars < 1 OR p_stars > 5 THEN
    RETURN jsonb_build_object('error', 'invalid_stars');
  END IF;

  INSERT INTO public.user_ratings (rater_id, target_id, stars)
  VALUES (v_actor, p_target_id, p_stars)
  ON CONFLICT (rater_id, target_id)
  DO UPDATE SET stars = EXCLUDED.stars, updated_at = now();

  SELECT AVG(stars), COUNT(*) INTO v_avg, v_count
  FROM public.user_ratings
  WHERE target_id = p_target_id;

  UPDATE public.users
  SET rating_stars = ROUND(v_avg::NUMERIC, 1), rating_count = v_count
  WHERE id = p_target_id;

  RETURN jsonb_build_object(
    'new_avg', ROUND(v_avg::NUMERIC, 1),
    'total_ratings', v_count
  );
END;
$$;

ALTER FUNCTION public.rate_user(UUID, DOUBLE PRECISION) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rate_user(UUID, DOUBLE PRECISION)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rate_user(UUID, DOUBLE PRECISION)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_sync_like_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.users SET like_count = like_count + 1
    WHERE id = NEW.pitch_owner_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.users SET like_count = GREATEST(0, like_count - 1)
    WHERE id = OLD.pitch_owner_id;
  END IF;
  RETURN NULL;
END;
$$;

ALTER FUNCTION public.fn_sync_like_count() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.fn_sync_like_count()
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.fn_sync_connection_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.status = 'accepted' THEN
    UPDATE public.users SET connections = connections + 1
    WHERE id IN (NEW.requester_id, NEW.addressee_id);
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.status <> 'accepted' AND NEW.status = 'accepted' THEN
      UPDATE public.users SET connections = connections + 1
      WHERE id IN (NEW.requester_id, NEW.addressee_id);
    ELSIF OLD.status = 'accepted' AND NEW.status <> 'accepted' THEN
      UPDATE public.users SET connections = GREATEST(0, connections - 1)
      WHERE id IN (NEW.requester_id, NEW.addressee_id);
    END IF;
  ELSIF TG_OP = 'DELETE' AND OLD.status = 'accepted' THEN
    UPDATE public.users SET connections = GREATEST(0, connections - 1)
    WHERE id IN (OLD.requester_id, OLD.addressee_id);
  END IF;
  RETURN NULL;
END;
$$;

ALTER FUNCTION public.fn_sync_connection_count() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.fn_sync_connection_count()
  FROM PUBLIC, anon, authenticated, service_role;

COMMENT ON FUNCTION public.protect_user_privileged_columns() IS
  'Blocks direct client writes to administrative, economic and derived users columns. Internal SECURITY DEFINER and service-role writers require separate authorization audits.';

COMMIT;

NOTIFY pgrst, 'reload schema';

-- ============================================================================
-- PRE-FLIGHT AUDIT (READ ONLY; run and review before setting the confirmation)
-- ============================================================================
-- SELECT id FROM public.users WHERE is_admin IS TRUE;
-- SELECT id FROM public.users WHERE is_premium IS TRUE;
-- SELECT id FROM public.users WHERE is_verified IS TRUE;
-- SELECT id, b2b_tokens FROM public.users WHERE COALESCE(b2b_tokens, 0) <> 0;
-- SELECT id, boost_started_at, boost_ends_at, boost_type, boost_target_city
-- FROM public.users WHERE boost_ends_at > now();
-- SELECT id, profile_views, match_percentage, rating_stars, rating_count,
--        like_count, connections, employer_rating_stars, employer_rating_count
-- FROM public.users
-- WHERE COALESCE(profile_views, 0) < 0
--    OR COALESCE(match_percentage, 0) NOT BETWEEN 0 AND 100
--    OR COALESCE(rating_stars, 0) NOT BETWEEN 0 AND 5
--    OR COALESCE(rating_count, 0) < 0
--    OR COALESCE(like_count, 0) < 0
--    OR COALESCE(connections, 0) < 0
--    OR COALESCE(employer_rating_stars, 0) NOT BETWEEN 0 AND 5
--    OR COALESCE(employer_rating_count, 0) < 0;
-- No query above mutates, deletes, corrects or migrates historical data.
