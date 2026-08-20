-- ============================================================================
-- 043 - Pipeline de sourcing por búsqueda + rehace shortlist_candidates
-- ============================================================================
-- Las 7 etapas de `_Headhunter_Pipeline_Busqueda.png` (Descubiertos →
-- Contactados → Interesados → Presentados → Entrevista con cliente → Oferta
-- → Colocado) NO son `job_applications.status` (6 estados, matriz de
-- transición blindada por RLS en la migración 038, compartida con Empresa —
-- deliberadamente fuera de alcance, ver 042). Describen sourcing de
-- headhunter: candidatos que el headhunter encuentra/contacta vía Talent
-- Pool o matching, la mayoría de los cuales nunca postula formalmente.
-- Verificado leyendo headhunter_talent_pool_screen.dart completo: hoy no
-- existe ningún gancho para sumar un candidato a una búsqueda — se modela
-- como tabla nueva, propia de Headhunter, sin tocar job_applications.
--
-- shortlist_candidates (migración 039, verificado vacía en producción antes
-- de correr esto — 19/8/2026) asumía candidatos de shortlist salidos de
-- job_applications. En realidad salen del pipeline de sourcing de arriba:
-- se reemplaza application_id por pipeline_candidate_id, y se agregan
-- client_decision/client_comment/decision_at para Feedback_Cliente.png.
-- ============================================================================

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
-- headhunter_pipeline_candidates
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.headhunter_pipeline_candidates (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  headhunter_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  job_id           UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  candidate_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  stage            TEXT NOT NULL DEFAULT 'descubierto' CHECK (stage IN (
                     'descubierto', 'contactado', 'interesado', 'presentado',
                     'entrevista', 'oferta', 'colocado'
                   )),
  match_score      DOUBLE PRECISION,
  stage_changed_at TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (job_id, candidate_id)
);

CREATE INDEX IF NOT EXISTS idx_hpc_headhunter ON public.headhunter_pipeline_candidates (headhunter_id);
CREATE INDEX IF NOT EXISTS idx_hpc_job         ON public.headhunter_pipeline_candidates (job_id);

ALTER TABLE public.headhunter_pipeline_candidates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hpc_select ON public.headhunter_pipeline_candidates;
DROP POLICY IF EXISTS hpc_insert ON public.headhunter_pipeline_candidates;
DROP POLICY IF EXISTS hpc_update ON public.headhunter_pipeline_candidates;
DROP POLICY IF EXISTS hpc_delete ON public.headhunter_pipeline_candidates;

CREATE POLICY hpc_select ON public.headhunter_pipeline_candidates
  FOR SELECT TO authenticated USING (headhunter_id = auth.uid());

CREATE POLICY hpc_insert ON public.headhunter_pipeline_candidates
  FOR INSERT TO authenticated WITH CHECK (headhunter_id = auth.uid());

CREATE POLICY hpc_update ON public.headhunter_pipeline_candidates
  FOR UPDATE TO authenticated
  USING (headhunter_id = auth.uid())
  WITH CHECK (headhunter_id = auth.uid());

CREATE POLICY hpc_delete ON public.headhunter_pipeline_candidates
  FOR DELETE TO authenticated USING (headhunter_id = auth.uid());

CREATE OR REPLACE FUNCTION public.headhunter_pipeline_candidates_stage_dates()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.stage IS DISTINCT FROM OLD.stage THEN
    NEW.stage_changed_at := now();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_hpc_stage_dates ON public.headhunter_pipeline_candidates;
CREATE TRIGGER trg_hpc_stage_dates
  BEFORE UPDATE ON public.headhunter_pipeline_candidates
  FOR EACH ROW
  WHEN (OLD.stage IS DISTINCT FROM NEW.stage)
  EXECUTE FUNCTION public.headhunter_pipeline_candidates_stage_dates();


-- ────────────────────────────────────────────────────────────────────────────
-- shortlist_candidates — reemplaza application_id por pipeline_candidate_id
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.shortlist_candidates
  DROP COLUMN IF EXISTS application_id;

ALTER TABLE public.shortlist_candidates
  ADD COLUMN IF NOT EXISTS pipeline_candidate_id UUID
    REFERENCES public.headhunter_pipeline_candidates(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS client_decision TEXT NOT NULL DEFAULT 'pendiente'
    CHECK (client_decision IN ('pendiente', 'avanzar', 'entrevistar', 'rechazar')),
  ADD COLUMN IF NOT EXISTS client_comment TEXT,
  ADD COLUMN IF NOT EXISTS decision_at TIMESTAMPTZ;

ALTER TABLE public.shortlist_candidates
  ALTER COLUMN pipeline_candidate_id SET NOT NULL;

DROP INDEX IF EXISTS shortlist_candidates_shortlist_id_application_id_key;
ALTER TABLE public.shortlist_candidates
  DROP CONSTRAINT IF EXISTS shortlist_candidates_shortlist_id_application_id_key;
ALTER TABLE public.shortlist_candidates
  ADD CONSTRAINT shortlist_candidates_shortlist_pipeline_unique
    UNIQUE (shortlist_id, pipeline_candidate_id);

NOTIFY pgrst, 'reload schema';

COMMIT;
