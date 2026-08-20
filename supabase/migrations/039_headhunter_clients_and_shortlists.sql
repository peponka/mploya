-- ============================================================================
-- 039 - Clientes de headhunter y shortlists
-- ============================================================================
-- Nuevo, aditivo: no toca ninguna tabla existente. Se aplica a mano contra
-- producción (proyecto Supabase "nexowork") vía `supabase db query --linked
-- -f`, igual que 029-038 — este proyecto nunca usó el mecanismo de control
-- de migraciones de Supabase (supabase_migrations.schema_migrations), así
-- que verificar que esto quedó aplicado significa consultar los objetos
-- vivos (information_schema / pg_policies), no `supabase migration list`.
--
-- Motivo: el rediseño de las pantallas de Headhunter (Alta de cliente,
-- Shortlist para cliente) asumía un modelo de datos que no existía. Se
-- verificó en vivo (19/8/2026) que no hay ninguna tabla `clients` ni
-- `shortlist*` en producción antes de escribir esto.
--
-- `headhunter_clients` mapea 1:1 los 4 pasos del wizard mockeado
-- (información básica / contacto principal / preferencias de trabajo /
-- resumen). `shortlists`/`shortlist_candidates` modelan una shortlist como
-- un subconjunto rankeado de `job_applications` de UNA vacante, enviada (o
-- no) a un cliente. `match_score` en shortlist_candidates se llena desde la
-- función real `match_candidates_for_job` (migración 034) al armar la
-- shortlist — no se inventa un número en ningún punto de este archivo.
-- ============================================================================

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
-- headhunter_clients
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.headhunter_clients (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  headhunter_id         UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,

  company_name          TEXT NOT NULL,
  country               TEXT,
  industry               TEXT,
  city                  TEXT,

  contact_first_name    TEXT,
  contact_last_name     TEXT,
  contact_role          TEXT,
  contact_email         TEXT,
  contact_phone         TEXT,
  contact_channel       TEXT CHECK (contact_channel IN ('email', 'whatsapp', 'llamada')),

  work_mode             TEXT CHECK (work_mode IN (
                           'colaboracion_continua', 'busquedas_puntuales',
                           'mandato_exclusivo', 'tiempo_determinado'
                         )),
  response_time         TEXT CHECK (response_time IN (
                           '24_48h', '2_3_dias', '1_semana', 'mas_1_semana'
                         )),
  confidentiality_level TEXT CHECK (confidentiality_level IN ('basico', 'alto', 'muy_alto')),
  update_channel        TEXT CHECK (update_channel IN ('email', 'whatsapp', 'llamada', 'reuniones')),

  notes                 TEXT,

  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_headhunter_clients_headhunter
  ON public.headhunter_clients (headhunter_id);

ALTER TABLE public.headhunter_clients ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hc_select ON public.headhunter_clients;
DROP POLICY IF EXISTS hc_insert ON public.headhunter_clients;
DROP POLICY IF EXISTS hc_update ON public.headhunter_clients;
DROP POLICY IF EXISTS hc_delete ON public.headhunter_clients;

CREATE POLICY hc_select ON public.headhunter_clients
  FOR SELECT TO authenticated
  USING (headhunter_id = auth.uid());

CREATE POLICY hc_insert ON public.headhunter_clients
  FOR INSERT TO authenticated
  WITH CHECK (headhunter_id = auth.uid());

CREATE POLICY hc_update ON public.headhunter_clients
  FOR UPDATE TO authenticated
  USING (headhunter_id = auth.uid())
  WITH CHECK (headhunter_id = auth.uid());

CREATE POLICY hc_delete ON public.headhunter_clients
  FOR DELETE TO authenticated
  USING (headhunter_id = auth.uid());

CREATE OR REPLACE FUNCTION public.headhunter_clients_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_headhunter_clients_updated_at ON public.headhunter_clients;
CREATE TRIGGER trg_headhunter_clients_updated_at
  BEFORE UPDATE ON public.headhunter_clients
  FOR EACH ROW
  EXECUTE FUNCTION public.headhunter_clients_touch_updated_at();


-- ────────────────────────────────────────────────────────────────────────────
-- shortlists
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.shortlists (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  headhunter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  job_id        UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  client_id     UUID REFERENCES public.headhunter_clients(id) ON DELETE SET NULL,
  status        TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'sent')),
  sent_at       TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT shortlists_sent_at_coherente CHECK ((status = 'sent') = (sent_at IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_shortlists_headhunter ON public.shortlists (headhunter_id);
CREATE INDEX IF NOT EXISTS idx_shortlists_job         ON public.shortlists (job_id);
CREATE INDEX IF NOT EXISTS idx_shortlists_client       ON public.shortlists (client_id);

ALTER TABLE public.shortlists ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sl_select ON public.shortlists;
DROP POLICY IF EXISTS sl_insert ON public.shortlists;
DROP POLICY IF EXISTS sl_update ON public.shortlists;
DROP POLICY IF EXISTS sl_delete ON public.shortlists;

CREATE POLICY sl_select ON public.shortlists
  FOR SELECT TO authenticated
  USING (headhunter_id = auth.uid());

CREATE POLICY sl_insert ON public.shortlists
  FOR INSERT TO authenticated
  WITH CHECK (headhunter_id = auth.uid());

CREATE POLICY sl_update ON public.shortlists
  FOR UPDATE TO authenticated
  USING (headhunter_id = auth.uid())
  WITH CHECK (headhunter_id = auth.uid());

CREATE POLICY sl_delete ON public.shortlists
  FOR DELETE TO authenticated
  USING (headhunter_id = auth.uid());


-- ────────────────────────────────────────────────────────────────────────────
-- shortlist_candidates
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.shortlist_candidates (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shortlist_id   UUID NOT NULL REFERENCES public.shortlists(id) ON DELETE CASCADE,
  application_id UUID NOT NULL REFERENCES public.job_applications(id) ON DELETE CASCADE,
  rank           INT NOT NULL,
  match_score    DOUBLE PRECISION,
  note           TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (shortlist_id, application_id)
);

CREATE INDEX IF NOT EXISTS idx_shortlist_candidates_shortlist
  ON public.shortlist_candidates (shortlist_id);

ALTER TABLE public.shortlist_candidates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sc_select ON public.shortlist_candidates;
DROP POLICY IF EXISTS sc_insert ON public.shortlist_candidates;
DROP POLICY IF EXISTS sc_update ON public.shortlist_candidates;
DROP POLICY IF EXISTS sc_delete ON public.shortlist_candidates;

CREATE POLICY sc_select ON public.shortlist_candidates
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.shortlists s
      WHERE s.id = shortlist_candidates.shortlist_id
        AND s.headhunter_id = auth.uid()
    )
  );

CREATE POLICY sc_insert ON public.shortlist_candidates
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.shortlists s
      WHERE s.id = shortlist_candidates.shortlist_id
        AND s.headhunter_id = auth.uid()
    )
  );

CREATE POLICY sc_update ON public.shortlist_candidates
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.shortlists s
      WHERE s.id = shortlist_candidates.shortlist_id
        AND s.headhunter_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.shortlists s
      WHERE s.id = shortlist_candidates.shortlist_id
        AND s.headhunter_id = auth.uid()
    )
  );

CREATE POLICY sc_delete ON public.shortlist_candidates
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.shortlists s
      WHERE s.id = shortlist_candidates.shortlist_id
        AND s.headhunter_id = auth.uid()
    )
  );

NOTIFY pgrst, 'reload schema';

COMMIT;
