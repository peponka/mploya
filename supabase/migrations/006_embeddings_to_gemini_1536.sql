-- ================================================================
--  MIGRACIÓN 006 — Migrar embeddings de HuggingFace(384) a Gemini(1536)
--
--  Motivo: el endpoint de HuggingFace usado en 003/005 fue retirado y el
--  Inference API quedó gateado para cuentas free. Se comprobó que NINGÚN
--  registro tenía embedding (users.profile_embedding = 0 filas), así que
--  cambiar de proveedor y de dimensión no destruye datos.
--
--  Nuevo proveedor: Gemini `gemini-embedding-001` con outputDimensionality=1536
--  (< 2000, límite de índice de pgvector). Aislado en las Edge Functions
--  generate-embedding y generate-job-embedding.
--
--  Ejecutar en: Supabase Dashboard → SQL Editor. Idempotente.
-- ================================================================

CREATE EXTENSION IF NOT EXISTS vector;

-- ── users.profile_embedding: 384 → 1536 ──────────────────────────
DROP INDEX IF EXISTS idx_users_embedding;

ALTER TABLE public.users
  ALTER COLUMN profile_embedding TYPE vector(1536)
  USING NULL;   -- estaba vacío; descartamos cualquier resto

CREATE INDEX IF NOT EXISTS idx_users_embedding
  ON public.users
  USING hnsw (profile_embedding vector_cosine_ops);

COMMENT ON COLUMN public.users.profile_embedding IS
  'Embedding 1536-dim (Gemini gemini-embedding-001) del perfil, generado por la '
  'Edge Function generate-embedding.';

-- ── jobs.embedding: 384 → 1536 ───────────────────────────────────
DROP INDEX IF EXISTS idx_jobs_embedding;

ALTER TABLE public.jobs
  ALTER COLUMN embedding TYPE vector(1536)
  USING NULL;

CREATE INDEX IF NOT EXISTS idx_jobs_embedding
  ON public.jobs
  USING hnsw (embedding vector_cosine_ops);

COMMENT ON COLUMN public.jobs.embedding IS
  'Embedding 1536-dim (Gemini gemini-embedding-001) de la vacante, generado por la '
  'Edge Function generate-job-embedding. Mismo espacio que users.profile_embedding.';

-- Las RPC match_candidates_for_job / match_jobs_for_candidate / match_users_by_embedding
-- no hardcodean la dimensión, así que siguen funcionando sin cambios.
