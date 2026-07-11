-- ================================================================
--  MIGRACIÓN 007 — Entrevistas IA (Prompt B del MVP)
--
--  Modelo: una entrevista pertenece a una vacante (jobs) y a un candidato (users).
--  Tiene preguntas (generadas por IA), respuestas en video (con transcripción) y
--  un informe final para RRHH. Reusa la infra de transcripción existente
--  (transcribe-video / deepgram-proxy) para el campo transcript.
--
--  Ejecutar en: Supabase Dashboard → SQL Editor. Idempotente.
-- ================================================================

-- ── §1  Tablas ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.interviews (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id        UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  candidate_id  UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'in_progress', 'completed')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at  TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.interview_questions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  interview_id  UUID NOT NULL REFERENCES public.interviews(id) ON DELETE CASCADE,
  ord           INT  NOT NULL DEFAULT 0,
  text          TEXT NOT NULL,
  category      TEXT,                       -- technical | behavioral | motivation
  generated_by  TEXT NOT NULL DEFAULT 'ai', -- ai | human
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.interview_answers (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id   UUID NOT NULL REFERENCES public.interview_questions(id) ON DELETE CASCADE,
  interview_id  UUID NOT NULL REFERENCES public.interviews(id) ON DELETE CASCADE,
  video_url     TEXT,
  transcript    TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.interview_reports (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  interview_id  UUID NOT NULL UNIQUE REFERENCES public.interviews(id) ON DELETE CASCADE,
  summary       TEXT,
  competencies  JSONB,   -- [{name, score, note}]
  keywords      JSONB,   -- ["...", "..."]
  score         INT,     -- 0-100
  rationale     TEXT,    -- por qué del score (IA explicable)
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_interviews_job        ON public.interviews(job_id);
CREATE INDEX IF NOT EXISTS idx_interviews_candidate  ON public.interviews(candidate_id);
CREATE INDEX IF NOT EXISTS idx_iq_interview          ON public.interview_questions(interview_id);
CREATE INDEX IF NOT EXISTS idx_ia_interview          ON public.interview_answers(interview_id);

-- ── §2  Helper: ¿el usuario actual es parte de esta entrevista? ──
--    Es parte si es el candidato, o la empresa dueña de la vacante.

CREATE OR REPLACE FUNCTION public.is_interview_party(p_interview_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.interviews i
    JOIN public.jobs j ON j.id = i.job_id
    WHERE i.id = p_interview_id
      AND (i.candidate_id = auth.uid() OR j.company_id = auth.uid())
  );
$$;

-- ── §3  RLS ──────────────────────────────────────────────────────

ALTER TABLE public.interviews         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interview_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interview_answers   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interview_reports   ENABLE ROW LEVEL SECURITY;

-- interviews: candidato o empresa dueña de la vacante
DROP POLICY IF EXISTS "interview parties" ON public.interviews;
CREATE POLICY "interview parties" ON public.interviews
  FOR ALL
  USING (
    candidate_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.jobs j WHERE j.id = job_id AND j.company_id = auth.uid())
  )
  WITH CHECK (
    candidate_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.jobs j WHERE j.id = job_id AND j.company_id = auth.uid())
  );

-- tablas hijas: acceso vía is_interview_party
DROP POLICY IF EXISTS "iq parties" ON public.interview_questions;
CREATE POLICY "iq parties" ON public.interview_questions
  FOR ALL USING (public.is_interview_party(interview_id))
  WITH CHECK (public.is_interview_party(interview_id));

DROP POLICY IF EXISTS "ia parties" ON public.interview_answers;
CREATE POLICY "ia parties" ON public.interview_answers
  FOR ALL USING (public.is_interview_party(interview_id))
  WITH CHECK (public.is_interview_party(interview_id));

DROP POLICY IF EXISTS "ir parties" ON public.interview_reports;
CREATE POLICY "ir parties" ON public.interview_reports
  FOR ALL USING (public.is_interview_party(interview_id))
  WITH CHECK (public.is_interview_party(interview_id));
