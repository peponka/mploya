-- ============================================================================
-- 046 - Cultura de la Empresa (video institucional + historias del equipo)
-- ============================================================================
-- Aditivo: no toca ninguna tabla existente. Se aplica a mano contra
-- producción (proyecto Supabase "nexowork"), igual que 029-045.
--
-- Motivo: `empresa_perfil_screen.dart` y `empresa_editar_perfil_screen.dart`
-- documentan (11/8/2026) que la pantalla "Cultura de la Empresa" (mockup
-- `cultura de la empresa.png`, Pantalla 40) se dejó afuera A PROPÓSITO
-- porque `public.users` no tiene dónde guardar el video institucional, los
-- valores de la empresa ni las historias en video del equipo — construirla
-- antes habría significado texto de muestra. Pedro pidió (29/8/2026)
-- construirla en serio, así que esta migración agrega el modelo real.
--
-- `company_culture` es una fila por empresa (el video institucional + hasta
-- 4 valores con ícono). `company_culture_stories` son N historias en video
-- de integrantes del equipo, independientes entre sí. Ambas viven en tablas
-- propias — no se mezclan campos sueltos dentro de `about` como hacía el
-- formulario legacy `CompanyProfileFormScreen` (ver auditoría en
-- empresa_editar_perfil_screen.dart).
--
-- El video usa el mismo bucket público "videos" que pitches/nexus/stories
-- (ver storage_service.dart), bajo el prefijo `culture/`.
--
-- Lectura pública para `authenticated` (igual que `jobs`): esta pantalla es
-- contenido de marca que cualquier candidato puede ver antes de postularse,
-- no un dato privado de la empresa. Escritura sólo para la propia empresa.
-- ============================================================================

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
-- company_culture (una fila por empresa)
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.company_culture (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                     UUID NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,

  intro_video_url             TEXT,
  intro_video_duration_seconds INTEGER CHECK (intro_video_duration_seconds IS NULL OR intro_video_duration_seconds >= 0),

  -- Hasta 4 valores de la empresa, cada uno {icon_key, titulo, descripcion}.
  -- El límite de 4 (visto en el mockup) se valida en la app al guardar; acá
  -- sólo se garantiza que sea un array JSON y no crezca sin control.
  valores                     JSONB NOT NULL DEFAULT '[]'::jsonb
                                CHECK (
                                  jsonb_typeof(valores) = 'array'
                                  AND jsonb_array_length(valores) <= 4
                                ),

  founded_year                INTEGER CHECK (founded_year IS NULL OR founded_year BETWEEN 1800 AND 2100),
  employee_count               INTEGER CHECK (employee_count IS NULL OR employee_count >= 0),
  growth_percentage           NUMERIC CHECK (growth_percentage IS NULL OR growth_percentage >= -100),

  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.company_culture ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cc_select ON public.company_culture;
DROP POLICY IF EXISTS cc_insert ON public.company_culture;
DROP POLICY IF EXISTS cc_update ON public.company_culture;
DROP POLICY IF EXISTS cc_delete ON public.company_culture;

CREATE POLICY cc_select ON public.company_culture
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY cc_insert ON public.company_culture
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY cc_update ON public.company_culture
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY cc_delete ON public.company_culture
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.company_culture_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_company_culture_updated_at ON public.company_culture;
CREATE TRIGGER trg_company_culture_updated_at
  BEFORE UPDATE ON public.company_culture
  FOR EACH ROW
  EXECUTE FUNCTION public.company_culture_touch_updated_at();

-- ────────────────────────────────────────────────────────────────────────────
-- company_culture_stories (N historias en video del equipo, por empresa)
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.company_culture_stories (
  id                           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_user_id              UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,

  member_name                  TEXT NOT NULL,
  member_role                  TEXT,
  quote                        TEXT,
  video_url                    TEXT NOT NULL,
  video_duration_seconds       INTEGER CHECK (video_duration_seconds IS NULL OR video_duration_seconds >= 0),
  sort_order                   INTEGER NOT NULL DEFAULT 0,

  created_at                   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_company_culture_stories_company
  ON public.company_culture_stories (company_user_id, sort_order);

ALTER TABLE public.company_culture_stories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ccs_select ON public.company_culture_stories;
DROP POLICY IF EXISTS ccs_insert ON public.company_culture_stories;
DROP POLICY IF EXISTS ccs_update ON public.company_culture_stories;
DROP POLICY IF EXISTS ccs_delete ON public.company_culture_stories;

CREATE POLICY ccs_select ON public.company_culture_stories
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY ccs_insert ON public.company_culture_stories
  FOR INSERT TO authenticated
  WITH CHECK (company_user_id = auth.uid());

CREATE POLICY ccs_update ON public.company_culture_stories
  FOR UPDATE TO authenticated
  USING (company_user_id = auth.uid())
  WITH CHECK (company_user_id = auth.uid());

CREATE POLICY ccs_delete ON public.company_culture_stories
  FOR DELETE TO authenticated
  USING (company_user_id = auth.uid());

NOTIFY pgrst, 'reload schema';

COMMIT;
