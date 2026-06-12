-- ============================================================================
-- 🚨 EMERGENCIA RLS: RiverHub-DB (nfybmqpdrvyxucgpqqmo)
-- Fecha: 6 Mayo 2026
-- Patrón: Multitenancy por company_id
-- 
-- EJECUTAR EN: Supabase Dashboard → SQL Editor → New query → Run
-- ============================================================================

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  PASO 1: HABILITAR RLS EN TODAS LAS TABLAS PÚBLICAS (loop dinámico)   ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

DO $$
DECLARE
    tbl RECORD;
    fixed INTEGER := 0;
BEGIN
    FOR tbl IN 
        SELECT tablename
        FROM pg_tables 
        WHERE schemaname = 'public' 
          AND rowsecurity = false
          AND tablename NOT IN ('spatial_ref_sys', 'geometry_columns', 'geography_columns')
        ORDER BY tablename
    LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tbl.tablename);
        fixed := fixed + 1;
        RAISE NOTICE 'RLS habilitado → %', tbl.tablename;
    END LOOP;
    RAISE NOTICE '✅ Total tablas corregidas: %', fixed;
END $$;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  PASO 2: POLÍTICAS POR TABLA (multitenancy company_id)                ║
-- ║  Patrón: user pertenece a company → ve data de su company             ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Helper: get_my_company_id() — ya existe en la DB, no recrear
-- (tiene policies dependientes en vessels, voyages, logs, crew, etc.)

-- ─── profiles ───────────────────────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='profiles' AND policyname='rls_profiles_select') THEN
    CREATE POLICY "rls_profiles_select" ON public.profiles FOR SELECT USING (id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='profiles' AND policyname='rls_profiles_update') THEN
    CREATE POLICY "rls_profiles_update" ON public.profiles FOR UPDATE USING (id = auth.uid());
  END IF;
END $$;

-- ─── user_profiles ──────────────────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='user_profiles' AND policyname='rls_up_select') THEN
    CREATE POLICY "rls_up_select" ON public.user_profiles FOR SELECT USING (
      user_id = auth.uid() 
      OR company_id = public.get_my_company_id()
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='user_profiles' AND policyname='rls_up_update') THEN
    CREATE POLICY "rls_up_update" ON public.user_profiles FOR UPDATE USING (user_id = auth.uid());
  END IF;
END $$;

-- ─── Tablas operativas con company_id (patrón tenant isolation) ─────────────
-- Todas usan el mismo patrón: SELECT/INSERT/UPDATE filtrado por company_id

DO $$
DECLARE
  tbl TEXT;
  tables TEXT[] := ARRAY[
    'vessels', 'crew_members', 'clients', 'voyages', 'convoys',
    'fuel_logs', 'maintenance_tasks', 'spare_parts', 'logbook_entries',
    'quotations', 'comms', 'incidents', 'documents', 'daily_reports',
    'inventory_items', 'inventory_movements', 'service_orders',
    'cargo_manifests', 'geofences', 'safety_rules', 'alerts',
    'logs', 'audit_log', 'fleet_assets', 'crew'
  ];
BEGIN
  FOREACH tbl IN ARRAY tables LOOP
    -- Verificar que la tabla existe y tiene company_id
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = tbl AND column_name = 'company_id'
    ) THEN
      -- SELECT: solo data de mi company
      IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = tbl AND policyname = 'rls_tenant_select') THEN
        EXECUTE format(
          'CREATE POLICY "rls_tenant_select" ON public.%I FOR SELECT USING (company_id::text = public.get_my_company_id()::text)',
          tbl
        );
      END IF;
      -- INSERT: solo para mi company
      IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = tbl AND policyname = 'rls_tenant_insert') THEN
        EXECUTE format(
          'CREATE POLICY "rls_tenant_insert" ON public.%I FOR INSERT WITH CHECK (company_id::text = public.get_my_company_id()::text)',
          tbl
        );
      END IF;
      -- UPDATE: solo data de mi company
      IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = tbl AND policyname = 'rls_tenant_update') THEN
        EXECUTE format(
          'CREATE POLICY "rls_tenant_update" ON public.%I FOR UPDATE USING (company_id::text = public.get_my_company_id()::text)',
          tbl
        );
      END IF;
      -- DELETE: solo data de mi company
      IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = tbl AND policyname = 'rls_tenant_delete') THEN
        EXECUTE format(
          'CREATE POLICY "rls_tenant_delete" ON public.%I FOR DELETE USING (company_id::text = public.get_my_company_id()::text)',
          tbl
        );
      END IF;
      RAISE NOTICE '✅ Policies creadas para %', tbl;
    ELSE
      RAISE NOTICE '⏭️ Tabla % no existe o no tiene company_id — omitida', tbl;
    END IF;
  END LOOP;
END $$;

-- ─── companies (solo superadmin escribe, todos leen) ────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='companies' AND policyname='rls_companies_select') THEN
    CREATE POLICY "rls_companies_select" ON public.companies FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='companies' AND policyname='rls_companies_admin') THEN
    CREATE POLICY "rls_companies_admin" ON public.companies FOR ALL USING (
      EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role = 'superadmin')
    ) WITH CHECK (
      EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role = 'superadmin')
    );
  END IF;
END $$;

-- ─── subscriptions (company-scoped) ─────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'subscriptions') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='subscriptions' AND policyname='rls_subs_select') THEN
      CREATE POLICY "rls_subs_select" ON public.subscriptions FOR SELECT USING (
        company_id::text = public.get_my_company_id()
        OR EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role = 'superadmin')
      );
    END IF;
  END IF;
END $$;

-- ─── payments (company-scoped) ──────────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'payments') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='payments' AND policyname='rls_pay_select') THEN
      CREATE POLICY "rls_pay_select" ON public.payments FOR SELECT USING (
        company_id::text = public.get_my_company_id()
        OR EXISTS (SELECT 1 FROM public.user_profiles WHERE user_id = auth.uid() AND role = 'superadmin')
      );
    END IF;
  END IF;
END $$;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  PASO 3: VERIFICACIÓN — Debe devolver 0 filas                         ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND rowsecurity = false
  AND tablename NOT IN ('spatial_ref_sys', 'geometry_columns', 'geography_columns')
ORDER BY tablename;
