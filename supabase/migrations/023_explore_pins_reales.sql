-- ============================================================================
-- 023 — Mapa de Candidatos con usuarios REALES
-- ============================================================================
-- Hallazgo de la auditoría (29/7/2026): `explore_screen.dart` no tenía NINGUNA
-- referencia a Supabase — todos los pines del mapa salían de `simCandidates`
-- (datos inventados en el código). Un candidato real que se registrara nunca
-- aparecía en el mapa.
--
-- La función `get_explore_pins` ya existía y NADIE la llamaba. Se le agregan
-- avatar_url y video_url para que el pin muestre la foto real y el badge
-- "Con video", y se marca SECURITY DEFINER + search_path fijo.
-- ============================================================================

DROP FUNCTION IF EXISTS public.get_explore_pins(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);

CREATE OR REPLACE FUNCTION public.get_explore_pins(
  p_lat       DOUBLE PRECISION,
  p_lng       DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 50
)
RETURNS TABLE (
  pin_id       UUID,
  pin_name     TEXT,
  pin_headline TEXT,
  pin_type     TEXT,
  avatar_url   TEXT,
  has_video    BOOLEAN,
  latitude     DOUBLE PRECISION,
  longitude    DOUBLE PRECISION,
  distance_km  DOUBLE PRECISION
)
SECURITY DEFINER
SET search_path = public
LANGUAGE sql STABLE AS $$
  SELECT * FROM (
    SELECT
      u.id                                   AS pin_id,
      u.name::TEXT                           AS pin_name,
      COALESCE(u.headline, '')::TEXT         AS pin_headline,
      COALESCE(u.account_type, 'candidato')::TEXT AS pin_type,
      u.avatar_url::TEXT                     AS avatar_url,
      (u.video_url IS NOT NULL AND u.video_url <> '') AS has_video,
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
      AND u.deleted_at IS NULL
      AND u.name IS NOT NULL
  ) sub
  WHERE distance_km <= p_radius_km
  ORDER BY distance_km ASC
  LIMIT 200;
$$;

GRANT EXECUTE ON FUNCTION public.get_explore_pins(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION)
  TO authenticated, anon;

NOTIFY pgrst, 'reload schema';
