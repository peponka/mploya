-- ═══════════════════════════════════════════════════════════════════════════════
-- Mploya — Complete SQL Schema (Supabase PostgreSQL)
-- Generated: 2026-05-19
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── CORE TABLES ─────────────────────────────────────────────────────────────

-- Users: Main profile table (candidates + companies)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT auth.uid(),
  name TEXT NOT NULL DEFAULT '',
  headline TEXT NOT NULL DEFAULT '',
  avatar_url TEXT,
  video_url TEXT,
  account_type TEXT NOT NULL DEFAULT 'candidato'
    CHECK (account_type IN ('candidato', 'empresa', 'headhunter', 'confidencial', 'stealth')),
  skills TEXT[] DEFAULT '{}',
  tags TEXT[] DEFAULT '{}',
  experience JSONB DEFAULT '[]'::jsonb,
  education JSONB DEFAULT '[]'::jsonb,
  location TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  is_premium BOOLEAN DEFAULT FALSE,
  is_verified BOOLEAN DEFAULT FALSE,
  is_open_to_work BOOLEAN DEFAULT FALSE,
  is_hiring BOOLEAN DEFAULT FALSE,
  connections INT DEFAULT 0,
  profile_views INT DEFAULT 0,
  match_percentage DOUBLE PRECISION DEFAULT 0,
  profile_completion INT DEFAULT 0,
  bio TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Connections: Bi-directional connection requests
CREATE TABLE IF NOT EXISTS connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  addressee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (requester_id, addressee_id)
);

-- Messages: Real-time chat
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  text TEXT NOT NULL DEFAULT '',
  is_read BOOLEAN DEFAULT FALSE,
  file_url TEXT,
  file_name TEXT,
  file_type TEXT,
  file_size_bytes INT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Posts: Feed content (video posts)
CREATE TABLE IF NOT EXISTS posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  video_url TEXT NOT NULL,
  caption TEXT DEFAULT '',
  hashtags TEXT[] DEFAULT '{}',
  likes_count INT DEFAULT 0,
  comments_count INT DEFAULT 0,
  shares_count INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── SOCIAL FEATURES ─────────────────────────────────────────────────────────

-- Nexus Signals: Interest signals (likes, micro-pitches)
CREATE TABLE IF NOT EXISTS nexus_signals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  signal_type TEXT NOT NULL DEFAULT 'interest'
    CHECK (signal_type IN ('interest', 'micro_pitch', 'super_like')),
  message TEXT,
  video_url TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (sender_id, receiver_id, signal_type)
);

-- Stories: Ephemeral stories (24h)
CREATE TABLE IF NOT EXISTS stories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  media_url TEXT NOT NULL,
  media_type TEXT DEFAULT 'video' CHECK (media_type IN ('image', 'video')),
  caption TEXT,
  views_count INT DEFAULT 0,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '24 hours'),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Saved Items: Bookmarked profiles/jobs
CREATE TABLE IF NOT EXISTS saved_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  saved_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  saved_job_id UUID,
  item_type TEXT NOT NULL CHECK (item_type IN ('user', 'job')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, saved_user_id),
  UNIQUE (user_id, saved_job_id)
);

-- ── PORTFOLIO & RATINGS ─────────────────────────────────────────────────────

-- Portfolio Videos: User portfolio items (up to 3)
CREATE TABLE IF NOT EXISTS portfolio_videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  description TEXT DEFAULT '',
  video_url TEXT NOT NULL,
  thumbnail_url TEXT,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Employer Reviews: Company ratings (4 categories)
CREATE TABLE IF NOT EXISTS employer_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reviewer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  overall_rating DOUBLE PRECISION NOT NULL CHECK (overall_rating >= 1 AND overall_rating <= 5),
  communication_rating DOUBLE PRECISION CHECK (communication_rating >= 1 AND communication_rating <= 5),
  transparency_rating DOUBLE PRECISION CHECK (transparency_rating >= 1 AND transparency_rating <= 5),
  respect_rating DOUBLE PRECISION CHECK (respect_rating >= 1 AND respect_rating <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (company_id, reviewer_id)
);

-- ── SAFETY & MODERATION ─────────────────────────────────────────────────────

-- Blocked Users
CREATE TABLE IF NOT EXISTS blocked_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (blocker_id, blocked_id)
);

-- User Reports
CREATE TABLE IF NOT EXISTS user_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reported_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  details TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── NOTIFICATIONS ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  data JSONB DEFAULT '{}'::jsonb,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── REFERRALS ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS referral_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code TEXT NOT NULL UNIQUE,
  uses_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  referred_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  referral_code TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (referred_id)
);

-- ── SAVED JOBS ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS saved_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  job_id TEXT NOT NULL,
  saved_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, job_id)
);

-- ── PROFILE VIEWS ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS profile_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  viewer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  viewed_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ DEFAULT now()
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- RPC FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Nearby users with Haversine formula (no PostGIS needed)
CREATE OR REPLACE FUNCTION get_nearby_users(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  radius_km DOUBLE PRECISION DEFAULT 50,
  max_results INT DEFAULT 50,
  caller_type TEXT DEFAULT 'candidato'
)
RETURNS TABLE (
  id UUID, name TEXT, headline TEXT, video_url TEXT,
  account_type TEXT, latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION, distance_km DOUBLE PRECISION
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT * FROM (
    SELECT
      u.id, u.name, u.headline, u.video_url, u.account_type,
      u.latitude, u.longitude,
      (6371 * acos(LEAST(1.0,
        cos(radians(user_lat)) * cos(radians(u.latitude))
        * cos(radians(u.longitude) - radians(user_lng))
        + sin(radians(user_lat)) * sin(radians(u.latitude))
      ))) AS distance_km
    FROM users u
    WHERE u.id != auth.uid()
      AND u.latitude IS NOT NULL
      AND u.longitude IS NOT NULL
      AND (
        (caller_type = 'empresa' AND u.account_type != 'empresa')
        OR (caller_type != 'empresa' AND u.account_type = 'empresa')
      )
  ) sub
  WHERE distance_km <= radius_km
  ORDER BY distance_km ASC
  LIMIT max_results;
$$;

-- Connection status check
CREATE OR REPLACE FUNCTION get_connection_status(p_other_user_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  conn RECORD;
BEGIN
  SELECT * INTO conn FROM connections
  WHERE (requester_id = auth.uid() AND addressee_id = p_other_user_id)
     OR (requester_id = p_other_user_id AND addressee_id = auth.uid());
  IF NOT FOUND THEN RETURN json_build_object('status', 'none');
  END IF;
  RETURN json_build_object('status', conn.status);
END;
$$;

-- Send connection request
CREATE OR REPLACE FUNCTION send_connection_request(p_addressee_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO connections (requester_id, addressee_id, status)
  VALUES (auth.uid(), p_addressee_id, 'pending')
  ON CONFLICT (requester_id, addressee_id) DO NOTHING;
  RETURN json_build_object('status', 'pending');
END;
$$;

-- Block user (atomic: inserts block + deletes connection)
CREATE OR REPLACE FUNCTION block_user(p_blocked_id UUID, p_reason TEXT DEFAULT NULL)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO blocked_users (blocker_id, blocked_id, reason)
  VALUES (auth.uid(), p_blocked_id, p_reason)
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;
  DELETE FROM connections WHERE
    (requester_id = auth.uid() AND addressee_id = p_blocked_id) OR
    (requester_id = p_blocked_id AND addressee_id = auth.uid());
  RETURN json_build_object('ok', true);
END;
$$;

-- Unblock user
CREATE OR REPLACE FUNCTION unblock_user(p_blocked_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM blocked_users
  WHERE blocker_id = auth.uid() AND blocked_id = p_blocked_id;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- PERFORMANCE INDEXES
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_users_account_type ON users(account_type);
CREATE INDEX IF NOT EXISTS idx_users_location ON users(latitude, longitude) WHERE latitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_connections_requester ON connections(requester_id, status);
CREATE INDEX IF NOT EXISTS idx_connections_addressee ON connections(addressee_id, status);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(sender_id, receiver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_user ON posts(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_nexus_signals_receiver ON nexus_signals(receiver_id, is_read);
CREATE INDEX IF NOT EXISTS idx_stories_user ON stories(user_id, expires_at);
CREATE INDEX IF NOT EXISTS idx_saved_items_user ON saved_items(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker ON blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_videos_user ON portfolio_videos(user_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_employer_reviews_company ON employer_reviews(company_id);
CREATE INDEX IF NOT EXISTS idx_profile_views_viewed ON profile_views(viewed_id, viewed_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════════════════════════════

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Users: read all, update own
CREATE POLICY users_select ON users FOR SELECT USING (true);
CREATE POLICY users_update ON users FOR UPDATE USING (auth.uid() = id);

-- Connections: only see own
CREATE POLICY connections_select ON connections FOR SELECT
  USING (auth.uid() = requester_id OR auth.uid() = addressee_id);
CREATE POLICY connections_insert ON connections FOR INSERT
  WITH CHECK (auth.uid() = requester_id);

-- Messages: only see own conversations
CREATE POLICY messages_select ON messages FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
CREATE POLICY messages_insert ON messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

-- Blocked users: only own blocks
CREATE POLICY blocked_select ON blocked_users FOR SELECT
  USING (auth.uid() = blocker_id);
CREATE POLICY blocked_insert ON blocked_users FOR INSERT
  WITH CHECK (auth.uid() = blocker_id);

-- Notifications: only own
CREATE POLICY notifications_select ON notifications FOR SELECT
  USING (auth.uid() = user_id);
