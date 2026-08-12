-- =============================================================================
-- Migración 014: Habilitar RLS en todas las tablas del esquema public
-- =============================================================================
-- Soluciona la alerta de Supabase: "Table publicly accessible (rls_disabled_in_public)"
--
-- Ejecutar en: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- =============================================================================

-- 1. Habilitar RLS de forma dinámica en TODAS las tablas creadas por el usuario en 'public'
-- Excluye tablas del sistema como 'spatial_ref_sys' (PostGIS)
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT tablename 
    FROM pg_tables 
    WHERE schemaname = 'public' 
      AND tablename NOT IN ('spatial_ref_sys')
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', r.tablename);
  END LOOP;
END $$;

-- 2. Asegurar políticas básicas en las tablas principales de Mploya / Nexowork / RiverHub

-- ─── TABLA: users ───────────────────────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'users') THEN
    DROP POLICY IF EXISTS "users_select_authenticated" ON public.users;
    CREATE POLICY "users_select_authenticated" ON public.users FOR SELECT TO authenticated USING (true);

    DROP POLICY IF EXISTS "users_update_own" ON public.users;
    CREATE POLICY "users_update_own" ON public.users FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

    DROP POLICY IF EXISTS "users_insert_own" ON public.users;
    CREATE POLICY "users_insert_own" ON public.users FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
  END IF;
END $$;

-- ─── TABLA: profiles ────────────────────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'profiles') THEN
    ALTER TABLE public.profiles NO FORCE ROW LEVEL SECURITY; -- Permite triggers de creación
    
    DROP POLICY IF EXISTS "profiles_select_authenticated" ON public.profiles;
    CREATE POLICY "profiles_select_authenticated" ON public.profiles FOR SELECT TO authenticated USING (true);

    DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
    CREATE POLICY "profiles_insert_own" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

    DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
    CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

    DROP POLICY IF EXISTS "profiles_delete_own" ON public.profiles;
    CREATE POLICY "profiles_delete_own" ON public.profiles FOR DELETE TO authenticated USING (auth.uid() = id);
  END IF;
END $$;

-- ─── TABLA: connections ─────────────────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'connections') THEN
    DROP POLICY IF EXISTS "connections_select" ON public.connections;
    CREATE POLICY "connections_select" ON public.connections FOR SELECT TO authenticated USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

    DROP POLICY IF EXISTS "connections_insert" ON public.connections;
    CREATE POLICY "connections_insert" ON public.connections FOR INSERT TO authenticated WITH CHECK (auth.uid() = requester_id);

    DROP POLICY IF EXISTS "connections_update" ON public.connections;
    CREATE POLICY "connections_update" ON public.connections FOR UPDATE TO authenticated USING (auth.uid() = requester_id OR auth.uid() = addressee_id);
  END IF;
END $$;

-- ─── TABLA: jobs ────────────────────────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'jobs') THEN
    DROP POLICY IF EXISTS "jobs_select_authenticated" ON public.jobs;
    CREATE POLICY "jobs_select_authenticated" ON public.jobs FOR SELECT TO authenticated USING (true);

    DROP POLICY IF EXISTS "jobs_insert_company" ON public.jobs;
    CREATE POLICY "jobs_insert_company" ON public.jobs FOR INSERT TO authenticated WITH CHECK (auth.uid() = company_id);

    DROP POLICY IF EXISTS "jobs_update_company" ON public.jobs;
    CREATE POLICY "jobs_update_company" ON public.jobs FOR UPDATE TO authenticated USING (auth.uid() = company_id);
  END IF;
END $$;

-- ─── TABLA: job_applications ────────────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'job_applications') THEN
    DROP POLICY IF EXISTS "applications_select" ON public.job_applications;
    CREATE POLICY "applications_select" ON public.job_applications FOR SELECT TO authenticated USING (auth.uid() = candidate_id OR EXISTS (SELECT 1 FROM public.jobs WHERE jobs.id = job_applications.job_id AND jobs.company_id = auth.uid()));

    DROP POLICY IF EXISTS "applications_insert" ON public.job_applications;
    CREATE POLICY "applications_insert" ON public.job_applications FOR INSERT TO authenticated WITH CHECK (auth.uid() = candidate_id);

    DROP POLICY IF EXISTS "applications_update" ON public.job_applications;
    CREATE POLICY "applications_update" ON public.job_applications FOR UPDATE TO authenticated USING (auth.uid() = candidate_id OR EXISTS (SELECT 1 FROM public.jobs WHERE jobs.id = job_applications.job_id AND jobs.company_id = auth.uid()));
  END IF;
END $$;

-- ─── TABLA: messages ────────────────────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'messages') THEN
    DROP POLICY IF EXISTS "messages_select" ON public.messages;
    CREATE POLICY "messages_select" ON public.messages FOR SELECT TO authenticated USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

    DROP POLICY IF EXISTS "messages_insert" ON public.messages;
    CREATE POLICY "messages_insert" ON public.messages FOR INSERT TO authenticated WITH CHECK (auth.uid() = sender_id);
  END IF;
END $$;

-- ─── TABLA: notifications ───────────────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'notifications') THEN
    DROP POLICY IF EXISTS "notifications_select_own" ON public.notifications;
    CREATE POLICY "notifications_select_own" ON public.notifications FOR SELECT TO authenticated USING (auth.uid() = user_id);

    DROP POLICY IF EXISTS "notifications_update_own" ON public.notifications;
    CREATE POLICY "notifications_update_own" ON public.notifications FOR UPDATE TO authenticated USING (auth.uid() = user_id);
  END IF;
END $$;
