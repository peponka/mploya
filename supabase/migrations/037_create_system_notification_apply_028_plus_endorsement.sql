-- 037_create_system_notification_apply_028_plus_endorsement.sql
--
-- Aplica el contrato de autorización que ya estaba diseñado y verificado en
-- 028_create_system_notification_hardening.sql (13/8/2026) — nunca se había
-- ejecutado contra la base real (mismo patrón de siempre en este proyecto:
-- archivo en el repo ≠ aplicado). Reverificado hoy (18/8/2026) contra la base
-- viva antes de aplicar:
--   · FORCE ROW LEVEL SECURITY sigue en false en job_applications,
--     ghost_applications, nexus_signals y jobs (028 depende de esto).
--   · notification_title_for_type, el CHECK de nexus_signals.status y las
--     columnas de notifications no cambiaron.
--   · El cambio de Dart que 028 pedía (acceptSignal → p_type =
--     'connection_accepted') YA ESTÁ HECHO (nexus_service.dart).
--   · jobs_screen.dart YA NO llama a create_system_notification directamente
--     (la migración 030 lo dejó como comentario histórico) — postula vía
--     INSERT en job_applications y el trigger de 030 notifica. Ya no es
--     riesgo para el contrato de 028 (que exigía esa fila para autorizar
--     'jobAlert' a un tercero).
--
-- DRIFT ENCONTRADO HOY que 028 no contemplaba: hay un 7º llamador,
-- `profile_section_widgets.dart:221` (endorsement de skill en perfil ajeno),
-- con p_type = 'endorsement' — NO está en la lista blanca original de 028.
-- Aplicar 028 tal cual habría roto esa notificación en silencio (queda
-- atrapada por un `.catchError((_) {})`, así que no se habría notado como
-- error, sólo como feature muerta). Es una acción social abierta: cualquier
-- autenticado puede endosar una skill en el perfil de OTRO (gateado en Dart
-- por `!isOwnProfile`); no depende de ninguna relación previa como
-- connection/comment, así que sólo necesita "no es a mí mismo" — lo cual ya
-- garantiza la rama v_self de la función (si alguien se auto-endosara,
-- p_user_id = auth.uid() cae en la rama de auto-notificación, que sólo
-- admite 'jobAlert', y se rechaza).

BEGIN;

CREATE OR REPLACE FUNCTION public.create_system_notification(
  p_user_id     UUID,
  p_type        TEXT,
  p_description TEXT,
  p_actor_id    UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor       UUID    := auth.uid();
  v_self        BOOLEAN;
  v_title       TEXT;
  v_sender_name TEXT;
  v_authorized  BOOLEAN := FALSE;
BEGIN
  -- ── 1. Sesión obligatoria ─────────────────────────────────────────────────
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'create_system_notification: sin sesión activa'
      USING ERRCODE = '28000';
  END IF;

  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'create_system_notification: p_user_id es obligatorio'
      USING ERRCODE = '22023';
  END IF;

  -- ── 2. El actor declarado no puede ser otro que el autenticado ────────────
  IF p_actor_id IS NOT NULL AND p_actor_id <> v_actor THEN
    RAISE EXCEPTION
      'create_system_notification: p_actor_id (%) no coincide con auth.uid() (%)',
      p_actor_id, v_actor
      USING ERRCODE = '42501';
  END IF;

  -- ── 3. Lista blanca de tipos ──────────────────────────────────────────────
  -- Los 5 que usa la app hoy (jobAlert / connection / connection_accepted /
  -- comment / endorsement). Ampliarla debe ser una decisión explícita.
  IF p_type IS NULL
     OR p_type NOT IN ('jobAlert', 'connection', 'connection_accepted', 'comment', 'endorsement')
  THEN
    RAISE EXCEPTION 'create_system_notification: tipo no permitido (%)', p_type
      USING ERRCODE = '22023';
  END IF;

  v_self := (p_user_id = v_actor);

  IF v_self THEN
    -- ── 4a. AUTO-NOTIFICACIÓN ───────────────────────────────────────────────
    IF p_type <> 'jobAlert' THEN
      RAISE EXCEPTION
        'create_system_notification: una auto-notificación sólo puede ser jobAlert (recibido %)',
        p_type
        USING ERRCODE = '42501';
    END IF;

    v_authorized := TRUE;
    v_title      := public.notification_title_for_type('jobAlert');

  ELSE
    -- ── 4b. NOTIFICACIÓN A UN TERCERO ───────────────────────────────────────
    IF p_actor_id IS NULL THEN
      RAISE EXCEPTION
        'create_system_notification: p_actor_id es obligatorio para notificar a un tercero'
        USING ERRCODE = '42501';
    END IF;

    IF p_type = 'jobAlert' THEN
      SELECT
        EXISTS (
          SELECT 1
          FROM public.job_applications ja
          JOIN public.jobs j ON j.id = ja.job_id
          WHERE ja.candidate_id = v_actor
            AND j.company_id    = p_user_id
        )
        OR EXISTS (
          SELECT 1
          FROM public.ghost_applications g
          JOIN public.jobs j ON j.id = g.job_id
          WHERE g.candidate_id = v_actor
            AND j.company_id   = p_user_id
        )
      INTO v_authorized;

      v_title := 'Nueva postulación';

    ELSIF p_type = 'connection' THEN
      SELECT EXISTS (
        SELECT 1
        FROM public.nexus_signals s
        WHERE s.sender_id   = v_actor
          AND s.receiver_id = p_user_id
      ) INTO v_authorized;

      v_title := public.notification_title_for_type('connection');

    ELSIF p_type = 'connection_accepted' THEN
      SELECT EXISTS (
        SELECT 1
        FROM public.nexus_signals s
        WHERE s.receiver_id = v_actor
          AND s.sender_id   = p_user_id
          AND s.status      = 'matched'
      ) INTO v_authorized;

      v_title := public.notification_title_for_type('connection_accepted');

    ELSIF p_type = 'comment' THEN
      SELECT EXISTS (
        SELECT 1
        FROM public.nexus_signals s
        WHERE s.sender_id   = v_actor
          AND s.receiver_id = p_user_id
      ) INTO v_authorized;

      v_title := public.notification_title_for_type('comment');

    ELSIF p_type = 'endorsement' THEN
      -- Acción social abierta (perfil_section_widgets.dart): cualquier
      -- autenticado puede endosar una skill en un perfil que no es el suyo.
      -- No depende de ninguna relación previa; "no es a mí mismo" ya lo
      -- garantiza la rama v_self de arriba.
      v_authorized := TRUE;
      v_title      := 'Validación de habilidad';
    END IF;

    IF NOT v_authorized THEN
      RAISE EXCEPTION
        'create_system_notification: no hay relación que autorice esta notificación (tipo %, destinatario %)',
        p_type, p_user_id
        USING ERRCODE = '42501';
    END IF;

    -- ── 5. El nombre del emisor se DERIVA, no se recibe ────────────────────
    SELECT u.name INTO v_sender_name
    FROM public.users u
    WHERE u.id = v_actor;
  END IF;

  -- ── 6. Inserción ──────────────────────────────────────────────────────────
  -- Sin gate contra `profiles`: la FK notifications.user_id → users(id) ya
  -- garantiza que el destinatario exista.
  INSERT INTO public.notifications (user_id, type, title, body, sender_name)
  VALUES (p_user_id, p_type, v_title, p_description, v_sender_name);
END;
$$;

COMMENT ON FUNCTION public.create_system_notification(UUID, TEXT, TEXT, UUID) IS
  'Inserta una notificación del sistema (SECURITY DEFINER: notifications no '
  'tiene política de INSERT). El actor sale de auth.uid(); p_actor_id sólo se '
  'admite si coincide. Cada tipo exige su propia relación emisor-destinatario. '
  'Ver migraciones 028 y 037.';

-- ── Permisos ────────────────────────────────────────────────────────────────
-- Igual que 028 proponía: queda exclusivamente para authenticated. Sin
-- sesión la función ya aborta con 28000; se quita el permiso a PUBLIC/anon
-- para no agrandar la superficie. service_role se revoca porque no hay
-- ningún llamador real (verificado: ninguna Edge Function ni trigger la
-- menciona).
REVOKE EXECUTE ON FUNCTION public.create_system_notification(UUID, TEXT, TEXT, UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_system_notification(UUID, TEXT, TEXT, UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION public.create_system_notification(UUID, TEXT, TEXT, UUID) FROM service_role;
GRANT  EXECUTE ON FUNCTION public.create_system_notification(UUID, TEXT, TEXT, UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
