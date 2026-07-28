-- ============================================================================
-- 015 — Push (FCM): leer la service key desde Vault (reemplaza el enfoque 014)
-- ============================================================================
-- La migración 014 leía la URL y la service key con current_setting('app.*'),
-- que se setean con ALTER DATABASE ... SET. En Supabase eso NO funciona: ni el
-- rol `postgres` tiene permiso ("permission denied to set parameter"), así que
-- el trigger quedaba inerte.
--
-- Enfoque correcto en Supabase:
--   • La URL del proyecto NO es secreta (viaja en la app) → va hardcodeada.
--   • La service key SÍ es secreta → se guarda en Vault (supabase_vault) y se
--     lee en tiempo de ejecución desde vault.decrypted_secrets.
--
-- PASO MANUAL (una sola vez, en el SQL Editor). Guarda la service_role key
-- (Project Settings → API → service_role) en Vault con el nombre esperado:
--
--   select vault.create_secret('TU_SERVICE_ROLE_KEY', 'service_role_key', 'FCM push');
--
-- Para rotarla más adelante:
--   select vault.update_secret(
--     (select id from vault.secrets where name = 'service_role_key'),
--     'NUEVA_KEY');
--
-- Mientras el secreto no exista, el trigger simplemente no envía push (la
-- notificación in-app se guarda igual).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_push_on_notification()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, extensions, vault
LANGUAGE plpgsql AS $$
DECLARE
  -- URL del proyecto (pública, no secreta).
  v_project_url CONSTANT TEXT := 'https://qclipzefqndcefwwixdy.supabase.co';
  v_token TEXT;
  v_key   TEXT;
  v_title TEXT;
BEGIN
  -- Solo si el destinatario tiene token FCM registrado.
  SELECT fcm_token INTO v_token FROM public.users WHERE id = NEW.user_id;
  IF v_token IS NULL OR v_token = '' THEN
    RETURN NEW;
  END IF;

  -- Service key desde Vault. Si no está cargada, no se envía push.
  SELECT decrypted_secret INTO v_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key'
  LIMIT 1;

  IF v_key IS NULL OR v_key = '' THEN
    RETURN NEW;
  END IF;

  v_title := public.notification_title_for_type(NEW.type);

  -- pg_net es asíncrono: no bloquea ni hace fallar el INSERT.
  PERFORM net.http_post(
    url     := v_project_url || '/functions/v1/send-fcm',
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
  -- Best-effort: si el push falla, la notificación in-app igual se guarda.
  RAISE WARNING 'notify_push_on_notification falló: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- El trigger de 014 sigue siendo válido; se recrea por idempotencia.
DROP TRIGGER IF EXISTS on_notification_push ON public.notifications;
CREATE TRIGGER on_notification_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.notify_push_on_notification();
