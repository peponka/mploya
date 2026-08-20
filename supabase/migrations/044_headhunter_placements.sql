-- ============================================================================
-- 044 - Colocaciones, fees/comisiones y fuente del pipeline
-- ============================================================================
-- Última pieza de las 9 pantallas de Headhunter: `18_Headhunter_Colocaciones_
-- Analytics.png` pide fees/comisiones en USD, algo que no existe en NINGÚN
-- lado del proyecto — es un concepto nuevo, no una tabla que faltaba
-- completar. `fee_amount` es NULLABLE a propósito: el headhunter puede
-- registrar una colocación sin saber el fee todavía y cargarlo después; los
-- KPIs de fee suman sólo los valores reales, un dato ausente no es un cero.
--
-- `pipeline_candidates.source` distingue cómo llegó el candidato al pipeline
-- (match real vía `discoverMatchesForJob` vs. agregado a mano desde Talent
-- Pool) — es lo único que la app puede saber con certeza sobre "fuente"; no
-- existe flujo de referido ni de postulación formal en este modelo de
-- sourcing (migración 043), así que esas dos categorías del mockup quedan
-- siempre en 0 — no se inventa un tercer valor para llenarlas.
--
-- `pipeline_stage_history` es nueva: sin ella no hay forma de calcular
-- tiempo promedio real por etapa (`stage_changed_at`, migración 043, sólo
-- guarda el último cambio, no el historial). Arranca vacía — las tablas de
-- pipeline son de hoy, no hay transiciones históricas que backfillear.
-- ============================================================================

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
-- headhunter_placements
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.headhunter_placements (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  headhunter_id         UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  pipeline_candidate_id UUID NOT NULL UNIQUE
                          REFERENCES public.headhunter_pipeline_candidates(id) ON DELETE CASCADE,
  job_id                UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  client_id             UUID REFERENCES public.headhunter_clients(id) ON DELETE SET NULL,
  candidate_id          UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,

  fee_amount            NUMERIC(12,2),
  currency              TEXT NOT NULL DEFAULT 'USD',
  payment_status        TEXT NOT NULL DEFAULT 'pendiente' CHECK (payment_status IN ('pendiente', 'cobrado')),

  placed_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  paid_at               TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT headhunter_placements_paid_at_coherente
    CHECK ((payment_status = 'cobrado') = (paid_at IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_hplacements_headhunter ON public.headhunter_placements (headhunter_id);
CREATE INDEX IF NOT EXISTS idx_hplacements_client     ON public.headhunter_placements (client_id);
CREATE INDEX IF NOT EXISTS idx_hplacements_job         ON public.headhunter_placements (job_id);

ALTER TABLE public.headhunter_placements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hplacements_select ON public.headhunter_placements;
DROP POLICY IF EXISTS hplacements_insert ON public.headhunter_placements;
DROP POLICY IF EXISTS hplacements_update ON public.headhunter_placements;
DROP POLICY IF EXISTS hplacements_delete ON public.headhunter_placements;

CREATE POLICY hplacements_select ON public.headhunter_placements
  FOR SELECT TO authenticated USING (headhunter_id = auth.uid());

CREATE POLICY hplacements_insert ON public.headhunter_placements
  FOR INSERT TO authenticated WITH CHECK (headhunter_id = auth.uid());

CREATE POLICY hplacements_update ON public.headhunter_placements
  FOR UPDATE TO authenticated
  USING (headhunter_id = auth.uid())
  WITH CHECK (headhunter_id = auth.uid());

CREATE POLICY hplacements_delete ON public.headhunter_placements
  FOR DELETE TO authenticated USING (headhunter_id = auth.uid());


-- ────────────────────────────────────────────────────────────────────────────
-- headhunter_pipeline_candidates.source
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.headhunter_pipeline_candidates
  ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'busqueda_activa'
    CHECK (source IN ('busqueda_activa', 'talent_pool'));

COMMENT ON COLUMN public.headhunter_pipeline_candidates.source IS
  'Cómo llegó el candidato al pipeline: busqueda_activa (match real vía match_candidates_for_job) o talent_pool (agregado a mano). No hay flujo de "referido" ni "aplicación" en este modelo de sourcing.';


-- ────────────────────────────────────────────────────────────────────────────
-- headhunter_pipeline_stage_history
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.headhunter_pipeline_stage_history (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_candidate_id UUID NOT NULL
                          REFERENCES public.headhunter_pipeline_candidates(id) ON DELETE CASCADE,
  from_stage            TEXT,
  to_stage              TEXT NOT NULL,
  changed_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hpc_history_candidate
  ON public.headhunter_pipeline_stage_history (pipeline_candidate_id);

ALTER TABLE public.headhunter_pipeline_stage_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hpc_history_select ON public.headhunter_pipeline_stage_history;

-- Sólo lectura para el dueño, vía join. Sin policy de escritura para
-- `authenticated` a propósito: sólo el trigger de abajo (que corre con los
-- privilegios de quien define la función) inserta acá.
CREATE POLICY hpc_history_select ON public.headhunter_pipeline_stage_history
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.headhunter_pipeline_candidates hpc
      WHERE hpc.id = headhunter_pipeline_stage_history.pipeline_candidate_id
        AND hpc.headhunter_id = auth.uid()
    )
  );

REVOKE INSERT, UPDATE, DELETE ON public.headhunter_pipeline_stage_history FROM authenticated, anon;

-- Amplía el trigger de la 043: además de pisar stage_changed_at, deja
-- constancia del cambio en la historia.
CREATE OR REPLACE FUNCTION public.headhunter_pipeline_candidates_stage_dates()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.stage IS DISTINCT FROM OLD.stage THEN
    NEW.stage_changed_at := now();
    INSERT INTO public.headhunter_pipeline_stage_history (pipeline_candidate_id, from_stage, to_stage)
    VALUES (NEW.id, OLD.stage, NEW.stage);
  END IF;
  RETURN NEW;
END;
$$;

NOTIFY pgrst, 'reload schema';

COMMIT;
