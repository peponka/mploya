-- ============================================================================
-- 022 — Último punto: que `email` no sea legible por cualquier usuario logueado
-- ============================================================================
-- Tras la 021, un usuario registrado ya no ve fcm_token ni embeddings, pero SÍ
-- el email de todos. No se pudo revocar entonces porque el panel de admin lo
-- necesita (admin_dashboard_screen: listado de usuarios y listado de boosts).
--
-- Solución: mover esas dos consultas a RPCs SECURITY DEFINER que verifican
-- is_admin() (que ya existe y es SECURITY DEFINER), y sacarle `email` a
-- `authenticated`. Así el email solo sale por una puerta que valida permisos.
--
-- Nota: `upsertUserProfile` ESCRIBE users.email pero no lo lee, así que revocar
-- SELECT no afecta el registro.
-- ============================================================================

DROP FUNCTION IF EXISTS public.admin_list_users(TEXT, INTEGER);
CREATE OR REPLACE FUNCTION public.admin_list_users(
  p_account_type TEXT DEFAULT NULL,
  p_limit        INTEGER DEFAULT 200
)
RETURNS TABLE (
  id           UUID,
  name         TEXT,
  email        TEXT,
  account_type TEXT,
  is_verified  BOOLEAN,
  is_premium   BOOLEAN,
  location     TEXT,
  video_url    TEXT,
  created_at   TIMESTAMPTZ
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'solo administradores';
  END IF;

  RETURN QUERY
  -- Casts explícitos: los tipos reales son mezcla de text/varchar/USER-DEFINED
  -- y un RETURNS TABLE que no coincide da 42804 en tiempo de ejecución.
  SELECT u.id, u.name::TEXT, u.email::TEXT, u.account_type::TEXT,
         u.is_verified, u.is_premium,
         u.location::TEXT, u.video_url::TEXT, u.created_at
  FROM public.users u
  WHERE p_account_type IS NULL OR u.account_type = p_account_type
  ORDER BY u.created_at DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_users(TEXT, INTEGER) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_list_boosted();
CREATE OR REPLACE FUNCTION public.admin_list_boosted()
RETURNS TABLE (
  id            UUID,
  name          TEXT,
  email         TEXT,
  account_type  TEXT,
  boost_ends_at TIMESTAMPTZ
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'solo administradores';
  END IF;

  RETURN QUERY
  SELECT u.id, u.name::TEXT, u.email::TEXT, u.account_type::TEXT, u.boost_ends_at
  FROM public.users u
  WHERE u.boost_ends_at > now()
  ORDER BY u.boost_ends_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_boosted() TO authenticated;

-- Recalcular la lista blanca de `authenticated` sumando `email` a las excluidas.
DO $$
DECLARE v_cols TEXT;
BEGIN
  SELECT string_agg(quote_ident(column_name), ', ' ORDER BY ordinal_position)
    INTO v_cols
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'users'
    AND column_name NOT IN ('fcm_token', 'profile_embedding', 'email');

  EXECUTE 'REVOKE SELECT ON public.users FROM authenticated';
  EXECUTE format('GRANT SELECT (%s) ON public.users TO authenticated', v_cols);
END $$;

NOTIFY pgrst, 'reload schema';
