-- ================================================================
--  MIGRACIÓN 005 — Embeddings de vacantes + matching vacante↔candidato
--
--  Extiende la fundación de AI Matching (ver 003):
--    • 003 agregó users.profile_embedding vector(384) + match_users_by_embedding
--    • 005 agrega jobs.embedding vector(384) + match_candidates_for_job / match_jobs_for_candidate
--
--  Mismo modelo (all-MiniLM-L6-v2, 384 dims) que los perfiles, así los vectores
--  de vacantes y candidatos viven en el mismo espacio y la similitud coseno tiene
--  sentido. El proveedor de embeddings está aislado en la Edge Function
--  generate-job-embedding: cambiarlo (p. ej. a Gemini) es un swap de esa función
--  + cambiar la dimensión de estas columnas + re-vectorizar.
--
--  Ejecutar en: Supabase Dashboard → SQL Editor → New Query → Run
--  Idempotente (IF NOT EXISTS + CREATE OR REPLACE): re-ejecutable sin daño.
-- ================================================================

CREATE EXTENSION IF NOT EXISTS vector;

-- ================================================================
-- §1  Columna de embedding en jobs (384 dims = all-MiniLM-L6-v2)
-- ================================================================

ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS embedding vector(384);

CREATE INDEX IF NOT EXISTS idx_jobs_embedding
  ON public.jobs
  USING hnsw (embedding vector_cosine_ops);

COMMENT ON COLUMN public.jobs.embedding IS
  'Embedding 384-dim (all-MiniLM-L6-v2) de la vacante, generado por la Edge Function '
  'generate-job-embedding. Alineado con users.profile_embedding para matching coseno.';


-- ================================================================
-- §2  RPC: match_candidates_for_job
--     Candidatos ordenados por similitud coseno a UNA vacante.
--     Usado por el dashboard de la empresa (ranking de postulantes).
-- ================================================================

CREATE OR REPLACE FUNCTION match_candidates_for_job(
  p_job_id UUID,
  p_limit  INT DEFAULT 20
)
RETURNS TABLE (
  id           UUID,
  name         TEXT,
  headline     TEXT,
  avatar_url   TEXT,
  account_type TEXT,
  tags         TEXT[],
  similarity   FLOAT
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    u.id,
    u.name,
    u.headline,
    u.avatar_url,
    u.account_type,
    u.tags,
    1 - (u.profile_embedding <=> j.embedding) AS similarity
  FROM public.jobs j
  JOIN public.users u ON TRUE
  WHERE j.id = p_job_id
    AND j.embedding IS NOT NULL
    AND u.profile_embedding IS NOT NULL
    AND u.account_type IN ('candidato', 'confidencial', 'stealth')
  ORDER BY u.profile_embedding <=> j.embedding
  LIMIT p_limit;
$$;

COMMENT ON FUNCTION match_candidates_for_job IS
  'Retorna los candidatos más compatibles con una vacante por similitud coseno. '
  'NOTA (hardening Prompt A): agregar chequeo de que auth.uid() sea la empresa dueña de la vacante.';


-- ================================================================
-- §3  RPC: match_jobs_for_candidate
--     Vacantes ordenadas por similitud coseno al perfil del candidato.
--     Base para "Recomendaciones de empleo por IA" (dashboard candidato, F3).
-- ================================================================

CREATE OR REPLACE FUNCTION match_jobs_for_candidate(
  p_user_id UUID,
  p_limit   INT DEFAULT 20
)
RETURNS TABLE (
  id          UUID,
  title       TEXT,
  company_id  UUID,
  salary_range TEXT,
  location    TEXT,
  similarity  FLOAT
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    j.id,
    j.title,
    j.company_id,
    j.salary_range,
    j.location,
    1 - (j.embedding <=> u.profile_embedding) AS similarity
  FROM public.users u
  JOIN public.jobs j ON TRUE
  WHERE u.id = p_user_id
    AND u.profile_embedding IS NOT NULL
    AND j.embedding IS NOT NULL
    AND COALESCE(j.is_active, TRUE) = TRUE
  ORDER BY j.embedding <=> u.profile_embedding
  LIMIT p_limit;
$$;

COMMENT ON FUNCTION match_jobs_for_candidate IS
  'Retorna las vacantes más compatibles con el perfil de un candidato por similitud coseno.';
