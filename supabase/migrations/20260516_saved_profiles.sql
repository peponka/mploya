-- ─────────────────────────────────────────────────────────────────────────────
-- Saved Profiles — tabla para guardar perfiles desde el feed
-- Ejecutar en Supabase SQL Editor
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS saved_profiles (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  saved_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz DEFAULT now(),
  UNIQUE(user_id, saved_user_id)
);

-- RLS: solo el dueño puede ver/crear/borrar sus guardados
ALTER TABLE saved_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own saved profiles" ON saved_profiles;
CREATE POLICY "Users can view own saved profiles" ON saved_profiles
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can save profiles" ON saved_profiles;
CREATE POLICY "Users can save profiles" ON saved_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can unsave profiles" ON saved_profiles;
CREATE POLICY "Users can unsave profiles" ON saved_profiles
  FOR DELETE USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_saved_profiles_user ON saved_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_profiles_saved ON saved_profiles(saved_user_id);
