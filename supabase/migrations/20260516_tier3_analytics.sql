-- ─────────────────────────────────────────────────────────────────────────────
-- Migración Tier 3: Event Analytics + Rate Limiting + Cleanup
-- Ejecutar en Supabase SQL Editor (una sola vez)
-- ─────────────────────────────────────────────────────────────────────────────

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. TABLA app_events — Tracking de eventos in-app
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS app_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  event_name TEXT NOT NULL,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Índices para queries rápidas
CREATE INDEX IF NOT EXISTS idx_events_user ON app_events(user_id);
CREATE INDEX IF NOT EXISTS idx_events_type ON app_events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_created ON app_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_user_type ON app_events(user_id, event_type);

-- RLS: cada usuario solo puede insertar/leer sus propios eventos
ALTER TABLE app_events ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users insert own events') THEN
    CREATE POLICY "Users insert own events"
      ON app_events FOR INSERT
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users read own events') THEN
    CREATE POLICY "Users read own events"
      ON app_events FOR SELECT
      USING (auth.uid() = user_id);
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. FUNCIÓN auto-cleanup — Eliminar eventos > 90 días (cron job)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION cleanup_old_events()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM app_events
  WHERE created_at < now() - INTERVAL '90 days';
END;
$$;

-- NOTA: Activar en Supabase Dashboard → Database → Extensions → pg_cron:
--   SELECT cron.schedule(
--     'cleanup-old-events',
--     '0 3 * * 0',  -- Domingos a las 3 AM
--     'SELECT cleanup_old_events()'
--   );

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. VISTA analytics_summary — Resumen de actividad por usuario
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW user_event_summary AS
SELECT
  user_id,
  event_type,
  COUNT(*) as event_count,
  MIN(created_at) as first_event,
  MAX(created_at) as last_event
FROM app_events
WHERE created_at > now() - INTERVAL '30 days'
GROUP BY user_id, event_type;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. RATE LIMITING — Función para verificar rate limits
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION check_rate_limit(
  p_action TEXT,
  p_max_count INTEGER DEFAULT 30,
  p_window_minutes INTEGER DEFAULT 1
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM app_events
  WHERE user_id = auth.uid()
    AND event_type = p_action
    AND created_at > now() - (p_window_minutes || ' minutes')::INTERVAL;

  RETURN v_count < p_max_count;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. ÍNDICES de performance adicionales
-- ═══════════════════════════════════════════════════════════════════════════

-- Índice compuesto para búsquedas recientes (la app filtra por fecha en queries)
CREATE INDEX IF NOT EXISTS idx_events_recent
  ON app_events(user_id, event_type, created_at DESC);

-- Trigger: Limitar tamaño de metadata JSON (máx 4KB)
CREATE OR REPLACE FUNCTION limit_event_metadata()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF length(NEW.metadata::TEXT) > 4096 THEN
    NEW.metadata = '{}'::JSONB;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_limit_event_metadata ON app_events;
CREATE TRIGGER trg_limit_event_metadata
  BEFORE INSERT ON app_events
  FOR EACH ROW
  EXECUTE FUNCTION limit_event_metadata();
