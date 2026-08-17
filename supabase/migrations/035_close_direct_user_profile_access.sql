-- ============================================================================
-- 035 - Close direct user profile access and expose least-privilege contracts
-- ============================================================================
-- Deployment order: 032, 033, 034, then this migration.
-- This migration is intentionally incompatible with clients that still query
-- public.users directly. Deploy only with the matching web client.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_missing TEXT[];
  v_legacy_unlocks BIGINT;
BEGIN
  IF to_regprocedure('public.get_my_profile()') IS NULL
    OR to_regprocedure('public.is_admin()') IS NULL
    OR to_regprocedure('public.get_stealth_catalog()') IS NULL
    OR to_regprocedure('public.get_explore_pins(double precision,double precision,double precision)') IS NULL
    OR to_regclass('public.candidate_unlock_ledger') IS NULL
    OR to_regclass('public.profile_unlocks') IS NULL
  THEN
    RAISE EXCEPTION '035 precondition: migrations 032-034 are required';
  END IF;

  SELECT array_agg(required.column_name ORDER BY required.column_name)
  INTO v_missing
  FROM unnest(ARRAY[
    'id', 'name', 'headline', 'about', 'video_url', 'skills', 'experience',
    'education', 'is_premium', 'is_verified', 'open_to_work', 'location',
    'created_at', 'avatar_url', 'banner_url', 'company', 'profile_views',
    'is_hiring', 'match_percentage', 'rating_stars', 'rating_count',
    'like_count', 'connections', 'ai_transcript_json', 'account_type', 'tags',
    'city', 'salary_expectation', 'soft_skills', 'employer_rating_stars',
    'employer_rating_count', 'personality_scores', 'deleted_at', 'fcm_token',
    'transcript_url', 'latitude', 'longitude', 'boost_started_at',
    'boost_ends_at', 'profile_embedding', 'push_enabled',
    'email_notifications_enabled', 'job_alerts_enabled', 'blind_hiring_mode'
  ]) AS required(column_name)
  WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.columns c
    WHERE c.table_schema = 'public' AND c.table_name = 'users'
      AND c.column_name = required.column_name
  );
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION '035 precondition: public.users columns missing: %', v_missing;
  END IF;

  SELECT COUNT(*) INTO v_legacy_unlocks
  FROM public.profile_unlocks
  WHERE authorization_version IS NULL;
  IF v_legacy_unlocks <> 5 THEN
    RAISE EXCEPTION
      '035 precondition: expected five quarantined historical unlocks, found %',
      v_legacy_unlocks;
  END IF;
END;
$$;

-- A normal public profile never includes confidential account families. The
-- owner privileges of this view cannot bypass privacy because the exclusion is
-- part of the view predicate and only an explicit public column list exists.
DROP VIEW IF EXISTS public.feed_ranked;
DROP VIEW IF EXISTS public.accessible_user_profiles;
DROP VIEW IF EXISTS public.safe_user_profiles;

CREATE VIEW public.safe_user_profiles
WITH (security_barrier = true, security_invoker = false)
AS
SELECT
  u.id,
  u.name::TEXT AS name,
  u.headline::TEXT AS headline,
  u.about::TEXT AS about,
  u.video_url,
  u.skills,
  u.experience,
  u.education,
  u.is_premium,
  u.is_verified,
  u.open_to_work,
  u.created_at,
  u.avatar_url,
  u.banner_url,
  u.company,
  u.profile_views,
  u.is_hiring,
  u.rating_stars,
  u.rating_count,
  u.like_count,
  u.connections,
  u.account_type::TEXT AS account_type,
  u.tags,
  u.city,
  u.soft_skills,
  u.employer_rating_stars,
  u.employer_rating_count
FROM public.users u
WHERE u.deleted_at IS NULL
  AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) <> 'stealth'
  AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) NOT LIKE 'confidenc%'
  AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) NOT LIKE 'confidential%';

ALTER VIEW public.safe_user_profiles OWNER TO postgres;
REVOKE ALL ON public.safe_user_profiles
  FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.safe_user_profiles TO anon, authenticated;

-- Authenticated clients use this projection. Confidential identities appear
-- only when 034 has produced both version-1 authorization and matching ledger.
CREATE VIEW public.accessible_user_profiles
WITH (security_barrier = true, security_invoker = false)
AS
SELECT
  u.id,
  u.name::TEXT AS name,
  u.headline::TEXT AS headline,
  u.about::TEXT AS about,
  u.video_url,
  u.transcript_url,
  u.skills,
  u.experience,
  u.education,
  u.is_premium,
  u.is_verified,
  u.open_to_work,
  u.location::TEXT AS location,
  u.created_at,
  u.avatar_url,
  u.banner_url,
  u.company,
  u.profile_views,
  u.is_hiring,
  u.match_percentage,
  u.rating_stars,
  u.rating_count,
  u.like_count,
  u.connections,
  u.ai_transcript_json,
  u.account_type::TEXT AS account_type,
  u.tags,
  u.city,
  u.salary_expectation,
  u.soft_skills,
  u.employer_rating_stars,
  u.employer_rating_count,
  u.personality_scores
FROM public.users u
WHERE u.deleted_at IS NULL
  AND (
    u.id = auth.uid()
    OR
    (
      lower(btrim(COALESCE(u.account_type::TEXT, ''))) <> 'stealth'
      AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) NOT LIKE 'confidenc%'
      AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) NOT LIKE 'confidential%'
    )
    OR EXISTS (
      SELECT 1
      FROM public.profile_unlocks pu
      JOIN public.candidate_unlock_ledger ledger
        ON ledger.id = pu.authorization_ledger_id
       AND ledger.actor_id = pu.company_id
       AND ledger.candidate_id = pu.candidate_id
       AND ledger.authorization_version = 1
      JOIN public.users actor ON actor.id = pu.company_id
      WHERE pu.company_id = auth.uid()
        AND pu.candidate_id = u.id
        AND pu.authorization_version = 1
        AND actor.deleted_at IS NULL
        AND lower(btrim(COALESCE(actor.account_type::TEXT, '')))
          IN ('empresa', 'headhunter')
    )
  );

ALTER VIEW public.accessible_user_profiles OWNER TO postgres;
REVOKE ALL ON public.accessible_user_profiles
  FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.accessible_user_profiles TO authenticated;

-- Feed keeps paid ordering server-side without exposing boost timestamps,
-- target cities or billing state. Locked confidential profiles never enter.
CREATE VIEW public.feed_ranked
WITH (security_barrier = true, security_invoker = false)
AS
SELECT
  p.*,
  (CASE WHEN u.boost_ends_at > now() THEN 1000 ELSE 0 END)
    + (CASE WHEN u.is_premium THEN 100 ELSE 0 END) AS base_score
FROM public.accessible_user_profiles p
JOIN public.users u ON u.id = p.id
WHERE p.video_url IS NOT NULL AND p.video_url <> '';

ALTER VIEW public.feed_ranked OWNER TO postgres;
REVOKE ALL ON public.feed_ranked FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.feed_ranked TO authenticated;

-- 032 established the private own-profile contract. Now that every remaining
-- own consumer uses it, preserve the contextual match field that Profile read
-- previously without adding privileged, economic or internal columns.
DROP FUNCTION public.get_my_profile();
CREATE FUNCTION public.get_my_profile()
RETURNS TABLE (
  id UUID, name TEXT, headline TEXT, about TEXT, video_url TEXT, skills JSONB,
  experience JSONB, education JSONB, is_premium BOOLEAN, is_verified BOOLEAN,
  open_to_work BOOLEAN, location TEXT, created_at TIMESTAMPTZ, avatar_url TEXT,
  banner_url TEXT, company TEXT, profile_views INTEGER, is_hiring BOOLEAN,
  latitude DOUBLE PRECISION, longitude DOUBLE PRECISION,
  match_percentage DOUBLE PRECISION, rating_stars DOUBLE PRECISION,
  rating_count INTEGER, like_count INTEGER, connections INTEGER,
  ai_transcript_json JSONB, account_type TEXT, tags TEXT[],
  onboarding_step INTEGER, city TEXT, salary_expectation TEXT,
  soft_skills JSONB, employer_rating_stars NUMERIC,
  employer_rating_count INTEGER, blind_hiring_mode BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_actor UUID := auth.uid();
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'get_my_profile: sesion no disponible' USING ERRCODE = '28000';
  END IF;
  RETURN QUERY
  SELECT u.id, u.name::TEXT, u.headline::TEXT, u.about::TEXT, u.video_url,
    u.skills, u.experience, u.education, u.is_premium, u.is_verified,
    u.open_to_work, u.location::TEXT, u.created_at, u.avatar_url, u.banner_url,
    u.company, u.profile_views, u.is_hiring, u.latitude, u.longitude,
    u.match_percentage, u.rating_stars, u.rating_count, u.like_count,
    u.connections, u.ai_transcript_json, u.account_type::TEXT, u.tags,
    u.onboarding_step, u.city, u.salary_expectation, u.soft_skills,
    u.employer_rating_stars, u.employer_rating_count, u.blind_hiring_mode
  FROM public.users u WHERE u.id = v_actor AND u.deleted_at IS NULL;
END;
$$;

-- Private own-account mutations that remain required by the existing client.
CREATE OR REPLACE FUNCTION public.update_my_setting(p_key TEXT, p_value BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_actor IS NULL OR p_value IS NULL THEN
    RAISE EXCEPTION 'update_my_setting: solicitud no disponible'
      USING ERRCODE = '28000';
  END IF;
  SELECT lower(btrim(COALESCE(account_type::TEXT, ''))) INTO v_role
  FROM public.users WHERE id = v_actor AND deleted_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'update_my_setting: solicitud no disponible'
      USING ERRCODE = '42501';
  END IF;

  CASE p_key
    WHEN 'push_enabled' THEN
      UPDATE public.users SET push_enabled = p_value WHERE id = v_actor;
    WHEN 'email_notifications_enabled' THEN
      UPDATE public.users SET email_notifications_enabled = p_value WHERE id = v_actor;
    WHEN 'job_alerts_enabled' THEN
      UPDATE public.users SET job_alerts_enabled = p_value WHERE id = v_actor;
    WHEN 'blind_hiring_mode' THEN
      IF v_role NOT IN ('empresa', 'headhunter') THEN
        RAISE EXCEPTION 'update_my_setting: opcion no permitida' USING ERRCODE = '42501';
      END IF;
      UPDATE public.users SET blind_hiring_mode = p_value WHERE id = v_actor;
    WHEN 'is_hiring' THEN
      IF v_role NOT IN ('empresa', 'headhunter') THEN
        RAISE EXCEPTION 'update_my_setting: opcion no permitida' USING ERRCODE = '42501';
      END IF;
      UPDATE public.users SET is_hiring = p_value WHERE id = v_actor;
    ELSE
      RAISE EXCEPTION 'update_my_setting: opcion desconocida' USING ERRCODE = '22023';
  END CASE;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_my_fcm_token(p_token TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_actor UUID := auth.uid();
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'set_my_fcm_token: sesion no disponible' USING ERRCODE = '28000';
  END IF;
  IF p_token IS NOT NULL AND (btrim(p_token) = '' OR length(p_token) > 4096) THEN
    RAISE EXCEPTION 'set_my_fcm_token: token invalido' USING ERRCODE = '22023';
  END IF;
  UPDATE public.users SET fcm_token = p_token WHERE id = v_actor AND deleted_at IS NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_my_profile_analysis(
  p_kind TEXT,
  p_value JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_actor UUID := auth.uid();
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'set_my_profile_analysis: sesion no disponible' USING ERRCODE = '28000';
  END IF;
  IF p_value IS NOT NULL AND octet_length(p_value::TEXT) > 262144 THEN
    RAISE EXCEPTION 'set_my_profile_analysis: contenido invalido' USING ERRCODE = '22023';
  END IF;
  CASE p_kind
    WHEN 'soft_skills' THEN
      UPDATE public.users SET soft_skills = p_value WHERE id = v_actor AND deleted_at IS NULL;
    WHEN 'ai_transcript_json' THEN
      IF p_value IS NOT NULL AND jsonb_typeof(p_value) <> 'array' THEN
        RAISE EXCEPTION 'set_my_profile_analysis: contenido invalido' USING ERRCODE = '22023';
      END IF;
      UPDATE public.users SET ai_transcript_json = p_value WHERE id = v_actor AND deleted_at IS NULL;
    WHEN 'personality_scores' THEN
      IF p_value IS NOT NULL AND jsonb_typeof(p_value) <> 'object' THEN
        RAISE EXCEPTION 'set_my_profile_analysis: contenido invalido' USING ERRCODE = '22023';
      END IF;
      UPDATE public.users SET personality_scores = p_value WHERE id = v_actor AND deleted_at IS NULL;
    ELSE
      RAISE EXCEPTION 'set_my_profile_analysis: tipo desconocido' USING ERRCODE = '22023';
  END CASE;
END;
$$;

-- Preserve avatar behavior for every own role while retaining the Storage
-- ownership check introduced by 032.
CREATE OR REPLACE FUNCTION public.set_my_profile_avatar(p_avatar_url TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_expected_path TEXT;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'set_my_profile_avatar: sesion no disponible' USING ERRCODE = '28000';
  END IF;
  v_expected_path := '/storage/v1/object/public/videos/avatars/' || v_actor::TEXT || '.jpg';
  IF p_avatar_url IS NOT NULL AND position(v_expected_path IN p_avatar_url) = 0 THEN
    RAISE EXCEPTION 'set_my_profile_avatar: origen de storage no permitido' USING ERRCODE = '22023';
  END IF;
  UPDATE public.users SET avatar_url = p_avatar_url
  WHERE id = v_actor AND deleted_at IS NULL;
END;
$$;

-- Private entitlement dates are needed only to render the current actor's
-- existing boost result. They are never exposed through a public projection.
CREATE OR REPLACE FUNCTION public.get_my_profile_entitlements()
RETURNS TABLE (
  is_premium BOOLEAN,
  is_verified BOOLEAN,
  boost_started_at TIMESTAMPTZ,
  boost_ends_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT u.is_premium, u.is_verified, u.boost_started_at, u.boost_ends_at
  FROM public.users u
  WHERE u.id = auth.uid() AND u.deleted_at IS NULL;
$$;

-- Distance is calculated server-side so exact coordinates never cross the API
-- boundary. Locked confidential candidates are omitted unless 034 granted a
-- version-1 authorization backed by the matching immutable ledger row.
CREATE OR REPLACE FUNCTION public.search_accessible_talent(
  p_text TEXT DEFAULT '',
  p_skills TEXT[] DEFAULT '{}',
  p_city TEXT DEFAULT '',
  p_radius_km INTEGER DEFAULT NULL,
  p_only_available BOOLEAN DEFAULT FALSE,
  p_only_verified BOOLEAN DEFAULT FALSE,
  p_with_salary BOOLEAN DEFAULT FALSE,
  p_limit INTEGER DEFAULT 60
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  headline TEXT,
  avatar_url TEXT,
  city TEXT,
  tags TEXT[],
  is_verified BOOLEAN,
  open_to_work BOOLEAN,
  salary_expectation TEXT,
  distance_km DOUBLE PRECISION,
  actor_has_coordinates BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_actor_role TEXT;
  v_latitude DOUBLE PRECISION;
  v_longitude DOUBLE PRECISION;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'search_accessible_talent: resultados no disponibles'
      USING ERRCODE = '28000';
  END IF;

  SELECT lower(btrim(COALESCE(u.account_type::TEXT, ''))), u.latitude, u.longitude
    INTO v_actor_role, v_latitude, v_longitude
  FROM public.users u
  WHERE u.id = v_actor AND u.deleted_at IS NULL;
  IF NOT FOUND OR v_actor_role NOT IN ('empresa', 'headhunter') THEN
    RAISE EXCEPTION 'search_accessible_talent: resultados no disponibles'
      USING ERRCODE = '42501';
  END IF;
  IF p_radius_km IS NOT NULL AND (p_radius_km < 1 OR p_radius_km > 500) THEN
    RAISE EXCEPTION 'search_accessible_talent: radio invalido'
      USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  WITH candidates AS (
    SELECT
      u.*,
      CASE
        WHEN v_latitude IS NULL OR v_longitude IS NULL
          OR u.latitude IS NULL OR u.longitude IS NULL THEN NULL
        ELSE 6371.0 * 2.0 * asin(sqrt(
          power(sin(radians(u.latitude - v_latitude) / 2.0), 2)
          + cos(radians(v_latitude)) * cos(radians(u.latitude))
          * power(sin(radians(u.longitude - v_longitude) / 2.0), 2)
        ))
      END AS computed_distance
    FROM public.users u
    WHERE u.deleted_at IS NULL
      AND (
        lower(btrim(COALESCE(u.account_type::TEXT, ''))) = 'candidato'
        OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) = 'stealth'
        OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidenc%'
        OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidential%'
      )
      AND (
        (
          lower(btrim(COALESCE(u.account_type::TEXT, ''))) <> 'stealth'
          AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) NOT LIKE 'confidenc%'
          AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) NOT LIKE 'confidential%'
        )
        OR EXISTS (
          SELECT 1
          FROM public.profile_unlocks pu
          JOIN public.candidate_unlock_ledger ledger
            ON ledger.id = pu.authorization_ledger_id
           AND ledger.actor_id = pu.company_id
           AND ledger.candidate_id = pu.candidate_id
           AND ledger.authorization_version = 1
          WHERE pu.company_id = v_actor
            AND pu.candidate_id = u.id
            AND pu.authorization_version = 1
        )
      )
      AND (btrim(COALESCE(p_text, '')) = '' OR u.headline ILIKE '%' || btrim(p_text) || '%')
      AND (btrim(COALESCE(p_city, '')) = '' OR u.city ILIKE '%' || btrim(p_city) || '%')
      AND (COALESCE(cardinality(p_skills), 0) = 0 OR u.tags && p_skills)
      AND (NOT COALESCE(p_only_available, FALSE) OR u.open_to_work IS TRUE)
      AND (NOT COALESCE(p_only_verified, FALSE) OR u.is_verified IS TRUE)
      AND (NOT COALESCE(p_with_salary, FALSE) OR u.salary_expectation IS NOT NULL)
  )
  SELECT c.id, c.name::TEXT, c.headline::TEXT, c.avatar_url, c.city::TEXT,
    COALESCE(c.tags, '{}')::TEXT[], c.is_verified, c.open_to_work,
    c.salary_expectation::TEXT, c.computed_distance,
    (v_latitude IS NOT NULL AND v_longitude IS NOT NULL)
  FROM candidates c
  WHERE p_radius_km IS NULL
    OR v_latitude IS NULL OR v_longitude IS NULL
    OR (c.computed_distance IS NOT NULL AND c.computed_distance <= p_radius_km)
  ORDER BY
    CASE WHEN p_radius_km IS NOT NULL THEN c.computed_distance END NULLS LAST,
    c.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 60), 1), 100);
END;
$$;

-- Administrative dashboards receive aggregates, not a second general-purpose
-- profile endpoint. Authorization comes exclusively from 033 memberships.
CREATE OR REPLACE FUNCTION public.admin_profile_metrics(p_since TIMESTAMPTZ)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_result JSONB;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin_profile_metrics: operacion no disponible'
      USING ERRCODE = '42501';
  END IF;
  SELECT jsonb_build_object(
    'users', COUNT(*),
    'candidates', COUNT(*) FILTER (
      WHERE lower(btrim(COALESCE(account_type::TEXT, ''))) = 'candidato'),
    'companies', COUNT(*) FILTER (
      WHERE lower(btrim(COALESCE(account_type::TEXT, ''))) = 'empresa'),
    'headhunters', COUNT(*) FILTER (
      WHERE lower(btrim(COALESCE(account_type::TEXT, ''))) = 'headhunter'),
    'confidential', COUNT(*) FILTER (
      WHERE lower(btrim(COALESCE(account_type::TEXT, ''))) = 'stealth'
         OR lower(btrim(COALESCE(account_type::TEXT, ''))) LIKE 'confidenc%'
         OR lower(btrim(COALESCE(account_type::TEXT, ''))) LIKE 'confidential%'),
    'active_boosts', COUNT(*) FILTER (WHERE boost_ends_at > now()),
    'profile_views', COALESCE(SUM(profile_views), 0),
    'growth', COALESCE(jsonb_agg(created_at) FILTER (WHERE created_at >= p_since), '[]'::JSONB),
    'tags', COALESCE(jsonb_agg(tags) FILTER (WHERE tags IS NOT NULL), '[]'::JSONB),
    'cities', COALESCE(jsonb_agg(city) FILTER (WHERE city IS NOT NULL), '[]'::JSONB)
  ) INTO v_result
  FROM public.users
  WHERE deleted_at IS NULL;
  RETURN v_result;
END;
$$;

-- The existing embedding RPC keeps its positional contract, but the supplied
-- UUID is no longer authority and confidential identities remain inaccessible.
CREATE OR REPLACE FUNCTION public.match_users_by_embedding(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 10,
  p_min_score DOUBLE PRECISION DEFAULT 0.20
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
DECLARE v_actor UUID := auth.uid();
BEGIN
  IF v_actor IS NULL OR p_user_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'match_users_by_embedding: resultados no disponibles'
      USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH me AS (
    SELECT u.profile_embedding, COALESCE(u.tags, '{}')::TEXT[] AS tags,
           lower(btrim(COALESCE(u.account_type::TEXT, ''))) AS account_type
    FROM public.users u WHERE u.id = v_actor AND u.deleted_at IS NULL
  ), scored AS (
    SELECT u.id, u.name, u.headline, u.avatar_url, u.account_type,
      COALESCE(u.tags, '{}')::TEXT[] AS tags,
      public.rescale_similarity(1 - (u.profile_embedding <=> me.profile_embedding)) AS sem,
      public.skill_overlap(me.tags, COALESCE(u.tags, '{}')::TEXT[]) AS skl
    FROM me JOIN public.users u ON u.id <> v_actor
    WHERE me.profile_embedding IS NOT NULL AND u.profile_embedding IS NOT NULL
      AND u.deleted_at IS NULL
      AND (me.account_type IN ('empresa', 'headhunter')) <>
          (lower(btrim(COALESCE(u.account_type::TEXT, ''))) IN ('empresa', 'headhunter'))
      AND (
        lower(btrim(COALESCE(u.account_type::TEXT, ''))) <> 'stealth'
        AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) NOT LIKE 'confidenc%'
        AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) NOT LIKE 'confidential%'
        OR EXISTS (
          SELECT 1 FROM public.profile_unlocks pu
          JOIN public.candidate_unlock_ledger l ON l.id = pu.authorization_ledger_id
            AND l.actor_id = pu.company_id AND l.candidate_id = pu.candidate_id
            AND l.authorization_version = 1
          WHERE pu.company_id = v_actor AND pu.candidate_id = u.id
            AND pu.authorization_version = 1
        )
      )
  )
  SELECT scored.id, scored.name, scored.headline, scored.avatar_url,
    scored.account_type, scored.tags,
    (0.7 * scored.sem + 0.3 * scored.skl), scored.sem, scored.skl
  FROM scored
  WHERE (0.7 * scored.sem + 0.3 * scored.skl) >= p_min_score
  ORDER BY (0.7 * scored.sem + 0.3 * scored.skl) DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 10), 1), 100);
END;
$$;

-- Preserve the social recommendation contract while excluding every locked
-- confidential family. Exact geography and boost dates remain server-side.
CREATE OR REPLACE FUNCTION public.get_recommended_users(p_limit INTEGER DEFAULT 30)
RETURNS TABLE (
  user_id UUID, name TEXT, headline TEXT, avatar_url TEXT, account_type TEXT,
  location TEXT, tags TEXT[], video_url TEXT, rating_stars DOUBLE PRECISION,
  is_premium BOOLEAN, is_verified BOOLEAN, connections INTEGER,
  mutual_count BIGINT, affinity_score DOUBLE PRECISION
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_my_tags TEXT[];
  v_my_city TEXT;
  v_my_type TEXT;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'get_recommended_users: resultados no disponibles'
      USING ERRCODE = '28000';
  END IF;
  SELECT COALESCE(u.tags, '{}')::TEXT[], u.city::TEXT,
         lower(btrim(COALESCE(u.account_type::TEXT, '')))
    INTO v_my_tags, v_my_city, v_my_type
  FROM public.users u WHERE u.id = v_actor AND u.deleted_at IS NULL;
  IF NOT FOUND THEN RETURN; END IF;

  RETURN QUERY
  WITH my_contacts AS (
    SELECT CASE WHEN c.requester_id = v_actor THEN c.addressee_id ELSE c.requester_id END AS contact_id
    FROM public.connections c
    WHERE c.status = 'accepted'
      AND (c.requester_id = v_actor OR c.addressee_id = v_actor)
  ), existing_connections AS (
    SELECT CASE WHEN c.requester_id = v_actor THEN c.addressee_id ELSE c.requester_id END AS connected_id
    FROM public.connections c
    WHERE (c.requester_id = v_actor OR c.addressee_id = v_actor)
      AND c.status IN ('pending', 'accepted')
  )
  SELECT u.id, u.name::TEXT, u.headline::TEXT, u.avatar_url, u.account_type::TEXT,
    u.city::TEXT, COALESCE(u.tags, '{}')::TEXT[], u.video_url,
    u.rating_stars, u.is_premium, u.is_verified, u.connections,
    (SELECT COUNT(*) FROM my_contacts mc
      JOIN (
        SELECT CASE WHEN c2.requester_id = u.id THEN c2.addressee_id ELSE c2.requester_id END AS id
        FROM public.connections c2
        WHERE c2.status = 'accepted'
          AND (c2.requester_id = u.id OR c2.addressee_id = u.id)
      ) theirs ON theirs.id = mc.contact_id)::BIGINT,
    (
      COALESCE((SELECT COUNT(*)::DOUBLE PRECISION FROM unnest(COALESCE(u.tags, '{}')::TEXT[]) tag
        WHERE tag = ANY(v_my_tags)) * 40.0
        / GREATEST(cardinality(v_my_tags), 1), 0)
      + CASE WHEN u.city IS NOT NULL AND v_my_city IS NOT NULL
          AND lower(u.city::TEXT) = lower(v_my_city) THEN 20.0 ELSE 0.0 END
      + CASE WHEN u.video_url IS NOT NULL AND u.video_url <> '' THEN 15.0 ELSE 0.0 END
      + (COALESCE(u.rating_stars, 0) / 5.0 * 15.0)
      + CASE WHEN u.boost_ends_at > now() THEN 10.0 ELSE 0.0 END
    )::DOUBLE PRECISION
  FROM public.users u
  WHERE u.id <> v_actor AND u.deleted_at IS NULL
    AND u.id NOT IN (SELECT connected_id FROM existing_connections)
    AND (
      (v_my_type IN ('empresa', 'headhunter')) <>
      (lower(btrim(COALESCE(u.account_type::TEXT, ''))) IN ('empresa', 'headhunter'))
    )
    AND (
      (
        lower(btrim(COALESCE(u.account_type::TEXT, ''))) <> 'stealth'
        AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) NOT LIKE 'confidenc%'
        AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) NOT LIKE 'confidential%'
      )
      OR EXISTS (
        SELECT 1 FROM public.profile_unlocks pu
        JOIN public.candidate_unlock_ledger ledger
          ON ledger.id = pu.authorization_ledger_id
         AND ledger.actor_id = pu.company_id
         AND ledger.candidate_id = pu.candidate_id
         AND ledger.authorization_version = 1
        WHERE pu.company_id = v_actor AND pu.candidate_id = u.id
          AND pu.authorization_version = 1
      )
    )
  ORDER BY 14 DESC, u.rating_stars DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 30), 1), 100);
END;
$$;

-- Keep the existing 11-column pipeline contract. A locked confidential peer
-- remains visible as a process row but carries no UUID, identity or profile
-- attributes until a valid 034 authorization exists for the actor.
CREATE OR REPLACE FUNCTION public.get_my_pipeline()
RETURNS TABLE (
  connection_id UUID, ats_status TEXT, user_id UUID, user_name TEXT,
  user_headline TEXT, user_avatar_url TEXT, user_account_type TEXT,
  user_video_url TEXT, is_confidential BOOLEAN, user_skills JSONB,
  match_percentage DOUBLE PRECISION
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH peers AS (
    SELECT c.id AS connection_id, c.ats_status, c.updated_at,
      u.id AS user_id, u.name, u.headline, u.avatar_url, u.account_type,
      u.video_url, u.skills, u.match_percentage,
      (
        lower(btrim(COALESCE(u.account_type::TEXT, ''))) = 'stealth'
        OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidenc%'
        OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidential%'
      ) AS confidential,
      EXISTS (
        SELECT 1 FROM public.profile_unlocks pu
        JOIN public.candidate_unlock_ledger ledger
          ON ledger.id = pu.authorization_ledger_id
         AND ledger.actor_id = pu.company_id
         AND ledger.candidate_id = pu.candidate_id
         AND ledger.authorization_version = 1
        WHERE pu.company_id = auth.uid() AND pu.candidate_id = u.id
          AND pu.authorization_version = 1
      ) AS authorized
    FROM public.connections c
    JOIN public.users u ON u.id = CASE
      WHEN c.requester_id = auth.uid() THEN c.addressee_id ELSE c.requester_id END
    WHERE auth.uid() IS NOT NULL
      AND (c.requester_id = auth.uid() OR c.addressee_id = auth.uid())
      AND c.status <> 'blocked' AND u.deleted_at IS NULL
  )
  SELECT p.connection_id, p.ats_status,
    CASE WHEN p.confidential AND NOT p.authorized THEN NULL ELSE p.user_id END,
    CASE WHEN p.confidential AND NOT p.authorized THEN 'Candidato Confidencial' ELSE p.name::TEXT END,
    CASE WHEN p.confidential AND NOT p.authorized THEN NULL ELSE p.headline::TEXT END,
    CASE WHEN p.confidential AND NOT p.authorized THEN NULL ELSE p.avatar_url END,
    CASE WHEN p.confidential AND NOT p.authorized THEN 'confidencial' ELSE p.account_type::TEXT END,
    CASE WHEN p.confidential AND NOT p.authorized THEN NULL ELSE p.video_url END,
    p.confidential,
    CASE WHEN p.confidential AND NOT p.authorized THEN NULL ELSE p.skills END,
    CASE WHEN p.confidential AND NOT p.authorized THEN NULL ELSE p.match_percentage END
  FROM peers p
  ORDER BY p.updated_at DESC;
$$;

-- Referral notifications keep the business event but anonymize the referred
-- actor when that actor belongs to any confidential account family.
CREATE OR REPLACE FUNCTION public.redeem_referral_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_referrer UUID;
  v_name TEXT;
BEGIN
  IF v_actor IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'no_auth'); END IF;
  SELECT rc.user_id INTO v_referrer FROM public.referral_codes rc
  WHERE upper(rc.code) = upper(trim(p_code)) LIMIT 1;
  IF v_referrer IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'codigo_invalido'); END IF;
  IF v_referrer = v_actor THEN RETURN jsonb_build_object('ok', false, 'error', 'autorreferido'); END IF;
  IF EXISTS (SELECT 1 FROM public.referrals r WHERE r.referred_id = v_actor) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ya_canjeado');
  END IF;
  INSERT INTO public.referrals (referrer_id, referred_id, referral_code, reward_granted)
  VALUES (v_referrer, v_actor, upper(trim(p_code)), false);
  UPDATE public.referral_codes SET uses_count = COALESCE(uses_count, 0) + 1
  WHERE upper(code) = upper(trim(p_code));
  SELECT CASE
    WHEN lower(btrim(COALESCE(u.account_type::TEXT, ''))) = 'stealth'
      OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidenc%'
      OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidential%'
    THEN 'Alguien'::TEXT ELSE COALESCE(u.name::TEXT, 'Alguien') END
    INTO v_name FROM public.users u WHERE u.id = v_actor;
  INSERT INTO public.notifications (user_id, type, title, body, sender_name)
  VALUES (v_referrer, 'referral', 'Sumaste un referido 🎉',
    v_name || ' se registró en Mploya con tu invitación', v_name);
  RETURN jsonb_build_object('ok', true, 'referrer_id', v_referrer);
END;
$$;

-- Preserve the nine-column map contract but expose only coarse points. The
-- distance uses the same rounded coordinates, preventing repeated calls from
-- becoming an exact-location oracle.
CREATE OR REPLACE FUNCTION public.get_explore_pins(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 50
)
RETURNS TABLE (
  pin_id UUID, pin_name TEXT, pin_headline TEXT, pin_type TEXT,
  avatar_url TEXT, has_video BOOLEAN, latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION, distance_km DOUBLE PRECISION
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH coarse AS (
    SELECT u.id, u.name::TEXT AS name, COALESCE(u.headline, '')::TEXT AS headline,
      COALESCE(u.account_type, 'candidato')::TEXT AS account_type,
      u.avatar_url, (u.video_url IS NOT NULL AND u.video_url <> '') AS has_video,
      round(u.latitude::NUMERIC, 2)::DOUBLE PRECISION AS latitude,
      round(u.longitude::NUMERIC, 2)::DOUBLE PRECISION AS longitude
    FROM public.users u
    WHERE auth.uid() IS NOT NULL AND u.id IS DISTINCT FROM auth.uid()
      AND u.latitude IS NOT NULL AND u.longitude IS NOT NULL
      AND u.deleted_at IS NULL AND u.name IS NOT NULL
      AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) <> 'stealth'
      AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) NOT LIKE 'confidenc%'
      AND lower(btrim(COALESCE(u.account_type::TEXT, ''))) NOT LIKE 'confidential%'
  ), measured AS (
    SELECT c.*, 6371.0 * acos(LEAST(1.0,
      cos(radians(p_lat)) * cos(radians(c.latitude))
      * cos(radians(c.longitude) - radians(p_lng))
      + sin(radians(p_lat)) * sin(radians(c.latitude)))) AS distance_km
    FROM coarse c
  )
  SELECT m.id, m.name, m.headline, m.account_type, m.avatar_url, m.has_video,
    m.latitude, m.longitude, round(m.distance_km::NUMERIC, 1)::DOUBLE PRECISION
  FROM measured m
  WHERE m.distance_km <= LEAST(GREATEST(COALESCE(p_radius_km, 50), 1), 500)
  ORDER BY m.distance_km LIMIT 200;
$$;

-- Public referral landing must not reveal a confidential referrer's identity.
CREATE OR REPLACE FUNCTION public.get_referrer_name(p_code TEXT)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN lower(btrim(COALESCE(u.account_type::TEXT, ''))) = 'stealth'
      OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidenc%'
      OR lower(btrim(COALESCE(u.account_type::TEXT, ''))) LIKE 'confidential%'
    THEN 'Alguien'::TEXT ELSE u.name::TEXT END
  FROM public.referral_codes rc
  JOIN public.users u ON u.id = rc.user_id AND u.deleted_at IS NULL
  WHERE upper(rc.code) = upper(trim(p_code))
  LIMIT 1;
$$;

-- Remove broad table policies and privileges. SECURITY DEFINER functions and
-- server-side service-role jobs keep their internal access; clients do not.
DO $$
DECLARE p RECORD;
BEGIN
  FOR p IN
    SELECT polname
    FROM pg_policy
    WHERE polrelid = 'public.users'::regclass
      AND polcmd IN ('r', '*')
      AND (
        polroles = ARRAY[0::OID]
        OR polroles && ARRAY[
          (SELECT oid FROM pg_roles WHERE rolname = 'anon'),
          (SELECT oid FROM pg_roles WHERE rolname = 'authenticated')
        ]
      )
  LOOP
    EXECUTE format('DROP POLICY %I ON public.users', p.polname);
  END LOOP;
END;
$$;

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.users FROM PUBLIC, anon, authenticated;

ALTER FUNCTION public.update_my_setting(TEXT, BOOLEAN) OWNER TO postgres;
ALTER FUNCTION public.get_my_profile() OWNER TO postgres;
ALTER FUNCTION public.set_my_fcm_token(TEXT) OWNER TO postgres;
ALTER FUNCTION public.set_my_profile_analysis(TEXT, JSONB) OWNER TO postgres;
ALTER FUNCTION public.set_my_profile_avatar(TEXT) OWNER TO postgres;
ALTER FUNCTION public.get_my_profile_entitlements() OWNER TO postgres;
ALTER FUNCTION public.search_accessible_talent(TEXT, TEXT[], TEXT, INTEGER, BOOLEAN, BOOLEAN, BOOLEAN, INTEGER) OWNER TO postgres;
ALTER FUNCTION public.admin_profile_metrics(TIMESTAMPTZ) OWNER TO postgres;
ALTER FUNCTION public.match_users_by_embedding(UUID, INTEGER, DOUBLE PRECISION) OWNER TO postgres;
ALTER FUNCTION public.get_recommended_users(INTEGER) OWNER TO postgres;
ALTER FUNCTION public.get_my_pipeline() OWNER TO postgres;
ALTER FUNCTION public.redeem_referral_code(TEXT) OWNER TO postgres;
ALTER FUNCTION public.get_explore_pins(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) OWNER TO postgres;
ALTER FUNCTION public.get_referrer_name(TEXT) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.update_my_setting(TEXT, BOOLEAN)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_my_profile()
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.set_my_fcm_token(TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.set_my_profile_analysis(TEXT, JSONB)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.set_my_profile_avatar(TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_my_profile_entitlements()
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.search_accessible_talent(TEXT, TEXT[], TEXT, INTEGER, BOOLEAN, BOOLEAN, BOOLEAN, INTEGER)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_profile_metrics(TIMESTAMPTZ)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.match_users_by_embedding(UUID, INTEGER, DOUBLE PRECISION)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_recommended_users(INTEGER)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_my_pipeline()
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.redeem_referral_code(TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_explore_pins(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_referrer_name(TEXT)
  FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.update_my_setting(TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_fcm_token(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_profile_analysis(TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_profile_avatar(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_profile_entitlements() TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_accessible_talent(TEXT, TEXT[], TEXT, INTEGER, BOOLEAN, BOOLEAN, BOOLEAN, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_profile_metrics(TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.match_users_by_embedding(UUID, INTEGER, DOUBLE PRECISION) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_recommended_users(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_pipeline() TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_referral_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_explore_pins(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_referrer_name(TEXT) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
