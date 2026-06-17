-- ================================================================
--  MIGRACIÓN 003 — Job Alerts + pgvector para AI Matching
--
--  Ejecutar en: Supabase Dashboard → SQL Editor → New Query → Run
-- ================================================================


-- ================================================================
-- §1  pgvector — Motor de embeddings para AI Matching
-- ================================================================

CREATE EXTENSION IF NOT EXISTS vector;

-- Columna de embedding en users (384 dims = all-MiniLM-L6-v2)
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS profile_embedding vector(384);

-- Índice HNSW para búsqueda por similitud coseno (rápido en producción)
CREATE INDEX IF NOT EXISTS idx_users_embedding
  ON public.users
  USING hnsw (profile_embedding vector_cosine_ops);

COMMENT ON COLUMN public.users.profile_embedding IS
  'Embedding 384-dim generado por all-MiniLM-L6-v2 via Edge Function generate-embedding.';


-- ================================================================
-- §2  RPC: match_users_by_embedding
--     Retorna usuarios ordenados por similitud coseno al usuario dado.
-- ================================================================

CREATE OR REPLACE FUNCTION match_users_by_embedding(
  p_user_id UUID,
  p_limit   INT DEFAULT 10
)
RETURNS TABLE (
  id              UUID,
  name            TEXT,
  headline        TEXT,
  avatar_url      TEXT,
  account_type    TEXT,
  tags            TEXT[],
  similarity      FLOAT
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    u.id,
    u.name,
    u.headline,
    u.avatar_url,
    u.account_type,
    u.tags,
    1 - (u.profile_embedding <=> src.profile_embedding) AS similarity
  FROM public.users u
  JOIN public.users src ON src.id = p_user_id
  WHERE u.id != p_user_id
    AND u.profile_embedding IS NOT NULL
    AND src.profile_embedding IS NOT NULL
  ORDER BY u.profile_embedding <=> src.profile_embedding
  LIMIT p_limit;
$$;

COMMENT ON FUNCTION match_users_by_embedding IS
  'Retorna los usuarios más similares usando similitud coseno sobre profile_embedding.';


-- ================================================================
-- §3  Trigger: alertas automáticas cuando se publica una vacante
--
--  Al insertar un job, notifica a todos los candidatos cuyos
--  tags se superpongan con los tags de la vacante.
-- ================================================================

CREATE OR REPLACE FUNCTION notify_candidates_on_new_job()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_company_name TEXT;
BEGIN
  -- Obtener nombre de la empresa
  SELECT name INTO v_company_name
  FROM public.users
  WHERE id = NEW.company_id
  LIMIT 1;

  -- Insertar notificación para cada candidato con tags compatibles
  INSERT INTO public.notifications (user_id, type, description, actor_id)
  SELECT DISTINCT
    u.id,
    'jobAlert',
    '💼 Nueva vacante que coincide con tu perfil: "' || NEW.title || '"'
      || CASE WHEN v_company_name IS NOT NULL THEN ' en ' || v_company_name ELSE '' END
      || CASE WHEN NEW.location IS NOT NULL AND NEW.location != '' THEN ' · ' || NEW.location ELSE '' END,
    NEW.company_id
  FROM public.users u
  WHERE
    -- Solo candidatos (no la propia empresa)
    u.id != COALESCE(NEW.company_id, '00000000-0000-0000-0000-000000000000'::uuid)
    AND u.account_type IN ('candidato', 'confidencial', 'stealth')
    -- Con al menos un tag en común (operador de solapamiento de arrays)
    AND NEW.tags && u.tags;

  RETURN NEW;
END;
$$;

-- Crear el trigger (eliminar si ya existe para poder re-ejecutar la migración)
DROP TRIGGER IF EXISTS trg_job_alert_on_insert ON public.jobs;

CREATE TRIGGER trg_job_alert_on_insert
  AFTER INSERT ON public.jobs
  FOR EACH ROW
  WHEN (NEW.is_active = TRUE AND array_length(NEW.tags, 1) > 0)
  EXECUTE FUNCTION notify_candidates_on_new_job();

COMMENT ON TRIGGER trg_job_alert_on_insert ON public.jobs IS
  'Notifica automáticamente a candidatos con tags compatibles cuando se publica una vacante.';


-- ================================================================
-- §4  RPC: create_system_notification (si no existe)
--     Usada por NotificationService.createGeoNotification y otros.
-- ================================================================

CREATE OR REPLACE FUNCTION create_system_notification(
  p_user_id    UUID,
  p_type       TEXT,
  p_description TEXT,
  p_actor_id   UUID DEFAULT NULL
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.notifications (user_id, type, description, actor_id)
  VALUES (p_user_id, p_type, p_description, p_actor_id);
END;
$$;

COMMENT ON FUNCTION create_system_notification IS
  'Inserta una notificación del sistema sin restricción de RLS (SECURITY DEFINER).';
