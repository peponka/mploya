-- ============================================================================
-- 018 — Referidos: hacer que el canje funcione (estaba roto de dos formas)
-- ============================================================================
-- Diagnóstico (28/7/2026): hay 6 códigos generados y 0 referidos registrados.
-- Motivos:
--   1) El link que reparte la app (https://mploya.ai/invite/<code>) daba 404
--      → se agrega la landing en Vercel (dist/api/invite.js).
--   2) `ReferralService.applyCode()` hace
--         from('referral_codes').select().eq('code', code)
--      pero la política RLS de referral_codes es `auth.uid() = user_id`: solo el
--      DUEÑO puede leer su fila. El invitado siempre recibía null → jamás se
--      insertaba en `referrals`.
--
-- Solución: dos funciones SECURITY DEFINER, que corren con permisos del owner y
-- exponen lo mínimo necesario, en vez de aflojar el RLS de las tablas.
-- ============================================================================

-- ── 1. Nombre de quien invita (para la landing pública) ─────────────────────
-- Devuelve solo el nombre; no expone id, email ni nada más.
CREATE OR REPLACE FUNCTION public.get_referrer_name(p_code TEXT)
RETURNS TEXT
SECURITY DEFINER
SET search_path = public
LANGUAGE sql
STABLE AS $$
  SELECT u.name
  FROM public.referral_codes rc
  JOIN public.users u ON u.id = rc.user_id
  WHERE upper(rc.code) = upper(trim(p_code))
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_referrer_name(TEXT) TO anon, authenticated;

-- ── 2. Canjear un código ────────────────────────────────────────────────────
-- Lo llama el usuario YA registrado (auth.uid() = invitado). Valida:
--   • que el código exista
--   • que no se autorrefiera
--   • que ese usuario no haya canjeado antes (una sola vez por cuenta)
-- Devuelve jsonb {ok, error?, referrer_id?}.
CREATE OR REPLACE FUNCTION public.redeem_referral_code(p_code TEXT)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_me       UUID := auth.uid();
  v_referrer UUID;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  SELECT user_id INTO v_referrer
  FROM public.referral_codes
  WHERE upper(code) = upper(trim(p_code))
  LIMIT 1;

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

  -- Avisarle a quien invitó (el trigger de la 015 lo convierte en push).
  INSERT INTO public.notifications (user_id, actor_id, type, description)
  VALUES (
    v_referrer,
    v_me,
    'referral',
    COALESCE((SELECT name FROM public.users WHERE id = v_me), 'Alguien')
      || ' se sumó a Mploya con tu invitación 🎉'
  );

  RETURN jsonb_build_object('ok', true, 'referrer_id', v_referrer);
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_referral_code(TEXT) TO authenticated;

-- ── 3. Conteo de referidos propios (para la pantalla de Referidos) ──────────
CREATE OR REPLACE FUNCTION public.my_referral_count()
RETURNS INTEGER
SECURITY DEFINER
SET search_path = public
LANGUAGE sql
STABLE AS $$
  SELECT COUNT(*)::int FROM public.referrals WHERE referrer_id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.my_referral_count() TO authenticated;

NOTIFY pgrst, 'reload schema';
