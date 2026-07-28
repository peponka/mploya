-- ============================================================================
-- 021 — Segunda capa: quitarle a `authenticated` lo que el cliente nunca lee
-- ============================================================================
-- La 017 cerró el acceso ANÓNIMO. Faltaba el segundo orden: cualquier usuario
-- REGISTRADO podía leer el fcm_token (token de push) y el embedding de todos.
--
-- Antes no se podía tocar porque 10 consultas hacían `.select()` (todas las
-- columnas). Esas 10 ahora piden columnas explícitas
-- (lib/utils/user_columns.dart → kUserColumns), verificado contra los 30 campos
-- que usa NexUser.fromJson.
--
-- OJO (misma lección que 016→017): un REVOKE por columna NO recorta un GRANT de
-- tabla. Hay que revocar la tabla y volver a otorgar la lista blanca. Acá se
-- genera dinámicamente = todas las columnas menos las excluidas, así no se
-- desactualiza si mañana se agrega una columna nueva.
--
-- Se excluyen solo columnas con CERO lecturas en el cliente:
--   fcm_token         → token de push (permitiría spam dirigido)
--   profile_embedding → vector del perfil (derivado, pesado)
--
-- NO se excluye `email`: lo usa el panel de admin (admin_dashboard_screen).
-- Migrarlo a una RPC con is_admin() queda pendiente.
-- ============================================================================

DO $$
DECLARE
  v_cols TEXT;
BEGIN
  SELECT string_agg(quote_ident(column_name), ', ' ORDER BY ordinal_position)
    INTO v_cols
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'users'
    AND column_name NOT IN ('fcm_token', 'profile_embedding');

  EXECUTE 'REVOKE SELECT ON public.users FROM authenticated';
  EXECUTE format('GRANT SELECT (%s) ON public.users TO authenticated', v_cols);
END $$;

NOTIFY pgrst, 'reload schema';
