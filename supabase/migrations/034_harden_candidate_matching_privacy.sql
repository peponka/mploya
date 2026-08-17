-- ============================================================================
-- 034 - Private candidate matching, opaque handles and atomic unlock ledger
-- ============================================================================
-- Live schema audited read-only on 2026-08-16.
--
-- Contract correction: get_company_candidates currently returns 20 columns,
-- not 21. Preflight locks the exact live 20-column contract before appending
-- three named privacy fields for map-based Flutter consumers.
--
-- Deployment order: 032, then 033, then this migration.
-- ============================================================================

BEGIN;

-- Fail closed if the live database differs from the audited contract.
DO $$
DECLARE
  v_result TEXT;
  v_columns TEXT;
  v_historical_unlocks BIGINT;
BEGIN
  IF to_regprocedure('public.get_my_profile()') IS NULL
    OR to_regclass('public.safe_user_profiles') IS NULL
  THEN
    RAISE EXCEPTION '034 precondition: migration 032 is not applied';
  END IF;

  IF to_regclass('public.admin_memberships') IS NULL
    OR to_regprocedure('public.is_admin()') IS NULL
    OR to_regprocedure('public.protect_user_privileged_columns()') IS NULL
  THEN
    RAISE EXCEPTION '034 precondition: migration 033 is not applied';
  END IF;

  IF to_regprocedure(
      'public.match_candidates_for_job(uuid,integer,double precision)'
    ) IS NULL
    OR to_regprocedure('public.get_company_candidates(text)') IS NULL
    OR to_regprocedure('public.get_stealth_catalog()') IS NULL
    OR to_regprocedure('public.unlock_stealth_profile(uuid)') IS NULL
    OR to_regprocedure('public.claim_welcome_credits()') IS NULL
  THEN
    RAISE EXCEPTION '034 precondition: an audited RPC signature is missing';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    WHERE p.oid IN (
      to_regprocedure(
        'public.match_candidates_for_job(uuid,integer,double precision)'
      )::oid,
      to_regprocedure('public.get_company_candidates(text)')::oid,
      to_regprocedure('public.get_stealth_catalog()')::oid,
      to_regprocedure('public.unlock_stealth_profile(uuid)')::oid,
      to_regprocedure('public.claim_welcome_credits()')::oid
    )
      AND pg_get_userbyid(p.proowner) NOT IN (
        'postgres', 'service_role', 'supabase_admin'
      )
  ) THEN
    RAISE EXCEPTION '034 precondition: an audited RPC has an unexpected owner';
  END IF;

  SELECT pg_get_function_result(
    to_regprocedure('public.get_company_candidates(text)')::oid
  ) INTO v_result;
  IF v_result IS DISTINCT FROM
    'TABLE(application_id uuid, candidate_id uuid, candidate_name text, candidate_headline text, candidate_avatar_url text, candidate_tags text[], candidate_video_url text, candidate_location text, candidate_salary_expectation text, candidate_is_verified boolean, candidate_open_to_work boolean, candidate_rating_stars double precision, candidate_rating_count integer, candidate_experience jsonb, job_id uuid, job_title text, job_tags text[], status text, is_favorite boolean, applied_at timestamp with time zone)'
  THEN
    RAISE EXCEPTION '034 precondition: get_company_candidates return contract changed';
  END IF;

  SELECT pg_get_function_result(
    to_regprocedure(
      'public.match_candidates_for_job(uuid,integer,double precision)'
    )::oid
  ) INTO v_result;
  IF v_result IS DISTINCT FROM
    'TABLE(id uuid, name character varying, headline character varying, avatar_url text, account_type character varying, tags text[], similarity double precision, semantic_score double precision, skill_score double precision)'
  THEN
    RAISE EXCEPTION '034 precondition: match_candidates_for_job return contract changed';
  END IF;

  SELECT pg_get_function_result(
    to_regprocedure('public.get_stealth_catalog()')::oid
  ) INTO v_result;
  IF v_result IS DISTINCT FROM
    'TABLE(candidate_id uuid, headline text, about text, tags text[], budget text, is_unlocked boolean, real_name text)'
  THEN
    RAISE EXCEPTION '034 precondition: get_stealth_catalog return contract changed';
  END IF;

  SELECT string_agg(
    c.column_name || ':' || c.udt_name || ':' || c.is_nullable,
    ',' ORDER BY c.ordinal_position
  ) INTO v_columns
  FROM information_schema.columns c
  WHERE c.table_schema = 'public' AND c.table_name = 'company_wallets';
  IF v_columns IS DISTINCT FROM
    'company_id:uuid:NO,credits_balance:int4:NO,subscription_tier:varchar:YES,updated_at:timestamptz:NO'
  THEN
    RAISE EXCEPTION '034 precondition: company_wallets columns changed';
  END IF;

  SELECT string_agg(
    c.column_name || ':' || c.udt_name || ':' || c.is_nullable,
    ',' ORDER BY c.ordinal_position
  ) INTO v_columns
  FROM information_schema.columns c
  WHERE c.table_schema = 'public' AND c.table_name = 'profile_unlocks';
  IF v_columns IS DISTINCT FROM
    'id:uuid:NO,company_id:uuid:NO,candidate_id:uuid:NO,unlocked_at:timestamptz:NO'
  THEN
    RAISE EXCEPTION '034 precondition: profile_unlocks columns changed';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.company_wallets'::regclass
      AND conname = 'company_wallets_pkey'
      AND pg_get_constraintdef(oid) = 'PRIMARY KEY (company_id)'
  ) OR NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.profile_unlocks'::regclass
      AND conname = 'profile_unlocks_uniq'
      AND pg_get_constraintdef(oid) = 'UNIQUE (company_id, candidate_id)'
  ) THEN
    RAISE EXCEPTION '034 precondition: wallet or unlock uniqueness changed';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'jobs'
      AND column_name = 'company_id' AND data_type = 'uuid'
      AND is_nullable = 'YES'
  ) THEN
    RAISE EXCEPTION '034 precondition: jobs.company_id contract changed';
  END IF;

  SELECT count(*) INTO v_historical_unlocks FROM public.profile_unlocks;
  IF v_historical_unlocks <> 5 THEN
    RAISE EXCEPTION
      '034 precondition: expected 5 quarantined historical unlocks, found %',
      v_historical_unlocks;
  END IF;

  IF to_regclass('public.candidate_access_handles') IS NOT NULL
    OR to_regclass('public.candidate_unlock_ledger') IS NOT NULL
    OR to_regclass('public.candidate_unlock_pricing') IS NOT NULL
  THEN
    RAISE EXCEPTION '034 precondition: private unlock objects already exist';
  END IF;
END;
$$;

-- Random handles are unique per actor/candidate pair and never client-readable.
CREATE TABLE public.candidate_access_handles (
  handle UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  candidate_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  CONSTRAINT candidate_access_handles_actor_candidate_uniq
    UNIQUE (actor_id, candidate_id),
  CONSTRAINT candidate_access_handles_not_self CHECK (actor_id <> candidate_id)
);

ALTER TABLE public.candidate_access_handles OWNER TO postgres;
ALTER TABLE public.candidate_access_handles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.candidate_access_handles FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.candidate_access_handles
  FROM PUBLIC, anon, authenticated, service_role;

-- Existing product behavior fixes the price at one credit server-side.
CREATE TABLE public.candidate_unlock_pricing (
  product_key TEXT PRIMARY KEY,
  credit_cost INTEGER NOT NULL CHECK (credit_cost > 0),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT candidate_unlock_pricing_product_check
    CHECK (product_key = 'stealth_profile')
);

ALTER TABLE public.candidate_unlock_pricing OWNER TO postgres;
ALTER TABLE public.candidate_unlock_pricing ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.candidate_unlock_pricing FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.candidate_unlock_pricing
  FROM PUBLIC, anon, authenticated, service_role;
INSERT INTO public.candidate_unlock_pricing (product_key, credit_cost)
VALUES ('stealth_profile', 1);

-- Immutable, idempotent debit evidence.
CREATE TABLE public.candidate_unlock_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  candidate_id UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  candidate_handle UUID NOT NULL
    REFERENCES public.candidate_access_handles(handle) ON DELETE RESTRICT,
  credit_cost INTEGER NOT NULL CHECK (credit_cost > 0),
  balance_before INTEGER NOT NULL CHECK (balance_before >= 0),
  balance_after INTEGER NOT NULL CHECK (balance_after >= 0),
  authorization_version SMALLINT NOT NULL DEFAULT 1
    CHECK (authorization_version = 1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT candidate_unlock_ledger_actor_candidate_uniq
    UNIQUE (actor_id, candidate_id),
  CONSTRAINT candidate_unlock_ledger_handle_uniq UNIQUE (candidate_handle),
  CONSTRAINT candidate_unlock_ledger_balance_check
    CHECK (balance_after = balance_before - credit_cost)
);

ALTER TABLE public.candidate_unlock_ledger OWNER TO postgres;
ALTER TABLE public.candidate_unlock_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.candidate_unlock_ledger FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.candidate_unlock_ledger
  FROM PUBLIC, anon, authenticated, service_role;

-- Quarantine legacy unlocks without updating or deleting the five rows.
DROP POLICY IF EXISTS profile_unlocks_insert_company ON public.profile_unlocks;
REVOKE ALL ON TABLE public.profile_unlocks
  FROM PUBLIC, anon, authenticated, service_role;
ALTER TABLE public.profile_unlocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_unlocks FORCE ROW LEVEL SECURITY;

ALTER TABLE public.profile_unlocks
  ADD COLUMN authorization_version SMALLINT,
  ADD COLUMN authorization_ledger_id UUID;
ALTER TABLE public.profile_unlocks
  ADD CONSTRAINT profile_unlocks_authorization_version_check
    CHECK (authorization_version IS NULL OR authorization_version = 1),
  ADD CONSTRAINT profile_unlocks_authorization_pair_check
    CHECK (
      (authorization_version IS NULL AND authorization_ledger_id IS NULL)
      OR (authorization_version = 1 AND authorization_ledger_id IS NOT NULL)
    ),
  ADD CONSTRAINT profile_unlocks_authorization_ledger_fkey
    FOREIGN KEY (authorization_ledger_id)
    REFERENCES public.candidate_unlock_ledger(id) ON DELETE RESTRICT;

ALTER TABLE public.profile_unlocks DROP CONSTRAINT profile_unlocks_uniq;
CREATE UNIQUE INDEX profile_unlocks_authorized_pair_uniq
  ON public.profile_unlocks (company_id, candidate_id)
  WHERE authorization_version = 1;
CREATE UNIQUE INDEX profile_unlocks_authorized_ledger_uniq
  ON public.profile_unlocks (authorization_ledger_id)
  WHERE authorization_ledger_id IS NOT NULL;

-- Wallet remains owner-readable; clients lose all mutation privileges.
REVOKE ALL ON TABLE public.company_wallets FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.company_wallets TO authenticated;
ALTER TABLE public.company_wallets FORCE ROW LEVEL SECURITY;

-- Locked catalog rows expose only a per-actor random handle and generic name.
DROP FUNCTION public.get_stealth_catalog();
CREATE FUNCTION public.get_stealth_catalog()
RETURNS TABLE (
  candidate_handle UUID,
  candidate_id UUID,
  is_unlocked BOOLEAN,
  unlocked_at TIMESTAMPTZ,
  real_name TEXT,
  headline TEXT,
  about TEXT,
  tags TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_actor_type TEXT;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'get_stealth_catalog: catalogo no disponible'
      USING ERRCODE = '28000';
  END IF;

  SELECT lower(btrim(COALESCE(u.account_type::TEXT, '')))
  INTO v_actor_type
  FROM public.users u
  WHERE u.id = v_actor AND u.deleted_at IS NULL;
  IF NOT FOUND OR v_actor_type NOT IN ('empresa', 'headhunter') THEN
    RAISE EXCEPTION 'get_stealth_catalog: catalogo no disponible'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.candidate_access_handles (actor_id, candidate_id)
  SELECT v_actor, u.id
  FROM public.users u
  WHERE u.id <> v_actor
    AND u.deleted_at IS NULL
    AND (
      lower(btrim(COALESCE(u.account_type::TEXT, ''))) = 'stealth'
      OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidenc%'
      OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidential%'
    )
  ON CONFLICT ON CONSTRAINT candidate_access_handles_actor_candidate_uniq
    DO NOTHING;

  RETURN QUERY
  SELECT
    h.handle,
    CASE WHEN authorized.unlock_id IS NOT NULL THEN u.id ELSE NULL::UUID END,
    authorized.unlock_id IS NOT NULL,
    authorized.unlocked_at,
    CASE WHEN authorized.unlock_id IS NOT NULL
      THEN u.name::TEXT ELSE 'Confidencial'::TEXT END,
    CASE WHEN authorized.unlock_id IS NOT NULL
      THEN u.headline::TEXT ELSE NULL::TEXT END,
    CASE WHEN authorized.unlock_id IS NOT NULL
      THEN u.about::TEXT ELSE NULL::TEXT END,
    CASE WHEN authorized.unlock_id IS NOT NULL
      THEN COALESCE(u.tags, '{}')::TEXT[] ELSE '{}'::TEXT[] END
  FROM public.candidate_access_handles h
  JOIN public.users u ON u.id = h.candidate_id
  LEFT JOIN LATERAL (
    SELECT pu.id AS unlock_id, pu.unlocked_at
    FROM public.profile_unlocks pu
    JOIN public.candidate_unlock_ledger ledger
      ON ledger.id = pu.authorization_ledger_id
      AND ledger.actor_id = pu.company_id
      AND ledger.candidate_id = pu.candidate_id
      AND ledger.authorization_version = 1
    WHERE pu.company_id = v_actor
      AND pu.candidate_id = u.id
      AND pu.authorization_version = 1
    LIMIT 1
  ) authorized ON TRUE
  WHERE h.actor_id = v_actor
    AND h.revoked_at IS NULL
    AND (h.expires_at IS NULL OR h.expires_at > now())
    AND u.deleted_at IS NULL
    AND (
      lower(btrim(COALESCE(u.account_type::TEXT, ''))) = 'stealth'
      OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidenc%'
      OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidential%'
    )
  ORDER BY (authorized.unlock_id IS NOT NULL) DESC, h.created_at;
END;
$$;

ALTER FUNCTION public.get_stealth_catalog() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_stealth_catalog()
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_stealth_catalog() TO authenticated;

-- Handle resolution, debit, ledger and authorization are one transaction.
DROP FUNCTION public.unlock_stealth_profile(UUID);
CREATE FUNCTION public.unlock_stealth_profile(p_candidate_handle UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_actor_type TEXT;
  v_candidate UUID;
  v_cost INTEGER;
  v_balance INTEGER;
  v_ledger_id UUID := gen_random_uuid();
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;
  IF p_candidate_handle IS NULL THEN
    RETURN jsonb_build_object('error', 'candidate_unavailable');
  END IF;

  SELECT lower(btrim(COALESCE(u.account_type::TEXT, '')))
  INTO v_actor_type
  FROM public.users u
  WHERE u.id = v_actor AND u.deleted_at IS NULL;
  IF NOT FOUND OR v_actor_type NOT IN ('empresa', 'headhunter') THEN
    RETURN jsonb_build_object('error', 'not_allowed');
  END IF;

  SELECT h.candidate_id
  INTO v_candidate
  FROM public.candidate_access_handles h
  JOIN public.users u ON u.id = h.candidate_id
  WHERE h.handle = p_candidate_handle
    AND h.actor_id = v_actor
    AND h.revoked_at IS NULL
    AND (h.expires_at IS NULL OR h.expires_at > now())
    AND u.deleted_at IS NULL
    AND (
      lower(btrim(COALESCE(u.account_type::TEXT, ''))) = 'stealth'
      OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidenc%'
      OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidential%'
    )
  FOR UPDATE OF h;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'candidate_unavailable');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.profile_unlocks pu
    JOIN public.candidate_unlock_ledger ledger
      ON ledger.id = pu.authorization_ledger_id
      AND ledger.actor_id = v_actor
      AND ledger.candidate_id = v_candidate
      AND ledger.authorization_version = 1
    WHERE pu.company_id = v_actor
      AND pu.candidate_id = v_candidate
      AND pu.authorization_version = 1
  ) THEN
    RETURN jsonb_build_object('status', 'already_unlocked');
  END IF;

  SELECT pricing.credit_cost INTO v_cost
  FROM public.candidate_unlock_pricing pricing
  WHERE pricing.product_key = 'stealth_profile' AND pricing.active IS TRUE;
  IF NOT FOUND OR v_cost IS NULL OR v_cost <= 0 THEN
    RETURN jsonb_build_object('error', 'configuration_unavailable');
  END IF;

  SELECT wallet.credits_balance INTO v_balance
  FROM public.company_wallets wallet
  WHERE wallet.company_id = v_actor
  FOR UPDATE;
  IF NOT FOUND OR v_balance < v_cost THEN
    RETURN jsonb_build_object(
      'error', 'insufficient_funds', 'balance', COALESCE(v_balance, 0)
    );
  END IF;

  UPDATE public.company_wallets
  SET credits_balance = v_balance - v_cost, updated_at = now()
  WHERE company_id = v_actor;

  INSERT INTO public.candidate_unlock_ledger (
    id, actor_id, candidate_id, candidate_handle, credit_cost,
    balance_before, balance_after, authorization_version
  ) VALUES (
    v_ledger_id, v_actor, v_candidate, p_candidate_handle, v_cost,
    v_balance, v_balance - v_cost, 1
  );
  INSERT INTO public.profile_unlocks (
    company_id, candidate_id, unlocked_at,
    authorization_version, authorization_ledger_id
  ) VALUES (v_actor, v_candidate, now(), 1, v_ledger_id);

  RETURN jsonb_build_object(
    'status', 'success', 'remaining_balance', v_balance - v_cost
  );
END;
$$;

ALTER FUNCTION public.unlock_stealth_profile(UUID) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.unlock_stealth_profile(UUID)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.unlock_stealth_profile(UUID) TO authenticated;

-- Match IA preserves its nine output columns and excludes locked profiles.
CREATE OR REPLACE FUNCTION public.match_candidates_for_job(
  p_job_id UUID,
  p_limit INTEGER DEFAULT 20,
  p_min_score DOUBLE PRECISION DEFAULT 0.25
)
RETURNS TABLE (
  id UUID, name VARCHAR, headline VARCHAR, avatar_url TEXT,
  account_type VARCHAR, tags TEXT[], similarity DOUBLE PRECISION,
  semantic_score DOUBLE PRECISION, skill_score DOUBLE PRECISION
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_actor_type TEXT;
  v_owner UUID;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'match_candidates_for_job: vacante no disponible'
      USING ERRCODE = '28000';
  END IF;
  SELECT lower(btrim(COALESCE(u.account_type::TEXT, '')))
  INTO v_actor_type
  FROM public.users u
  WHERE u.id = v_actor AND u.deleted_at IS NULL;
  IF NOT FOUND OR v_actor_type NOT IN ('empresa', 'headhunter') THEN
    RAISE EXCEPTION 'match_candidates_for_job: vacante no disponible'
      USING ERRCODE = '42501';
  END IF;
  SELECT j.company_id INTO v_owner FROM public.jobs j WHERE j.id = p_job_id;
  IF NOT FOUND OR v_owner IS NULL OR v_owner IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'match_candidates_for_job: vacante no disponible'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH job AS (
    SELECT j.embedding,
      COALESCE(j.tags, '{}')::TEXT[] ||
        COALESCE(j.skills, '{}')::TEXT[] AS wanted
    FROM public.jobs j
    WHERE j.id = p_job_id AND j.company_id = v_actor
      AND j.company_id IS NOT NULL AND j.embedding IS NOT NULL
  ),
  scored AS (
    SELECT u.id, u.name, u.headline, u.avatar_url, u.account_type,
      COALESCE(u.tags, '{}')::TEXT[] AS candidate_tags,
      public.rescale_similarity(
        1 - (u.profile_embedding <=> job.embedding)
      ) AS semantic_value,
      public.skill_overlap(
        job.wanted, COALESCE(u.tags, '{}')::TEXT[]
      ) AS skill_value,
      (
        lower(btrim(COALESCE(u.account_type::TEXT, ''))) = 'stealth'
        OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidenc%'
        OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidential%'
      ) AS confidential,
      EXISTS (
        SELECT 1 FROM public.profile_unlocks pu
        JOIN public.candidate_unlock_ledger ledger
          ON ledger.id = pu.authorization_ledger_id
          AND ledger.actor_id = v_actor
          AND ledger.candidate_id = u.id
          AND ledger.authorization_version = 1
        WHERE pu.company_id = v_actor AND pu.candidate_id = u.id
          AND pu.authorization_version = 1
      ) AS unlocked
    FROM job JOIN public.users u ON TRUE
    WHERE u.profile_embedding IS NOT NULL AND u.deleted_at IS NULL
      AND u.id <> v_actor
      AND (
        lower(btrim(COALESCE(u.account_type::TEXT, ''))) = 'candidato'
        OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) = 'stealth'
        OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidenc%'
        OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidential%'
      )
  )
  SELECT s.id, s.name::VARCHAR, s.headline::VARCHAR, s.avatar_url,
    s.account_type::VARCHAR, s.candidate_tags,
    0.7 * s.semantic_value + 0.3 * s.skill_value,
    s.semantic_value, s.skill_value
  FROM scored s
  WHERE (NOT s.confidential OR s.unlocked)
    AND (0.7 * s.semantic_value + 0.3 * s.skill_value) >=
      LEAST(GREATEST(COALESCE(p_min_score, 0.25), 0.0), 1.0)
  ORDER BY (0.7 * s.semantic_value + 0.3 * s.skill_value) DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100);
END;
$$;

ALTER FUNCTION public.match_candidates_for_job(
  UUID, INTEGER, DOUBLE PRECISION
) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.match_candidates_for_job(
  UUID, INTEGER, DOUBLE PRECISION
) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.match_candidates_for_job(
  UUID, INTEGER, DOUBLE PRECISION
) TO authenticated;

-- Applications keep the 20 live fields and append three privacy fields.
-- Locked confidential rows are excluded; candidate_id is never null.
DROP FUNCTION public.get_company_candidates(TEXT);
CREATE FUNCTION public.get_company_candidates(
  p_status TEXT DEFAULT NULL,
  p_job_id UUID DEFAULT NULL
)
RETURNS TABLE (
  application_id UUID, candidate_id UUID, candidate_name TEXT,
  candidate_headline TEXT, candidate_avatar_url TEXT, candidate_tags TEXT[],
  candidate_video_url TEXT, candidate_location TEXT,
  candidate_salary_expectation TEXT, candidate_is_verified BOOLEAN,
  candidate_open_to_work BOOLEAN, candidate_rating_stars DOUBLE PRECISION,
  candidate_rating_count INTEGER, candidate_experience JSONB, job_id UUID,
  job_title TEXT, job_tags TEXT[], status TEXT, is_favorite BOOLEAN,
  applied_at TIMESTAMPTZ, candidate_account_type TEXT,
  is_confidential BOOLEAN, is_unlocked BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_actor_type TEXT;
  v_owner UUID;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'get_company_candidates: vacante no disponible'
      USING ERRCODE = '28000';
  END IF;
  SELECT lower(btrim(COALESCE(u.account_type::TEXT, '')))
  INTO v_actor_type
  FROM public.users u
  WHERE u.id = v_actor AND u.deleted_at IS NULL;
  IF NOT FOUND OR v_actor_type NOT IN ('empresa', 'headhunter') THEN
    RAISE EXCEPTION 'get_company_candidates: vacante no disponible'
      USING ERRCODE = '42501';
  END IF;
  IF p_job_id IS NOT NULL THEN
    SELECT j.company_id INTO v_owner FROM public.jobs j WHERE j.id = p_job_id;
    IF NOT FOUND OR v_owner IS NULL OR v_owner IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION 'get_company_candidates: vacante no disponible'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN QUERY
  WITH owned AS (
    SELECT ja.*, j.title AS owned_job_title, j.tags AS owned_job_tags,
      u.name AS private_name, u.headline AS private_headline,
      u.avatar_url AS private_avatar_url, u.tags AS private_tags,
      u.video_url AS private_video_url, u.location AS private_location,
      u.salary_expectation AS private_salary_expectation,
      u.is_verified AS private_is_verified,
      u.open_to_work AS private_open_to_work,
      u.rating_stars AS private_rating_stars,
      u.rating_count AS private_rating_count,
      u.experience AS private_experience,
      u.account_type AS private_account_type,
      (
        lower(btrim(COALESCE(u.account_type::TEXT, ''))) = 'stealth'
        OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidenc%'
        OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidential%'
      ) AS private_confidential,
      EXISTS (
        SELECT 1 FROM public.profile_unlocks pu
        JOIN public.candidate_unlock_ledger ledger
          ON ledger.id = pu.authorization_ledger_id
          AND ledger.actor_id = v_actor
          AND ledger.candidate_id = u.id
          AND ledger.authorization_version = 1
        WHERE pu.company_id = v_actor AND pu.candidate_id = u.id
          AND pu.authorization_version = 1
      ) AS private_unlocked
    FROM public.job_applications ja
    JOIN public.jobs j ON j.id = ja.job_id
    JOIN public.users u ON u.id = ja.candidate_id
    WHERE j.company_id = v_actor AND j.company_id IS NOT NULL
      AND (p_job_id IS NULL OR j.id = p_job_id)
      AND (p_status IS NULL OR ja.status = p_status)
      AND u.deleted_at IS NULL
  )
  SELECT o.id, o.candidate_id, o.private_name::TEXT,
    o.private_headline::TEXT, o.private_avatar_url::TEXT,
    COALESCE(o.private_tags, '{}')::TEXT[], o.private_video_url::TEXT,
    o.private_location::TEXT, o.private_salary_expectation::TEXT,
    o.private_is_verified, o.private_open_to_work,
    o.private_rating_stars, o.private_rating_count, o.private_experience,
    o.job_id, o.owned_job_title::TEXT, o.owned_job_tags, o.status::TEXT,
    o.is_favorite, o.created_at,
    lower(btrim(COALESCE(o.private_account_type::TEXT, ''))),
    o.private_confidential, (o.private_confidential AND o.private_unlocked)
  FROM owned o
  WHERE NOT o.private_confidential OR o.private_unlocked
  ORDER BY o.created_at DESC
  LIMIT 200;
END;
$$;

ALTER FUNCTION public.get_company_candidates(TEXT, UUID) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_company_candidates(TEXT, UUID)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_company_candidates(TEXT, UUID)
  TO authenticated;

COMMENT ON TABLE public.candidate_access_handles IS
  'Private random handles scoped to one actor and confidential candidate.';
COMMENT ON TABLE public.candidate_unlock_ledger IS
  'Immutable version-1 debit evidence for one authorized profile unlock.';
COMMENT ON FUNCTION public.get_stealth_catalog() IS
  'Opaque catalog. Locked rows expose no candidate UUID or identifying data.';
COMMENT ON FUNCTION public.unlock_stealth_profile(UUID) IS
  'Resolves an actor-scoped handle and debits the server price atomically.';
COMMENT ON FUNCTION public.match_candidates_for_job(
  UUID, INTEGER, DOUBLE PRECISION
) IS
  'Owned-job ranking; confidential candidates require a ledger-backed unlock.';
COMMENT ON FUNCTION public.get_company_candidates(TEXT, UUID) IS
  'Owned applications; locked confidential rows are excluded.';

COMMIT;

NOTIFY pgrst, 'reload schema';

-- Staging-only validation matrix: anon/null session; Empresa and Headhunter
-- owner; foreign/missing/null-owner job; normal/confidenc*/confidential*/
-- stealth; blocked exclusion; unlocked inclusion; actor-scoped handles;
-- foreign/revoked handle; insufficient funds; successful debit; idempotent
-- retry; direct INSERT denied; five legacy rows remain version NULL; PII absent
-- before and available after; PUBLIC/anon/service_role denied on all four RPCs.
