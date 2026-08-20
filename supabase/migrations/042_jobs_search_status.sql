-- ============================================================================
-- 042 - Estado real de búsqueda (jobs.search_status)
-- ============================================================================
-- El mockup canónico `10_Headhunter_Busquedas_Activas.png` filtra por CUATRO
-- estados mutuamente excluyentes por búsqueda: Abierta / En proceso /
-- En pausa / Cerrada (con sus propios contadores y %). `jobs.is_active`
-- (booleano) no alcanza para eso, y `jobs.paused_at` (migración 040, agregada
-- en esta misma sesión, todavía sin ningún consumidor real salvo mi propio
-- código de dashboard) tampoco: sólo cubre pausa, no las cuatro.
--
-- Se reemplaza por una columna de estado real. `is_active` NO se toca (sigue
-- gobernando visibilidad pública en feed/explore/matching para los tres
-- roles); `search_status` es un campo adicional, propio del flujo de
-- Headhunter, que no participa de esa lógica.
--
-- Backfill: única inferencia honesta posible desde datos existentes es
-- `is_active = false → 'cerrada'`. Todo lo demás (abierta/en_proceso/
-- en_pausa) requiere que el headhunter lo setee — no hay forma de derivarlo
-- de datos que no existen, así que el resto de las vacantes activas quedan
-- en 'abierta' (el estado por defecto, y el más probable para una vacante
-- que sigue activa y nunca se marcó en pausa).
-- ============================================================================

BEGIN;

ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS search_status TEXT NOT NULL DEFAULT 'abierta'
    CHECK (search_status IN ('abierta', 'en_proceso', 'en_pausa', 'cerrada'));

UPDATE public.jobs SET search_status = 'cerrada' WHERE is_active = false;

ALTER TABLE public.jobs DROP COLUMN IF EXISTS paused_at;

COMMENT ON COLUMN public.jobs.search_status IS
  'Estado de la búsqueda para el flujo de Headhunter (abierta/en_proceso/en_pausa/cerrada). No gobierna visibilidad pública — para eso sigue existiendo is_active.';

NOTIFY pgrst, 'reload schema';

COMMIT;
