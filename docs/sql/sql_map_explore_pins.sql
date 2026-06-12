-- ============================================================
-- SQL MAP EXPLORE PINS — Ejecutar en Supabase SQL Editor
-- Muestra Candidatos a las Empresas y Empresas a los Candidatos
-- ============================================================

CREATE OR REPLACE FUNCTION get_explore_pins(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 50.0
)
RETURNS TABLE (
  pin_id UUID,
  pin_name TEXT,
  pin_headline TEXT,
  pin_type TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  distance_km DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_type TEXT;
BEGIN
  -- Obtener el tipo de cuenta del usuario actual
  SELECT u.account_type INTO v_caller_type FROM users u WHERE u.id = auth.uid();
  
  -- Si es una empresa, buscamos candidatos cercanos (hasta 50km por defecto)
  IF v_caller_type = 'empresa' THEN
    RETURN QUERY
    SELECT 
      u.id AS pin_id,
      u.name AS pin_name,
      u.headline AS pin_headline,
      u.account_type AS pin_type,
      ST_Y(u.location::geometry) AS latitude,
      ST_X(u.location::geometry) AS longitude,
      (ST_DistanceSphere(u.location::geometry, ST_MakePoint(p_lng, p_lat)) / 1000.0)::DOUBLE PRECISION AS distance_km
    FROM users u
    WHERE u.id != auth.uid()
      AND u.account_type != 'empresa'
      AND u.is_active = true
      AND u.location IS NOT NULL
      AND ST_DWithin(u.location::geography, ST_MakePoint(p_lng, p_lat)::geography, p_radius_km * 1000)
    ORDER BY distance_km ASC
    LIMIT 60;
      
  -- Si es un candidato (o cualquier otro), buscamos empresas/vacantes cercanas
  ELSE
    RETURN QUERY
    SELECT 
      u.id AS pin_id,
      u.name AS pin_name,
      u.headline AS pin_headline,
      u.account_type AS pin_type,
      ST_Y(u.location::geometry) AS latitude,
      ST_X(u.location::geometry) AS longitude,
      (ST_DistanceSphere(u.location::geometry, ST_MakePoint(p_lng, p_lat)) / 1000.0)::DOUBLE PRECISION AS distance_km
    FROM users u
    WHERE u.id != auth.uid()
      AND u.account_type = 'empresa'
      AND u.is_active = true
      AND u.location IS NOT NULL
      AND ST_DWithin(u.location::geography, ST_MakePoint(p_lng, p_lat)::geography, p_radius_km * 1000)
    ORDER BY distance_km ASC
    LIMIT 60;
  END IF;
END;
$$;
