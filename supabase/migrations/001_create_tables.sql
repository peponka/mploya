-- =============================================================================
-- Migración principal de mploya
-- =============================================================================
-- Crea las tablas: videos, matches, connections, video_likes
-- Configura RLS, índices de rendimiento y buckets de Storage.
--
-- NOTA: La tabla `profiles` ya existe (creada por auth_service).
-- =============================================================================

-- ─── Videos ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.videos (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  url         text NOT NULL,
  thumbnail_url text,
  duration    integer NOT NULL DEFAULT 0,
  type        text NOT NULL DEFAULT 'pitch'
              CHECK (type IN ('pitch', 'story', 'reply', 'portfolio')),
  title       text,
  description text,
  score       integer NOT NULL DEFAULT 0,
  hashtags    text[] NOT NULL DEFAULT '{}',
  view_count  integer NOT NULL DEFAULT 0,
  like_count  integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.videos IS 'Videos de la plataforma: pitches, stories, replies y portfolio.';

-- ─── Matches ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.matches (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_user_id   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status           text NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending', 'active', 'connected', 'rejected')),
  type             text NOT NULL DEFAULT 'candidate'
                   CHECK (type IN ('candidate', 'company')),
  match_percentage integer NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),

  -- Un usuario no puede tener match duplicado con el mismo target
  UNIQUE (user_id, target_user_id)
);

COMMENT ON TABLE public.matches IS 'Matches entre usuarios (candidato ↔ empresa/candidato).';

-- ─── Connections ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.connections (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  connected_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status            text NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'blocked', 'removed')),
  connected_at      timestamptz NOT NULL DEFAULT now(),

  -- Una conexión única por par de usuarios
  UNIQUE (user_id, connected_user_id)
);

COMMENT ON TABLE public.connections IS 'Conexiones confirmadas entre usuarios.';

-- ─── Video Likes ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.video_likes (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  video_id   uuid NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),

  -- Un usuario solo puede dar like una vez por video
  UNIQUE (user_id, video_id)
);

COMMENT ON TABLE public.video_likes IS 'Likes de usuarios a videos.';

-- =============================================================================
-- Habilitar RLS
-- =============================================================================

ALTER TABLE public.videos      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.video_likes ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- Políticas RLS — Videos
-- =============================================================================

-- Cualquier usuario autenticado puede ver videos
CREATE POLICY "videos_select_authenticated"
  ON public.videos FOR SELECT
  TO authenticated
  USING (true);

-- Solo el dueño puede insertar sus propios videos
CREATE POLICY "videos_insert_own"
  ON public.videos FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Solo el dueño puede actualizar sus videos
CREATE POLICY "videos_update_own"
  ON public.videos FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Solo el dueño puede eliminar sus videos
CREATE POLICY "videos_delete_own"
  ON public.videos FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- =============================================================================
-- Políticas RLS — Matches
-- =============================================================================

-- Un usuario puede ver matches donde es participante
CREATE POLICY "matches_select_participant"
  ON public.matches FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR auth.uid() = target_user_id);

-- Un usuario puede crear matches donde es el origen
CREATE POLICY "matches_insert_own"
  ON public.matches FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Un participante puede actualizar el match (aceptar, rechazar, conectar)
CREATE POLICY "matches_update_participant"
  ON public.matches FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id OR auth.uid() = target_user_id)
  WITH CHECK (auth.uid() = user_id OR auth.uid() = target_user_id);

-- Solo el creador puede eliminar el match
CREATE POLICY "matches_delete_own"
  ON public.matches FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- =============================================================================
-- Políticas RLS — Connections
-- =============================================================================

-- Un usuario puede ver sus conexiones
CREATE POLICY "connections_select_own"
  ON public.connections FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR auth.uid() = connected_user_id);

-- Un usuario puede crear conexiones donde es participante
CREATE POLICY "connections_insert_own"
  ON public.connections FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Un participante puede actualizar la conexión
CREATE POLICY "connections_update_participant"
  ON public.connections FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id OR auth.uid() = connected_user_id)
  WITH CHECK (auth.uid() = user_id OR auth.uid() = connected_user_id);

-- Un participante puede eliminar la conexión
CREATE POLICY "connections_delete_participant"
  ON public.connections FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id OR auth.uid() = connected_user_id);

-- =============================================================================
-- Políticas RLS — Video Likes
-- =============================================================================

-- Cualquier autenticado puede ver los likes (para conteo)
CREATE POLICY "video_likes_select_authenticated"
  ON public.video_likes FOR SELECT
  TO authenticated
  USING (true);

-- Un usuario solo puede insertar sus propios likes
CREATE POLICY "video_likes_insert_own"
  ON public.video_likes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Un usuario solo puede eliminar sus propios likes
CREATE POLICY "video_likes_delete_own"
  ON public.video_likes FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- =============================================================================
-- Índices de rendimiento
-- =============================================================================

-- Videos: feed ordenado por fecha, filtro por usuario, filtro por tipo
CREATE INDEX IF NOT EXISTS idx_videos_created_at   ON public.videos (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_videos_user_id      ON public.videos (user_id);
CREATE INDEX IF NOT EXISTS idx_videos_type         ON public.videos (type);
CREATE INDEX IF NOT EXISTS idx_videos_user_type    ON public.videos (user_id, type);

-- Matches: búsqueda por participante y estado
CREATE INDEX IF NOT EXISTS idx_matches_user_id        ON public.matches (user_id);
CREATE INDEX IF NOT EXISTS idx_matches_target_user_id ON public.matches (target_user_id);
CREATE INDEX IF NOT EXISTS idx_matches_status         ON public.matches (status);
CREATE INDEX IF NOT EXISTS idx_matches_user_status    ON public.matches (user_id, status);

-- Connections: búsqueda por usuario
CREATE INDEX IF NOT EXISTS idx_connections_user_id           ON public.connections (user_id);
CREATE INDEX IF NOT EXISTS idx_connections_connected_user_id ON public.connections (connected_user_id);

-- Video Likes: búsqueda por video y por usuario
CREATE INDEX IF NOT EXISTS idx_video_likes_video_id ON public.video_likes (video_id);
CREATE INDEX IF NOT EXISTS idx_video_likes_user_id  ON public.video_likes (user_id);

-- =============================================================================
-- Buckets de Storage
-- =============================================================================
-- Nota: los buckets se crean como públicos para servir URLs directas.
-- Las políticas de escritura se controlan via RLS en storage.objects.

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('videos',     'videos',     true),
  ('avatars',    'avatars',    true),
  ('thumbnails', 'thumbnails', true)
ON CONFLICT (id) DO NOTHING;

-- ─── Políticas de Storage — Videos ──────────────────────────────────

CREATE POLICY "videos_storage_select"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'videos');

CREATE POLICY "videos_storage_insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'videos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "videos_storage_delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'videos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ─── Políticas de Storage — Avatars ─────────────────────────────────

CREATE POLICY "avatars_storage_select"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'avatars');

CREATE POLICY "avatars_storage_insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "avatars_storage_delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ─── Políticas de Storage — Thumbnails ──────────────────────────────

CREATE POLICY "thumbnails_storage_select"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'thumbnails');

CREATE POLICY "thumbnails_storage_insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'thumbnails'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "thumbnails_storage_delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'thumbnails'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- =============================================================================
-- Trigger para actualizar updated_at automáticamente
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_videos_updated_at
  BEFORE UPDATE ON public.videos
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_matches_updated_at
  BEFORE UPDATE ON public.matches
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================================================
-- Función RPC para incrementar view_count atómicamente
-- =============================================================================

CREATE OR REPLACE FUNCTION public.increment_view_count(p_video_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE public.videos
  SET view_count = view_count + 1
  WHERE id = p_video_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
