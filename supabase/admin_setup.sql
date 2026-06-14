-- ═══════════════════════════════════════════════════════════════════════════
-- Mploya — Configuración del Panel de Administración
--
-- Ejecutá este script UNA vez en el SQL Editor de Supabase.
-- Habilita la columna users.is_admin y las políticas RLS para que los
-- administradores puedan leer y moderar usuarios, ofertas y reportes.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1) Columna is_admin -------------------------------------------------------
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_admin boolean NOT NULL DEFAULT false;

-- 2) Helper SECURITY DEFINER para evitar recursión de RLS -------------------
--    Devuelve true si el usuario actual es admin.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT u.is_admin FROM public.users u WHERE u.id = auth.uid()),
    false
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- 3) Políticas RLS para administradores -------------------------------------
--    (se suman a las políticas existentes; no las reemplazan)

-- USERS: los admins pueden ver y editar cualquier perfil
DROP POLICY IF EXISTS "admins read all users" ON public.users;
CREATE POLICY "admins read all users" ON public.users
  FOR SELECT USING (public.is_admin());

DROP POLICY IF EXISTS "admins update all users" ON public.users;
CREATE POLICY "admins update all users" ON public.users
  FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());

-- JOBS: los admins pueden ver y eliminar cualquier oferta
DROP POLICY IF EXISTS "admins manage jobs" ON public.jobs;
CREATE POLICY "admins manage jobs" ON public.jobs
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- USER_REPORTS: los admins pueden ver y resolver reportes
--   (creá la tabla antes si todavía no existe)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_reports'
  ) THEN
    EXECUTE 'ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "admins manage reports" ON public.user_reports';
    EXECUTE 'CREATE POLICY "admins manage reports" ON public.user_reports
               FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin())';
  END IF;
END $$;

-- 4) Convertí tu cuenta en administrador ------------------------------------
--    Reemplazá el email por el tuyo y ejecutá esta línea.
-- UPDATE public.users SET is_admin = true WHERE email = 'tu-email@ejemplo.com';
