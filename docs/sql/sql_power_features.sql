-- ═══════════════════════════════════════════════════════════════════════════
-- Mploya — SQL para Power Features (Ejecutar en Supabase SQL Editor)
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Tabla de Vistas de Perfil (Quién vio tu perfil)
CREATE TABLE IF NOT EXISTS profile_views (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  viewer_id uuid NOT NULL,
  viewed_id uuid NOT NULL,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pv_viewed ON profile_views(viewed_id);
CREATE INDEX IF NOT EXISTS idx_pv_viewer ON profile_views(viewer_id);

-- RLS para profile_views
ALTER TABLE profile_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert views" ON profile_views
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can read their own views" ON profile_views
  FOR SELECT TO authenticated
  USING (viewed_id = auth.uid() OR viewer_id = auth.uid());


-- 2. Tabla de Comentarios en Pitches
CREATE TABLE IF NOT EXISTS pitch_comments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  author_id uuid NOT NULL,
  target_user_id uuid NOT NULL,
  text text NOT NULL,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pc_target ON pitch_comments(target_user_id);
CREATE INDEX IF NOT EXISTS idx_pc_author ON pitch_comments(author_id);

-- RLS para pitch_comments
ALTER TABLE pitch_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert comments" ON pitch_comments
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "Anyone can read comments" ON pitch_comments
  FOR SELECT TO authenticated
  USING (true);


-- 3. Columna avatar_url (si no existe)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url text;

-- 4. Columna city (si no existe — ya debería estar)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS city text;

-- ═══════════════════════════════════════════════════════════════════════════
-- LISTO — Ejecuta todo lo anterior de una sola vez en SQL Editor
-- ═══════════════════════════════════════════════════════════════════════════
