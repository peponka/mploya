-- ============================================================================
-- 028 — create_system_notification: contrato de autorización
-- ============================================================================
-- QUÉ HABÍA EN LA BASE (leído con pg_get_functiondef el 13/8/2026, NO copiado
-- de schema.sql ni de la migración 003, que describen otra cosa):
--
--     CREATE OR REPLACE FUNCTION public.create_system_notification(
--       p_user_id uuid, p_type text, p_description text, p_actor_id uuid DEFAULT NULL)
--      RETURNS void LANGUAGE plpgsql SECURITY DEFINER
--     AS $function$
--     BEGIN
--       IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
--         RETURN;
--       END IF;
--       INSERT INTO public.notifications (user_id, type, title, body)
--       VALUES (p_user_id, p_type, p_type, p_description);
--     END;
--     $function$
--
-- Owner postgres · SIN search_path · EXECUTE para PUBLIC, anon, authenticated
-- y service_role.
--
-- TRES PROBLEMAS, EN ORDEN DE GRAVEDAD
--
-- 1. NO HAY NINGUNA COMPROBACIÓN DE IDENTIDAD. No se llama a auth.uid(), no se
--    valida p_type y p_actor_id se acepta y se DESCARTA. Como además tiene
--    EXECUTE para anon, y es la única vía de escritura a public.notifications
--    (que no tiene política de INSERT — ver 027), y cada fila dispara un push
--    FCM real vía notify_push_on_notification (020): hoy cualquiera con la anon
--    key puede mandarle a cualquier usuario un push con texto arbitrario,
--    conociendo sólo su UUID. Es el vector de phishing que la migración 027
--    evitó abrir por política, ya abierto por esta función.
--
-- 2. EL GATE CONTRA public.profiles descarta en silencio a los usuarios que no
--    están en esa tabla legacy (20 de 61 al 12/8/2026 — ver 027). La app
--    escribe en public.users y no menciona `profiles` ni una vez en todo lib/.
--
-- 3. title = p_type: el usuario ve "jobAlert" crudo como título, en la app y en
--    el push — notify_push_on_notification hace
--    COALESCE(NULLIF(NEW.title,''), notification_title_for_type(NEW.type)), y
--    como title llega no vacío, el traductor nunca se dispara.
--
-- QUÉ HACE ESTA MIGRACIÓN
--
-- Reemplaza el cuerpo por un contrato de autorización ligado AL TIPO. No se usa
-- un OR general: cada tipo admite exactamente la relación que le corresponde,
-- porque 'jobAlert' cubre tres situaciones distintas (postulación normal, ghost
-- apply y auto-notificación geo) y un OR suelto dejaría que cualquiera de esas
-- relaciones habilitara cualquier tipo.
--
-- LA FIRMA NO CAMBIA. Los identity arguments de la base coinciden exactamente
-- con los de 003 (p_user_id uuid, p_type text, p_description text, p_actor_id
-- uuid), así que CREATE OR REPLACE es válido y PRESERVA owner y ACL — un
-- DROP + CREATE los perdería.
--
-- POR QUÉ ESTA MIGRACIÓN VIENE CON UN CAMBIO EN DART (UNA LÍNEA)
--
-- `sendInterest` (solicitud) y `acceptSignal` (aceptación) mandaban los DOS
-- p_type = 'connection'. Son hechos distintos —"te mandaron una solicitud" vs
-- "te la aceptaron"— y ninguna regla dentro de esta función puede separarlos
-- con certeza si llegan etiquetados igual: cuando existen las dos señales
-- recíprocas (A→B y B→A), las dos relaciones son verdaderas a la vez y
-- cualquier orden de evaluación se equivoca en uno de los dos casos.
--
-- Medido en la base el 13/8/2026: 24 señales, 2 pares recíprocos, 0 en estado
-- 'matched'. O sea que hoy la colisión no puede ocurrir todavía, pero esos 2
-- pares la producirían en cuanto uno se acepte.
--
-- Por eso acceptSignal pasa a mandar p_type = 'connection_accepted' (una línea
-- en nexus_service.dart:142) y cada tipo queda con UNA sola dirección
-- autorizada. Sin desempates ni heurísticas.
--
-- LOS 6 LLAMADORES QUE ESTE CONTRATO DEBE SEGUIR ADMITIENDO
--   lib/screens/jobs_screen.dart:397           jobAlert            → dueño de la vacante
--   lib/services/ghost_apply_service.dart:161  jobAlert            → dueño de la vacante
--   lib/services/nexus_service.dart:57         connection          → receptor de la señal
--   lib/services/nexus_service.dart:98         comment             → receptor de la señal
--   lib/services/nexus_service.dart:140        connection_accepted → emisor de la señal
--   lib/services/notification_service.dart:236 jobAlert            → sí mismo, sin actor
--
-- DEPENDENCIAS — TODAS VERIFICADAS CONTRA LA BASE VIVA EL 13/8/2026
-- (information_schema, pg_class, pg_constraint, pg_policies, pg_indexes)
--   · public.job_applications (candidate_id uuid, job_id uuid)          ✔
--   · public.ghost_applications (candidate_id uuid, job_id uuid)        ✔
--   · public.nexus_signals (sender_id uuid, receiver_id uuid, status)   ✔
--   · public.jobs (id uuid, company_id uuid)                            ✔
--   · public.notifications (user_id, type, title, body, sender_name)    ✔
--   · public.users (id, name)                                           ✔
--   · public.notification_title_for_type(text)                          ✔
--        Los cuatro títulos, ejecutados en vivo:
--          'connection'          → "Nueva solicitud de conexión"
--          'connection_accepted' → "Conexión aceptada"
--          'comment'             → "Nuevo comentario"
--          'jobAlert'            → "Vacante que te puede interesar"
--   · nexus_signals_status_check = ('pending','matched','declined')      ✔
--
-- DOS CONDICIONES DE LAS QUE DEPENDE LA AUTORIZACIÓN, VERIFICADAS
--
-- 1. LOS `EXISTS` DEPENDEN DE QUE ESAS TABLAS SIGAN SIN `FORCE ROW LEVEL
--    SECURITY`. Hoy job_applications, ghost_applications, nexus_signals y jobs
--    tienen RLS activa, `relforcerowsecurity = false` y owner `postgres`. Como
--    esta función es SECURITY DEFINER con owner `postgres`, adentro el
--    current_user ES el dueño de esas tablas y la RLS no se le aplica: los
--    EXISTS ven todas las filas, que es exactamente lo que necesitan para
--    validar una relación entre DOS personas distintas. Si alguien pusiera
--    `ALTER TABLE … FORCE ROW LEVEL SECURITY` en cualquiera de las cuatro, los
--    chequeos empezarían a dar falso y TODA notificación a terceros se
--    rechazaría con 42501. No es hipotético: es la clase de cambio que se hace
--    "endureciendo seguridad" sin ver que rompe esto.
--
-- 2. `jobs.company_id` ES NULLABLE (verificado). En `j.company_id = p_user_id`
--    un NULL evalúa a NULL, no a TRUE: una vacante sin empresa asignada NUNCA
--    autoriza una notificación. Es el comportamiento deseado —no se puede
--    notificar a un dueño que no existe— y no produce error, pero conviene
--    saberlo antes de investigar un 42501 "inexplicable".
--
-- DEUDA SEPARADA, NO SE RESUELVE ACÁ
--
-- `public.nexus_signals` tiene TRES políticas de UPDATE superpuestas y las
-- permissive se combinan con OR, así que la más estricta queda anulada:
--     "Receivers can update status"  USING (auth.uid() = receiver_id)
--     "rls_nexus_update"             USING (auth.uid() = sender_id OR = receiver_id)
--     "users_update_own_signals"     USING (auth.uid() = sender_id OR = receiver_id)
-- Resultado: EL EMISOR PUEDE CAMBIAR EL ESTADO DE SU PROPIA SEÑAL, incluido
-- ponerla en 'matched'. Sumado a que NexusService.acceptSignal
-- (nexus_service.dart:118-129) nunca comprueba que el llamador sea el
-- receiver_id, un emisor puede auto-matchearse. Arreglarlo es tocar políticas
-- de nexus_signals y/o Dart: fuera del alcance de esta migración.
--
-- Efecto colateral de 028 sobre ese abuso: al auto-matchearse, acceptSignal
-- notifica a `signal.sender_id`, que es el propio atacante → cae en la rama de
-- auto-notificación, que sólo admite 'jobAlert', y se rechaza con 42501. O sea
-- que 028 corta el aviso, pero NO el cambio de estado. La deuda sigue viva.
--
-- NO se ejecuta como parte de este cambio. Ejecutar en: Supabase Dashboard →
-- SQL Editor. Idempotente.
-- ============================================================================


CREATE OR REPLACE FUNCTION public.create_system_notification(
  p_user_id     UUID,
  p_type        TEXT,
  p_description TEXT,
  p_actor_id    UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
-- search_path fijo: sin esto, una función SECURITY DEFINER con owner `postgres`
-- es secuestrable creando objetos homónimos en un esquema que el llamador
-- controle.
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
  -- El actor SIEMPRE sale de auth.uid(), nunca del parámetro.
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'create_system_notification: sin sesión activa'
      USING ERRCODE = '28000';
  END IF;

  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'create_system_notification: p_user_id es obligatorio'
      USING ERRCODE = '22023';
  END IF;

  -- ── 2. El actor declarado no puede ser otro que el autenticado ────────────
  -- p_actor_id se conserva sólo por compatibilidad de firma. Antes se ignoraba
  -- en silencio; ahora, si miente, es un error explícito.
  IF p_actor_id IS NOT NULL AND p_actor_id <> v_actor THEN
    RAISE EXCEPTION
      'create_system_notification: p_actor_id (%) no coincide con auth.uid() (%)',
      p_actor_id, v_actor
      USING ERRCODE = '42501';
  END IF;

  -- ── 3. Lista blanca de tipos ──────────────────────────────────────────────
  -- Los cuatro que usa la app hoy. Ampliarla debe ser una decisión explícita,
  -- no un string que llega del cliente. El chequeo de NULL va aparte: `NULL NOT
  -- IN (...)` evalúa a NULL, que en un IF se comporta como falso y dejaría
  -- pasar un tipo nulo.
  IF p_type IS NULL
     OR p_type NOT IN ('jobAlert', 'connection', 'connection_accepted', 'comment')
  THEN
    RAISE EXCEPTION 'create_system_notification: tipo no permitido (%)', p_type
      USING ERRCODE = '22023';
  END IF;

  v_self := (p_user_id = v_actor);

  IF v_self THEN
    -- ── 4a. AUTO-NOTIFICACIÓN ───────────────────────────────────────────────
    -- Único caso legítimo sin actor: NotificationService.createGeoNotification
    -- se avisa a sí mismo que hay empresas cerca. No requiere relación con
    -- nadie, pero sí queda acotado a 'jobAlert': nadie se manda a sí mismo una
    -- conexión ni un comentario.
    IF p_type <> 'jobAlert' THEN
      RAISE EXCEPTION
        'create_system_notification: una auto-notificación sólo puede ser jobAlert (recibido %)',
        p_type
        USING ERRCODE = '42501';
    END IF;

    v_authorized := TRUE;
    v_title      := public.notification_title_for_type('jobAlert');
    -- sender_name queda NULL a propósito: no hay tercero que mostrar.

  ELSE
    -- ── 4b. NOTIFICACIÓN A UN TERCERO ───────────────────────────────────────
    -- Acá el actor es obligatorio: si le escribís a otro, tenés que firmar.
    IF p_actor_id IS NULL THEN
      RAISE EXCEPTION
        'create_system_notification: p_actor_id es obligatorio para notificar a un tercero'
        USING ERRCODE = '42501';
    END IF;

    IF p_type = 'jobAlert' THEN
      -- Postulación normal (jobs_screen) o ghost apply (ghost_apply_service):
      -- en ambos el candidato autenticado le avisa a la empresa DUEÑA de la
      -- vacante a la que se postuló. La postulación tiene que existir.
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

      -- Título correcto para el caso: notification_title_for_type('jobAlert')
      -- devuelve "Vacante que te puede interesar", que es falso acá — la
      -- empresa no recibe una vacante, recibe una postulación.
      v_title := 'Nueva postulación';

    ELSIF p_type = 'connection' THEN
      -- SOLICITUD — nexus_service.dart:57 (sendInterest). UNA sola dirección:
      -- el actor es el EMISOR de la señal y le avisa al receptor.
      SELECT EXISTS (
        SELECT 1
        FROM public.nexus_signals s
        WHERE s.sender_id   = v_actor
          AND s.receiver_id = p_user_id
      ) INTO v_authorized;

      v_title := public.notification_title_for_type('connection');

    ELSIF p_type = 'connection_accepted' THEN
      -- ACEPTACIÓN — nexus_service.dart:140 (acceptSignal). Dirección inversa
      -- y estado exigido: el actor es el RECEPTOR, le avisa al EMISOR, y la
      -- señal ya tiene que estar en 'matched'. El orden lo garantiza el
      -- llamador: acceptSignal hace el UPDATE a 'matched' (líneas 127-129)
      -- ANTES de notificar (línea 140), así que al llegar acá ya cambió.
      --
      -- Exigir el estado es lo que distingue una aceptación real de un mensaje
      -- libre disfrazado de aceptación. `status` sólo admite
      -- 'pending' | 'matched' | 'declined' (CHECK verificado en la base).
      SELECT EXISTS (
        SELECT 1
        FROM public.nexus_signals s
        WHERE s.receiver_id = v_actor
          AND s.sender_id   = p_user_id
          AND s.status      = 'matched'
      ) INTO v_authorized;

      v_title := public.notification_title_for_type('connection_accepted');

    ELSIF p_type = 'comment' THEN
      -- Micro-pitch (nexus_service:98): SÓLO en la dirección emisor → receptor.
      -- A diferencia de 'connection', acá la dirección inversa no es legítima.
      SELECT EXISTS (
        SELECT 1
        FROM public.nexus_signals s
        WHERE s.sender_id   = v_actor
          AND s.receiver_id = p_user_id
      ) INTO v_authorized;

      v_title := public.notification_title_for_type('comment');
    END IF;

    IF NOT v_authorized THEN
      RAISE EXCEPTION
        'create_system_notification: no hay relación que autorice esta notificación (tipo %, destinatario %)',
        p_type, p_user_id
        USING ERRCODE = '42501';
    END IF;

    -- ── 5. El nombre del emisor se DERIVA, no se recibe ────────────────────
    -- Nunca de un parámetro: siempre de public.users por auth.uid().
    SELECT u.name INTO v_sender_name
    FROM public.users u
    WHERE u.id = v_actor;
  END IF;

  -- ── 6. Inserción ──────────────────────────────────────────────────────────
  -- Sin gate contra `profiles`: la FK notifications.user_id → users(id) ya
  -- garantiza que el destinatario exista, y si no existe levanta 23503 en vez
  -- de descartar la notificación en silencio.
  INSERT INTO public.notifications (user_id, type, title, body, sender_name)
  VALUES (p_user_id, p_type, v_title, p_description, v_sender_name);
END;
$$;

COMMENT ON FUNCTION public.create_system_notification(UUID, TEXT, TEXT, UUID) IS
  'Inserta una notificación del sistema (SECURITY DEFINER: notifications no '
  'tiene política de INSERT). El actor sale de auth.uid(); p_actor_id sólo se '
  'admite si coincide. Cada tipo exige su propia relación emisor-destinatario. '
  'Ver migración 028.';


-- ── Permisos ────────────────────────────────────────────────────────────────
-- La función tenía EXECUTE para PUBLIC, anon, authenticated y service_role.
-- Queda EXCLUSIVAMENTE para authenticated.
--
-- · PUBLIC y anon: sin sesión la función ya no puede hacer nada (aborta con
--   28000), pero se quita el permiso igual — que una función SECURITY DEFINER
--   con owner `postgres` sea invocable sin autenticar no aporta nada y agranda
--   la superficie.
--
-- · service_role: se revoca porque se comprobó que NO existe ningún llamador.
--   Evidencia (13/8/2026): pg_proc no devuelve ninguna función ni trigger cuyo
--   cuerpo mencione create_system_notification (0 filas), y ninguna Edge
--   Function de supabase/functions la referencia. Además la función se apoya
--   entera en auth.uid(), que con service_role es NULL: una llamada así
--   abortaría con 28000 de todos modos.
REVOKE EXECUTE ON FUNCTION public.create_system_notification(UUID, TEXT, TEXT, UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_system_notification(UUID, TEXT, TEXT, UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION public.create_system_notification(UUID, TEXT, TEXT, UUID) FROM service_role;
GRANT  EXECUTE ON FUNCTION public.create_system_notification(UUID, TEXT, TEXT, UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
