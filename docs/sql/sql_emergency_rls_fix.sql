-- ============================================================================
-- 🚨 EMERGENCIA: Habilitar RLS en TODAS las tablas públicas — Mploya/Nexwork
-- Fecha: 6 Mayo 2026 (v2 — columnas corregidas del schema real)
-- 
-- EJECUTAR EN: Supabase Dashboard → SQL Editor → New query → Run
-- PROYECTO: nexowork
-- ============================================================================

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  PASO 1: HABILITAR RLS EN TODAS LAS TABLAS                            ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.pitch_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.job_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.saved_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.pitch_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.nexus_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.profile_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.pitch_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.company_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.profile_unlocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.portfolio_videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.employer_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.ghost_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.company_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.pitch_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.challenge_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.content_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.fcm_tokens ENABLE ROW LEVEL SECURITY;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  PASO 2: POLÍTICAS RLS PARA CADA TABLA                                ║
-- ║  Columnas verificadas contra schema.sql y 20260331_full_schema_v2.sql  ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- ─── users (id = auth.uid()) ────────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='users' AND policyname='rls_users_select') THEN
    CREATE POLICY "rls_users_select" ON public.users FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='users' AND policyname='rls_users_update') THEN
    CREATE POLICY "rls_users_update" ON public.users FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='users' AND policyname='rls_users_insert') THEN
    CREATE POLICY "rls_users_insert" ON public.users FOR INSERT WITH CHECK (auth.uid() = id);
  END IF;
END $$;

-- ─── connections (requester_id, addressee_id) ───────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='connections' AND policyname='rls_conn_select') THEN
    CREATE POLICY "rls_conn_select" ON public.connections FOR SELECT USING (auth.uid() IN (requester_id, addressee_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='connections' AND policyname='rls_conn_insert') THEN
    CREATE POLICY "rls_conn_insert" ON public.connections FOR INSERT WITH CHECK (auth.uid() = requester_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='connections' AND policyname='rls_conn_update') THEN
    CREATE POLICY "rls_conn_update" ON public.connections FOR UPDATE USING (auth.uid() IN (requester_id, addressee_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='connections' AND policyname='rls_conn_delete') THEN
    CREATE POLICY "rls_conn_delete" ON public.connections FOR DELETE USING (auth.uid() IN (requester_id, addressee_id));
  END IF;
END $$;

-- ─── messages (sender_id, receiver_id) ──────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='messages' AND policyname='rls_msg_select') THEN
    CREATE POLICY "rls_msg_select" ON public.messages FOR SELECT USING (auth.uid() IN (sender_id, receiver_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='messages' AND policyname='rls_msg_insert') THEN
    CREATE POLICY "rls_msg_insert" ON public.messages FOR INSERT WITH CHECK (auth.uid() = sender_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='messages' AND policyname='rls_msg_update') THEN
    CREATE POLICY "rls_msg_update" ON public.messages FOR UPDATE USING (auth.uid() IN (sender_id, receiver_id));
  END IF;
END $$;

-- ─── notifications (user_id) ───────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='notifications' AND policyname='rls_notif_all') THEN
    CREATE POLICY "rls_notif_all" ON public.notifications FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- ─── pitch_likes (liker_id, pitch_owner_id) ─────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='pitch_likes' AND policyname='rls_pl_select') THEN
    CREATE POLICY "rls_pl_select" ON public.pitch_likes FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='pitch_likes' AND policyname='rls_pl_insert') THEN
    CREATE POLICY "rls_pl_insert" ON public.pitch_likes FOR INSERT WITH CHECK (auth.uid() = liker_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='pitch_likes' AND policyname='rls_pl_delete') THEN
    CREATE POLICY "rls_pl_delete" ON public.pitch_likes FOR DELETE USING (auth.uid() = liker_id);
  END IF;
END $$;

-- ─── user_ratings (rater_id, target_id) ─────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='user_ratings' AND policyname='rls_ur_select') THEN
    CREATE POLICY "rls_ur_select" ON public.user_ratings FOR SELECT USING (auth.uid() IN (rater_id, target_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='user_ratings' AND policyname='rls_ur_insert') THEN
    CREATE POLICY "rls_ur_insert" ON public.user_ratings FOR INSERT WITH CHECK (auth.uid() = rater_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='user_ratings' AND policyname='rls_ur_update') THEN
    CREATE POLICY "rls_ur_update" ON public.user_ratings FOR UPDATE USING (auth.uid() = rater_id);
  END IF;
END $$;

-- ─── jobs (company_id) ─────────────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='jobs' AND policyname='rls_jobs_select') THEN
    CREATE POLICY "rls_jobs_select" ON public.jobs FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='jobs' AND policyname='rls_jobs_insert') THEN
    CREATE POLICY "rls_jobs_insert" ON public.jobs FOR INSERT WITH CHECK (auth.uid() = company_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='jobs' AND policyname='rls_jobs_update') THEN
    CREATE POLICY "rls_jobs_update" ON public.jobs FOR UPDATE USING (auth.uid() = company_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='jobs' AND policyname='rls_jobs_delete') THEN
    CREATE POLICY "rls_jobs_delete" ON public.jobs FOR DELETE USING (auth.uid() = company_id);
  END IF;
END $$;

-- ─── job_applications (candidate_id) ────────────────────────────────────────
-- candidate_id puede postularse; el employer del job puede ver/actualizar
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='job_applications' AND policyname='rls_ja_select') THEN
    CREATE POLICY "rls_ja_select" ON public.job_applications FOR SELECT USING (
      auth.uid() = candidate_id OR
      auth.uid() IN (SELECT company_id FROM public.jobs WHERE id = job_id)
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='job_applications' AND policyname='rls_ja_insert') THEN
    CREATE POLICY "rls_ja_insert" ON public.job_applications FOR INSERT WITH CHECK (auth.uid() = candidate_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='job_applications' AND policyname='rls_ja_update') THEN
    CREATE POLICY "rls_ja_update" ON public.job_applications FOR UPDATE USING (
      auth.uid() = candidate_id OR
      auth.uid() IN (SELECT company_id FROM public.jobs WHERE id = job_id)
    );
  END IF;
END $$;

-- ─── posts (user_id) ───────────────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='posts' AND policyname='rls_posts_select') THEN
    CREATE POLICY "rls_posts_select" ON public.posts FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='posts' AND policyname='rls_posts_manage') THEN
    CREATE POLICY "rls_posts_manage" ON public.posts FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- ─── saved_profiles (user_id) ──────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='saved_profiles' AND policyname='rls_saved_all') THEN
    CREATE POLICY "rls_saved_all" ON public.saved_profiles FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- ─── pitch_reactions (user_id) ─────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='pitch_reactions' AND policyname='rls_pr_select') THEN
    CREATE POLICY "rls_pr_select" ON public.pitch_reactions FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='pitch_reactions' AND policyname='rls_pr_manage') THEN
    CREATE POLICY "rls_pr_manage" ON public.pitch_reactions FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- ─── user_blocks (blocker_id) ──────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='user_blocks' AND policyname='rls_blocks_all') THEN
    CREATE POLICY "rls_blocks_all" ON public.user_blocks FOR ALL USING (auth.uid() = blocker_id) WITH CHECK (auth.uid() = blocker_id);
  END IF;
END $$;

-- ─── stories (user_id) ────────────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='stories' AND policyname='rls_stories_select') THEN
    CREATE POLICY "rls_stories_select" ON public.stories FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='stories' AND policyname='rls_stories_manage') THEN
    CREATE POLICY "rls_stories_manage" ON public.stories FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- ─── nexus_signals (sender_id, receiver_id) ─────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='nexus_signals' AND policyname='rls_nexus_select') THEN
    CREATE POLICY "rls_nexus_select" ON public.nexus_signals FOR SELECT USING (auth.uid() IN (sender_id, receiver_id));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='nexus_signals' AND policyname='rls_nexus_insert') THEN
    CREATE POLICY "rls_nexus_insert" ON public.nexus_signals FOR INSERT WITH CHECK (auth.uid() = sender_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='nexus_signals' AND policyname='rls_nexus_update') THEN
    CREATE POLICY "rls_nexus_update" ON public.nexus_signals FOR UPDATE USING (auth.uid() IN (sender_id, receiver_id));
  END IF;
END $$;

-- ─── profile_views (viewer_id, viewed_id) ──────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='profile_views' AND policyname='rls_pv_all') THEN
    CREATE POLICY "rls_pv_all" ON public.profile_views FOR ALL USING (auth.uid() = viewer_id OR auth.uid() = viewed_id) WITH CHECK (auth.uid() = viewer_id);
  END IF;
END $$;

-- ─── pitch_comments (author_id) ────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='pitch_comments' AND policyname='rls_pc_select') THEN
    CREATE POLICY "rls_pc_select" ON public.pitch_comments FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='pitch_comments' AND policyname='rls_pc_manage') THEN
    CREATE POLICY "rls_pc_manage" ON public.pitch_comments FOR ALL USING (auth.uid() = author_id) WITH CHECK (auth.uid() = author_id);
  END IF;
END $$;

-- ─── company_wallets (company_id) ──────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='company_wallets' AND policyname='rls_cw_select') THEN
    CREATE POLICY "rls_cw_select" ON public.company_wallets FOR SELECT USING (auth.uid() = company_id);
  END IF;
END $$;

-- ─── profile_unlocks (company_id, candidate_id) ────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='profile_unlocks' AND policyname='rls_pu_company') THEN
    CREATE POLICY "rls_pu_company" ON public.profile_unlocks FOR SELECT USING (auth.uid() = company_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='profile_unlocks' AND policyname='rls_pu_candidate') THEN
    CREATE POLICY "rls_pu_candidate" ON public.profile_unlocks FOR SELECT USING (auth.uid() = candidate_id);
  END IF;
END $$;

-- ─── portfolio_videos (user_id) ────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='portfolio_videos' AND policyname='rls_pv2_select') THEN
    CREATE POLICY "rls_pv2_select" ON public.portfolio_videos FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='portfolio_videos' AND policyname='rls_pv2_manage') THEN
    CREATE POLICY "rls_pv2_manage" ON public.portfolio_videos FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- ─── employer_reviews (candidate_id, company_id) ───────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='employer_reviews' AND policyname='rls_er_select') THEN
    CREATE POLICY "rls_er_select" ON public.employer_reviews FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='employer_reviews' AND policyname='rls_er_manage') THEN
    CREATE POLICY "rls_er_manage" ON public.employer_reviews FOR ALL USING (auth.uid() = candidate_id) WITH CHECK (auth.uid() = candidate_id);
  END IF;
END $$;

-- ─── ghost_applications (candidate_id) ─────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ghost_applications' AND policyname='rls_ga_all') THEN
    CREATE POLICY "rls_ga_all" ON public.ghost_applications FOR ALL USING (auth.uid() = candidate_id) WITH CHECK (auth.uid() = candidate_id);
  END IF;
END $$;

-- ─── company_verifications (company_id) ────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='company_verifications' AND policyname='rls_cv_all') THEN
    CREATE POLICY "rls_cv_all" ON public.company_verifications FOR ALL USING (auth.uid() = company_id) WITH CHECK (auth.uid() = company_id);
  END IF;
END $$;

-- ─── pitch_challenges (no owner — admin/system content, read-only) ──────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='pitch_challenges' AND policyname='rls_pch_select') THEN
    CREATE POLICY "rls_pch_select" ON public.pitch_challenges FOR SELECT USING (true);
  END IF;
END $$;

-- ─── challenge_entries (user_id) ───────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='challenge_entries' AND policyname='rls_ce_select') THEN
    CREATE POLICY "rls_ce_select" ON public.challenge_entries FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='challenge_entries' AND policyname='rls_ce_manage') THEN
    CREATE POLICY "rls_ce_manage" ON public.challenge_entries FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  PASO 3: VERIFICACIÓN                                                  ║
-- ║  Ejecutar después — debería devolver 0 filas                           ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND rowsecurity = false
ORDER BY tablename;
