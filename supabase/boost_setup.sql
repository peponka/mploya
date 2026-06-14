-- ─────────────────────────────────────────────────────────────────────────────
-- Boost: guardar cuándo arrancó el boost para poder medir su impacto real
-- (cuántas vistas de perfil generó desde que se activó).
--
-- Correr una vez en el SQL editor de Supabase. Es idempotente.
-- Si no se corre, el Boost sigue funcionando igual; solo no se muestra la
-- tarjeta de "vistas generadas" (degradación elegante).
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS boost_started_at timestamptz;
