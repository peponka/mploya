-- ═══════════════════════════════════════════════════════════════════════════════
-- MPLOYA — SCRIPT MAESTRO DE PRODUCCIÓN v1.0
-- Fecha: 14/04/2026
-- 
-- INSTRUCCIONES:
-- 1. Abrir Supabase Dashboard → SQL Editor → New Query
-- 2. Pegar TODO este contenido
-- 3. Click "Run" (o Ctrl+Enter)
-- 4. Verificar que dice "Success" sin errores rojos
--
-- Este script es 100% IDEMPOTENTE — se puede ejecutar múltiples veces
-- sin romper nada (usa IF NOT EXISTS, CREATE OR REPLACE, etc.)
-- ═══════════════════════════════════════════════════════════════════════════════


-- ================================================================
-- §1  EXTENSIONES REQUERIDAS
-- ================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;
-- CREATE EXTENSION IF NOT EXISTS vector;  -- Descomentar si tu plan Supabase soporta pgvector


-- ================================================================
-- §2  FIX CRÍTICO: get_stealth_catalog() — Type mismatch (Error 42804)
-- 
-- Causa: Las columnas headline/about en users son TEXT, pero 
--        el RETURNS TABLE las declaraba como VARCHAR.
-- NOTA: Necesitamos DROP primero porque Postgres no permite
--       cambiar tipos de retorno con CREATE OR REPLACE.
-- ================================================================
DROP FUNCTION IF EXISTS public.get_stealth_catalog();

CREATE OR REPLACE FUNCTION public.get_stealth_catalog()
RETURNS TABLE (
  candidate_id UUID,
  headline TEXT,
  about TEXT,
  tags TEXT[],
  budget TEXT,
  is_unlocked BOOLEAN,
  real_name TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me UUID := auth.uid();
BEGIN
  RETURN QUERY
  SELECT 
    u.id, 
    u.headline, 
    u.about, 
    u.tags,
    '1M+'::TEXT AS budget,
    (pu.id IS NOT NULL) AS is_unlocked,
    CASE WHEN pu.id IS NOT NULL THEN u.name ELSE 'Confidencial'::TEXT END AS real_name
  FROM public.users u
  LEFT JOIN public.profile_unlocks pu ON pu.candidate_id = u.id AND pu.company_id = v_me
  WHERE u.account_type = 'confidencial';
END;
$$;


-- ================================================================
-- §3  HISTORIAS 24h (Stories)
-- ================================================================
CREATE TABLE IF NOT EXISTS public.stories (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content     TEXT,
  media_url   TEXT,
  media_type  TEXT DEFAULT 'text'
    CHECK (media_type IN ('text', 'image', 'video')),
  created_at  TIMESTAMPTZ DEFAULT now(),
  expires_at  TIMESTAMPTZ DEFAULT (now() + interval '24 hours')
);

ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;

-- Políticas RLS (idempotentes con DO block)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'stories_select_active' AND tablename = 'stories') THEN
    CREATE POLICY stories_select_active ON public.stories FOR SELECT USING (expires_at > now());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'stories_insert_own' AND tablename = 'stories') THEN
    CREATE POLICY stories_insert_own ON public.stories FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'stories_delete_own' AND tablename = 'stories') THEN
    CREATE POLICY stories_delete_own ON public.stories FOR DELETE USING (auth.uid() = user_id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_stories_user_id ON public.stories(user_id);
CREATE INDEX IF NOT EXISTS idx_stories_expires_at ON public.stories(expires_at);
CREATE INDEX IF NOT EXISTS idx_stories_created_at ON public.stories(created_at DESC);

GRANT SELECT, INSERT, DELETE ON public.stories TO authenticated;

-- Vista: usuarios con stories activas
CREATE OR REPLACE VIEW public.active_story_users AS
SELECT DISTINCT
  s.user_id,
  u.name,
  u.headline,
  u.avatar_url,
  u.account_type,
  u.video_url,
  MAX(s.created_at) AS latest_story_at
FROM public.stories s
JOIN public.users u ON u.id = s.user_id
WHERE s.expires_at > now()
GROUP BY s.user_id, u.name, u.headline, u.avatar_url, u.account_type, u.video_url
ORDER BY latest_story_at DESC;

GRANT SELECT ON public.active_story_users TO authenticated;


-- ================================================================
-- §4  MATCH EXPIRADO (7 días anti-ghosting)
-- ================================================================
ALTER TABLE public.connections ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
ALTER TABLE public.connections ADD COLUMN IF NOT EXISTS expired BOOLEAN DEFAULT false;

CREATE OR REPLACE FUNCTION set_connection_expiry()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'pending' AND NEW.expires_at IS NULL THEN
    NEW.expires_at := NOW() + INTERVAL '7 days';
  END IF;
  IF NEW.status = 'accepted' THEN
    NEW.expires_at := NULL;
    NEW.expired := false;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_connection_expiry ON public.connections;
CREATE TRIGGER trg_connection_expiry
  BEFORE INSERT OR UPDATE ON public.connections
  FOR EACH ROW
  EXECUTE FUNCTION set_connection_expiry();

-- Función para expirar matches vencidos (llamar via cron o Edge Function)
CREATE OR REPLACE FUNCTION expire_stale_connections()
RETURNS INTEGER AS $$
DECLARE expired_count INTEGER;
BEGIN
  UPDATE public.connections
  SET status = 'expired', expired = true
  WHERE status = 'pending' AND expires_at IS NOT NULL AND expires_at < NOW();
  GET DIAGNOSTICS expired_count = ROW_COUNT;
  RETURN expired_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ================================================================
-- §5  BADGE "✓ Verificado" (auto-verificar con video pitch)
-- ================================================================
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false;

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

DROP TRIGGER IF EXISTS trg_auto_verify_video ON public.users;
CREATE TRIGGER trg_auto_verify_video
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION auto_verify_on_video();

-- Marcar verificados a quienes ya tienen video
UPDATE public.users SET is_verified = true 
WHERE video_url IS NOT NULL AND video_url != '' AND (is_verified IS NULL OR is_verified = false);


-- ================================================================
-- §6  SOPORTE DE ARCHIVOS EN MENSAJES
-- ================================================================
ALTER TABLE public.messages 
  ADD COLUMN IF NOT EXISTS file_url TEXT,
  ADD COLUMN IF NOT EXISTS file_name TEXT,
  ADD COLUMN IF NOT EXISTS file_type TEXT,
  ADD COLUMN IF NOT EXISTS file_size_bytes BIGINT;


-- ================================================================
-- §7  RPC BATCH QUERY (Solución N+1 del Feed)
-- ================================================================
CREATE OR REPLACE FUNCTION public.get_card_metadata_batch(p_target_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me UUID := auth.uid();
  v_result JSONB;
  v_nexus_sent BOOLEAN;
  v_connection_status TEXT;
  v_is_bookmarked BOOLEAN;
  v_active_reaction TEXT;
  v_reaction_counts JSONB;
  v_reply_video_url TEXT;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.nexus_signals WHERE sender_id = v_me AND receiver_id = p_target_user_id
  ) INTO v_nexus_sent;

  SELECT status INTO v_connection_status 
  FROM public.connections 
  WHERE (requester_id = v_me AND addressee_id = p_target_user_id) 
     OR (requester_id = p_target_user_id AND addressee_id = v_me) 
  LIMIT 1;

  SELECT EXISTS(
    SELECT 1 FROM public.saved_profiles WHERE user_id = v_me AND saved_user_id = p_target_user_id
  ) INTO v_is_bookmarked;

  SELECT emoji INTO v_active_reaction 
  FROM public.pitch_reactions WHERE user_id = v_me AND target_user_id = p_target_user_id;

  SELECT COALESCE(jsonb_object_agg(emoji, count), '{}'::jsonb) INTO v_reaction_counts
  FROM public.pitch_reaction_counts WHERE target_user_id = p_target_user_id;

  SELECT video_url INTO v_reply_video_url 
  FROM public.nexus_signals 
  WHERE signal_type = 'micro_pitch' 
    AND ((sender_id = p_target_user_id AND receiver_id = v_me) OR (sender_id = v_me AND receiver_id = p_target_user_id))
  LIMIT 1;

  v_result := jsonb_build_object(
    'nexus_sent', COALESCE(v_nexus_sent, false),
    'connection_status', COALESCE(v_connection_status, 'none'),
    'is_bookmarked', COALESCE(v_is_bookmarked, false),
    'active_reaction', v_active_reaction,
    'reaction_counts', v_reaction_counts,
    'reply_video_url', v_reply_video_url
  );
  RETURN v_result;

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('error', SQLERRM);
END;
$$;


-- ================================================================
-- §8  ÍNDICES DE RENDIMIENTO (Performance Boost)
-- ================================================================
CREATE INDEX IF NOT EXISTS idx_users_feed ON public.users (account_type, created_at DESC)
  WHERE video_url IS NOT NULL AND video_url != '';

CREATE INDEX IF NOT EXISTS idx_nexus_sender ON public.nexus_signals (sender_id, receiver_id, signal_type);
CREATE INDEX IF NOT EXISTS idx_nexus_receiver ON public.nexus_signals (receiver_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_connections_pair ON public.connections (requester_id, addressee_id, status);
CREATE INDEX IF NOT EXISTS idx_connections_addressee ON public.connections (addressee_id, status);

CREATE INDEX IF NOT EXISTS idx_pitch_likes_liker ON public.pitch_likes (liker_id, pitch_owner_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications (user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_saved_profiles_user ON public.saved_profiles (user_id, saved_user_id);
CREATE INDEX IF NOT EXISTS idx_users_boost_active ON public.users (boost_ends_at);

CREATE INDEX IF NOT EXISTS idx_messages_conversation 
  ON public.messages (sender_id, receiver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_unread
  ON public.messages (receiver_id, is_read) WHERE is_read = false;


-- ================================================================
-- §9  PROTECCIÓN PREMIUM (Anti-hack: prevenir auto-premium)
-- ================================================================
CREATE OR REPLACE FUNCTION prevent_client_premium_update()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.is_premium IS DISTINCT FROM NEW.is_premium THEN
    IF current_setting('request.jwt.claims', true)::json->>'role' = 'authenticated' THEN
      NEW.is_premium := OLD.is_premium;
      RAISE NOTICE 'Blocked client-side is_premium update for user %', OLD.id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS prevent_premium_self_update ON public.users;
CREATE TRIGGER prevent_premium_self_update
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION prevent_client_premium_update();


-- ================================================================
-- §10  PUSH NOTIFICATIONS TRIGGER (InMail → Firebase)
-- ================================================================
CREATE OR REPLACE FUNCTION public.notify_inmail_push() 
RETURNS TRIGGER SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_receiver_fcm TEXT;
  v_sender_name VARCHAR;
BEGIN
  SELECT fcm_token INTO v_receiver_fcm FROM public.users WHERE id = NEW.receiver_id;
  IF v_receiver_fcm IS NOT NULL THEN
    SELECT name INTO v_sender_name FROM public.users WHERE id = NEW.sender_id;
    -- Edge Function call (descomentar cuando esté deployada):
    -- PERFORM net.http_post(
    --     url := 'https://[TU-PROYECTO].supabase.co/functions/v1/send-fcm',
    --     headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer [SERVICE_KEY]'),
    --     body := jsonb_build_object('token', v_receiver_fcm, 'title', '💼 InMail: ' || v_sender_name, 'body', NEW.text)
    -- );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_new_inmail ON public.messages;
CREATE TRIGGER on_new_inmail
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_inmail_push();


-- ================================================================
-- §11  JOB APPLICATIONS (Postulaciones a Vacantes)
-- ================================================================
CREATE TABLE IF NOT EXISTS public.job_applications (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id         UUID        NOT NULL,
  candidate_id   UUID        NOT NULL,
  status         TEXT        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','viewed','accepted','rejected')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT job_applications_uniq UNIQUE (job_id, candidate_id)
);

ALTER TABLE public.job_applications ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_job_applications_job ON public.job_applications (job_id, status);
CREATE INDEX IF NOT EXISTS idx_job_applications_candidate ON public.job_applications (candidate_id, status);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'job_apps_select' AND tablename = 'job_applications') THEN
    CREATE POLICY job_apps_select ON public.job_applications FOR SELECT USING (
      auth.uid() = candidate_id OR auth.uid() IN (
        SELECT company_id FROM public.jobs WHERE id = job_id
      )
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'job_apps_insert' AND tablename = 'job_applications') THEN
    CREATE POLICY job_apps_insert ON public.job_applications FOR INSERT WITH CHECK (auth.uid() = candidate_id);
  END IF;
END $$;

GRANT SELECT, INSERT ON public.job_applications TO authenticated;


-- ================================================================
-- §12  GRANTS FINALES
-- ================================================================
GRANT EXECUTE ON FUNCTION public.get_stealth_catalog()             TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_card_metadata_batch(UUID)     TO authenticated;
GRANT EXECUTE ON FUNCTION public.expire_stale_connections()        TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_connection_expiry()           TO authenticated;


-- ================================================================
-- ✅ VERIFICACIÓN — Ejecutar por separado después del script
-- ================================================================
-- SELECT routine_name FROM information_schema.routines
-- WHERE routine_schema = 'public' AND routine_type = 'FUNCTION'
-- ORDER BY routine_name;
--
-- SELECT tablename FROM pg_tables
-- WHERE schemaname = 'public' ORDER BY tablename;
--
-- SELECT policyname, tablename FROM pg_policies
-- WHERE schemaname = 'public' ORDER BY tablename, policyname;
