-- 012_fix_connections_fk_to_users.sql
--
-- SEGUNDO BUG REAL en el mismo flujo de conexiones (después de 011): incluso
-- con las columnas legacy ya nullable, enviar una solicitud sigue fallando:
--
--   code 23503 — insert or update on table "connections" violates foreign
--   key constraint "connections_requester_id_fkey"
--   Key (requester_id)=(<uid real>) is not present in table "profiles"
--
-- Causa: connections.requester_id y connections.addressee_id tienen FKs que
-- apuntan a `public.profiles`, una tabla vieja de un esquema anterior
-- (columnas full_name/user_type/job_seeker) que ya no se usa para altas de
-- usuarios reales. Los usuarios reales viven en `public.users` desde hace
-- tiempo. Como ningún usuario nuevo tiene fila en `profiles`, el INSERT
-- muere siempre → conectar sigue roto para cualquier cuenta real.
--
-- Fix: repuntar las FKs a public.users(id), que es la tabla real.

ALTER TABLE public.connections
  DROP CONSTRAINT IF EXISTS connections_requester_id_fkey;
ALTER TABLE public.connections
  ADD CONSTRAINT connections_requester_id_fkey
  FOREIGN KEY (requester_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.connections
  DROP CONSTRAINT IF EXISTS connections_addressee_id_fkey;
ALTER TABLE public.connections
  ADD CONSTRAINT connections_addressee_id_fkey
  FOREIGN KEY (addressee_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- Nota: las columnas legacy (user_id, connected_user_id) quedaron nullable
-- en 011 y el RPC actual no las usa, así que no hace falta tocar sus FKs
-- para desbloquear el flujo. Si en el futuro se detecta que también
-- bloquean algo, repuntearlas a public.users(id) igual que arriba.
