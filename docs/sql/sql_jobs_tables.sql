-- ═══════════════════════════════════════════════════════════
-- PARCHE: Agregar columnas faltantes a tabla jobs existente
-- ═══════════════════════════════════════════════════════════

-- Agregar columnas que no existen (IF NOT EXISTS no es soportado para columnas,
-- pero ALTER TABLE ADD COLUMN con IF NOT EXISTS sí en PostgreSQL 9.6+)
DO $$
BEGIN
  -- modality
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='jobs' AND column_name='modality') THEN
    ALTER TABLE public.jobs ADD COLUMN modality TEXT DEFAULT 'remote' CHECK (modality IN ('remote', 'hybrid', 'onsite'));
  END IF;

  -- seniority
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='jobs' AND column_name='seniority') THEN
    ALTER TABLE public.jobs ADD COLUMN seniority TEXT DEFAULT 'mid' CHECK (seniority IN ('junior', 'mid', 'senior', 'lead', 'clevel'));
  END IF;

  -- is_active
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='jobs' AND column_name='is_active') THEN
    ALTER TABLE public.jobs ADD COLUMN is_active BOOLEAN DEFAULT true;
  END IF;

  -- applicants_count
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='jobs' AND column_name='applicants_count') THEN
    ALTER TABLE public.jobs ADD COLUMN applicants_count INT DEFAULT 0;
  END IF;

  -- description
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='jobs' AND column_name='description') THEN
    ALTER TABLE public.jobs ADD COLUMN description TEXT;
  END IF;

  -- updated_at
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='jobs' AND column_name='updated_at') THEN
    ALTER TABLE public.jobs ADD COLUMN updated_at TIMESTAMPTZ DEFAULT now();
  END IF;
END $$;

-- Índices
CREATE INDEX IF NOT EXISTS idx_jobs_company ON public.jobs(company_id);
CREATE INDEX IF NOT EXISTS idx_jobs_active ON public.jobs(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_jobs_seniority ON public.jobs(seniority);
CREATE INDEX IF NOT EXISTS idx_jobs_modality ON public.jobs(modality);

-- RLS
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "jobs_read_active" ON public.jobs;
CREATE POLICY "jobs_read_active" ON public.jobs
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "jobs_insert_own" ON public.jobs;
CREATE POLICY "jobs_insert_own" ON public.jobs
  FOR INSERT WITH CHECK (auth.uid() = company_id);

DROP POLICY IF EXISTS "jobs_update_own" ON public.jobs;
CREATE POLICY "jobs_update_own" ON public.jobs
  FOR UPDATE USING (auth.uid() = company_id);

DROP POLICY IF EXISTS "jobs_delete_own" ON public.jobs;
CREATE POLICY "jobs_delete_own" ON public.jobs
  FOR DELETE USING (auth.uid() = company_id);

-- ═══════════════════════════════════════════════════════════
-- TABLA: job_applications
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.job_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  candidate_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'applied' CHECK (status IN ('applied', 'reviewed', 'interview', 'rejected', 'hired')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(job_id, candidate_id)
);

CREATE INDEX IF NOT EXISTS idx_applications_job ON public.job_applications(job_id);
CREATE INDEX IF NOT EXISTS idx_applications_candidate ON public.job_applications(candidate_id);

ALTER TABLE public.job_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "apps_read_own" ON public.job_applications;
CREATE POLICY "apps_read_own" ON public.job_applications
  FOR SELECT USING (
    auth.uid() = candidate_id 
    OR auth.uid() IN (SELECT company_id FROM public.jobs WHERE id = job_id)
  );

DROP POLICY IF EXISTS "apps_insert_own" ON public.job_applications;
CREATE POLICY "apps_insert_own" ON public.job_applications
  FOR INSERT WITH CHECK (auth.uid() = candidate_id);
