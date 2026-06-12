-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Phase 3 Features — Reposts + Subtitles
-- Date: 2026-05-14
-- Features:
--   1. social_reposts table for internal repost functionality
--   2. Indexes and RLS for reposts
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. Social Reposts Table ──
CREATE TABLE IF NOT EXISTS social_reposts (
  id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reposted_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at    timestamptz DEFAULT now(),
  UNIQUE(user_id, reposted_user_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_reposts_user ON social_reposts(user_id);
CREATE INDEX IF NOT EXISTS idx_reposts_target ON social_reposts(reposted_user_id);

-- RLS
ALTER TABLE social_reposts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all reposts"
  ON social_reposts FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own reposts"
  ON social_reposts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own reposts"
  ON social_reposts FOR DELETE
  USING (auth.uid() = user_id);

-- ── 2. Ensure ai_transcript_json column exists ──
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND column_name = 'ai_transcript_json'
  ) THEN
    ALTER TABLE users ADD COLUMN ai_transcript_json jsonb DEFAULT '[]'::jsonb;
  END IF;
END $$;

-- ── 3. Personality scores column for IA analysis ──
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND column_name = 'personality_scores'
  ) THEN
    ALTER TABLE users ADD COLUMN personality_scores jsonb DEFAULT NULL;
  END IF;
END $$;
