-- ============================================================
-- Migración: Audit Fixes — 16 Mayo 2026
-- Corrige: RLS job_applications, columnas RPC incorrectas,
--          trigger push inactivo, sistema de bloqueo de usuarios
-- ============================================================

-- ═══════════════════════════════════════════════════════════════
-- 1. RLS para job_applications (CRÍTICO — estaba sin RLS)
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.job_applications ENABLE ROW LEVEL SECURITY;

-- Candidato puede ver sus propias postulaciones
CREATE POLICY "job_applications_select_own_candidate" ON public.job_applications
  FOR SELECT TO authenticated
  USING (candidate_id = auth.uid());

-- Empresa puede ver postulaciones a sus vacantes
CREATE POLICY "job_applications_select_company" ON public.job_applications
  FOR SELECT TO authenticated
  USING (
    job_id IN (SELECT id FROM public.jobs WHERE company_id = auth.uid())
  );

-- Solo el candidato puede postularse (INSERT)
CREATE POLICY "job_applications_insert_own" ON public.job_applications
  FOR INSERT TO authenticated
  WITH CHECK (candidate_id = auth.uid());

-- Solo la empresa puede cambiar estado (UPDATE)
CREATE POLICY "job_applications_update_company" ON public.job_applications
  FOR UPDATE TO authenticated
  USING (
    job_id IN (SELECT id FROM public.jobs WHERE company_id = auth.uid())
  );

-- Candidato puede retirar su postulación (DELETE)
CREATE POLICY "job_applications_delete_own" ON public.job_applications
  FOR DELETE TO authenticated
  USING (candidate_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════
-- 2. Fix create_job_with_postgis (columnas incorrectas)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.create_job_with_postgis(
  p_title VARCHAR,
  p_salary VARCHAR,
  p_tags TEXT[],
  p_is_stealth BOOLEAN,
  p_lat FLOAT,
  p_lng FLOAT
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me UUID := auth.uid();
  v_job_id UUID;
BEGIN
  INSERT INTO public.jobs (company_id, title, salary_range, tags, type, location_geom)
  VALUES (
    v_me, p_title, p_salary, p_tags,
    CASE WHEN p_is_stealth THEN 'stealth' ELSE 'standard' END,
    CASE WHEN p_lat IS NOT NULL THEN ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography ELSE NULL END
  ) RETURNING id INTO v_job_id;
  RETURN v_job_id;
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- 3. Fix add_headhunter_credits (columna correcta)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.add_headhunter_credits(p_company_id UUID, p_credits INT)
RETURNS VOID SECURITY DEFINER LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.company_wallets (company_id, credits_balance)
  VALUES (p_company_id, p_credits)
  ON CONFLICT (company_id) DO UPDATE SET
    credits_balance = public.company_wallets.credits_balance + p_credits,
    updated_at = NOW();
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- 4. Desactivar trigger de push vacío (solo overhead sin lógica)
-- ═══════════════════════════════════════════════════════════════

-- El trigger notify_inmail_push no hace nada útil (Edge Function comentada).
-- Lo eliminamos para quitar overhead en cada INSERT de messages.
DROP TRIGGER IF EXISTS on_new_inmail ON public.messages;
-- La función se mantiene para reactivar cuando la Edge Function esté lista.

-- ═══════════════════════════════════════════════════════════════
-- 5. Sistema de bloqueo de usuarios
-- ═══════════════════════════════════════════════════════════════

-- Tabla de bloqueos
CREATE TABLE IF NOT EXISTS public.blocked_users (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  blocker_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason      TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE(blocker_id, blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker ON public.blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked ON public.blocked_users(blocked_id);

ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

-- Solo puedo ver mis propios bloqueos
CREATE POLICY "blocked_users_select_own" ON public.blocked_users
  FOR SELECT TO authenticated
  USING (blocker_id = auth.uid());

-- Solo puedo bloquear a otros (no a mí mismo)
CREATE POLICY "blocked_users_insert_own" ON public.blocked_users
  FOR INSERT TO authenticated
  WITH CHECK (blocker_id = auth.uid() AND blocked_id != auth.uid());

-- Solo puedo desbloquear a quienes yo bloqueé
CREATE POLICY "blocked_users_delete_own" ON public.blocked_users
  FOR DELETE TO authenticated
  USING (blocker_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════
-- 6. RPC: Bloquear usuario (elimina conexión + bloquea)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.block_user(
  p_blocked_id UUID,
  p_reason TEXT DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me UUID := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  IF v_me = p_blocked_id THEN
    RETURN jsonb_build_object('error', 'cannot_block_self');
  END IF;

  -- 1. Insertar bloqueo
  INSERT INTO public.blocked_users (blocker_id, blocked_id, reason)
  VALUES (v_me, p_blocked_id, p_reason)
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

  -- 2. Eliminar conexión existente (en ambas direcciones)
  DELETE FROM public.connections
  WHERE (requester_id = v_me AND addressee_id = p_blocked_id)
     OR (requester_id = p_blocked_id AND addressee_id = v_me);

  -- 3. Eliminar mensajes entre ambos
  DELETE FROM public.messages
  WHERE (sender_id = v_me AND receiver_id = p_blocked_id)
     OR (sender_id = p_blocked_id AND receiver_id = v_me);

  RETURN jsonb_build_object('status', 'blocked', 'blocked_id', p_blocked_id);
END;
$$;

-- RPC: Desbloquear usuario
CREATE OR REPLACE FUNCTION public.unblock_user(p_blocked_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_me UUID := auth.uid();
BEGIN
  DELETE FROM public.blocked_users
  WHERE blocker_id = v_me AND blocked_id = p_blocked_id;

  RETURN jsonb_build_object('status', 'unblocked', 'blocked_id', p_blocked_id);
END;
$$;

COMMENT ON TABLE public.blocked_users IS 'Bloqueos entre usuarios. Un usuario bloqueado no puede ver el perfil, enviar mensajes ni conectar con quien lo bloqueó.';

-- ═══════════════════════════════════════════════════════════════
-- 7. Sistema de reportes de usuarios
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.user_reports (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  reporter_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason        TEXT NOT NULL CHECK (reason IN ('harassment','spam','fake_profile','inappropriate','scam','other')),
  details       TEXT,
  status        TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','reviewed','dismissed','actioned')),
  created_at    TIMESTAMPTZ DEFAULT now(),
  reviewed_at   TIMESTAMPTZ,
  reviewed_by   UUID REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS idx_user_reports_status ON public.user_reports(status);
CREATE INDEX IF NOT EXISTS idx_user_reports_reported ON public.user_reports(reported_id);

ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;

-- Solo puedo ver mis propios reportes
CREATE POLICY "user_reports_select_own" ON public.user_reports
  FOR SELECT TO authenticated
  USING (reporter_id = auth.uid());

-- Solo puedo crear reportes (no editar/borrar)
CREATE POLICY "user_reports_insert_own" ON public.user_reports
  FOR INSERT TO authenticated
  WITH CHECK (reporter_id = auth.uid() AND reported_id != auth.uid());

COMMENT ON TABLE public.user_reports IS 'Reportes de usuarios. Procesados manualmente desde el Admin Panel.';
