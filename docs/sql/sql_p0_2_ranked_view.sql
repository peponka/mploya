-- ================================================================
-- P0-2 FIX: FEED RANKING TRASLADADO AL SERVIDOR (SQL View)
-- Copia este texto y córrelo en el SQL Editor de tu Supabase.
-- ================================================================

-- Creamos una vista dinámica que precalcula los "Puntos" de jerarquía.
-- A diferencia de la de Claude (Materialized), esta es en tiempo real, 
-- por lo que si alguien edita su perfil, el cambio se refleja al instante.

CREATE OR REPLACE VIEW public.feed_ranked AS
SELECT
  u.*,
  (CASE WHEN u.boost_ends_at > now() THEN 1000 ELSE 0 END
   + CASE WHEN u.is_premium THEN 100 ELSE 0 END) AS base_score
FROM public.users u
WHERE u.video_url IS NOT NULL AND u.video_url != '';

-- Las políticas de seguridad (RLS) se heredan directamente de la tabla 'users'.
