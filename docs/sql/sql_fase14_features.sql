-- ═══════════════════════════════════════════════════════════════════════════════
-- Mploya Fase 14 — SQL para Features del 12 de Abril 2026
-- ═══════════════════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────────────────
-- PUNTO 4: Match Expirado (7 días anti-ghosting)
-- Agrega columna expires_at y función para expirar matches sin respuesta
-- ──────────────────────────────────────────────────────────────────────────────

-- Agregar columna de expiración a connections (si no existe)
ALTER TABLE connections ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
ALTER TABLE connections ADD COLUMN IF NOT EXISTS expired BOOLEAN DEFAULT false;

-- Trigger: Auto-setear expires_at a 7 días cuando se crea una connection pendiente
CREATE OR REPLACE FUNCTION set_connection_expiry()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'pending' AND NEW.expires_at IS NULL THEN
    NEW.expires_at := NOW() + INTERVAL '7 days';
  END IF;
  -- Limpiar expiración si se acepta
  IF NEW.status = 'accepted' THEN
    NEW.expires_at := NULL;
    NEW.expired := false;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_connection_expiry ON connections;
CREATE TRIGGER trg_connection_expiry
  BEFORE INSERT OR UPDATE ON connections
  FOR EACH ROW
  EXECUTE FUNCTION set_connection_expiry();

-- Función cron para expirar matches vencidos (llamar periódicamente)
-- Opción A: pg_cron (si está habilitado en Supabase)
-- Opción B: Edge Function disparada por cron externo
CREATE OR REPLACE FUNCTION expire_stale_connections()
RETURNS INTEGER AS $$
DECLARE
  expired_count INTEGER;
BEGIN
  UPDATE connections
  SET status = 'expired', expired = true
  WHERE status = 'pending'
    AND expires_at IS NOT NULL
    AND expires_at < NOW();
  
  GET DIAGNOSTICS expired_count = ROW_COUNT;
  RETURN expired_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC para llamar desde Dart o Edge Function
-- SELECT expire_stale_connections();

-- ──────────────────────────────────────────────────────────────────────────────
-- PUNTO 5: Badge "✓ Verificado" (video pitch completado)
-- Agrega columna is_verified que se activa cuando el usuario sube video pitch
-- ──────────────────────────────────────────────────────────────────────────────

ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false;

-- Trigger: Auto-verificar cuando se sube un video pitch
CREATE OR REPLACE FUNCTION auto_verify_on_video()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.video_url IS NOT NULL AND NEW.video_url != '' 
     AND (OLD.video_url IS NULL OR OLD.video_url = '') THEN
    NEW.is_verified := true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_verify_video ON users;
CREATE TRIGGER trg_auto_verify_video
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION auto_verify_on_video();

-- Marcar como verificados a los que ya tienen video
UPDATE users SET is_verified = true 
WHERE video_url IS NOT NULL AND video_url != '' AND is_verified = false;

-- ──────────────────────────────────────────────────────────────────────────────
-- PUNTO 6: Notificaciones Geolocalizadas (PostGIS)
-- RPC para encontrar empresas cercanas al usuario
-- ──────────────────────────────────────────────────────────────────────────────

-- Requiere extensión PostGIS (ya habilitada en Supabase)
-- CREATE EXTENSION IF NOT EXISTS postgis;

-- Función: empresas cercanas en un radio dado (km)
CREATE OR REPLACE FUNCTION nearby_companies(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  headline TEXT,
  avatar_url TEXT,
  location TEXT,
  distance_km DOUBLE PRECISION
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.name,
    u.headline,
    u.avatar_url,
    u.location,
    ROUND(
      (ST_DistanceSphere(
        ST_MakePoint(u.longitude, u.latitude),
        ST_MakePoint(p_lng, p_lat)
      ) / 1000.0)::NUMERIC, 1
    )::DOUBLE PRECISION AS distance_km
  FROM users u
  WHERE u.account_type IN ('empresa', 'headhunter')
    AND u.latitude IS NOT NULL 
    AND u.longitude IS NOT NULL
    AND ST_DistanceSphere(
      ST_MakePoint(u.longitude, u.latitude),
      ST_MakePoint(p_lng, p_lat)
    ) <= p_radius_km * 1000
  ORDER BY distance_km ASC
  LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────────────────────────
-- PUNTO 7: Subtítulos IA — Columna para almacenar transcripciones
-- ──────────────────────────────────────────────────────────────────────────────

-- La columna ai_transcript_json ya existe en users, confirmamos
-- ALTER TABLE users ADD COLUMN IF NOT EXISTS ai_transcript_json JSONB DEFAULT '[]'::jsonb;

-- ──────────────────────────────────────────────────────────────────────────────
-- PUNTO 8: Motor de Match IA — Columna para embeddings
-- ──────────────────────────────────────────────────────────────────────────────

-- Habilitar extensión pgvector (si no está)
CREATE EXTENSION IF NOT EXISTS vector;

-- Agregar columna de embedding al perfil del usuario
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_embedding vector(384);

-- Índice para búsqueda de similitud (IVFFlat)
-- Nota: solo crear después de tener >100 registros con embeddings
-- CREATE INDEX IF NOT EXISTS idx_users_embedding ON users 
--   USING ivfflat (profile_embedding vector_cosine_ops) WITH (lists = 10);

-- Función: Match por similitud de embeddings
CREATE OR REPLACE FUNCTION match_users_by_embedding(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  headline TEXT,
  avatar_url TEXT,
  account_type TEXT,
  similarity DOUBLE PRECISION
) AS $$
DECLARE
  user_embedding vector(384);
BEGIN
  -- Obtener embedding del usuario actual
  SELECT u.profile_embedding INTO user_embedding
  FROM users u WHERE u.id = p_user_id;
  
  IF user_embedding IS NULL THEN
    RETURN;
  END IF;
  
  RETURN QUERY
  SELECT 
    u.id,
    u.name,
    u.headline,
    u.avatar_url,
    u.account_type,
    (1 - (u.profile_embedding <=> user_embedding))::DOUBLE PRECISION AS similarity
  FROM users u
  WHERE u.id != p_user_id
    AND u.profile_embedding IS NOT NULL
  ORDER BY u.profile_embedding <=> user_embedding ASC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
