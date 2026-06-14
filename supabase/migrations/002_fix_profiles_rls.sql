-- =============================================================================
-- Migración 002: Habilitar RLS en la tabla `profiles`
-- =============================================================================
-- PROBLEMA: La tabla `profiles` no tenía RLS habilitado, lo que permitía
-- que cualquier persona con la URL del proyecto pudiera leer, editar y
-- borrar datos de todos los usuarios.
--
-- Esta migración:
--   1. Habilita RLS en `profiles`
--   2. Crea políticas granulares para SELECT, INSERT, UPDATE y DELETE
--   3. Agrega política para que el service_role siga funcionando
-- =============================================================================

-- ─── Habilitar RLS ──────────────────────────────────────────────────

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- ─── Políticas RLS — Profiles ───────────────────────────────────────

-- Cualquier usuario autenticado puede ver perfiles (necesario para
-- mostrar nombres, avatares, etc. en el feed, matches y conexiones)
CREATE POLICY "profiles_select_authenticated"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

-- Un usuario solo puede insertar su propio perfil
-- (el id del perfil debe coincidir con el uid de auth)
CREATE POLICY "profiles_insert_own"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Un usuario solo puede actualizar su propio perfil
CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Un usuario solo puede eliminar su propio perfil
CREATE POLICY "profiles_delete_own"
  ON public.profiles FOR DELETE
  TO authenticated
  USING (auth.uid() = id);

-- =============================================================================
-- NOTA: El rol `service_role` bypasea RLS automáticamente en Supabase,
-- así que las Edge Functions y triggers del servidor siguen funcionando
-- sin necesidad de políticas adicionales.
-- =============================================================================
