-- ================================================================
--  MPLOYA — schema.sql
--  Pega este archivo completo en:
--  Supabase Dashboard → SQL Editor → New Query → Run
--
--  SEGURO DE RE-EJECUTAR: usa IF NOT EXISTS / CREATE OR REPLACE /
--  DROP … IF EXISTS en cada objeto.
-- ================================================================


-- ================================================================
-- §1  TABLA: users  (ampliar columnas existentes)
-- ================================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS avatar_url           TEXT,
  ADD COLUMN IF NOT EXISTS banner_url           TEXT,
  ADD COLUMN IF NOT EXISTS company              TEXT,
  ADD COLUMN IF NOT EXISTS profile_views        INT         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_hiring            BOOLEAN     NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS latitude             FLOAT,
  ADD COLUMN IF NOT EXISTS longitude            FLOAT,
  ADD COLUMN IF NOT EXISTS match_percentage     FLOAT       NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating_stars         FLOAT       NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating_count         INT         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS like_count           INT         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS connections          INT         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ai_transcript_json   JSONB       NOT NULL DEFAULT '[]'::jsonb;

-- Índices de rendimiento sobre users
CREATE INDEX IF NOT EXISTS idx_users_geo
  ON public.users (latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_match_pct
  ON public.users (match_percentage DESC);

CREATE INDEX IF NOT EXISTS idx_users_rating
  ON public.users (rating_stars DESC);

CREATE INDEX IF NOT EXISTS idx_users_like_count
  ON public.users (like_count DESC);

COMMENT ON COLUMN public.users.avatar_url         IS 'URL pública de la foto de perfil (Supabase Storage).';
COMMENT ON COLUMN public.users.match_percentage   IS 'Score semántico IA 0–100.';
COMMENT ON COLUMN public.users.rating_stars       IS 'Promedio de estrellas 0–5. Recalculado por RPC rate_user().';
COMMENT ON COLUMN public.users.rating_count       IS 'Total de calificaciones recibidas.';
COMMENT ON COLUMN public.users.like_count         IS 'Likes al Video-Pitch. Mantenido por trigger.';
COMMENT ON COLUMN public.users.connections        IS 'Conexiones aceptadas. Mantenido por trigger.';
COMMENT ON COLUMN public.users.ai_transcript_json IS 'Array [{start, end, text}] para subtítulos del Video-Pitch.';


-- ================================================================
-- §2  TABLA: connections
-- ================================================================

CREATE TABLE IF NOT EXISTS public.connections (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id  UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  addressee_id  UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status        TEXT        NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending','accepted','rejected','blocked')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT connections_no_self   CHECK (requester_id <> addressee_id),
  CONSTRAINT connections_pair_uniq UNIQUE (requester_id, addressee_id)
);

CREATE INDEX IF NOT EXISTS idx_connections_requester ON public.connections (requester_id, status);
CREATE INDEX IF NOT EXISTS idx_connections_addressee ON public.connections (addressee_id, status);

COMMENT ON TABLE  public.connections        IS 'Solicitudes y conexiones de red entre usuarios.';
COMMENT ON COLUMN public.connections.status IS 'pending | accepted | rejected | blocked';


-- ================================================================
-- §3  TABLA: pitch_likes
-- ================================================================

CREATE TABLE IF NOT EXISTS public.pitch_likes (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  liker_id        UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pitch_owner_id  UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT pitch_likes_no_self  CHECK (liker_id <> pitch_owner_id),
  CONSTRAINT pitch_likes_uniq     UNIQUE (liker_id, pitch_owner_id)
);

CREATE INDEX IF NOT EXISTS idx_pitch_likes_owner ON public.pitch_likes (pitch_owner_id);
CREATE INDEX IF NOT EXISTS idx_pitch_likes_liker ON public.pitch_likes (liker_id);

COMMENT ON TABLE public.pitch_likes IS 'Likes únicos sobre Video-Pitches. Actualiza users.like_count vía trigger.';


-- ================================================================
-- §4  TABLA: user_ratings
-- ================================================================

CREATE TABLE IF NOT EXISTS public.user_ratings (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  rater_id    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_id   UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stars       FLOAT       NOT NULL CHECK (stars >= 1 AND stars <= 5),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT user_ratings_no_self CHECK (rater_id <> target_id),
  CONSTRAINT user_ratings_uniq    UNIQUE (rater_id, target_id)
);

CREATE INDEX IF NOT EXISTS idx_user_ratings_target ON public.user_ratings (target_id);

COMMENT ON TABLE public.user_ratings IS 'Calificaciones 1-5 estrellas. RPC rate_user() recalcula el promedio.';


-- ================================================================
-- §5  TABLA: messages
-- ================================================================

CREATE TABLE IF NOT EXISTS public.messages (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id   UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text        TEXT        NOT NULL CHECK (length(text) > 0 AND length(text) <= 4000),
  is_read     BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT messages_no_self CHECK (sender_id <> receiver_id)
);

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_messages_conversation
  ON public.messages (sender_id, receiver_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_unread
  ON public.messages (receiver_id, is_read)
  WHERE is_read = FALSE;

COMMENT ON TABLE public.messages IS 'Mensajes directos entre usuarios. Consumido por MessagingScreen via .stream().';

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can see their own messages" ON public.messages
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can send messages" ON public.messages
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update their received messages" ON public.messages
    FOR UPDATE USING (auth.uid() = receiver_id);

ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;


-- ================================================================
-- §6  TRIGGERS
-- ================================================================

-- 6a. updated_at automático
CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_connections_updated_at  ON public.connections;
CREATE TRIGGER trg_connections_updated_at
  BEFORE UPDATE ON public.connections
  FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_user_ratings_updated_at ON public.user_ratings;
CREATE TRIGGER trg_user_ratings_updated_at
  BEFORE UPDATE ON public.user_ratings
  FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();


-- 6b. Sync users.like_count
CREATE OR REPLACE FUNCTION public.fn_sync_like_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.users SET like_count = like_count + 1
    WHERE id = NEW.pitch_owner_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.users SET like_count = GREATEST(0, like_count - 1)
    WHERE id = OLD.pitch_owner_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_like_count ON public.pitch_likes;
CREATE TRIGGER trg_sync_like_count
  AFTER INSERT OR DELETE ON public.pitch_likes
  FOR EACH ROW EXECUTE FUNCTION public.fn_sync_like_count();


-- 6c. Sync users.connections
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


-- ================================================================
-- §7  RPCs DE NEGOCIO  (SECURITY DEFINER — ejecutan como postgres)
-- ================================================================

-- ── 7a. send_connection_request ──────────────────────────────
-- Flutter: supabase.rpc('send_connection_request', params: {'p_addressee_id': id})
-- Retorna: {status, connection_id, message} | {error}
CREATE OR REPLACE FUNCTION public.send_connection_request(p_addressee_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me  UUID := auth.uid();
  v_row public.connections%ROWTYPE;
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


-- ── 7b. respond_connection ────────────────────────────────────
-- Flutter: supabase.rpc('respond_connection', params: {'p_requester_id': id, 'p_action': 'accept'})
-- p_action: 'accept' | 'reject'
CREATE OR REPLACE FUNCTION public.respond_connection(
  p_requester_id UUID,
  p_action       TEXT
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


-- ── 7c. get_connection_status ─────────────────────────────────
-- Flutter: supabase.rpc('get_connection_status', params: {'p_other_user_id': id})
-- Retorna: {status, connection_id, i_am_requester}
CREATE OR REPLACE FUNCTION public.get_connection_status(p_other_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
DECLARE
  v_me  UUID := auth.uid();
  v_row public.connections%ROWTYPE;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('status', 'none');
  END IF;

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


-- ── 7d. toggle_pitch_like ─────────────────────────────────────
-- Flutter: supabase.rpc('toggle_pitch_like', params: {'p_pitch_owner_id': id})
-- Retorna: {liked: bool, like_count: int}
-- El trigger fn_sync_like_count mantiene users.like_count actualizado.
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

  -- Lectura O(1) del contador cacheado (sin COUNT(*))
  SELECT like_count INTO v_count
  FROM public.users
  WHERE id = p_pitch_owner_id;

  RETURN jsonb_build_object(
    'liked',      v_liked,
    'like_count', COALESCE(v_count, 0)
  );
END;
$$;


-- ── 7e. rate_user ─────────────────────────────────────────────
-- Flutter: supabase.rpc('rate_user', params: {'p_target_id': id, 'p_stars': 4.5})
-- Hace upsert en user_ratings y recalcula users.rating_stars / rating_count.
CREATE OR REPLACE FUNCTION public.rate_user(p_target_id UUID, p_stars FLOAT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me    UUID := auth.uid();
  v_avg   FLOAT;
  v_count INT;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;
  IF v_me = p_target_id THEN
    RETURN jsonb_build_object('error', 'self_rate');
  END IF;
  IF p_stars < 1 OR p_stars > 5 THEN
    RETURN jsonb_build_object('error', 'invalid_stars');
  END IF;

  INSERT INTO public.user_ratings (rater_id, target_id, stars)
  VALUES (v_me, p_target_id, p_stars)
  ON CONFLICT (rater_id, target_id)
  DO UPDATE SET stars = EXCLUDED.stars, updated_at = NOW();

  SELECT AVG(stars), COUNT(*) INTO v_avg, v_count
  FROM public.user_ratings
  WHERE target_id = p_target_id;

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


-- ================================================================
-- §8  ROW LEVEL SECURITY (RLS)
-- ================================================================

-- ── connections ──────────────────────────────────────────────
ALTER TABLE public.connections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "connections_select" ON public.connections;
DROP POLICY IF EXISTS "connections_insert" ON public.connections;
DROP POLICY IF EXISTS "connections_update" ON public.connections;
DROP POLICY IF EXISTS "connections_delete" ON public.connections;

CREATE POLICY "connections_select"
  ON public.connections FOR SELECT
  USING (auth.uid() IN (requester_id, addressee_id));

CREATE POLICY "connections_insert"
  ON public.connections FOR INSERT
  WITH CHECK (auth.uid() = requester_id);

CREATE POLICY "connections_update"
  ON public.connections FOR UPDATE
  USING (auth.uid() IN (requester_id, addressee_id));

CREATE POLICY "connections_delete"
  ON public.connections FOR DELETE
  USING (auth.uid() IN (requester_id, addressee_id));


-- ── pitch_likes ───────────────────────────────────────────────
ALTER TABLE public.pitch_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pitch_likes_select" ON public.pitch_likes;
DROP POLICY IF EXISTS "pitch_likes_insert" ON public.pitch_likes;
DROP POLICY IF EXISTS "pitch_likes_delete" ON public.pitch_likes;

-- Todos los usuarios autenticados pueden ver los likes (necesario para
-- que el stream del feed devuelva like_count actualizado en users).
CREATE POLICY "pitch_likes_select"
  ON public.pitch_likes FOR SELECT
  TO authenticated
  USING (TRUE);

CREATE POLICY "pitch_likes_insert"
  ON public.pitch_likes FOR INSERT
  WITH CHECK (auth.uid() = liker_id);

CREATE POLICY "pitch_likes_delete"
  ON public.pitch_likes FOR DELETE
  USING (auth.uid() = liker_id);


-- ── user_ratings ──────────────────────────────────────────────
ALTER TABLE public.user_ratings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_ratings_select" ON public.user_ratings;
DROP POLICY IF EXISTS "user_ratings_insert" ON public.user_ratings;
DROP POLICY IF EXISTS "user_ratings_update" ON public.user_ratings;

CREATE POLICY "user_ratings_select"
  ON public.user_ratings FOR SELECT
  USING (auth.uid() IN (rater_id, target_id));

CREATE POLICY "user_ratings_insert"
  ON public.user_ratings FOR INSERT
  WITH CHECK (auth.uid() = rater_id);

CREATE POLICY "user_ratings_update"
  ON public.user_ratings FOR UPDATE
  USING (auth.uid() = rater_id);


-- ── messages ──────────────────────────────────────────────────
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "messages_select" ON public.messages;
DROP POLICY IF EXISTS "messages_insert" ON public.messages;
DROP POLICY IF EXISTS "messages_update" ON public.messages;
DROP POLICY IF EXISTS "messages_delete" ON public.messages;

CREATE POLICY "messages_select"
  ON public.messages FOR SELECT
  USING (auth.uid() IN (sender_id, receiver_id));

CREATE POLICY "messages_insert"
  ON public.messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

-- El receptor puede marcar como leído
CREATE POLICY "messages_update"
  ON public.messages FOR UPDATE
  USING (auth.uid() = receiver_id);

CREATE POLICY "messages_delete"
  ON public.messages FOR DELETE
  USING (auth.uid() = sender_id);


-- ================================================================
-- §9  REALTIME  (habilitar broadcast en tiempo real)
-- ================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'connections'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.connections;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'pitch_likes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.pitch_likes;
  END IF;
END $$;


-- ================================================================
-- §10  GRANTS  (acceso para el rol authenticated)
-- ================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON public.messages     TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.connections  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pitch_likes  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_ratings TO authenticated;

GRANT EXECUTE ON FUNCTION public.send_connection_request(UUID)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_connection(UUID, TEXT)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_connection_status(UUID)     TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_pitch_like(UUID)         TO authenticated;
GRANT EXECUTE ON FUNCTION public.rate_user(UUID, FLOAT)          TO authenticated;


-- ================================================================
-- §11  VERIFICACIÓN  (ejecuta esto por separado para confirmar)
-- ================================================================
--
-- Columnas añadidas a users:
--   SELECT column_name, data_type
--   FROM information_schema.columns
--   WHERE table_schema = 'public' AND table_name = 'users'
--   ORDER BY ordinal_position;
--
-- Tablas creadas:
--   SELECT tablename FROM pg_tables
--   WHERE schemaname = 'public' ORDER BY tablename;
--
-- RPCs disponibles:
--   SELECT routine_name FROM information_schema.routines
--   WHERE routine_schema = 'public' AND routine_type = 'FUNCTION'
--   ORDER BY routine_name;
--
-- Triggers activos:
--   WHERE trigger_schema = 'public'
--   ORDER BY event_object_table;
-- ================================================================

-- ================================================================
-- §12 CHAT Y MENSAJES EN TIEMPO REAL
-- ================================================================
-- NOTA: La tabla 'messages' se define en §5 (líneas ~119-138).
-- Las siguientes son operaciones idempotentes sobre esa tabla.

-- Asegurar RLS (ya habilitado en §5, idempotente)
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Políticas (IF NOT EXISTS no aplica a policies, se asumen creadas en §5)
-- Si necesitas recrear:
--   DROP POLICY IF EXISTS "..." ON public.messages;
--   CREATE POLICY "..." ...

-- Realtime (idempotente — no crashea si ya existe)
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;

-- ================================================================
-- §13 PUBLICACIONES DE TEXTO (POSTS)
-- ================================================================

CREATE TABLE IF NOT EXISTS public.posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    audience VARCHAR(50) DEFAULT 'Público General',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0
);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can see all public posts" ON public.posts
    FOR SELECT USING (true); 

CREATE POLICY "Users can create their own posts" ON public.posts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own posts" ON public.posts
    FOR DELETE USING (auth.uid() = user_id);

ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;


-- ================================================================
-- §14 NOTIFICACIONES / PANEL IA (NOTIFICATIONS)
-- ================================================================

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    type VARCHAR(50) NOT NULL, -- 'like', 'comment', 'connection', 'profileView', 'jobAlert', 'mention'
    description TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only see their own notifications" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id);

-- INSERT restringido (migración 20260501):
-- El actor debe ser el usuario autenticado, y no puede enviar a sí mismo.
-- Notificaciones del sistema usan RPC create_system_notification() (SECURITY DEFINER).
CREATE POLICY "notifications_insert_safe" ON public.notifications
    FOR INSERT WITH CHECK (
        (actor_id IS NULL OR actor_id = auth.uid())
        AND user_id != auth.uid()
    );

CREATE POLICY "Users can update their own notifications" ON public.notifications
    FOR UPDATE USING (auth.uid() = user_id);

ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- ================================================================
-- §15 OFERTAS DE EMPLEO / PORTAL (JOBS)
-- ================================================================
-- NOTA: La definición canónica de 'jobs' se encuentra en FASE 10 (~línea 831).
-- Esa versión tiene company_id NOT NULL y políticas más restrictivas:
--   - INSERT: auth.uid() = company_id (solo la empresa dueña)
--   - UPDATE/DELETE: auth.uid() = company_id
-- La versión aquí (§15) tenía INSERT abierto a cualquier autenticado, lo cual
-- es una brecha de seguridad. Se elimina esta definición duplicada.

-- Asegurar RLS (idempotente)
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;

-- Realtime (idempotente)
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.jobs;


-- ================================================================
-- §16 ECONOMÍA B2B (TOKENS / CRÉDITOS SAAS)
-- ================================================================

CREATE TABLE IF NOT EXISTS public.company_wallets (
    company_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    credits_balance INTEGER NOT NULL DEFAULT 0,
    subscription_tier VARCHAR(50) DEFAULT 'Freemium', -- 'Freemium', 'Pro Recruiter', 'Enterprise Elite'
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.company_wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Companies can see their own wallet" ON public.company_wallets
    FOR SELECT USING (auth.uid() = company_id);

-- ⚠️ SEGURIDAD CRÍTICA (Fase 11): 
-- Las billeteras YA NO se pueden modificar (Insert/Update) desde el cliente frontend.
-- Solo se pueden leer. El saldo lo manejan los pagos (Stripe) y los RPC internos.
-- Políticas de INSERT y UPDATE eliminadas.

-- Función segura para reclamar el bono de bienvenida (Solo 1 vez)
CREATE OR REPLACE FUNCTION public.claim_welcome_credits()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me UUID := auth.uid();
  v_exists BOOLEAN;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('error', 'not_authenticated'); END IF;

  SELECT EXISTS(SELECT 1 FROM public.company_wallets WHERE company_id = v_me) INTO v_exists;
  
  IF v_exists THEN
    RETURN jsonb_build_object('status', 'already_claimed');
  ELSE
    INSERT INTO public.company_wallets (company_id, credits_balance, subscription_tier) 
    VALUES (v_me, 5, 'Freemium');
    RETURN jsonb_build_object('status', 'success', 'balance', 5);
  END IF;
END;
$$;

-- ================================================================
-- FASE 12: PROTECCIÓN DE IDENTIDAD STEALTH (SUSTENTO DE DATOS)
-- ================================================================

-- Función para que reclutadores lean el catálogo sin filtrar nombres
CREATE OR REPLACE FUNCTION public.get_stealth_catalog()
RETURNS TABLE (
  candidate_id UUID,
  headline VARCHAR,
  about VARCHAR,
  tags TEXT[],
  budget VARCHAR,
  is_unlocked BOOLEAN,
  real_name VARCHAR
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
    -- Mock o extracción del ppto real
    '1M+'::VARCHAR AS budget,
    -- Verificar si MI empresa ya lo desbloqueó
    (pu.id IS NOT NULL) AS is_unlocked,
    -- Regla de oro: si está desbloqueado, muestro el nombre real. Si no, le inyecto mascarilla vacía.
    CASE WHEN pu.id IS NOT NULL THEN u.name ELSE 'Confidencial'::VARCHAR END AS real_name
  FROM public.users u
  LEFT JOIN public.profile_unlocks pu ON pu.candidate_id = u.id AND pu.company_id = v_me
  WHERE u.account_type = 'confidencial';
END;
$$;


CREATE TABLE IF NOT EXISTS public.profile_unlocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    candidate_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT profile_unlocks_uniq UNIQUE (company_id, candidate_id)
);

ALTER TABLE public.profile_unlocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Companies can see whom they unlocked" ON public.profile_unlocks
    FOR SELECT USING (auth.uid() = company_id);

CREATE POLICY "Candidates can see who unlocked them" ON public.profile_unlocks
    FOR SELECT USING (auth.uid() = candidate_id);

-- RPC TRANSACTION para desbloquear de forma segura
CREATE OR REPLACE FUNCTION public.unlock_stealth_profile(p_candidate_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me UUID := auth.uid();
  v_wallet RECORD;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  -- 1. Evitar auto-desbloqueo
  IF v_me = p_candidate_id THEN
    RETURN jsonb_build_object('error', 'cannot_unlock_self');
  END IF;

  -- 2. Verificar si ya lo desbloqueó antes
  IF EXISTS (SELECT 1 FROM public.profile_unlocks WHERE company_id = v_me AND candidate_id = p_candidate_id) THEN
    RETURN jsonb_build_object('status', 'already_unlocked');
  END IF;

  -- 3. Obtener billetera de la empresa con bloqueo para concurrencia (FOR UPDATE)
  SELECT * INTO v_wallet FROM public.company_wallets WHERE company_id = v_me FOR UPDATE;
  
  IF NOT FOUND THEN
    -- Si no existe wallet inicial, creamos una vacía.
    INSERT INTO public.company_wallets (company_id, credits_balance) VALUES (v_me, 0);
    RETURN jsonb_build_object('error', 'insufficient_funds', 'balance', 0);
  END IF;

  -- 4. Verificar fondos estrictamente
  IF v_wallet.credits_balance <= 0 THEN
    RETURN jsonb_build_object('error', 'insufficient_funds', 'balance', v_wallet.credits_balance);
  END IF;

  -- 5. Transacción atómica: Restar crédito y registrar
  UPDATE public.company_wallets SET credits_balance = credits_balance - 1, updated_at = NOW() WHERE company_id = v_me;
  INSERT INTO public.profile_unlocks (company_id, candidate_id) VALUES (v_me, p_candidate_id);

  RETURN jsonb_build_object('status', 'success', 'remaining_balance', v_wallet.credits_balance - 1);
END;
$$;

-- ================================================================
-- FASE 10: ATS JOBS Y MOTOR DE MATCHING CON HASHTAGS
-- ================================================================

CREATE TABLE IF NOT EXISTS public.jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    company_name VARCHAR(255) NOT NULL,
    title VARCHAR(255) NOT NULL,
    location VARCHAR(255),
    salary_range VARCHAR(100),
    type VARCHAR(50) DEFAULT 'Público', -- 'Público' o 'Stealth'
    tags TEXT[] DEFAULT '{}', -- Ej: ['#Flutter', '#Senior', '#Remoto']
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;

-- Todos pueden ver los trabajos
CREATE POLICY "Jobs are viewable by everyone" ON public.jobs
    FOR SELECT USING (true);

-- Empresas pueden insertar y editar sus propios trabajos
CREATE POLICY "Companies can insert own jobs" ON public.jobs
    FOR INSERT WITH CHECK (auth.uid() = company_id);

CREATE POLICY "Companies can update own jobs" ON public.jobs
    FOR UPDATE USING (auth.uid() = company_id);

CREATE POLICY "Companies can delete own jobs" ON public.jobs
    FOR DELETE USING (auth.uid() = company_id);


-- Función de Algoritmo de Match (AI Scoring Simulado)
-- Compara los tags de un trabajo o empresa con los tags del usuario y devuelve % (0-100)
CREATE OR REPLACE FUNCTION public.calculate_match_score(p_tags1 TEXT[], p_tags2 TEXT[])
RETURNS INTEGER LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    v_common_count INTEGER := 0;
    v_total_count INTEGER;
    tag TEXT;
BEGIN
    IF p_tags1 IS NULL OR p_tags2 IS NULL OR array_length(p_tags1, 1) = 0 OR array_length(p_tags2, 1) = 0 THEN
        RETURN 0;
    END IF;

    -- Conteo simple de elementos en común (Intersección)
    FOREACH tag IN ARRAY p_tags1 LOOP
        IF tag = ANY(p_tags2) THEN
            v_common_count := v_common_count + 1;
        END IF;
    END LOOP;

    v_total_count := array_length(p_tags1, 1);
    
    -- Calcula el porcentaje basado en cuántos tags requeridos se cumplieron
    IF v_total_count = 0 THEN RETURN 0; END IF;
    
    RETURN LEAST(100, (v_common_count * 100) / v_total_count);
END;
$$;

-- ================================================================
-- FASE M: POSTGIS Y GEOLOCALIZACIÓN PARA RADAR EXPLORE
-- ================================================================

-- 1. Habilitar el súper-poder espacial
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Añadir la columna de coordenadas exactas (geography POINT) a Usuarios y Vacantes
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS location_geom geography(POINT);
ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS location_geom geography(POINT);

-- 3. Crear índice geoespacial masivo para que buscar sea instantáneo incluso con millones de perfiles
CREATE INDEX IF NOT EXISTS users_geo_idx ON public.users USING GIST (location_geom);
CREATE INDEX IF NOT EXISTS jobs_geo_idx ON public.jobs USING GIST (location_geom);

-- 4. Función Backend: "Radar de Oportunidades"
-- Le mandas tu lat/lng y te escupe las vacantes alrededor con la distancia EXACTA en metros
CREATE OR REPLACE FUNCTION public.get_nearby_jobs(p_user_lat FLOAT, p_user_lng FLOAT, p_radius_km FLOAT DEFAULT 50.0)
RETURNS TABLE (
  job_id UUID,
  title VARCHAR,
  company_name VARCHAR,
  salary_range VARCHAR,
  distance_meters FLOAT,
  latitude FLOAT,
  longitude FLOAT
) LANGUAGE plpgsql STABLE AS $$
BEGIN
  RETURN QUERY
  SELECT 
    j.id, 
    j.title, 
    j.company_name,
    j.salary_range,
    -- Calcula distancia REAL teniendo en cuenta la curvatura de la tierra
    ST_Distance(
      j.location_geom, 
      ST_SetSRID(ST_MakePoint(p_user_lng, p_user_lat), 4326)::geography
    ) as distance_meters,
    ST_Y(j.location_geom::geometry) as latitude,
    ST_X(j.location_geom::geometry) as longitude
  FROM public.jobs j
  WHERE 
    j.location_geom IS NOT NULL 
    AND ST_DWithin(
      j.location_geom, 
      ST_SetSRID(ST_MakePoint(p_user_lng, p_user_lat), 4326)::geography, 
      p_radius_km * 1000 -- Convertimos KM a metros
    )
  ORDER BY distance_meters ASC;
END;
$$;

-- 5. Crear una vacante con coordenadas PostGIS directo desde Flutter
CREATE OR REPLACE FUNCTION public.create_job_with_postgis(
  p_title VARCHAR,
  p_salary VARCHAR,
  p_tags TEXT[],
  p_is_stealth BOOLEAN,
  p_lat FLOAT,
  p_lng FLOAT
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me UUID := auth.uid();
  v_job_id UUID;
BEGIN
  INSERT INTO public.jobs (company_id, title, salary_range, required_tags, is_stealth, location_geom)
  VALUES (
    v_me, p_title, p_salary, p_tags, p_is_stealth,
    CASE WHEN p_lat IS NOT NULL THEN ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography ELSE NULL END
  ) RETURNING id INTO v_job_id;
  RETURN v_job_id;
END;
$$;

-- ================================================================
-- FASE 13: WEBHOOK FIREBASE PARA PUSH NOTIFICATIONS
-- ================================================================
-- Trigger para disparar el Webhook cada vez que entra un mensaje nuevo (InMail)
CREATE OR REPLACE FUNCTION public.notify_inmail_push() 
RETURNS TRIGGER SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_receiver_fcm TEXT;
  v_sender_name VARCHAR;
BEGIN
  -- 1. Buscar si el perfil destino tiene Firebase instalado en su celular
  SELECT fcm_token INTO v_receiver_fcm FROM public.users WHERE id = NEW.receiver_id;
  
  IF v_receiver_fcm IS NOT NULL THEN
    
    -- 2. Traer el nombre del Headhunter para poner en la notificación
    SELECT name INTO v_sender_name FROM public.users WHERE id = NEW.sender_id;
    
    -- 3. Código Edge Function para pg_net (Lo dejas comentado si no tenés Edge Functions activas)
    /*
    PERFORM net.http_post(
        url := 'https://[TU-PROYECTO].supabase.co/functions/v1/send-fcm',
        headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer [SERVICE_KEY]'),
        body := jsonb_build_object(
            'token', v_receiver_fcm,
            'title', '💼 InMail Premium: ' || v_sender_name,
            'body', NEW.text
        )
    );
    */
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_new_inmail ON public.messages;
CREATE TRIGGER on_new_inmail
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_inmail_push();

-- ================================================================
-- REVENUECAT: CARGA NO-RLS PARA EDGE FUNCTIONS
-- ================================================================
CREATE OR REPLACE FUNCTION public.add_headhunter_credits(p_company_id UUID, p_credits INT) 
RETURNS VOID SECURITY DEFINER LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.company_wallets (company_id, headhunter_credits)
  VALUES (p_company_id, p_credits)
  ON CONFLICT (company_id) DO UPDATE SET 
    headhunter_credits = public.company_wallets.headhunter_credits + p_credits,
    updated_at = NOW();
END;
$$;

-- ================================================================
-- FASE 15: SWIPE TO APPLY (APLICACIONES A VACANTES EN VIDEO)
-- ================================================================
CREATE TABLE IF NOT EXISTS public.job_applications (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id         UUID        NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  candidate_id   UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status         TEXT        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','viewed','accepted','rejected')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT job_applications_uniq UNIQUE (job_id, candidate_id)
);

CREATE INDEX IF NOT EXISTS idx_job_applications_job ON public.job_applications (job_id, status);
CREATE INDEX IF NOT EXISTS idx_job_applications_candidate ON public.job_applications (candidate_id, status);

COMMENT ON TABLE public.job_applications IS 'Postulaciones de candidatos. Su Video Pitch se transfiere implícitamente por el candidate_id.';

-- ── RLS para job_applications ──
ALTER TABLE public.job_applications ENABLE ROW LEVEL SECURITY;

-- Candidatos ven sus propias aplicaciones
CREATE POLICY "Candidates can view own applications" ON public.job_applications
    FOR SELECT USING (auth.uid() = candidate_id);

-- Empresas ven aplicaciones a sus vacantes
CREATE POLICY "Companies can view applications to own jobs" ON public.job_applications
    FOR SELECT USING (
      EXISTS (SELECT 1 FROM public.jobs WHERE jobs.id = job_applications.job_id AND jobs.company_id = auth.uid())
    );

-- Candidatos pueden aplicar (insertar)
CREATE POLICY "Candidates can apply to jobs" ON public.job_applications
    FOR INSERT WITH CHECK (auth.uid() = candidate_id);

-- Empresas pueden actualizar estado de aplicaciones a sus vacantes
CREATE POLICY "Companies can update application status" ON public.job_applications
    FOR UPDATE USING (
      EXISTS (SELECT 1 FROM public.jobs WHERE jobs.id = job_applications.job_id AND jobs.company_id = auth.uid())
    );

-- Candidatos pueden retirar su aplicación
CREATE POLICY "Candidates can withdraw own applications" ON public.job_applications
    FOR DELETE USING (auth.uid() = candidate_id);
