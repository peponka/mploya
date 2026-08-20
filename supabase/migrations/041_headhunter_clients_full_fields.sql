-- ============================================================================
-- 041 - Completa headhunter_clients contra el mockup canónico + client_id en jobs
-- ============================================================================
-- La 039 se escribió a partir del canvas de Claude Design (una reconstrucción
-- de referencia), sin haber mirado todavía los PNG canónicos de
-- design-reference/FINAL_SCREENS_CODEX/.../FINAL_SCREENS — que SON la fuente
-- única de verdad de este proyecto (ver cabecera de mploya_tokens.dart). Al
-- revisarlos antes de construir la pantalla real (headhunter clientes.png,
-- 06/07/08/09_Headhunter_*_Cliente.png) aparecieron campos reales que 039 no
-- tenía: tamaño de empresa, sitio web, descripción, tipo de relación, nivel
-- de decisión de contacto, cómo se conocieron, frecuencia de búsquedas,
-- frecuencia de contacto, y DOS notas separadas (no una) — además de un
-- estado de cliente (activo/en pausa/finalizado) que se ve en la lista pero
-- no se carga en el wizard, y el vínculo cliente↔vacante que la lista
-- necesita para mostrar "3 búsquedas / 8 en proceso" por cliente.
--
-- La tabla se creó hoy (039) y sigue vacía en producción (verificado antes de
-- escribir esto: el único INSERT que existió fue una fila de prueba que ya se
-- borró) — por eso este archivo hace ALTER/SET NOT NULL/DROP directo, sin
-- backfill: no hay ninguna fila real que perder.
--
-- Los campos que en el mockup son un <select> con una sola opción visible en
-- la captura (nivel de decisión, cómo se conocieron, frecuencia de
-- búsquedas, frecuencia de contacto) quedan como TEXT sin CHECK: no se
-- inventa un enum completo a partir de un solo valor de ejemplo. Los que
-- tienen las N opciones completas y visibles (tipo de relación, modalidad,
-- tiempo de respuesta, confidencialidad, canal de novedades) sí llevan CHECK.
-- ============================================================================

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
-- Paso 1 · Información básica
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.headhunter_clients
  ALTER COLUMN industry SET NOT NULL,
  ALTER COLUMN country  SET NOT NULL,
  ALTER COLUMN city     SET NOT NULL;

ALTER TABLE public.headhunter_clients
  ADD COLUMN IF NOT EXISTS company_size TEXT,
  ADD COLUMN IF NOT EXISTS website      TEXT,
  ADD COLUMN IF NOT EXISTS description  TEXT CHECK (char_length(description) <= 300),
  ADD COLUMN IF NOT EXISTS relationship_type TEXT CHECK (
    relationship_type IN ('cliente_activo', 'prospecto', 'red_referido')
  );

-- ────────────────────────────────────────────────────────────────────────────
-- Paso 2 · Contacto principal
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.headhunter_clients
  ALTER COLUMN contact_first_name SET NOT NULL,
  ALTER COLUMN contact_last_name  SET NOT NULL,
  ALTER COLUMN contact_role       SET NOT NULL,
  ALTER COLUMN contact_email      SET NOT NULL,
  ALTER COLUMN contact_phone      SET NOT NULL;

ALTER TABLE public.headhunter_clients
  ADD COLUMN IF NOT EXISTS decision_level TEXT,
  ADD COLUMN IF NOT EXISTS how_we_met     TEXT,
  ADD COLUMN IF NOT EXISTS relationship_notes TEXT
    CHECK (char_length(relationship_notes) <= 300);

-- ────────────────────────────────────────────────────────────────────────────
-- Paso 3 · Preferencias de trabajo
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.headhunter_clients
  ADD COLUMN IF NOT EXISTS search_frequency  TEXT,
  ADD COLUMN IF NOT EXISTS contact_frequency TEXT,
  ADD COLUMN IF NOT EXISTS important_notes   TEXT
    CHECK (char_length(important_notes) <= 300);

-- `notes` (039) queda reemplazada por relationship_notes + important_notes,
-- que es lo que el mockup realmente pide (dos cuadros distintos, en pasos
-- distintos). Sin backfill: la tabla está vacía, no hay nada que migrar.
ALTER TABLE public.headhunter_clients DROP COLUMN IF EXISTS notes;

-- ────────────────────────────────────────────────────────────────────────────
-- Estado del cliente (lista "Mis clientes": Activo / En pausa / Finalizado)
-- ────────────────────────────────────────────────────────────────────────────
--
-- El wizard no lo carga (fija 'active' al crear); se edita después desde el
-- detalle del cliente, que no se construye en este pase. Claves alineadas
-- 1:1 con el enum MpStatus ya existente en widgets/ds/mp_chip.dart
-- (active/paused/finished), para no inventar un segundo vocabulario.
ALTER TABLE public.headhunter_clients
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'paused', 'finished'));

-- ────────────────────────────────────────────────────────────────────────────
-- jobs.client_id — vínculo cliente↔vacante
-- ────────────────────────────────────────────────────────────────────────────
--
-- Sin esto, "Mis clientes" no puede mostrar cuántas búsquedas tiene cada
-- cliente ni cuántos candidatos en proceso: son las columnas reales que el
-- mockup muestra por fila ("3 Búsquedas / 8 En proceso"). Nullable y
-- aditivo: no afecta a Empresa, que nunca usa esta columna.
ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS client_id UUID REFERENCES public.headhunter_clients(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_jobs_client ON public.jobs (client_id);

COMMENT ON COLUMN public.jobs.client_id IS
  'Cliente de headhunter dueño de esta búsqueda (headhunter_clients.id). NULL para vacantes de Empresa o vacantes de Headhunter todavía sin cliente asignado.';

NOTIFY pgrst, 'reload schema';

COMMIT;
