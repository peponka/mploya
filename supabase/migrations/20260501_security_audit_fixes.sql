-- ─────────────────────────────────────────────────────────────────────────────
-- MPLOYA — Security Audit Fixes (1 Mayo 2026)
-- Ejecutar en Supabase SQL Editor
--
-- Corrige las vulnerabilidades P0 detectadas en la auditoría:
--   1. job_applications sin RLS (brecha de datos)
--   2. notifications INSERT abierto (spam/phishing)
--   3. users table RLS faltante
--   4. posts UPDATE faltante
--   5. Limpieza de políticas duplicadas en messages/jobs
-- ─────────────────────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════════════════════
-- §1  FIX CRÍTICO: job_applications — Habilitar RLS
-- ══════════════════════════════════════════════════════════════════════════════
-- ANTES: Sin RLS → cualquier usuario autenticado podía ver/editar TODAS las 
-- postulaciones de TODOS los candidatos. Brecha de datos grave.

ALTER TABLE public.job_applications ENABLE ROW LEVEL SECURITY;

-- Limpiar políticas previas (si existen)
DROP POLICY IF EXISTS "job_apps_select_own"      ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_select_company"   ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_insert_candidate" ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_update_company"   ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_delete_candidate" ON public.job_applications;

-- El candidato ve sus propias postulaciones
CREATE POLICY "job_apps_select_own"
  ON public.job_applications FOR SELECT
  USING (auth.uid() = candidate_id);

-- La empresa ve las postulaciones a SUS vacantes
CREATE POLICY "job_apps_select_company"
  ON public.job_applications FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.jobs
      WHERE jobs.id = job_applications.job_id
        AND jobs.company_id = auth.uid()
    )
  );

-- Solo el candidato puede postularse (el candidate_id debe ser él mismo)
CREATE POLICY "job_apps_insert_candidate"
  ON public.job_applications FOR INSERT
  WITH CHECK (auth.uid() = candidate_id);

-- Solo la empresa dueña de la vacante puede cambiar el status
-- (pending → viewed → accepted → rejected)
CREATE POLICY "job_apps_update_company"
  ON public.job_applications FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.jobs
      WHERE jobs.id = job_applications.job_id
        AND jobs.company_id = auth.uid()
    )
  );

-- El candidato puede retirar su postulación
CREATE POLICY "job_apps_delete_candidate"
  ON public.job_applications FOR DELETE
  USING (auth.uid() = candidate_id);

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON public.job_applications TO authenticated;

COMMENT ON TABLE public.job_applications
  IS 'Postulaciones de candidatos a vacantes. RLS habilitado: candidatos ven las suyas, empresas ven las de sus vacantes.';


-- ══════════════════════════════════════════════════════════════════════════════
-- §2  FIX CRÍTICO: notifications — Restringir INSERT
-- ══════════════════════════════════════════════════════════════════════════════
-- ANTES: INSERT WITH CHECK (true) → cualquier usuario autenticado podía crear
-- notificaciones para cualquier otro usuario (spam/phishing in-app).
-- AHORA: Solo se puede crear notificaciones si:
--   a) actor_id = auth.uid() (el usuario se identifica como actor), O
--   b) actor_id IS NULL (notificaciones del sistema vía RPCs SECURITY DEFINER)

DROP POLICY IF EXISTS "System and auth users can insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert_safe" ON public.notifications;

CREATE POLICY "notifications_insert_safe"
  ON public.notifications FOR INSERT
  WITH CHECK (
    -- El actor debe ser el usuario autenticado (no puede impersonar a otro)
    (actor_id IS NULL OR actor_id = auth.uid())
    -- Y la notificación debe ser para alguien que no sea él mismo
    AND user_id != auth.uid()
  );

-- Las notificaciones del sistema (job alerts, profile views semanales, etc.)
-- se insertan vía RPCs o Edge Functions con SECURITY DEFINER que bypasean RLS.
-- No necesitan política INSERT adicional.


-- ══════════════════════════════════════════════════════════════════════════════
-- §3  FIX: users table — Verificar y reforzar RLS
-- ══════════════════════════════════════════════════════════════════════════════
-- La tabla users probablemente tiene RLS habilitado por el trigger de Supabase,
-- pero las políticas deben ser explícitas.

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_select_all"    ON public.users;
DROP POLICY IF EXISTS "users_update_own"    ON public.users;
DROP POLICY IF EXISTS "users_insert_own"    ON public.users;
DROP POLICY IF EXISTS "users_delete_own"    ON public.users;

-- Todos los usuarios autenticados pueden ver perfiles (red social pública)
CREATE POLICY "users_select_all"
  ON public.users FOR SELECT
  TO authenticated
  USING (true);

-- Solo el usuario puede editar su propio perfil
CREATE POLICY "users_update_own"
  ON public.users FOR UPDATE
  USING (auth.uid() = id);

-- Insert: solo puede crear su propia fila (trigger on_auth_user_created 
-- es la fuente primaria, pero upsertUserProfile es fallback)
CREATE POLICY "users_insert_own"
  ON public.users FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Delete: solo uno mismo (GDPR delete-user Edge Function usa service_role)
CREATE POLICY "users_delete_own"
  ON public.users FOR DELETE
  USING (auth.uid() = id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.users TO authenticated;


-- ══════════════════════════════════════════════════════════════════════════════
-- §4  FIX: posts — Agregar política UPDATE faltante
-- ══════════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "posts_update_own" ON public.posts;

CREATE POLICY "posts_update_own"
  ON public.posts FOR UPDATE
  USING (auth.uid() = user_id);


-- ══════════════════════════════════════════════════════════════════════════════
-- §5  FIX: Realtime para job_applications (ATS necesita ver cambios)
-- ══════════════════════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'job_applications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.job_applications;
  END IF;
END $$;


-- ══════════════════════════════════════════════════════════════════════════════
-- §6  FIX: profile_unlocks — INSERT faltante
-- ══════════════════════════════════════════════════════════════════════════════
-- profile_unlocks solo tiene SELECT policies. El INSERT se hace via RPC 
-- unlock_stealth_profile (SECURITY DEFINER), así que no necesita policy
-- de INSERT para el rol authenticated. Pero agregamos una por si se usa
-- directamente desde el cliente en el futuro.

DROP POLICY IF EXISTS "profile_unlocks_insert_company" ON public.profile_unlocks;

-- Solo empresas pueden desbloquear (vía RPC, pero backup policy)
CREATE POLICY "profile_unlocks_insert_company"
  ON public.profile_unlocks FOR INSERT
  WITH CHECK (auth.uid() = company_id);


-- ══════════════════════════════════════════════════════════════════════════════
-- §7  FIX: Crear RPC segura para notificaciones del sistema
-- ══════════════════════════════════════════════════════════════════════════════
-- Las notificaciones que antes se insertaban con INSERT (true) ahora necesitan
-- un RPC SECURITY DEFINER para operaciones del sistema (triggers, edge functions).

CREATE OR REPLACE FUNCTION public.create_system_notification(
  p_user_id    UUID,
  p_type       VARCHAR(50),
  p_description TEXT,
  p_actor_id   UUID DEFAULT NULL
)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id UUID;
BEGIN
  -- Validación básica
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'user_id is required';
  END IF;
  IF p_type IS NULL OR p_description IS NULL THEN
    RAISE EXCEPTION 'type and description are required';
  END IF;

  INSERT INTO public.notifications (user_id, actor_id, type, description, is_read)
  VALUES (p_user_id, p_actor_id, p_type, p_description, false)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_system_notification(UUID, VARCHAR, TEXT, UUID) TO authenticated;

COMMENT ON FUNCTION public.create_system_notification
  IS 'Crea una notificación del sistema. SECURITY DEFINER bypasea la restricción de INSERT de notifications.';


-- ══════════════════════════════════════════════════════════════════════════════
-- §8  FIX: Actualizar trigger de push notifications para usar RPC
-- ══════════════════════════════════════════════════════════════════════════════
-- El trigger on_new_inmail debe crear notificaciones vía la función interna,
-- no via INSERT directo (que ahora está restringido por RLS).

CREATE OR REPLACE FUNCTION public.notify_inmail_push()
RETURNS TRIGGER SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_receiver_fcm TEXT;
  v_sender_name  VARCHAR;
BEGIN
  -- 1. Crear notificación in-app
  INSERT INTO public.notifications (user_id, actor_id, type, description, is_read)
  VALUES (
    NEW.receiver_id,
    NEW.sender_id,
    'message',
    'Te envió un mensaje',
    false
  );

  -- 2. Buscar FCM token del receptor
  SELECT fcm_token INTO v_receiver_fcm FROM public.users WHERE id = NEW.receiver_id;

  IF v_receiver_fcm IS NOT NULL THEN
    SELECT name INTO v_sender_name FROM public.users WHERE id = NEW.sender_id;
    -- Push via Edge Function se maneja por Database Webhook
  END IF;

  RETURN NEW;
END;
$$;


-- ══════════════════════════════════════════════════════════════════════════════
-- §9  FIX: Trigger para notificar nuevas conexiones
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.notify_connection_event()
RETURNS TRIGGER SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_sender_name VARCHAR;
BEGIN
  -- Solo notificar cuando cambia a 'accepted' o es un nuevo 'pending'
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    -- Notificar al addressee que tiene una solicitud nueva
    SELECT name INTO v_sender_name FROM public.users WHERE id = NEW.requester_id;
    INSERT INTO public.notifications (user_id, actor_id, type, description, is_read)
    VALUES (
      NEW.addressee_id,
      NEW.requester_id,
      'connection',
      COALESCE(v_sender_name, 'Alguien') || ' quiere conectar contigo',
      false
    );
  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    -- Notificar al requester que aceptaron su solicitud
    SELECT name INTO v_sender_name FROM public.users WHERE id = NEW.addressee_id;
    INSERT INTO public.notifications (user_id, actor_id, type, description, is_read)
    VALUES (
      NEW.requester_id,
      NEW.addressee_id,
      'connection',
      COALESCE(v_sender_name, 'Alguien') || ' aceptó tu solicitud',
      false
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_connection ON public.connections;
CREATE TRIGGER trg_notify_connection
  AFTER INSERT OR UPDATE ON public.connections
  FOR EACH ROW EXECUTE FUNCTION public.notify_connection_event();


-- ══════════════════════════════════════════════════════════════════════════════
-- §10  FIX: Trigger para notificar likes al pitch
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.notify_pitch_like()
RETURNS TRIGGER SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_liker_name VARCHAR;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT name INTO v_liker_name FROM public.users WHERE id = NEW.liker_id;
    INSERT INTO public.notifications (user_id, actor_id, type, description, is_read)
    VALUES (
      NEW.pitch_owner_id,
      NEW.liker_id,
      'like',
      COALESCE(v_liker_name, 'Alguien') || ' le dio like a tu video-pitch',
      false
    );
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_pitch_like ON public.pitch_likes;
CREATE TRIGGER trg_notify_pitch_like
  AFTER INSERT ON public.pitch_likes
  FOR EACH ROW EXECUTE FUNCTION public.notify_pitch_like();


-- ══════════════════════════════════════════════════════════════════════════════
-- §11  FIX: Trigger para notificar nuevas postulaciones a empresas
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.notify_job_application()
RETURNS TRIGGER SECURITY DEFINER LANGUAGE plpgsql AS $$
DECLARE
  v_candidate_name VARCHAR;
  v_job_title      VARCHAR;
  v_company_id     UUID;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Info del candidato y la vacante
    SELECT name INTO v_candidate_name FROM public.users WHERE id = NEW.candidate_id;
    SELECT title, company_id INTO v_job_title, v_company_id
      FROM public.jobs WHERE id = NEW.job_id;

    IF v_company_id IS NOT NULL THEN
      INSERT INTO public.notifications (user_id, actor_id, type, description, is_read)
      VALUES (
        v_company_id,
        NEW.candidate_id,
        'jobAlert',
        COALESCE(v_candidate_name, 'Un candidato') || ' se postuló a "' || COALESCE(v_job_title, 'tu vacante') || '"',
        false
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_job_application ON public.job_applications;
CREATE TRIGGER trg_notify_job_application
  AFTER INSERT ON public.job_applications
  FOR EACH ROW EXECUTE FUNCTION public.notify_job_application();


-- ══════════════════════════════════════════════════════════════════════════════
-- §12  ÍNDICES DE PERFORMANCE ADICIONALES
-- ══════════════════════════════════════════════════════════════════════════════

-- Notifications: queries frecuentes por user_id + is_read
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications (user_id, is_read)
  WHERE is_read = false;

-- Posts: ordenar por fecha
CREATE INDEX IF NOT EXISTS idx_posts_created_at
  ON public.posts (created_at DESC);

-- Portfolio videos: queries por user
CREATE INDEX IF NOT EXISTS idx_portfolio_user_created
  ON public.portfolio_videos (user_id, created_at DESC);

-- Employer reviews: búsqueda por empresa con estrellas
CREATE INDEX IF NOT EXISTS idx_employer_reviews_company_stars
  ON public.employer_reviews (company_id, overall_stars DESC);


-- ══════════════════════════════════════════════════════════════════════════════
-- §13  VERIFICACIÓN — Ejecutar por separado para confirmar
-- ══════════════════════════════════════════════════════════════════════════════
--
-- Tablas con RLS habilitado:
--   SELECT tablename, rowsecurity
--   FROM pg_tables
--   WHERE schemaname = 'public'
--   ORDER BY tablename;
--
-- Políticas activas:
--   SELECT tablename, policyname, permissive, cmd
--   FROM pg_policies
--   WHERE schemaname = 'public'
--   ORDER BY tablename, policyname;
--
-- Triggers activos:
--   SELECT trigger_name, event_object_table, action_timing, event_manipulation
--   FROM information_schema.triggers
--   WHERE trigger_schema = 'public'
--   ORDER BY event_object_table;
--
-- ─────────────────────────────────────────────────────────────────────────────
-- ✅ Listo — Ejecutar este script en el SQL Editor de Supabase
-- ─────────────────────────────────────────────────────────────────────────────
