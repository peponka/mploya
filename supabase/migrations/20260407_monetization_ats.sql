-- ============================================================
-- MPLOYA — Migración de Monetización (Boosts) y Mini-CRM (ATS)
-- Fecha: 2026-04-07
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- BLOQUE 1: ALTER TABLE users (MONETIZACIÓN Y BOOSTS)
-- Añade los campos necesarios para gestionar Boosts locales y remotos
-- ─────────────────────────────────────────────────────────────

ALTER TABLE public.users
  -- Timestamp límite hasta dónde el usuario pagó su boost
  ADD COLUMN IF NOT EXISTS boost_ends_at       TIMESTAMPTZ,
  
  -- Tipo de boost para saber el comportamiento (ej: 'local', 'remote')
  ADD COLUMN IF NOT EXISTS boost_type          TEXT,
  
  -- Ciudad destino si pagó por "Boost Passport/Remote"
  ADD COLUMN IF NOT EXISTS boost_target_city   TEXT;

CREATE INDEX IF NOT EXISTS idx_users_boost_ends_at
  ON public.users (boost_ends_at);

COMMENT ON COLUMN public.users.boost_ends_at       IS 'Vencimiento del Boost. Si es mayor a NOW(), destaca al candidato.';
COMMENT ON COLUMN public.users.boost_type          IS 'Tipo de boost pagado (local, remote)';
COMMENT ON COLUMN public.users.boost_target_city   IS 'Ciudad elegida para Boost Passport/Remote';


-- ─────────────────────────────────────────────────────────────
-- BLOQUE 2: ALTER TABLE connections (MINI-CRM / ATS KANBAN)
-- Añade la columna ats_status para las fases del candidato en la empresa
-- ─────────────────────────────────────────────────────────────

ALTER TABLE public.connections
  -- El ats_status servirá para el tablero Kanban de la empresa
  -- Ej: 'new', 'interviewing', 'hired', 'rejected'
  ADD COLUMN IF NOT EXISTS ats_status TEXT NOT NULL DEFAULT 'new'
  CHECK (ats_status IN ('new', 'interviewing', 'hired', 'rejected'));

CREATE INDEX IF NOT EXISTS idx_connections_ats_status 
  ON public.connections (addressee_id, ats_status);

COMMENT ON COLUMN public.connections.ats_status IS 'Estado del candidato en el Mini-CRM de la empresa: new, interviewing, hired, rejected';


-- ─────────────────────────────────────────────────────────────
-- BLOQUE 3: EXPANDIR FUNCION get_connection_status PARA DEVOLVER EL ATS STATUS
-- Sobrescribimos el RPC existente para que retorne el ats_status
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_connection_status(p_other_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
DECLARE
  v_me  UUID := auth.uid();
  v_row public.connections%ROWTYPE;
BEGIN
  IF v_me IS NULL THEN RETURN jsonb_build_object('status', 'none'); END IF;

  SELECT * INTO v_row
  FROM public.connections
  WHERE (requester_id = v_me AND addressee_id = p_other_user_id)
     OR (requester_id = p_other_user_id AND addressee_id = v_me)
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'none');
  END IF;

  RETURN jsonb_build_object(
    'status',         v_row.status,
    'ats_status',     v_row.ats_status,
    'connection_id',  v_row.id,
    'i_am_requester', (v_row.requester_id = v_me)
  );
END;
$$;
