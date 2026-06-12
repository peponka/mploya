-- ─────────────────────────────────────────────────────────────────────────────
-- SOCIALNEXWORK — Portfolio Videos + Employer Reviews
-- Ejecutar en Supabase SQL Editor
-- ─────────────────────────────────────────────────────────────────────────────

-- ══════════════════════════════════════════════════════════════════════════════
-- 1. PORTFOLIO VIDEOS (max 3 por usuario)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.portfolio_videos (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  video_url   TEXT NOT NULL,
  title       TEXT NOT NULL DEFAULT '',
  description TEXT,
  duration_seconds INT DEFAULT 0,
  view_count  INT DEFAULT 0,
  like_count  INT DEFAULT 0,
  status      TEXT NOT NULL DEFAULT 'approved' CHECK (status IN ('processing','approved','rejected')),
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

-- Index para queries rápidas por usuario
CREATE INDEX IF NOT EXISTS idx_portfolio_videos_user_id ON public.portfolio_videos(user_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_videos_status ON public.portfolio_videos(status);

-- Constraint: máximo 3 videos por usuario (enforced via trigger)
CREATE OR REPLACE FUNCTION public.check_portfolio_limit()
RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT COUNT(*) FROM public.portfolio_videos WHERE user_id = NEW.user_id) >= 3 THEN
    RAISE EXCEPTION 'Portfolio limit reached: maximum 3 videos per user';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_portfolio_limit ON public.portfolio_videos;
CREATE TRIGGER trg_check_portfolio_limit
  BEFORE INSERT ON public.portfolio_videos
  FOR EACH ROW EXECUTE FUNCTION public.check_portfolio_limit();

-- RLS
ALTER TABLE public.portfolio_videos ENABLE ROW LEVEL SECURITY;

-- Todos pueden ver videos aprobados
CREATE POLICY "portfolio_select_approved" ON public.portfolio_videos
  FOR SELECT USING (status = 'approved' OR user_id = auth.uid());

-- Solo el owner puede insertar/editar/eliminar
CREATE POLICY "portfolio_insert_own" ON public.portfolio_videos
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "portfolio_update_own" ON public.portfolio_videos
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "portfolio_delete_own" ON public.portfolio_videos
  FOR DELETE USING (user_id = auth.uid());

-- RPC para incrementar vistas (evita race conditions)
CREATE OR REPLACE FUNCTION public.increment_portfolio_view(p_video_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.portfolio_videos
  SET view_count = view_count + 1
  WHERE id = p_video_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ══════════════════════════════════════════════════════════════════════════════
-- 2. EMPLOYER REVIEWS (candidatos califican empresas)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.employer_reviews (
  id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  candidate_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  company_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  overall_stars       NUMERIC(2,1) NOT NULL CHECK (overall_stars >= 1 AND overall_stars <= 5),
  communication_stars NUMERIC(2,1) DEFAULT 0 CHECK (communication_stars >= 0 AND communication_stars <= 5),
  transparency_stars  NUMERIC(2,1) DEFAULT 0 CHECK (transparency_stars >= 0 AND transparency_stars <= 5),
  respect_stars       NUMERIC(2,1) DEFAULT 0 CHECK (respect_stars >= 0 AND respect_stars <= 5),
  comment             TEXT,
  process_type        TEXT CHECK (process_type IS NULL OR process_type IN ('match','application','interview')),
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now(),
  -- Un candidato solo puede calificar una vez a cada empresa
  UNIQUE(candidate_id, company_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_employer_reviews_company ON public.employer_reviews(company_id);
CREATE INDEX IF NOT EXISTS idx_employer_reviews_candidate ON public.employer_reviews(candidate_id);
CREATE INDEX IF NOT EXISTS idx_employer_reviews_stars ON public.employer_reviews(overall_stars);

-- RLS
ALTER TABLE public.employer_reviews ENABLE ROW LEVEL SECURITY;

-- Todos pueden leer reviews
CREATE POLICY "reviews_select_all" ON public.employer_reviews
  FOR SELECT USING (true);

-- Solo el candidato puede crear/editar/eliminar su propia review
CREATE POLICY "reviews_insert_own" ON public.employer_reviews
  FOR INSERT WITH CHECK (candidate_id = auth.uid());

CREATE POLICY "reviews_update_own" ON public.employer_reviews
  FOR UPDATE USING (candidate_id = auth.uid());

CREATE POLICY "reviews_delete_own" ON public.employer_reviews
  FOR DELETE USING (candidate_id = auth.uid());


-- ══════════════════════════════════════════════════════════════════════════════
-- 3. CAMPOS EN USERS PARA EMPLOYER RATING (promedio pre-calculado)
-- ══════════════════════════════════════════════════════════════════════════════

DO $$ BEGIN
  ALTER TABLE public.users ADD COLUMN IF NOT EXISTS employer_rating_stars NUMERIC(2,1) DEFAULT 0;
  ALTER TABLE public.users ADD COLUMN IF NOT EXISTS employer_rating_count INT DEFAULT 0;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;


-- ══════════════════════════════════════════════════════════════════════════════
-- 4. TRIGGER: Auto-recalcular rating al insertar/actualizar/eliminar review
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.recalculate_employer_rating()
RETURNS TRIGGER AS $$
DECLARE
  v_company_id UUID;
  v_avg NUMERIC(2,1);
  v_count INT;
BEGIN
  -- Obtener company_id según la operación
  IF TG_OP = 'DELETE' THEN
    v_company_id := OLD.company_id;
  ELSE
    v_company_id := NEW.company_id;
  END IF;

  -- Recalcular
  SELECT COALESCE(ROUND(AVG(overall_stars)::numeric, 1), 0), COUNT(*)
  INTO v_avg, v_count
  FROM public.employer_reviews
  WHERE company_id = v_company_id;

  -- Actualizar users
  UPDATE public.users
  SET employer_rating_stars = v_avg,
      employer_rating_count = v_count
  WHERE id = v_company_id;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_recalculate_employer_rating ON public.employer_reviews;
CREATE TRIGGER trg_recalculate_employer_rating
  AFTER INSERT OR UPDATE OR DELETE ON public.employer_reviews
  FOR EACH ROW EXECUTE FUNCTION public.recalculate_employer_rating();


-- ══════════════════════════════════════════════════════════════════════════════
-- 5. STORAGE BUCKET PARA PORTFOLIO VIDEOS
-- ══════════════════════════════════════════════════════════════════════════════

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'portfolio-videos',
  'portfolio-videos',
  true,
  52428800, -- 50MB max
  ARRAY['video/mp4', 'video/quicktime', 'video/webm']
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
CREATE POLICY "portfolio_storage_select" ON storage.objects
  FOR SELECT USING (bucket_id = 'portfolio-videos');

CREATE POLICY "portfolio_storage_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'portfolio-videos' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "portfolio_storage_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'portfolio-videos' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- ✅ Listo — Ejecutar este script en el SQL Editor de Supabase
-- ─────────────────────────────────────────────────────────────────────────────
