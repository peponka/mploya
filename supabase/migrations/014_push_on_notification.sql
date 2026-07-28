-- ============================================================================
-- 014 — Push (FCM) automático para toda notificación in-app
-- ============================================================================
-- Hasta ahora el push solo se disparaba desde el cliente al mandar un mensaje
-- (chat_inmail_screen / messaging_screen invocan la Edge Function `send-fcm`).
-- El resto de los eventos (solicitud de conexión, postulación a una vacante,
-- alerta de vacante, vista de perfil…) solo generaban una fila en
-- `public.notifications`: el usuario se enteraba únicamente si abría la app.
--
-- Esta migración engancha un trigger a `notifications`: cada INSERT dispara un
-- push al dueño de la notificación. Así cualquier evento nuevo que inserte en
-- esa tabla queda cubierto sin tocar el cliente.
--
-- Requisitos (ya presentes en el proyecto):
--   • Extensión pg_net    → para http_post asíncrono desde Postgres
--   • Edge Function send-fcm desplegada (usa FIREBASE_SERVICE_ACCOUNT)
--   • users.fcm_token poblado por PushNotificationService
--
-- Config: la URL del proyecto y la service key se leen de configuración de BD
-- en vez de hardcodearse (evita el placeholder [TU-PROYECTO] que quedó sin
-- completar en schema.sql). Setear una sola vez, como superusuario:
--
--   ALTER DATABASE postgres SET app.supabase_url      = 'https://xxxx.supabase.co';
--   ALTER DATABASE postgres SET app.supabase_service_key = 'eyJ...';
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Título legible por tipo (espeja _titleForType en notifications_screen.dart)
CREATE OR REPLACE FUNCTION public.notification_title_for_type(p_type TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_type
    WHEN 'connection'          THEN 'Nueva solicitud de conexión'
    WHEN 'connection_request'  THEN 'Nueva solicitud de conexión'
    WHEN 'connection_accepted' THEN 'Conexión aceptada'
    WHEN 'message'             THEN 'Mensaje nuevo'
    WHEN 'like'                THEN 'Le interesó tu perfil'
    WHEN 'comment'             THEN 'Nuevo comentario'
    WHEN 'mention'             THEN 'Te mencionaron'
    WHEN 'profileView'         THEN 'Vieron tu perfil'
    WHEN 'jobAlert'            THEN 'Vacante que te puede interesar'
    WHEN 'job_application'     THEN 'Nueva postulación'
    WHEN 'interview'           THEN 'Entrevista agendada'
    WHEN 'interview_scheduled' THEN 'Entrevista agendada'
    WHEN 'nexus'               THEN 'Sugerencia de Nexus'
    ELSE 'Novedad'
  END;
$$;

CREATE OR REPLACE FUNCTION public.notify_push_on_notification()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, extensions
LANGUAGE plpgsql AS $$
DECLARE
  v_token   TEXT;
  v_url     TEXT := current_setting('app.supabase_url', true);
  v_key     TEXT := current_setting('app.supabase_service_key', true);
  v_title   TEXT;
BEGIN
  -- Sin config de URL/key no se intenta el push (evita romper el INSERT).
  IF v_url IS NULL OR v_key IS NULL THEN
    RETURN NEW;
  END IF;

  -- Solo si el destinatario tiene un token FCM registrado.
  SELECT fcm_token INTO v_token FROM public.users WHERE id = NEW.user_id;
  IF v_token IS NULL OR v_token = '' THEN
    RETURN NEW;
  END IF;

  v_title := public.notification_title_for_type(NEW.type);

  -- http_post de pg_net es asíncrono: no bloquea ni hace fallar el INSERT.
  PERFORM net.http_post(
    url     := v_url || '/functions/v1/send-fcm',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'Authorization', 'Bearer ' || v_key
               ),
    body    := jsonb_build_object(
                 'token', v_token,
                 'title', v_title,
                 'body',  COALESCE(NEW.description, ''),
                 'data',  jsonb_build_object(
                            'notification_id', NEW.id,
                            'type',            NEW.type,
                            'actor_id',        COALESCE(NEW.actor_id::text, '')
                          )
               )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- El push es best-effort: si falla, la notificación in-app igual se guarda.
  RAISE WARNING 'notify_push_on_notification falló: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_notification_push ON public.notifications;
CREATE TRIGGER on_notification_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.notify_push_on_notification();

-- El trigger viejo de messages quedaba en no-op (su http_post estaba comentado)
-- y los mensajes ya mandan push desde el cliente: se elimina para no confundir.
DROP TRIGGER IF EXISTS on_new_inmail ON public.messages;
DROP FUNCTION IF EXISTS public.notify_inmail_push();
