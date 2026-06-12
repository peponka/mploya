-- ============================================================
-- Stories System — Mploya
-- Historias efímeras (24h) con likes = "Estoy interesado"
-- ============================================================

-- Limpiar si existía parcialmente
DROP TABLE IF EXISTS story_likes CASCADE;
DROP TABLE IF EXISTS stories CASCADE;

-- ── Tabla de historias ──
CREATE TABLE stories (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  video_url   TEXT NOT NULL,
  caption     TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  expires_at  TIMESTAMPTZ DEFAULT now() + INTERVAL '24 hours',
  is_active   BOOLEAN DEFAULT true
);

-- ── Likes de historias (interés / contactame) ──
CREATE TABLE story_likes (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  story_id   UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(story_id, user_id)
);

-- ── Índices de rendimiento ──
CREATE INDEX idx_stories_user_id ON stories(user_id);
CREATE INDEX idx_stories_active ON stories(is_active, expires_at DESC);
CREATE INDEX idx_story_likes_story ON story_likes(story_id);
CREATE INDEX idx_story_likes_user ON story_likes(user_id);

-- ── RLS ──
ALTER TABLE stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_likes ENABLE ROW LEVEL SECURITY;

-- Cualquier usuario autenticado puede ver historias activas
CREATE POLICY "stories_select_authenticated" ON stories
  FOR SELECT TO authenticated
  USING (is_active = true AND expires_at > now());

-- Solo el dueño puede insertar/eliminar sus historias
CREATE POLICY "stories_insert_own" ON stories
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "stories_delete_own" ON stories
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Likes: cualquier autenticado puede dar like
CREATE POLICY "story_likes_select" ON story_likes
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "story_likes_insert" ON story_likes
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "story_likes_delete_own" ON story_likes
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());
