-- ============================================================================
-- 016 — Cerrar fuga de PII: quitar columnas sensibles al rol `anon`
-- ============================================================================
-- HALLAZGO (28/7/2026): la tabla public.users tiene políticas RLS de SELECT con
-- `USING (true)` para el rol público, así que CUALQUIERA con la anon key (que es
-- pública: viaja dentro de la app web y del APK) podía leer, sin login:
--
--   curl '.../rest/v1/users?select=name,email,latitude,salary_expectation,fcm_token'
--     -H "apikey: <anon>"
--   → [{"name":"...","email":"...","latitude":-25.27...,"fcm_token":"eArNOV..."}]
--
-- Es decir: emails, coordenadas GPS exactas, expectativa salarial y tokens de
-- push de los 59 usuarios quedaban expuestos.
--
-- ARREGLO: RLS es por fila, no por columna, así que se usan privilegios de
-- columna (GRANT/REVOKE por columna, nativo de Postgres) para sacarle a `anon`
-- las columnas sensibles. El rol `authenticated` NO se toca: la app hace
-- `select()` (todas las columnas) en ~122 lugares y se rompería.
--
-- Nota: queda pendiente el problema de segundo orden — un usuario logueado
-- todavía puede leer el email/ubicación de los demás. Arreglarlo requiere
-- cambiar esos ~122 `select()` por listas explícitas de columnas; se deja para
-- una pasada aparte porque es refactor de app, no de base.
-- ============================================================================

REVOKE SELECT (
  email,                -- PII
  fcm_token,            -- token de push
  latitude,             -- ubicación exacta
  longitude,            -- ubicación exacta
  location_geom,        -- ubicación exacta (PostGIS)
  salary_expectation,   -- dato sensible
  personality_scores,   -- análisis psicométrico
  ai_transcript_json,   -- transcripción del video
  is_admin,             -- revela cuentas admin
  b2b_tokens,           -- créditos internos
  deleted_at            -- estado interno
) ON public.users FROM anon;

-- Verificación (debe devolver 0 filas):
--   select column_name from information_schema.column_privileges
--   where grantee='anon' and table_name='users' and privilege_type='SELECT'
--     and column_name in ('email','fcm_token','latitude','longitude',
--                         'salary_expectation','personality_scores',
--                         'ai_transcript_json','is_admin','b2b_tokens',
--                         'location_geom','deleted_at');
