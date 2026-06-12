-- ================================================================
-- MPLOYA — Fix RLS for nexus_signals table
-- Fecha: 2026-04-08
-- Ejecutar en: Supabase Dashboard > SQL Editor > Run
-- ================================================================

-- 1. Habilitar RLS
ALTER TABLE public.nexus_signals ENABLE ROW LEVEL SECURITY;

-- 2. Policy: Los usuarios pueden insertar señales donde ellos son el sender
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'nexus_signals' AND policyname = 'users_insert_own_signals'
  ) THEN
    EXECUTE 'CREATE POLICY "users_insert_own_signals" ON public.nexus_signals FOR INSERT WITH CHECK (auth.uid() = sender_id)';
  END IF;
END $$;

-- 3. Policy: Los usuarios pueden ver señales donde son sender O receiver
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'nexus_signals' AND policyname = 'users_select_own_signals'
  ) THEN
    EXECUTE 'CREATE POLICY "users_select_own_signals" ON public.nexus_signals FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id)';
  END IF;
END $$;

-- 4. Policy: Los usuarios pueden actualizar señales donde son sender (para upsert)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'nexus_signals' AND policyname = 'users_update_own_signals'
  ) THEN
    EXECUTE 'CREATE POLICY "users_update_own_signals" ON public.nexus_signals FOR UPDATE USING (auth.uid() = sender_id OR auth.uid() = receiver_id) WITH CHECK (auth.uid() = sender_id OR auth.uid() = receiver_id)';
  END IF;
END $$;

-- 5. También arreglar permisos del bucket de storage para micro-pitches (si no existe)
-- Ir a Storage > Policies y asegurar que el bucket 'micro-pitches' permita upload autenticado.
-- INSERT INTO storage.buckets (id, name, public) VALUES ('micro-pitches', 'micro-pitches', false) ON CONFLICT (id) DO NOTHING;
