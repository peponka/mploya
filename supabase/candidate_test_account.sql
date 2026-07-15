-- ─────────────────────────────────────────────────────────────────────────────
-- Script SQL corregido para crear un Candidato de prueba confirmado.
--
-- Credenciales resultantes:
--   Email:    candidato@mploya.ai
--   Password: Mploya2026!
-- ─────────────────────────────────────────────────────────────────────────────

-- 1) Limpiar cualquier registro existente para evitar conflictos de claves únicas
DELETE FROM public.users WHERE email = 'candidato@mploya.ai';
DELETE FROM auth.users WHERE email = 'candidato@mploya.ai';

-- 2) Insertar el usuario limpio en la tabla de autenticación (auth.users)
INSERT INTO auth.users (
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
VALUES (
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'candidato@mploya.ai',
  crypt('Mploya2026!', gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}',
  '{}',
  now(),
  now(),
  '',
  '',
  '',
  ''
);

-- 3) Crear su perfil público en la tabla public.users configurado como candidato
--    con onboarding completo (step = 3) para entrar directo.
INSERT INTO public.users (
  id,
  email,
  account_type,
  onboarding_step,
  name,
  headline,
  is_hiring,
  created_at,
  updated_at
)
SELECT 
  id,
  email,
  'candidato',
  3,
  'Juan Pérez',
  'Flutter Developer Senior',
  false,
  now(),
  now()
FROM auth.users
WHERE email = 'candidato@mploya.ai';
