-- ============================================================
-- MPLOYA — Full Schema Migration v2
-- Fecha: 2026-03-31  (sustituye y completa la v1)
-- Cubre: Social Proof · Connections · Likes · Transcripts ·
--        Mensajes · Columnas faltantes en users
--
-- IDEMPOTENTE: seguro ejecutar más de una vez (IF NOT EXISTS / OR REPLACE)
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- BLOQUE 1: ALTER TABLE users
-- Añade TODAS las columnas que NexUser.fromJson espera.
-- Las que ya existían (id, name, email, etc.) no se tocan.
-- ─────────────────────────────────────────────────────────────

ALTER TABLE public.users
  -- Perfil básico (faltan en tabla actual)
  ADD COLUMN IF NOT EXISTS avatar_url       TEXT,
  ADD COLUMN IF NOT EXISTS banner_url       TEXT,
  ADD COLUMN IF NOT EXISTS company          TEXT,
  ADD COLUMN IF NOT EXISTS profile_views    INT         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_hiring        BOOLEAN     NOT NULL DEFAULT FALSE,

  -- Geo (ExploreScreen · radar de pines)
  ADD COLUMN IF NOT EXISTS latitude         FLOAT,
  ADD COLUMN IF NOT EXISTS longitude        FLOAT,

  -- Social Proof (TikTokReelCard · ProfileScreen)
  ADD COLUMN IF NOT EXISTS match_percentage FLOAT       NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating_stars     FLOAT       NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating_count     INT         NOT NULL DEFAULT 0,

  -- Like counter desnormalizado — mantenido por trigger
  ADD COLUMN IF NOT EXISTS like_count       INT         NOT NULL DEFAULT 0,

  -- Connection counter desnormalizado — mantenido por trigger
  ADD COLUMN IF NOT EXISTS connections      INT         NOT NULL DEFAULT 0,

  -- AI Transcript: [{start, end, text}] para subtítulos del pitch
  ADD COLUMN IF NOT EXISTS ai_transcript_json JSONB     NOT NULL DEFAULT '[]'::jsonb;

-- Índices de rendimiento
CREATE INDEX IF NOT EXISTS idx_users_geo
  ON public.users (latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_match_pct
  ON public.users (match_percentage DESC);

CREATE INDEX IF NOT EXISTS idx_users_rating
  ON public.users (rating_stars DESC);

CREATE INDEX IF NOT EXISTS idx_users_like_count
  ON public.users (like_count DESC);

-- Comentarios de columna
COMMENT ON COLUMN public.users.avatar_url          IS 'URL pública de la foto de perfil (Supabase Storage).';
COMMENT ON COLUMN public.users.banner_url          IS 'URL pública del banner de perfil.';
COMMENT ON COLUMN public.users.match_percentage    IS 'Score semántico IA 0–100. Actualizable vía edge function o admin.';
COMMENT ON COLUMN public.users.rating_stars        IS 'Promedio de estrellas 0–5. Recalculado por RPC rate_user().';
COMMENT ON COLUMN public.users.rating_count        IS 'Total de calificaciones recibidas.';
COMMENT ON COLUMN public.users.like_count          IS 'Likes al Video-Pitch. Sincronizado por trigger trg_sync_like_count.';
COMMENT ON COLUMN public.users.connections         IS 'Conexiones aceptadas. Sincronizado por trigger trg_sync_connection_count.';
COMMENT ON COLUMN public.users.ai_transcript_json  IS 'Array JSONB de segmentos [{start:float, end:float, text:string}].';


-- ─────────────────────────────────────────────────────────────
-- BLOQUE 2: TABLA connections
-- Solicitudes y conexiones entre usuarios.
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.connections (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id  UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  addressee_id  UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status        TEXT        NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending', 'accepted', 'rejected', 'blocked')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT connections_no_self CHECK (requester_id <> addressee_id),
  UNIQUE (requester_id, addressee_id)
);

CREATE INDEX IF NOT EXISTS idx_connections_requester ON public.connections (requester_id, status);
CREATE INDEX IF NOT EXISTS idx_connections_addressee ON public.connections (addressee_id, status);

COMMENT ON TABLE  public.connections        IS 'Solicitudes y conexiones de red profesional entre usuarios.';
COMMENT ON COLUMN public.connections.status IS 'pending | accepted | rejected | blocked';


-- ─────────────────────────────────────────────────────────────
-- BLOQUE 3: TABLA pitch_likes
-- Likes ("Match") sobre Video-Pitches.
-- Cada user tiene UN Video-Pitch (su perfil), por eso pitch_owner_id = user.id
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.pitch_likes (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  liker_id        UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pitch_owner_id  UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT pitch_likes_no_self CHECK (liker_id <> pitch_owner_id),
  UNIQUE (liker_id, pitch_owner_id)
);

CREATE INDEX IF NOT EXISTS idx_pitch_likes_owner ON public.pitch_likes (pitch_owner_id);
CREATE INDEX IF NOT EXISTS idx_pitch_likes_liker ON public.pitch_likes (liker_id);

COMMENT ON TABLE public.pitch_likes IS 'Likes únicos sobre Video-Pitches. Actualiza users.like_count vía trigger.';


-- ─────────────────────────────────────────────────────────────
-- BLOQUE 4: TABLA user_ratings
-- Calificaciones de estrella (1-5) sobre perfiles.
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.user_ratings (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  rater_id    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_id   UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stars       FLOAT       NOT NULL CHECK (stars >= 1 AND stars <= 5),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT user_ratings_no_self CHECK (rater_id <> target_id),
  UNIQUE (rater_id, target_id)
);

CREATE INDEX IF NOT EXISTS idx_user_ratings_target ON public.user_ratings (target_id);

COMMENT ON TABLE public.user_ratings IS 'Calificaciones 1-5 estrellas sobre perfiles. RPC rate_user() recalcula el promedio.';


-- ─────────────────────────────────────────────────────────────
-- BLOQUE 5: TABLA messages
-- Mensajes directos entre usuarios (MessagingScreen / ChatDetailScreen)
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.messages (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id   UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text        TEXT        NOT NULL CHECK (length(text) > 0 AND length(text) <= 4000),
  is_read     BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT messages_no_self CHECK (sender_id <> receiver_id)
);

-- Índice compuesto para la consulta de conversación bidireccional
-- (sender_id = A AND receiver_id = B) OR (sender_id = B AND receiver_id = A)
CREATE INDEX IF NOT EXISTS idx_messages_conversation
  ON public.messages (sender_id, receiver_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_receiver_unread
  ON public.messages (receiver_id, is_read)
  WHERE is_read = FALSE;

COMMENT ON TABLE public.messages IS 'Mensajes directos entre usuarios. Consumido por MessagingScreen via .stream().';


-- ─────────────────────────────────────────────────────────────
-- BLOQUE 6: TRIGGERS
-- ─────────────────────────────────────────────────────────────

-- 6a. updated_at automático (connections y user_ratings)
CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_connections_updated_at  ON public.connections;
DROP TRIGGER IF EXISTS trg_user_ratings_updated_at ON public.user_ratings;

CREATE TRIGGER trg_connections_updated_at
  BEFORE UPDATE ON public.connections
  FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

CREATE TRIGGER trg_user_ratings_updated_at
  BEFORE UPDATE ON public.user_ratings
  FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();


-- 6b. Sync users.like_count (INSERT / DELETE en pitch_likes)
CREATE OR REPLACE FUNCTION public.fn_sync_like_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.users
    SET like_count = like_count + 1
    WHERE id = NEW.pitch_owner_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.users
    SET like_count = GREATEST(0, like_count - 1)
    WHERE id = OLD.pitch_owner_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_like_count ON public.pitch_likes;
CREATE TRIGGER trg_sync_like_count
  AFTER INSERT OR DELETE ON public.pitch_likes
  FOR EACH ROW EXECUTE FUNCTION public.fn_sync_like_count();


-- 6c. Sync users.connections (transitions de status en connections)
CREATE OR REPLACE FUNCTION public.fn_sync_connection_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status = 'accepted' THEN
      UPDATE public.users SET connections = connections + 1
      WHERE id IN (NEW.requester_id, NEW.addressee_id);
    END IF;

  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.status <> 'accepted' AND NEW.status = 'accepted' THEN
      UPDATE public.users SET connections = connections + 1
      WHERE id IN (NEW.requester_id, NEW.addressee_id);
    ELSIF OLD.status = 'accepted' AND NEW.status <> 'accepted' THEN
      UPDATE public.users SET connections = GREATEST(0, connections - 1)
      WHERE id IN (NEW.requester_id, NEW.addressee_id);
    END IF;

  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.status = 'accepted' THEN
      UPDATE public.users SET connections = GREATEST(0, connections - 1)
      WHERE id IN (OLD.requester_id, OLD.addressee_id);
    END IF;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_connection_count ON public.connections;
CREATE TRIGGER trg_sync_connection_count
  AFTER INSERT OR UPDATE OR DELETE ON public.connections
  FOR EACH ROW EXECUTE FUNCTION public.fn_sync_connection_count();


-- ─────────────────────────────────────────────────────────────
-- BLOQUE 7: RPCs DE NEGOCIO
-- ─────────────────────────────────────────────────────────────

-- ── RPC 1: Enviar solicitud de conexión ──
-- SocialService.sendConnectionRequest(addresseeId)
-- Retorna: {status, connection_id, message} | {error}
CREATE OR REPLACE FUNCTION public.send_connection_request(p_addressee_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me   UUID := auth.uid();
  v_row  public.connections%ROWTYPE;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;
  IF v_me = p_addressee_id THEN
    RETURN jsonb_build_object('error', 'self_connect');
  END IF;

  SELECT * INTO v_row
  FROM public.connections
  WHERE (requester_id = v_me AND addressee_id = p_addressee_id)
     OR (requester_id = p_addressee_id AND addressee_id = v_me);

  IF FOUND THEN
    RETURN jsonb_build_object(
      'status',        v_row.status,
      'connection_id', v_row.id,
      'message',       'already_exists'
    );
  END IF;

  INSERT INTO public.connections (requester_id, addressee_id)
  VALUES (v_me, p_addressee_id)
  RETURNING id INTO v_row.id;

  RETURN jsonb_build_object(
    'status',        'pending',
    'connection_id', v_row.id,
    'message',       'pending_sent'
  );
END;
$$;


-- ── RPC 2: Responder solicitud (accept / reject) ──
-- SocialService.respondConnection(requesterId, 'accept'|'reject')
CREATE OR REPLACE FUNCTION public.respond_connection(
  p_requester_id UUID,
  p_action       TEXT  -- 'accept' | 'reject'
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me         UUID := auth.uid();
  v_new_status TEXT;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;
  IF p_action NOT IN ('accept', 'reject') THEN
    RETURN jsonb_build_object('error', 'invalid_action');
  END IF;

  v_new_status := CASE p_action WHEN 'accept' THEN 'accepted' ELSE 'rejected' END;

  UPDATE public.connections
  SET status = v_new_status
  WHERE requester_id = p_requester_id
    AND addressee_id = v_me
    AND status = 'pending';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'request_not_found');
  END IF;

  RETURN jsonb_build_object('status', v_new_status, 'message', 'ok');
END;
$$;


-- ── RPC 3: Consultar estado de conexión ──
-- SocialService.getConnectionStatus(otherUserId)
-- Retorna: {status, connection_id, i_am_requester}
CREATE OR REPLACE FUNCTION public.get_connection_status(p_other_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
DECLARE
  v_me  UUID := auth.uid();
  v_row public.connections%ROWTYPE;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('status', 'none'); END IF;

  SELECT * INTO v_row
  FROM public.connections
  WHERE (requester_id = v_me AND addressee_id = p_other_user_id)
     OR (requester_id = p_other_user_id AND addressee_id = v_me)
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'none');
  END IF;

  RETURN jsonb_build_object(
    'status',         v_row.status,
    'connection_id',  v_row.id,
    'i_am_requester', (v_row.requester_id = v_me)
  );
END;
$$;


-- ── RPC 4: Toggle like sobre Video-Pitch (idempotente) ──
-- SocialService.togglePitchLike(pitchOwnerId)
-- Retorna: {liked: bool, like_count: int}
CREATE OR REPLACE FUNCTION public.toggle_pitch_like(p_pitch_owner_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me    UUID := auth.uid();
  v_liked BOOL;
  v_count INT;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;
  IF v_me = p_pitch_owner_id THEN
    RETURN jsonb_build_object('error', 'self_like');
  END IF;

  -- Intentar unlike primero (DELETE devuelve FOUND si borró algo)
  DELETE FROM public.pitch_likes
  WHERE liker_id = v_me AND pitch_owner_id = p_pitch_owner_id;

  IF FOUND THEN
    v_liked := FALSE;
  ELSE
    INSERT INTO public.pitch_likes (liker_id, pitch_owner_id)
    VALUES (v_me, p_pitch_owner_id)
    ON CONFLICT DO NOTHING;
    v_liked := TRUE;
  END IF;

  -- Leer el contador cacheado (O(1) — sin COUNT(*))
  SELECT like_count INTO v_count FROM public.users WHERE id = p_pitch_owner_id;

  RETURN jsonb_build_object(
    'liked',      v_liked,
    'like_count', COALESCE(v_count, 0)
  );
END;
$$;


-- ── RPC 5: Calificar usuario (upsert de rating) ──
-- SocialService.rateUser(targetId, stars)
-- Recalcula rating_stars y rating_count en users.
CREATE OR REPLACE FUNCTION public.rate_user(p_target_id UUID, p_stars FLOAT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me    UUID := auth.uid();
  v_avg   FLOAT;
  v_count INT;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('error', 'not_authenticated'); END IF;
  IF v_me = p_target_id THEN RETURN jsonb_build_object('error', 'self_rate'); END IF;
  IF p_stars < 1 OR p_stars > 5 THEN RETURN jsonb_build_object('error', 'invalid_stars'); END IF;

  INSERT INTO public.user_ratings (rater_id, target_id, stars)
  VALUES (v_me, p_target_id, p_stars)
  ON CONFLICT (rater_id, target_id)
  DO UPDATE SET stars = EXCLUDED.stars, updated_at = NOW();

  SELECT AVG(stars), COUNT(*) INTO v_avg, v_count
  FROM public.user_ratings WHERE target_id = p_target_id;

  UPDATE public.users
  SET rating_stars = ROUND(v_avg::numeric, 1),
      rating_count = v_count
  WHERE id = p_target_id;

  RETURN jsonb_build_object(
    'new_avg',       ROUND(v_avg::numeric, 1),
    'total_ratings', v_count
  );
END;
$$;


-- ─────────────────────────────────────────────────────────────
-- BLOQUE 8: ROW LEVEL SECURITY (RLS)
-- ─────────────────────────────────────────────────────────────

-- ── connections ──
ALTER TABLE public.connections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "connections_select_participants" ON public.connections;
DROP POLICY IF EXISTS "connections_insert_as_requester" ON public.connections;
DROP POLICY IF EXISTS "connections_update_addressee"    ON public.connections;
DROP POLICY IF EXISTS "connections_delete_participants" ON public.connections;

CREATE POLICY "connections_select_participants"
  ON public.connections FOR SELECT
  USING (auth.uid() IN (requester_id, addressee_id));

CREATE POLICY "connections_insert_as_requester"
  ON public.connections FOR INSERT
  WITH CHECK (auth.uid() = requester_id);

CREATE POLICY "connections_update_addressee"
  ON public.connections FOR UPDATE
  USING (auth.uid() IN (requester_id, addressee_id));

CREATE POLICY "connections_delete_participants"
  ON public.connections FOR DELETE
  USING (auth.uid() IN (requester_id, addressee_id));


-- ── pitch_likes ──
ALTER TABLE public.pitch_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pitch_likes_select_authenticated" ON public.pitch_likes;
DROP POLICY IF EXISTS "pitch_likes_insert_as_liker"      ON public.pitch_likes;
DROP POLICY IF EXISTS "pitch_likes_delete_as_liker"      ON public.pitch_likes;

CREATE POLICY "pitch_likes_select_authenticated"
  ON public.pitch_likes FOR SELECT
  TO authenticated
  USING (TRUE);

CREATE POLICY "pitch_likes_insert_as_liker"
  ON public.pitch_likes FOR INSERT
  WITH CHECK (auth.uid() = liker_id);

CREATE POLICY "pitch_likes_delete_as_liker"
  ON public.pitch_likes FOR DELETE
  USING (auth.uid() = liker_id);


-- ── user_ratings ──
ALTER TABLE public.user_ratings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_ratings_select_own"  ON public.user_ratings;
DROP POLICY IF EXISTS "user_ratings_insert_own"  ON public.user_ratings;
DROP POLICY IF EXISTS "user_ratings_update_own"  ON public.user_ratings;

CREATE POLICY "user_ratings_select_own"
  ON public.user_ratings FOR SELECT
  USING (auth.uid() IN (rater_id, target_id));

CREATE POLICY "user_ratings_insert_own"
  ON public.user_ratings FOR INSERT
  WITH CHECK (auth.uid() = rater_id);

CREATE POLICY "user_ratings_update_own"
  ON public.user_ratings FOR UPDATE
  USING (auth.uid() = rater_id);


-- ── messages ──
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "messages_select_participants" ON public.messages;
DROP POLICY IF EXISTS "messages_insert_as_sender"    ON public.messages;
DROP POLICY IF EXISTS "messages_update_receiver"     ON public.messages;
DROP POLICY IF EXISTS "messages_delete_sender"       ON public.messages;

-- Solo los participantes de la conversación pueden ver los mensajes
CREATE POLICY "messages_select_participants"
  ON public.messages FOR SELECT
  USING (auth.uid() IN (sender_id, receiver_id));

-- Solo el remitente puede enviar
CREATE POLICY "messages_insert_as_sender"
  ON public.messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

-- El receptor puede marcar como leído (UPDATE is_read)
CREATE POLICY "messages_update_receiver"
  ON public.messages FOR UPDATE
  USING (auth.uid() = receiver_id);

-- El remitente puede borrar (retractarse dentro de una ventana de tiempo — implementar lógica en RPC si se desea)
CREATE POLICY "messages_delete_sender"
  ON public.messages FOR DELETE
  USING (auth.uid() = sender_id);


-- ─────────────────────────────────────────────────────────────
-- BLOQUE 9: REALTIME (habilitar publicación en tiempo real)
-- Supabase Realtime necesita que las tablas estén en la publication.
-- ─────────────────────────────────────────────────────────────

-- Añadir tablas al Realtime publication (solo ejecuta si no están ya)
DO $$
BEGIN
  -- messages: para el stream bidireccional de chat
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;

  -- connections: para notificaciones de solicitudes entrantes
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'connections'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.connections;
  END IF;

  -- pitch_likes: para feed de reacciones en tiempo real
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'pitch_likes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.pitch_likes;
  END IF;
END $$;


-- ─────────────────────────────────────────────────────────────
-- BLOQUE 10: GRANTS
-- Dar acceso al rol 'authenticated' a todos los objetos.
-- ─────────────────────────────────────────────────────────────

GRANT SELECT, INSERT, UPDATE, DELETE ON public.messages     TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.connections  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pitch_likes  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_ratings TO authenticated;

GRANT EXECUTE ON FUNCTION public.send_connection_request(UUID)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_connection(UUID, TEXT)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_connection_status(UUID)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_pitch_like(UUID)              TO authenticated;
GRANT EXECUTE ON FUNCTION public.rate_user(UUID, FLOAT)               TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- FIN DE MIGRACIÓN
-- Verificación rápida: ejecuta esto después para confirmar:
--
-- SELECT column_name FROM information_schema.columns
-- WHERE table_name = 'users' AND table_schema = 'public'
-- ORDER BY ordinal_position;
--
-- SELECT tablename FROM pg_tables
-- WHERE schemaname = 'public'
-- ORDER BY tablename;
-- ─────────────────────────────────────────────────────────────
