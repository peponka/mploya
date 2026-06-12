-- ============================================================
-- MPLOYA — Fix Security Vulnerability: Enable RLS on users
-- Fecha: 2026-04-08
-- Ejecutar en: Supabase Dashboard → SQL Editor → Run
-- Descripción: Supabase reportó una vulnerabilidad porque la
-- tabla public.users no tiene habilitado el Row-Level Security
-- (RLS), lo que permite lectura/escritura pública por defecto.
-- ============================================================

-- Habilitar RLS explícitamente en la tabla de usuarios
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Política existente (por si no se corrió antes):
-- Asegurar que el usuario pueda editar su propio perfil
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'users_own_upsert'
  ) THEN
    EXECUTE 'CREATE POLICY "users_own_upsert" ON public.users FOR ALL USING (auth.uid() = id) WITH CHECK (auth.uid() = id)';
  END IF;
END$$;

-- NUEVA POLÍTICA: Lectura global
-- Todos los usuarios autenticados (o anon) deben poder leer public.users (para feeds, radar, búsquedas, etc)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'users_select_all'
  ) THEN
    EXECUTE 'CREATE POLICY "users_select_all" ON public.users FOR SELECT USING (true)';
  END IF;
END$$;
