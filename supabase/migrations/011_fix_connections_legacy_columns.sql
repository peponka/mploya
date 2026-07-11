-- 011_fix_connections_legacy_columns.sql
--
-- BUG REAL DE PRODUCCIÓN: enviar solicitud de conexión falla SIEMPRE.
--
-- Síntoma: el RPC send_connection_request devuelve 400 con:
--   code 23502 — null value in column "user_id" of relation "connections"
--   violates not-null constraint
--
-- Causa: la tabla connections tiene columnas legacy (user_id,
-- connected_user_id) marcadas NOT NULL de una versión anterior del esquema.
-- El RPC actual inserta usando las columnas nuevas (requester_id,
-- addressee_id) y no rellena las legacy → el INSERT muere y NADIE puede
-- conectar en toda la app (el botón del feed parece funcionar porque la UI
-- es optimista, pero no guarda nada).
--
-- Fix mínimo y sin tocar el RPC: soltar el NOT NULL de las columnas legacy
-- y backfillearlas desde las nuevas para mantener consistencia con
-- cualquier código viejo que todavía las lea.

ALTER TABLE public.connections ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE public.connections ALTER COLUMN connected_user_id DROP NOT NULL;

-- Backfill defensivo de filas existentes (si las hay) donde las legacy
-- estén pobladas pero las nuevas no, y viceversa.
UPDATE public.connections
SET user_id = requester_id
WHERE user_id IS NULL AND requester_id IS NOT NULL;

UPDATE public.connections
SET connected_user_id = addressee_id
WHERE connected_user_id IS NULL AND addressee_id IS NOT NULL;
