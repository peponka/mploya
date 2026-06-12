-- ═══════════════════════════════════════════════════════════════════════════════
-- Migration: Skill Assessment Badges + Blind Hiring Mode
-- Date: 2026-05-14
-- ═══════════════════════════════════════════════════════════════════════════════

-- Limpiar intentos previos
DROP TABLE IF EXISTS skill_assessments CASCADE;
DROP TABLE IF EXISTS skill_assessment_catalog CASCADE;

-- ─── 1. Skill Assessments Table ──────────────────────────────────────────────
CREATE TABLE skill_assessments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  skill_name TEXT NOT NULL,
  skill_category TEXT NOT NULL DEFAULT 'technical',
  score INT NOT NULL CHECK (score >= 0 AND score <= 100),
  passed BOOLEAN NOT NULL DEFAULT false,
  questions_total INT NOT NULL DEFAULT 5,
  questions_correct INT NOT NULL DEFAULT 0,
  badge_level TEXT,
  time_taken_seconds INT,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  assessment_date DATE NOT NULL DEFAULT CURRENT_DATE
);

-- Prevent retaking same assessment within 24 hours
CREATE UNIQUE INDEX idx_skill_assessments_daily
  ON skill_assessments (user_id, skill_name, assessment_date);

CREATE INDEX idx_skill_assessments_user ON skill_assessments(user_id);
CREATE INDEX idx_skill_assessments_skill ON skill_assessments(skill_name);
CREATE INDEX idx_skill_assessments_passed ON skill_assessments(user_id, passed) WHERE passed = true;

-- RLS
ALTER TABLE skill_assessments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own assessments"
  ON skill_assessments FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own assessments"
  ON skill_assessments FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Public can see passed badges"
  ON skill_assessments FOR SELECT USING (passed = true);


-- ─── 2. Blind Hiring Mode Column ────────────────────────────────────────────
ALTER TABLE users ADD COLUMN IF NOT EXISTS blind_hiring_mode BOOLEAN DEFAULT false;


-- ─── 3. Skill Assessment Catalog ─────────────────────────────────────────────
CREATE TABLE skill_assessment_catalog (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  skill_name TEXT NOT NULL UNIQUE,
  category TEXT NOT NULL DEFAULT 'technical',
  description TEXT,
  icon_name TEXT,
  difficulty TEXT DEFAULT 'intermediate',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO skill_assessment_catalog (skill_name, category, description, icon_name, difficulty) VALUES
  ('React', 'technical', 'Componentes, hooks, estado y ciclo de vida', 'bolt_fill', 'intermediate'),
  ('Python', 'technical', 'Sintaxis, estructuras de datos y POO', 'chevron_left_slash_chevron_right', 'intermediate'),
  ('Flutter', 'technical', 'Widgets, state management y navegación', 'device_phone_portrait', 'intermediate'),
  ('JavaScript', 'technical', 'ES6+, closures, async/await y DOM', 'globe', 'intermediate'),
  ('SQL', 'technical', 'Consultas, joins, indexes y optimización', 'tray_full_fill', 'intermediate'),
  ('Node.js', 'technical', 'Express, middleware y APIs REST', 'cloud_fill', 'intermediate'),
  ('TypeScript', 'technical', 'Tipos, interfaces y generics', 'doc_text_fill', 'intermediate'),
  ('UX Design', 'soft', 'Principios de usabilidad y accesibilidad', 'paintbrush_fill', 'beginner'),
  ('Product Management', 'soft', 'Priorización, métricas y roadmaps', 'chart_bar_fill', 'intermediate'),
  ('Data Analysis', 'technical', 'Estadísticas, visualización y ETL', 'chart_pie_fill', 'intermediate'),
  ('AWS', 'technical', 'EC2, S3, Lambda y servicios core', 'cloud_fill', 'advanced'),
  ('Docker', 'technical', 'Contenedores, imágenes y compose', 'shippingbox_fill', 'intermediate'),
  ('Git', 'technical', 'Branches, merges, rebases y workflows', 'arrow_branch', 'beginner'),
  ('Comunicación', 'soft', 'Presentaciones, feedback y trabajo en equipo', 'bubble_left_and_bubble_right_fill', 'beginner'),
  ('Liderazgo', 'soft', 'Gestión de equipos, delegación y mentoría', 'person_3_fill', 'intermediate');

ALTER TABLE skill_assessment_catalog ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read skill catalog"
  ON skill_assessment_catalog FOR SELECT USING (true);


-- ─── 4. Función: Obtener badges de un usuario ───────────────────────────────
CREATE OR REPLACE FUNCTION get_user_badges(p_user_id UUID)
RETURNS TABLE (
  skill_name TEXT,
  badge_level TEXT,
  score INT,
  skill_category TEXT,
  earned_at TIMESTAMPTZ
) LANGUAGE sql STABLE AS $$
  SELECT DISTINCT ON (sa.skill_name)
    sa.skill_name,
    sa.badge_level,
    sa.score,
    sa.skill_category,
    sa.created_at AS earned_at
  FROM skill_assessments sa
  WHERE sa.user_id = p_user_id
    AND sa.passed = true
    AND (sa.expires_at IS NULL OR sa.expires_at > now())
  ORDER BY sa.skill_name, sa.score DESC;
$$;
