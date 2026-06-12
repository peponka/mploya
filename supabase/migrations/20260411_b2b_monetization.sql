-- ============================================================
-- MPLOYA — Migración de B2B Monetización (RevenueCat)
-- Fecha: 2026-04-11
-- ============================================================

-- Añadir campos para estado premium y tokens (si aplica) 
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS b2b_tokens INTEGER DEFAULT 0;

COMMENT ON COLUMN public.users.is_premium IS 'Identifica si la empresa/headhunter pagó suscripción Corporate/Premium por RevenueCat';
COMMENT ON COLUMN public.users.b2b_tokens IS 'Balance de tokens para uso avanzado (opcional)';
