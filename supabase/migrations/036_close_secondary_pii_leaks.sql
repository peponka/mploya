-- 036_close_secondary_pii_leaks.sql
--
-- Auditoría de seguimiento (18/8/2026) tras la 035: se encontraron 5 tablas
-- con exposición de PII o de datos internos por el mismo patrón (GRANT
-- amplio + política RLS permisiva, o política scaffolding de Supabase
-- nunca retirada). Verificado contra el código real (lib/, supabase/,
-- web-public/): NINGUNA de estas rutas está en uso por la app ni por
-- Edge Functions salvo `messages`, que ya tiene las políticas correctas
-- funcionando en paralelo. Cierre sin impacto funcional esperado.

BEGIN;

-- 1) messages: políticas "scaffolding" de plantilla Supabase, nunca
--    retiradas, que conviven (OR) con las políticas correctas
--    (messages_select / messages_select_conversation_participant /
--    messages_update / messages_update_own / messages_insert_own).
--    Permitían a cualquier usuario autenticado leer, editar o insertar
--    mensajes de cualquier conversación ajena.
DROP POLICY IF EXISTS "Allow select for authenticated" ON public.messages;
DROP POLICY IF EXISTS "Allow update for authenticated" ON public.messages;
DROP POLICY IF EXISTS "Allow insert for authenticated" ON public.messages;

-- 2) profiles: tabla legacy sin ninguna referencia en lib/, supabase/ ni
--    web-public/. Exponía email/phone/latitude/longitude exactos/fcm_token
--    en lectura pública (incluso sin login) y permitía INSERT arbitrario
--    sin autenticar. Se revoca el acceso de cliente por completo.
REVOKE ALL ON TABLE public.profiles FROM anon, authenticated;
DROP POLICY IF EXISTS "Profiles: public read" ON public.profiles;
DROP POLICY IF EXISTS "Profiles: anyone insert" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_authenticated" ON public.profiles;

-- 3) employees: sin ninguna referencia en el código. Exponía
--    email/phone/name de empleados de empresas en lectura pública.
REVOKE ALL ON TABLE public.employees FROM anon, authenticated;
DROP POLICY IF EXISTS "Employees: public read" ON public.employees;

-- 4) user_roles: sin ninguna referencia en el código. Se revoca acceso
--    de cliente por completo (evita además auto-asignación de `role`).
REVOKE ALL ON TABLE public.user_roles FROM anon, authenticated;

-- 5) moderation_log: la app solo hace INSERT (content_moderation_service.dart),
--    nunca SELECT. La política de lectura abierta a cualquier autenticado
--    se acota a admins.
DROP POLICY IF EXISTS "modlog_read_auth" ON public.moderation_log;
CREATE POLICY "moderation_log_select_admin" ON public.moderation_log
  FOR SELECT TO authenticated
  USING (is_admin());

-- 6) content_reports: INSERT/UPDATE/DELETE ya estaban correctamente
--    denegados (safe_deny_*, sin tocar). El SELECT estaba abierto a
--    cualquier autenticado (veía quién reportó a quién y por qué); se
--    acota al propio reporter o a un admin.
DROP POLICY IF EXISTS "safe_select_content_reports" ON public.content_reports;
CREATE POLICY "content_reports_select_own_or_admin" ON public.content_reports
  FOR SELECT TO authenticated
  USING (reporter_id = auth.uid() OR is_admin());

NOTIFY pgrst, 'reload schema';

COMMIT;
