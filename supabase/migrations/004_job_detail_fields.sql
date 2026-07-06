-- ============================================================================
-- 004 — Campos de detalle de oferta (para la pantalla JobDetailScreen)
-- ============================================================================
-- Agrega a public.jobs los campos que hacen escaneable el detalle de una oferta
-- (estilo ficha JobToday) + latitude/longitude planos para que Flutter pueda
-- dibujar el mini-mapa sin tener que parsear el geography location_geom.
--
-- Correr una sola vez en el SQL Editor de Supabase. Es idempotente
-- (ADD COLUMN IF NOT EXISTS + CREATE OR REPLACE), se puede re-ejecutar sin daño.
-- ----------------------------------------------------------------------------

-- 1. Columnas descriptivas (todas opcionales; la UI muestra solo las que tienen valor)
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS description       TEXT;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS employment_type   TEXT;   -- Jornada: 'Completa' / 'Parcial' / 'Por horas'
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS schedule          TEXT;   -- Horario: texto libre ('Lun a Vie, mañanas')
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS experience_level  TEXT;   -- 'Sin experiencia' / 'Se valora' / 'Imprescindible'
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS extras            TEXT;   -- 'Plus tips', 'Auto de empresa', etc.

-- 2. Coordenadas planas + backfill desde el geography existente
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION;
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

UPDATE public.jobs
SET latitude  = ST_Y(location_geom::geometry),
    longitude = ST_X(location_geom::geometry)
WHERE location_geom IS NOT NULL
  AND (latitude IS NULL OR longitude IS NULL);

-- 3. Alta de vacante actualizada — nuevos parámetros con DEFAULT NULL, así que
--    las llamadas viejas (6 args) siguen funcionando sin cambios.
CREATE OR REPLACE FUNCTION public.create_job_with_postgis(
  p_title            VARCHAR,
  p_salary           VARCHAR,
  p_tags             TEXT[],
  p_is_stealth       BOOLEAN,
  p_lat              FLOAT,
  p_lng              FLOAT,
  p_description      TEXT DEFAULT NULL,
  p_employment_type  TEXT DEFAULT NULL,
  p_schedule         TEXT DEFAULT NULL,
  p_experience_level TEXT DEFAULT NULL,
  p_extras           TEXT DEFAULT NULL
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me UUID := auth.uid();
  v_job_id UUID;
BEGIN
  INSERT INTO public.jobs (
    company_id, title, salary_range, required_tags, is_stealth, location_geom,
    latitude, longitude,
    description, employment_type, schedule, experience_level, extras
  )
  VALUES (
    v_me, p_title, p_salary, p_tags, p_is_stealth,
    CASE WHEN p_lat IS NOT NULL THEN ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography ELSE NULL END,
    p_lat, p_lng,
    p_description, p_employment_type, p_schedule, p_experience_level, p_extras
  ) RETURNING id INTO v_job_id;
  RETURN v_job_id;
END;
$$;
