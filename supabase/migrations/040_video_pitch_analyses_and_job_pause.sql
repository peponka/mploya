-- ============================================================================
-- 040 - Análisis de IA del video pitch + pausa de búsquedas
-- ============================================================================
-- Aditivo. `video_pitch_analyses` es tabla nueva; el único cambio a una
-- tabla existente es un ALTER TABLE ... ADD COLUMN IF NOT EXISTS sobre
-- `jobs` (nullable, no rompe nada de Empresa). Aplicada a mano contra
-- producción ("nexowork") vía `supabase db query --linked -f`.
--
-- video_pitch_analyses guarda el resultado de analizar users.video_url con
-- Gemini (Edge Function analyze-video-pitch, ver supabase/functions/). Es la
-- misma columna de video que ya usa headhunter_video_pitch_screen.dart /
-- empresa_video_pitch_screen.dart / set_my_profile_video — el video pitch es
-- un campo de perfil compartido entre roles, así que esta tabla se modela
-- por user_id sin ningún dato headhunter-specific, aunque hoy solo el UI de
-- Headhunter la consume. Solo la Edge Function (service role) escribe acá;
-- el dueño del perfil solo lee.
--
-- paused_at en jobs: verificado en vivo (19/8/2026) que jobs NO tiene
-- columna `status` (headhunter_dashboard_screen.dart:116 la pedía y rompía
-- en producción — se corrige aparte, ver commit de ese archivo). La columna
-- real de "abierta/cerrada" es `is_active` (boolean, ya existe). Para
-- "búsqueda en pausa" hace falta un estado nuevo real que el headhunter
-- setea a mano — no se fabrica un enum de 4 valores para algo que hoy no se
-- puede distinguir en la base: is_active AND paused_at IS NULL = abierta,
-- is_active AND paused_at IS NOT NULL = en pausa, NOT is_active = cerrada.
-- ============================================================================

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
-- video_pitch_analyses
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.video_pitch_analyses (
  user_id              UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  video_url            TEXT NOT NULL,
  transcript           TEXT,

  communication_score  DOUBLE PRECISION,
  clarity_score        DOUBLE PRECISION,
  authenticity_score   DOUBLE PRECISION,
  confidence_score     DOUBLE PRECISION,

  strengths            JSONB,
  skills               JSONB,
  overall_score        INT CHECK (overall_score BETWEEN 0 AND 100),

  analyzed_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.video_pitch_analyses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS vpa_select ON public.video_pitch_analyses;

-- Solo lectura para el dueño del perfil. Sin policy de INSERT/UPDATE/DELETE
-- a propósito: la Edge Function escribe con el service role, que salta RLS.
-- Un usuario autenticado normal no puede escribir su propio análisis (no
-- puede inventarse un resultado).
CREATE POLICY vpa_select ON public.video_pitch_analyses
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

REVOKE INSERT, UPDATE, DELETE ON public.video_pitch_analyses FROM authenticated, anon;


-- ────────────────────────────────────────────────────────────────────────────
-- jobs.paused_at
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS paused_at TIMESTAMPTZ;

COMMENT ON COLUMN public.jobs.paused_at IS
  'NULL = búsqueda no pausada. NOT NULL = en pausa desde esa fecha. Independiente de is_active (is_active=false es "cerrada", no "pausada").';

NOTIFY pgrst, 'reload schema';

COMMIT;
