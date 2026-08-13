-- ============================================================================
-- 026 — Pipeline real: la pantalla "Panel → Pipeline" mostraba 100% datos de
-- mentira (_demoCandidates hardcodeado en ats_dashboard_screen.dart). Existía
-- una versión con intención de datos reales (ats_kanban_screen.dart) pero
-- estaba huérfana (ninguna navegación llegaba a ella) Y ADEMÁS rota: llamaba
-- a get_my_pipeline(), que referencia connections.ats_status y
-- connections.updated_at — columnas que no existen en la tabla real.
-- ============================================================================

-- 1) Las columnas que get_my_pipeline() siempre asumió que existían.
ALTER TABLE public.connections
  ADD COLUMN IF NOT EXISTS ats_status TEXT NOT NULL DEFAULT 'pendiente',
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE OR REPLACE FUNCTION public.set_updated_at() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_connections_updated_at ON public.connections;
CREATE TRIGGER trg_connections_updated_at
  BEFORE UPDATE ON public.connections
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 2) get_my_pipeline() recreada: mismas columnas que ya devolvía + skills y
-- match_percentage (para las tarjetas del Pipeline), y usando el vocabulario
-- de etapas actual de la pantalla (pendiente/revision/entrevista/contratar/
-- rechazado) en vez del viejo (new/interviewing/hired/rejected) que traía el
-- Kanban huérfano.
DROP FUNCTION IF EXISTS public.get_my_pipeline();
CREATE FUNCTION public.get_my_pipeline()
RETURNS TABLE (
  connection_id     UUID,
  ats_status        TEXT,
  user_id           UUID,
  user_name         TEXT,
  user_headline     TEXT,
  user_avatar_url   TEXT,
  user_account_type TEXT,
  user_video_url    TEXT,
  is_confidential   BOOLEAN,
  user_skills       JSONB,
  match_percentage  DOUBLE PRECISION
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    c.id,
    c.ats_status,
    u.id,
    CASE WHEN u.account_type LIKE 'confidenc%' THEN 'Candidato Confidencial' ELSE u.name END,
    u.headline,
    CASE WHEN u.account_type LIKE 'confidenc%' THEN NULL ELSE u.avatar_url END,
    u.account_type::TEXT,
    u.video_url,
    (u.account_type LIKE 'confidenc%'),
    u.skills,
    u.match_percentage
  FROM public.connections c
  JOIN public.users u ON u.id = CASE
    WHEN c.requester_id = auth.uid() THEN c.addressee_id
    ELSE c.requester_id
  END
  WHERE (c.requester_id = auth.uid() OR c.addressee_id = auth.uid())
    AND c.status != 'blocked'
  ORDER BY c.updated_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_pipeline() TO authenticated;

-- 3) Cambiar de etapa (Aceptar avanza, Rechazar saca del pipeline visible).
-- Valida que quien llama sea parte de la connection — no cualquiera puede
-- mover el pipeline de otro.
CREATE OR REPLACE FUNCTION public.set_pipeline_status(p_connection_id UUID, p_status TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_status NOT IN ('pendiente', 'revision', 'entrevista', 'contratar', 'rechazado') THEN
    RAISE EXCEPTION 'estado invalido: %', p_status;
  END IF;

  UPDATE public.connections
  SET ats_status = p_status
  WHERE id = p_connection_id
    AND (requester_id = auth.uid() OR addressee_id = auth.uid());

  IF NOT FOUND THEN
    RAISE EXCEPTION 'connection % no encontrada o no pertenece al usuario', p_connection_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_pipeline_status(UUID, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
