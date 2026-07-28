-- ============================================================================
-- 020 — Corregir columnas de `notifications` en el push y en los referidos
-- ============================================================================
-- ERROR DE BASE (detectado el 28/7/2026 probando el canje de referidos de punta
-- a punta): las migraciones 015 y 018 se escribieron mirando `schema.sql` del
-- repo, que está DESACTUALIZADO respecto de la base real.
--
--   schema.sql dice:  notifications(user_id, actor_id, type, description, is_read, created_at)
--   la base real es:  notifications(user_id, type, title, body, is_read, data,
--                                   sender_name, sender_avatar_url, sender_headline,
--                                   company_name, avatar_url, created_at)
--
-- O sea: NO existen `actor_id` ni `description`; sí existen `title` y `body`.
--
-- Consecuencias que esto tuvo:
--  • `notify_push_on_notification` (015) leía NEW.description → error en tiempo
--    de ejecución, tragado por su propio EXCEPTION → **el push nunca se envió**.
--    Confirmado: net._http_response no tiene ninguna petición reciente.
--  • `redeem_referral_code` (018) insertaba (actor_id, description) → 42703, así
--    que el canje de referidos habría fallado siempre.
--
-- Esta migración reescribe ambas funciones contra el esquema REAL.
-- ============================================================================

-- ── 1. Push: usar title/body reales ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_push_on_notification()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, extensions, vault
LANGUAGE plpgsql AS $$
DECLARE
  v_project_url CONSTANT TEXT := 'https://qclipzefqndcefwwixdy.supabase.co';
  v_token TEXT;
  v_key   TEXT;
  v_title TEXT;
  v_body  TEXT;
BEGIN
  SELECT fcm_token INTO v_token FROM public.users WHERE id = NEW.user_id;
  IF v_token IS NULL OR v_token = '' THEN
    RETURN NEW;
  END IF;

  SELECT decrypted_secret INTO v_key
  FROM vault.decrypted_secrets WHERE name = 'service_role_key' LIMIT 1;
  IF v_key IS NULL OR v_key = '' THEN
    RETURN NEW;
  END IF;

  -- La tabla ya trae title/body; si vinieran vacíos se cae al título por tipo.
  v_title := COALESCE(NULLIF(NEW.title, ''), public.notification_title_for_type(NEW.type));
  v_body  := COALESCE(NEW.body, '');

  PERFORM net.http_post(
    url     := v_project_url || '/functions/v1/send-fcm',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'Authorization', 'Bearer ' || v_key
               ),
    body    := jsonb_build_object(
                 'token', v_token,
                 'title', v_title,
                 'body',  v_body,
                 'data',  jsonb_build_object(
                            'notification_id', NEW.id,
                            'type',            NEW.type
                          )
               )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Best-effort, pero dejando rastro: sin esto el fallo era invisible.
  RAISE WARNING 'notify_push_on_notification falló: % (%)', SQLERRM, SQLSTATE;
  RETURN NEW;
END;
$$;

-- ── 2. Referidos: insertar la notificación con las columnas reales ─────────
CREATE OR REPLACE FUNCTION public.redeem_referral_code(p_code TEXT)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_me       UUID := auth.uid();
  v_referrer UUID;
  v_name     TEXT;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  SELECT user_id INTO v_referrer
  FROM public.referral_codes
  WHERE upper(code) = upper(trim(p_code)) LIMIT 1;

  IF v_referrer IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'codigo_invalido');
  END IF;
  IF v_referrer = v_me THEN
    RETURN jsonb_build_object('ok', false, 'error', 'autorreferido');
  END IF;
  IF EXISTS (SELECT 1 FROM public.referrals WHERE referred_id = v_me) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ya_canjeado');
  END IF;

  INSERT INTO public.referrals (referrer_id, referred_id, referral_code, reward_granted)
  VALUES (v_referrer, v_me, upper(trim(p_code)), false);

  UPDATE public.referral_codes
  SET uses_count = COALESCE(uses_count, 0) + 1
  WHERE upper(code) = upper(trim(p_code));

  SELECT COALESCE(name, 'Alguien') INTO v_name FROM public.users WHERE id = v_me;

  INSERT INTO public.notifications (user_id, type, title, body, sender_name)
  VALUES (
    v_referrer,
    'referral',
    'Sumaste un referido 🎉',
    v_name || ' se registró en Mploya con tu invitación',
    v_name
  );

  RETURN jsonb_build_object('ok', true, 'referrer_id', v_referrer);
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_referral_code(TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
