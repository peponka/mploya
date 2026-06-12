-- ═══════════════════════════════════════════════════════════════════════════════
-- Migration: Phase 2 Features
-- Interview Prep, Smart Notifications, Profile Analytics, Referrals,
-- Saved Jobs, Company Reviews, Scheduling
-- Date: 2026-05-14
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─── 1. Saved Jobs ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS saved_jobs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  job_id UUID NOT NULL,
  saved_at TIMESTAMPTZ DEFAULT now(),
  notes TEXT,
  UNIQUE(user_id, job_id)
);

ALTER TABLE saved_jobs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own saved jobs" ON saved_jobs
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE INDEX idx_saved_jobs_user ON saved_jobs(user_id);


-- ─── 2. Company Reviews ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS company_reviews (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  reviewer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  company_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  overall_rating INT NOT NULL CHECK (overall_rating >= 1 AND overall_rating <= 5),
  interview_rating INT CHECK (interview_rating >= 1 AND interview_rating <= 5),
  culture_rating INT CHECK (culture_rating >= 1 AND culture_rating <= 5),
  pros TEXT,
  cons TEXT,
  interview_experience TEXT,
  is_anonymous BOOLEAN DEFAULT true,
  status TEXT DEFAULT 'published',
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(reviewer_id, company_id)
);

ALTER TABLE company_reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users create own reviews" ON company_reviews
  FOR INSERT WITH CHECK (auth.uid() = reviewer_id);
CREATE POLICY "Users read all published reviews" ON company_reviews
  FOR SELECT USING (status = 'published');
CREATE POLICY "Users update own reviews" ON company_reviews
  FOR UPDATE USING (auth.uid() = reviewer_id);

CREATE INDEX idx_company_reviews_company ON company_reviews(company_id);


-- ─── 3. Referral System ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS referral_codes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  code TEXT NOT NULL UNIQUE,
  uses_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS referrals (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  referrer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  referred_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  referral_code TEXT NOT NULL,
  reward_granted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(referred_id)
);

ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own referral code" ON referral_codes
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users read own referrals" ON referrals
  FOR SELECT USING (auth.uid() = referrer_id);

CREATE INDEX idx_referrals_referrer ON referrals(referrer_id);


-- ─── 4. Profile Analytics (daily snapshots) ─────────────────────────────────
CREATE TABLE IF NOT EXISTS profile_analytics (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  views INT DEFAULT 0,
  search_appearances INT DEFAULT 0,
  video_plays INT DEFAULT 0,
  matches INT DEFAULT 0,
  messages_received INT DEFAULT 0,
  UNIQUE(user_id, date)
);

ALTER TABLE profile_analytics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own analytics" ON profile_analytics
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "System inserts analytics" ON profile_analytics
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "System updates analytics" ON profile_analytics
  FOR UPDATE USING (auth.uid() = user_id);

CREATE INDEX idx_profile_analytics_user_date ON profile_analytics(user_id, date DESC);


-- ─── 5. Interview Scheduling ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS interview_slots (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  company_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  slot_date DATE NOT NULL,
  slot_time TIME NOT NULL,
  duration_minutes INT DEFAULT 30,
  is_available BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS scheduled_interviews (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  slot_id UUID REFERENCES interview_slots(id) ON DELETE SET NULL,
  company_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  candidate_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  scheduled_date DATE NOT NULL,
  scheduled_time TIME NOT NULL,
  duration_minutes INT DEFAULT 30,
  status TEXT DEFAULT 'pending',
  meeting_url TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(company_id, candidate_id, scheduled_date, scheduled_time)
);

ALTER TABLE interview_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_interviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Companies manage own slots" ON interview_slots
  FOR ALL USING (auth.uid() = company_id) WITH CHECK (auth.uid() = company_id);
CREATE POLICY "Anyone can see available slots" ON interview_slots
  FOR SELECT USING (is_available = true);

CREATE POLICY "Participants see own interviews" ON scheduled_interviews
  FOR SELECT USING (auth.uid() = company_id OR auth.uid() = candidate_id);
CREATE POLICY "Companies create interviews" ON scheduled_interviews
  FOR INSERT WITH CHECK (auth.uid() = company_id);
CREATE POLICY "Participants update interviews" ON scheduled_interviews
  FOR UPDATE USING (auth.uid() = company_id OR auth.uid() = candidate_id);

CREATE INDEX idx_interview_slots_company ON interview_slots(company_id, slot_date);
CREATE INDEX idx_scheduled_interviews_candidate ON scheduled_interviews(candidate_id);
CREATE INDEX idx_scheduled_interviews_company ON scheduled_interviews(company_id);


-- ─── 6. Notification Digests ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notification_digests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  digest_type TEXT NOT NULL DEFAULT 'weekly',
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB DEFAULT '{}',
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE notification_digests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own digests" ON notification_digests
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE INDEX idx_notification_digests_user ON notification_digests(user_id, created_at DESC);


-- ─── 7. Helper: Increment profile analytics ─────────────────────────────────
CREATE OR REPLACE FUNCTION increment_profile_stat(
  p_user_id UUID,
  p_field TEXT
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO profile_analytics (user_id, date)
  VALUES (p_user_id, CURRENT_DATE)
  ON CONFLICT (user_id, date) DO NOTHING;

  EXECUTE format(
    'UPDATE profile_analytics SET %I = %I + 1 WHERE user_id = $1 AND date = CURRENT_DATE',
    p_field, p_field
  ) USING p_user_id;
END;
$$;
