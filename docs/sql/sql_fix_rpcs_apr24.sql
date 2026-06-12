-- ============================================================
-- SQL Fixes para Mploya — Ejecutar en Supabase SQL Editor
-- Fecha: 24 Abril 2026
-- ============================================================

-- ─── FIX 1: getRecommendedUsers RPC ───
-- Error: "function lower(geography) does not exist"
-- El RPC intenta aplicar lower() a una columna geography.
-- Solución: Castear a text antes de lower(), o no aplicar lower a geography.

-- Verificar si existe la función y corregirla:
CREATE OR REPLACE FUNCTION get_recommended_users(
  p_user_id UUID,
  p_lat DOUBLE PRECISION DEFAULT NULL,
  p_lng DOUBLE PRECISION DEFAULT NULL,
  p_limit INT DEFAULT 20
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  headline TEXT,
  avatar_url TEXT,
  account_type TEXT,
  city TEXT,
  match_score DOUBLE PRECISION,
  distance_km DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.id,
    u.name,
    u.headline,
    u.avatar_url,
    u.account_type,
    u.city,
    -- Simple match score basado en campos completados
    (
      CASE WHEN u.headline IS NOT NULL THEN 0.2 ELSE 0 END +
      CASE WHEN u.avatar_url IS NOT NULL THEN 0.2 ELSE 0 END +
      CASE WHEN u.video_pitch_url IS NOT NULL THEN 0.3 ELSE 0 END +
      CASE WHEN u.skills IS NOT NULL AND array_length(u.skills, 1) > 0 THEN 0.15 ELSE 0 END +
      CASE WHEN u.experience IS NOT NULL THEN 0.15 ELSE 0 END
    )::DOUBLE PRECISION AS match_score,
    -- Distancia en km (si hay coordenadas)
    CASE
      WHEN p_lat IS NOT NULL AND p_lng IS NOT NULL AND u.location IS NOT NULL THEN
        ST_DistanceSphere(
          u.location::geometry,
          ST_MakePoint(p_lng, p_lat)
        ) / 1000.0
      ELSE NULL
    END::DOUBLE PRECISION AS distance_km
  FROM users u
  WHERE u.id != p_user_id
    AND u.is_active = true
  ORDER BY match_score DESC, u.created_at DESC
  LIMIT p_limit;
END;
$$;


-- ─── FIX 2: challenge_entries foreign key ───
-- Error: "Could not find a relationship between 'challenge_entries' and 'user_id'"
-- Verificar y agregar la foreign key si falta:

DO $$
BEGIN
  -- Solo agregar si la tabla existe pero no tiene el FK
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'challenge_entries') THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints
      WHERE constraint_type = 'FOREIGN KEY'
        AND table_name = 'challenge_entries'
        AND constraint_name LIKE '%user_id%'
    ) THEN
      ALTER TABLE challenge_entries
        ADD CONSTRAINT challenge_entries_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
      RAISE NOTICE 'FK challenge_entries.user_id → users.id creada';
    ELSE
      RAISE NOTICE 'FK ya existe, nada que hacer';
    END IF;
  ELSE
    RAISE NOTICE 'Tabla challenge_entries no existe, creándola...';
    CREATE TABLE IF NOT EXISTS challenge_entries (
      id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
      challenge_id UUID NOT NULL,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      video_url TEXT,
      score DOUBLE PRECISION DEFAULT 0,
      created_at TIMESTAMPTZ DEFAULT now()
    );
    -- RLS
    ALTER TABLE challenge_entries ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "Users can manage own entries"
      ON challenge_entries FOR ALL
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
    CREATE POLICY "Anyone can view entries"
      ON challenge_entries FOR SELECT
      USING (true);
  END IF;
END $$;
