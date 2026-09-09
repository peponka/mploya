-- ============================================================================
-- 048 — match_candidates_for_job no devolvía video_url (Match IA sin video)
-- ============================================================================
-- Motivo: Pedro reportó (30/8/2026) que en la pantalla de Empresa > Match IA
-- por vacante ("Seleccionar vacante" → tarjetas con % de match), TODOS los
-- candidatos aparecían con "Sin video pitch todavía", cuando antes sí se
-- veían los videos ahí mismo.
--
-- Se auditó la función `match_candidates_for_job` (definida en la migración
-- 034, "harden_candidate_matching_privacy") y su `RETURNS TABLE` nunca
-- incluyó la columna `video_url`:
--
--   RETURNS TABLE (
--     id UUID, name VARCHAR, headline VARCHAR, avatar_url TEXT,
--     account_type VARCHAR, tags TEXT[], similarity DOUBLE PRECISION,
--     semantic_score DOUBLE PRECISION, skill_score DOUBLE PRECISION
--   )
--
-- `AIMatchService.getCandidatesForJob()` (lib/services/ai_match_service.dart)
-- pasa cada fila de esta RPC directo a `NexUser.fromJson()`, así que sin la
-- columna `video_url` en el resultado, todas las tarjetas de esta pantalla
-- entran siempre a la rama "sin video" de TalentReelCard
-- (lib/widgets/empresa/talent_reel_card.dart:_initVideo, url == null →
-- _hasError = true), sin importar si el candidato realmente tiene video.
-- Esto es independiente del bug de RLS de la migración 047 (ese arregló el
-- feed general "Para ti"; este es un problema de contrato de columnas en
-- esta función puntual).
--
-- Fix: se agrega `video_url TEXT` al final del RETURNS TABLE y al SELECT,
-- sin tocar ninguna otra columna, orden ni la lógica de privacidad/scoring
-- existente. Es seguro exponerlo acá porque el filtro
-- `WHERE (NOT s.confidential OR s.unlocked)` ya garantiza que toda fila que
-- la función devuelve corresponde a un candidato no-confidencial o ya
-- desbloqueado por esta empresa — el mismo candidato cuyo nombre, avatar y
-- tags ya se estaban devolviendo.
-- ============================================================================

BEGIN;

DO $$
BEGIN
  IF to_regprocedure(
      'public.match_candidates_for_job(uuid,integer,double precision)'
    ) IS NULL
  THEN
    RAISE EXCEPTION '048 precondition: match_candidates_for_job (034) no está aplicada';
  END IF;
END;
$$;

-- Postgres no permite cambiar el tipo de retorno (agregar una columna a
-- RETURNS TABLE) con CREATE OR REPLACE: hay que borrar la función vieja
-- primero.
DROP FUNCTION IF EXISTS public.match_candidates_for_job(UUID, INTEGER, DOUBLE PRECISION);

CREATE OR REPLACE FUNCTION public.match_candidates_for_job(
  p_job_id UUID,
  p_limit INTEGER DEFAULT 20,
  p_min_score DOUBLE PRECISION DEFAULT 0.25
)
RETURNS TABLE (
  id UUID, name VARCHAR, headline VARCHAR, avatar_url TEXT,
  account_type VARCHAR, tags TEXT[], similarity DOUBLE PRECISION,
  semantic_score DOUBLE PRECISION, skill_score DOUBLE PRECISION,
  video_url TEXT
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
      u.video_url,
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
    s.semantic_value, s.skill_value,
    s.video_url
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

NOTIFY pgrst, 'reload schema';

COMMIT;
