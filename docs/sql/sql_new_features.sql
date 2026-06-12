-- ============================================================
-- SQL: Nuevas Features Mploya (Ghost Apply, Verificación, Challenges)
-- Ejecutar en Supabase SQL Editor
-- ============================================================

-- ── 1. Ghost Applications (Feature 2) ────────────────────────

CREATE TABLE IF NOT EXISTS ghost_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  blind_headline TEXT NOT NULL DEFAULT '',
  blind_about TEXT NOT NULL DEFAULT '',
  blind_tags JSONB DEFAULT '[]',
  match_score INT DEFAULT 0,
  is_unlocked BOOLEAN DEFAULT FALSE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','reviewed','shortlisted','rejected','unlocked')),
  unlocked_at TIMESTAMPTZ,
  unlocked_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(candidate_id, job_id)
);

-- RLS: Candidatos ven solo sus propias ghost apps
ALTER TABLE ghost_applications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ghost_apps_candidate_read" ON ghost_applications
  FOR SELECT USING (auth.uid() = candidate_id);

CREATE POLICY "ghost_apps_candidate_insert" ON ghost_applications
  FOR INSERT WITH CHECK (auth.uid() = candidate_id);

-- Empresas ven ghost apps de sus vacantes
CREATE POLICY "ghost_apps_company_read" ON ghost_applications
  FOR SELECT USING (
    job_id IN (SELECT id FROM jobs WHERE company_id = auth.uid())
  );

-- Empresas pueden desbloquear
CREATE POLICY "ghost_apps_company_update" ON ghost_applications
  FOR UPDATE USING (
    job_id IN (SELECT id FROM jobs WHERE company_id = auth.uid())
  );

-- Índices para rendimiento
CREATE INDEX IF NOT EXISTS idx_ghost_apps_job ON ghost_applications(job_id);
CREATE INDEX IF NOT EXISTS idx_ghost_apps_candidate ON ghost_applications(candidate_id);
CREATE INDEX IF NOT EXISTS idx_ghost_apps_status ON ghost_applications(status);


-- ── 2. Company Verifications (Feature 3) ─────────────────────

CREATE TABLE IF NOT EXISTS company_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  company_name TEXT NOT NULL DEFAULT '',
  level TEXT NOT NULL DEFAULT 'basic' CHECK (level IN ('basic','verified','trusted')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  document_urls JSONB DEFAULT '[]',
  notes TEXT DEFAULT '',
  review_note TEXT DEFAULT '',
  reviewed_by UUID REFERENCES auth.users(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE company_verifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "verif_read_own" ON company_verifications
  FOR SELECT USING (auth.uid() = company_id);

CREATE POLICY "verif_insert_own" ON company_verifications
  FOR INSERT WITH CHECK (auth.uid() = company_id);

-- Cualquier usuario puede ver el nivel de verificación (para badges)
CREATE POLICY "verif_read_public" ON company_verifications
  FOR SELECT USING (status = 'approved');

CREATE INDEX IF NOT EXISTS idx_verif_company ON company_verifications(company_id);
CREATE INDEX IF NOT EXISTS idx_verif_status ON company_verifications(status);


-- ── 3. Soft Skills en Users (Feature 4) ──────────────────────

ALTER TABLE users ADD COLUMN IF NOT EXISTS soft_skills JSONB DEFAULT NULL;


-- ── 4. Pitch Challenges (Feature 6) ─────────────────────────

CREATE TABLE IF NOT EXISTS pitch_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  emoji TEXT DEFAULT '🎯',
  max_duration_seconds INT DEFAULT 30,
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  participant_count INT DEFAULT 0,
  winner_user_id UUID REFERENCES auth.users(id),
  winner_name TEXT,
  prize_description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE pitch_challenges ENABLE ROW LEVEL SECURITY;

-- Todos pueden leer challenges
CREATE POLICY "challenges_read_all" ON pitch_challenges
  FOR SELECT USING (true);

CREATE INDEX IF NOT EXISTS idx_challenges_active ON pitch_challenges(is_active, starts_at, ends_at);


-- ── Challenge Entries ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS challenge_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id UUID NOT NULL REFERENCES pitch_challenges(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  video_url TEXT NOT NULL,
  likes INT DEFAULT 0,
  views INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(challenge_id, user_id)
);

ALTER TABLE challenge_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "entries_read_all" ON challenge_entries
  FOR SELECT USING (true);

CREATE POLICY "entries_insert_own" ON challenge_entries
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_entries_challenge ON challenge_entries(challenge_id);
CREATE INDEX IF NOT EXISTS idx_entries_likes ON challenge_entries(likes DESC);


-- ── RPCs para incrementos atómicos ───────────────────────────

CREATE OR REPLACE FUNCTION increment_challenge_participants(p_challenge_id UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE pitch_challenges
  SET participant_count = participant_count + 1
  WHERE id = p_challenge_id;
END;
$$;

CREATE OR REPLACE FUNCTION increment_challenge_likes(p_entry_id UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE challenge_entries
  SET likes = likes + 1
  WHERE id = p_entry_id;
END;
$$;


-- ── 5. Job Applications table (si no existe) ────────────────

CREATE TABLE IF NOT EXISTS job_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'applied' CHECK (status IN ('applied','reviewed','interview','hired','rejected')),
  video_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(candidate_id, job_id)
);

ALTER TABLE job_applications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "job_apps_candidate_read" ON job_applications
  FOR SELECT USING (auth.uid() = candidate_id);

CREATE POLICY "job_apps_candidate_insert" ON job_applications
  FOR INSERT WITH CHECK (auth.uid() = candidate_id);

CREATE POLICY "job_apps_company_read" ON job_applications
  FOR SELECT USING (
    job_id IN (SELECT id FROM jobs WHERE company_id = auth.uid())
  );


-- ── Seed: Primer Challenge de ejemplo ─────────────────────────

INSERT INTO pitch_challenges (title, description, emoji, max_duration_seconds, starts_at, ends_at)
VALUES (
  'Presentate en 30 segundos',
  '¿Quién sos y qué te hace único? Contalo en 30 seg.',
  '👋',
  30,
  date_trunc('week', now()),
  date_trunc('week', now()) + interval '6 days 23 hours 59 minutes'
) ON CONFLICT DO NOTHING;
