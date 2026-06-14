-- ─────────────────────────────────────────────────────────────────────────────
-- Cuenta de prueba HEADHUNTER lista para usar.
-- Pone una contraseña conocida y deja el onboarding completo para entrar directo
-- al feed. Correr una vez en el SQL editor de Supabase.
--
-- Login resultante:
--   Email:    pepeq68+headhunter@gmail.com
--   Password: Mploya2026
-- ─────────────────────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1) Password conocida + email confirmado
UPDATE auth.users
SET encrypted_password = crypt('Mploya2026', gen_salt('bf')),
    email_confirmed_at  = COALESCE(email_confirmed_at, now()),
    updated_at          = now()
WHERE email = 'pepeq68+headhunter@gmail.com';

-- 2) Perfil headhunter con onboarding completo (salta directo al feed)
UPDATE public.users
SET account_type   = 'headhunter',
    onboarding_step = 3,
    name           = 'TalentLab',
    headline       = 'Headhunter IT & Tech',
    is_hiring      = true
WHERE email = 'pepeq68+headhunter@gmail.com';
