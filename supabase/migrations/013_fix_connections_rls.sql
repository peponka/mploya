-- 013_fix_connections_rls.sql
--
-- TERCER BUG REAL en el mismo flujo de conexiones (después de 011 y 012):
-- después de arreglar el INSERT, el receptor de la solicitud (addressee)
-- no puede verla — ni por REST directo ni vía respond_connection, que
-- devuelve {"error": "request_not_found"} aunque la fila exista (confirmado
-- consultándola por id directamente: 0 filas para el addressee, pero el
-- INSERT como requester sí había devuelto 200 con connection_id real).
--
-- Causa: la política RLS de SELECT en connections solo evalúa
-- auth.uid() = requester_id (quien envía), nunca addressee_id (quien
-- recibe). Resultado: nadie puede aceptar una solicitud que le llega,
-- porque ni siquiera puede leerla. Esto rompe el flujo de conexión
-- completo para el lado receptor, en toda la app.
--
-- Fix: recrear las políticas de connections para que ambas partes
-- (requester y addressee) puedan ver y actualizar la fila, y solo el
-- requester pueda crearla. Se listan y dropean las políticas existentes
-- dinámicamente porque no se conoce su nombre exacto.

DO $$
DECLARE pol record;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'connections'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.connections', pol.policyname);
  END LOOP;
END $$;

ALTER TABLE public.connections ENABLE ROW LEVEL SECURITY;

CREATE POLICY connections_select ON public.connections
  FOR SELECT
  USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

CREATE POLICY connections_insert ON public.connections
  FOR INSERT
  WITH CHECK (auth.uid() = requester_id);

CREATE POLICY connections_update ON public.connections
  FOR UPDATE
  USING (auth.uid() = requester_id OR auth.uid() = addressee_id);
