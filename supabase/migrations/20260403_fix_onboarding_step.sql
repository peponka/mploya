-- ============================================================
-- MPLOYA — Onboarding step column + trigger saneado
-- Fecha: 2026-04-03
-- Ejecutar en: Supabase Dashboard → SQL Editor → Run
--
-- PROBLEMA RESUELTO:
--   El trigger anterior inyectaba name=split_part(email,'@',1) y
--   account_type podía tener DEFAULT 'candidato', engañando al
--   routing en Flutter que asumía "ya completó el onboarding".
--
-- SOLUCIÓN:
--   1. Columna onboarding_step como fuente de verdad del onboarding.
--   2. Trigger limpio: solo id + email + onboarding_step=0.
--   3. Se elimina DEFAULT en account_type para que NULL sea señal real.
-- ============================================================

-- 1. Columna onboarding_step
-- 0=nuevo  1=rol elegido  2=perfil completo  3=video subido
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS onboarding_step INTEGER NOT NULL DEFAULT 0;

-- Usuarios que ya completaron el onboarding (tienen video_url) → step 3
UPDATE public.users
  SET onboarding_step = 3
  WHERE video_url IS NOT NULL
    AND video_url <> ''
    AND onboarding_step = 0;

-- Usuarios que tienen perfil pero sin video → step 2
UPDATE public.users
  SET onboarding_step = 2
  WHERE account_type IS NOT NULL
    AND account_type <> ''
    AND (name IS NOT NULL AND name <> '')
    AND (video_url IS NULL OR video_url = '')
    AND onboarding_step = 0;

-- Usuarios que solo eligieron rol (tienen account_type pero name vacío) → step 1
UPDATE public.users
  SET onboarding_step = 1
  WHERE account_type IS NOT NULL
    AND account_type <> ''
    AND (name IS NULL OR name = '')
    AND onboarding_step = 0;

-- 2. Quitar DEFAULT de account_type para que NULL sea señal real de "sin rol"
ALTER TABLE public.users
  ALTER COLUMN account_type DROP DEFAULT;

-- 3. Trigger limpio — NO inyecta name ni account_type
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, email, name, onboarding_step)
  VALUES (NEW.id, NEW.email, '', 0)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE PROCEDURE public.handle_new_user();
