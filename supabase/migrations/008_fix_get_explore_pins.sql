-- 008_fix_get_explore_pins.sql
--
-- La función get_explore_pins() (usada por la pantalla Explorar para pintar
-- los pines del mapa) estaba fallando en cada llamada con:
--   "column u.is_active does not exist"
-- Esa columna nunca existió en public.users (probablemente quedó de una
-- versión anterior de la función). El error se tragaba silenciosamente en
-- el catch de Flutter, así que el mapa siempre mostraba "0 profesionales
-- cerca" sin importar cuántos usuarios reales hubiera con ubicación cargada.
--
-- Esta migración recrea la función con la misma lógica de distancia
-- (Haversine) que ya usa get_nearby_users, sin la columna inexistente.
-- Correr en: Supabase Dashboard → SQL Editor → pegar y ejecutar.

CREATE OR REPLACE FUNCTION public.get_explore_pins(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision DEFAULT 50
)
RETURNS TABLE (
  pin_id uuid,
  pin_name text,
  pin_headline text,
  pin_type text,
  latitude double precision,
  longitude double precision,
  distance_km double precision
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT * FROM (
    SELECT
      u.id AS pin_id,
      u.name AS pin_name,
      u.headline AS pin_headline,
      u.account_type AS pin_type,
      u.latitude,
      u.longitude,
      (6371 * acos(LEAST(1.0,
        cos(radians(p_lat)) * cos(radians(u.latitude))
        * cos(radians(u.longitude) - radians(p_lng))
        + sin(radians(p_lat)) * sin(radians(u.latitude))
      ))) AS distance_km
    FROM public.users u
    WHERE u.id IS DISTINCT FROM auth.uid()
      AND u.latitude IS NOT NULL
      AND u.longitude IS NOT NULL
  ) sub
  WHERE distance_km <= p_radius_km
  ORDER BY distance_km ASC
  LIMIT 200;
$$;

GRANT EXECUTE ON FUNCTION public.get_explore_pins(double precision, double precision, double precision) TO authenticated;
