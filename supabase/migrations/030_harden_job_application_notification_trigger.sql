-- ============================================================================
-- 030 — Endurecer notify_job_application(): el aviso de postulación
-- ============================================================================
-- QUÉ RESUELVE
--
-- `trg_notify_job_application` (AFTER INSERT sobre public.job_applications)
-- ejecuta `notify_job_application()`, que tenía tres defectos, todos
-- verificados en vivo contra la base el 13/8/2026 con pg_get_functiondef:
--
--   1. GATE LEGACY CONTRA `public.profiles`. El aviso sólo se insertaba si
--      `EXISTS (SELECT 1 FROM public.profiles WHERE id = v_company_id)`. Es el
--      mismo patrón que la migración 028 elimina de `create_system_notification`
--      — o sea que 028 cerraba esa deuda sólo a medias. Con 20 de 61 usuarios
--      ausentes de `profiles` (dato de 027), había empresas que NUNCA se
--      enteraban de que alguien se postuló a su vacante, en silencio y sin
--      dejar rastro. La app abandonó `profiles` hace tiempo: escribe en
--      `public.users` y no menciona `profiles` ni una vez en todo `lib/`.
--
--   2. NO ESCRIBÍA `sender_name`, aunque ya leía el nombre del candidato para
--      armar el cuerpo. La notificación llegaba sin remitente.
--
--   3. NO TENÍA BLOQUE `EXCEPTION`. Al ser AFTER INSERT, cualquier error dentro
--      del aviso se propagaba y ABORTABA el INSERT de la postulación: el
--      candidato veía "Error al aplicar" por culpa de una notificación. Un
--      aviso no puede impedir que alguien se postule. `notify_push_on_notification`
--      (020:71-74) ya era best-effort; ésta no.
--
-- Se agrega además `SET search_path = public, pg_temp`, que no tenía: una
-- función SECURITY DEFINER con owner `postgres` sin search_path fijo es
-- secuestrable creando objetos homónimos en un esquema que el llamador
-- controle. Sus referencias a tablas ya estaban calificadas, pero los
-- operadores (el `||`) no lo están.
--
-- ============================================================================
-- QUÉ NO HACE ESTA MIGRACIÓN
-- ============================================================================
--
-- · NO llama a `create_system_notification`, ni antes ni después. El aviso se
--   inserta directo en `public.notifications`. Funciona porque la función es
--   SECURITY DEFINER con owner `postgres`, dueño de la tabla, y `notifications`
--   tiene RLS activa pero SIN `FORCE`: por eso la ausencia de política de
--   INSERT (ver 027) no la frena. Si alguien ejecutara
--   `ALTER TABLE public.notifications FORCE ROW LEVEL SECURITY`, este trigger
--   dejaría de insertar — ahora en silencio, porque el EXCEPTION lo atrapa.
--
-- · NO toca Dart. NO toca `028` ni `029`. NO toca `job_applications`.
--
-- ============================================================================
-- ⚠️ ORDEN DE DESPLIEGUE — ESTO IMPORTA MÁS QUE LA MIGRACIÓN EN SÍ
-- ============================================================================
--
-- Auditado el 13/8/2026: HOY EXISTEN DOS CAMINOS DE POSTULACIÓN DISTINTOS, y
-- cada uno hace la mitad de lo que debería.
--
--   A · Búsqueda   `search_screen.dart:485` → `JobCard`
--       INSERTA en job_applications (`job_card.dart:98-101`) → dispara este
--       trigger → 1 notificación. NO llama a ninguna RPC.
--
--   B · Vacantes   `jobs_screen.dart:556` → `_applyToJob` (`:257`)
--       NO INSERTA NADA. Sólo marca estado local (`:388`) y llama a
--       `create_system_notification` (`:397-402`). La empresa recibe el aviso
--       y NO QUEDA FILA DE POSTULACIÓN. Eso explica que haya 18 vacantes,
--       61 usuarios y UNA sola fila en `job_applications`.
--
-- El trigger será la FUENTE ÚNICA de notificaciones de postulación **cuando se
-- corrija `jobs_screen.dart`**: agregarle el INSERT que le falta y eliminar su
-- llamada a `create_system_notification` (`:397-402`). Hasta entonces conviven
-- los dos caminos, y un candidato que postule por Búsqueda y después "postule"
-- otra vez por Vacantes a la MISMA vacante genera DOS notificaciones.
--
-- **`028` NO DEBE APLICARSE ANTES DE ESE FIX DE DART.** El contrato de
-- autorización de 028 exige, para un `jobAlert` a un tercero, que exista una
-- fila en `job_applications` o en `ghost_applications` del candidato hacia esa
-- empresa. El camino B nunca la crea: tras 028 su llamada devuelve 42501, que
-- el `try/catch` de `jobs_screen.dart:404-406` traga con un `debugPrint`.
-- Resultado: la pantalla principal de Vacantes pasaría de 1 aviso a CERO sin
-- que nadie se entere.
--
-- ORDEN SEGURO, sin ventana de cero avisos ni de duplicados:
--   1. 030  (esta migración) — los dos caminos notifican, y ahora también a las
--            empresas ausentes de `profiles`. El duplicado sigue siendo posible,
--            igual que hoy: no empeora nada.
--   2. App con el fix de `jobs_screen.dart` — el camino B pasa a insertar y a
--            notificar por trigger; se le quita la RPC. Acá DESAPARECE el
--            duplicado y el trigger queda como fuente única.
--   3. 028  — ya ninguna ruta de postulación depende de esa RPC.
--   4. 029  — independiente de todo esto, cuando quieras.
--
-- ============================================================================
-- DEPENDENCIAS VERIFICADAS EN VIVO (13/8/2026)
-- ============================================================================
--   · public.notifications (user_id, type, title, body, is_read, sender_name)
--       — las seis existen (ver 020 y 027). NO existen `actor_id` ni
--       `description`, aunque schema.sql las declare: no se usan acá.
--   · public.users (id, name)                                  ✔
--   · public.jobs  (id, title, company_id)                     ✔
--       `company_id` es NULLABLE y referencia public.users(id).
--       Verificado: 18 vacantes, 0 con company_id NULL — pero la columna lo
--       permite, así que el caso se contempla igual.
--   · trigger vivo: `trg_notify_job_application AFTER INSERT ON
--       public.job_applications FOR EACH ROW EXECUTE FUNCTION
--       notify_job_application()`  ✔ ÚNICO trigger de esta función.
--   · Los GRANT por columna que introduce 029 (§5) NO afectan a este trigger:
--       el registro NEW llega completo al trigger, con los defaults ya
--       aplicados, sin importar qué columnas nombró el INSERT del cliente.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor. Idempotente.
-- NO se ejecuta como parte de este cambio.
-- ============================================================================


CREATE OR REPLACE FUNCTION public.notify_job_application()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
-- search_path fijo: sin esto, una función SECURITY DEFINER con owner
-- `postgres` es secuestrable. `pg_temp` va ÚLTIMO a propósito — si fuera
-- primero, una tabla u operador temporal podría suplantar a los de `public`.
SET search_path = public, pg_temp
AS $$
DECLARE
  v_candidate_name TEXT;
  v_job_title      TEXT;
  v_company_id     UUID;
BEGIN
  -- Se conserva el guard de TG_OP de la versión anterior: hoy el trigger es
  -- AFTER INSERT, así que siempre es 'INSERT', pero quitarlo sería un cambio
  -- de comportamiento que esta migración no necesita.
  IF TG_OP = 'INSERT' THEN

    -- TODO SALE DE LA BASE. El cliente no elige destinatario, título ni texto:
    -- el candidato se lee por NEW.candidate_id, y la vacante y su dueño por
    -- NEW.job_id. Nada de lo que viaja en el INSERT del cliente se usa como
    -- contenido — sólo como clave de búsqueda.
    SELECT u.name INTO v_candidate_name
    FROM public.users u
    WHERE u.id = NEW.candidate_id;

    SELECT j.title, j.company_id INTO v_job_title, v_company_id
    FROM public.jobs j
    WHERE j.id = NEW.job_id;

    -- Sin dueño no hay a quién notificar. Antes esto se mezclaba con el gate
    -- contra `profiles` en una sola condición y las dos causas eran
    -- indistinguibles; ahora la única razón legítima para no avisar queda
    -- explícita y deja rastro en el log.
    IF v_company_id IS NULL THEN
      RAISE WARNING
        'notify_job_application: la vacante % no tiene company_id; no se notifica. La postulación se creó igual.',
        NEW.job_id;
      RETURN NEW;
    END IF;

    -- EL GATE CONTRA public.profiles SE ELIMINÓ ACÁ.
    -- Ya no se comprueba la existencia del destinatario: la FK
    -- `notifications.user_id -> users(id)` la garantiza, y si el usuario no
    -- existiera el INSERT levantaría 23503 — un error visible en el log, no un
    -- descarte silencioso. Ésa era la deuda: 20 de 61 usuarios no están en
    -- `profiles` y sus empresas nunca recibían el aviso.
    INSERT INTO public.notifications (user_id, type, title, body, is_read, sender_name)
    VALUES (
      v_company_id,
      'jobAlert',
      '📩 Nueva postulación',
      COALESCE(v_candidate_name, 'Un candidato')
        || ' se postuló a "' || COALESCE(v_job_title, 'tu vacante') || '"',
      false,
      COALESCE(v_candidate_name, 'Un candidato')
    );

  END IF;

  RETURN NEW;

EXCEPTION WHEN OTHERS THEN
  -- BEST-EFFORT. Un aviso no puede impedir que alguien se postule.
  --
  -- El bloque EXCEPTION crea una subtransacción: si el INSERT en
  -- `notifications` falla, se revierte SÓLO ese INSERT y la postulación queda
  -- creada. Antes, sin este bloque, el error se propagaba y abortaba la
  -- transacción entera — el candidato veía "Error al aplicar" por culpa de una
  -- notificación.
  --
  -- El warning NO incluye el nombre del candidato, el cuerpo del mensaje ni el
  -- id de la empresa.
  --
  -- SOBRE `job_id`: es un identificador interno de una vacante, no un dato
  -- personal directo — no contiene nombre, email ni texto. Sólo puede
  -- resolverse a una persona (job → company_id → users) por quien ya tiene
  -- acceso suficiente a la base, o sea exactamente la misma gente que puede
  -- leer este log. No agrega exposición.
  --
  -- SOBRE `SQLERRM`: devuelve ÚNICAMENTE el mensaje primario del error. Los
  -- valores de la fila que falló no viajan ahí: viven en el campo DETAIL
  -- (`Key (user_id)=(…)`, `Failing row contains (…)`), al que sólo se llega con
  -- GET STACKED DIAGNOSTICS PG_EXCEPTION_DETAIL — y esta función NO lo
  -- consulta. Por eso el warning puede loguearse sin exponer datos de la fila,
  -- y conviene conservarlo: sin él el fallo vuelve a ser invisible, que es
  -- justo el problema que esta migración corrige.
  RAISE WARNING
    'notify_job_application: no se pudo notificar la postulación a la vacante % — % (%). La postulación NO se aborta.',
    NEW.job_id, SQLERRM, SQLSTATE;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.notify_job_application() IS
  'Avisa a la empresa dueña de la vacante que recibió una postulación. Todo el contenido se deriva de la base (users, jobs); el cliente no elige destinatario ni texto. Best-effort: nunca aborta la postulación. Sin gate contra la tabla legacy `profiles` desde la migración 030.';


-- ── El trigger NO se recrea ─────────────────────────────────────────────────
-- `CREATE OR REPLACE FUNCTION` conserva el OID de la función, y el trigger la
-- referencia por OID, no por nombre: `trg_notify_job_application` sigue
-- apuntando a esta misma función ya endurecida, sin tocarlo.
--
-- Recrearlo sería innecesario y arriesgaría dejar DOS triggers si el DROP y el
-- CREATE se ejecutaran por separado en el SQL Editor. Se deja exactamente como
-- está:
--
--   CREATE TRIGGER trg_notify_job_application
--     AFTER INSERT ON public.job_applications
--     FOR EACH ROW EXECUTE FUNCTION notify_job_application()
--
-- Para confirmar que sigue habiendo UNO SOLO, después de aplicar:
--   SELECT tgname FROM pg_trigger
--    WHERE tgrelid = 'public.job_applications'::regclass AND NOT tgisinternal;


-- ── Permisos ────────────────────────────────────────────────────────────────
-- Esta función NO es una RPC: sólo la invoca el trigger. Tenía EXECUTE para
-- PUBLIC, anon, authenticated y service_role, lo cual no servía para nada y
-- ampliaba la superficie — cualquiera podía llamarla directo por PostgREST.
--
-- Se revoca de los cuatro y NO se otorga a ningún cliente.
--
-- EL TRIGGER SIGUE FUNCIONANDO: PostgreSQL comprueba el privilegio EXECUTE
-- sobre la función del trigger al hacer CREATE TRIGGER, no cada vez que el
-- trigger se dispara. Al ejecutarse, la función la invoca el motor, no el
-- usuario que hizo el INSERT. Además `postgres` —owner de la función y de las
-- tablas— conserva su EXECUTE implícito, así que un futuro CREATE TRIGGER
-- también seguiría siendo posible.
REVOKE EXECUTE ON FUNCTION public.notify_job_application() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notify_job_application() FROM anon;
REVOKE EXECUTE ON FUNCTION public.notify_job_application() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_job_application() FROM service_role;

NOTIFY pgrst, 'reload schema';


-- ============================================================================
-- PRUEBAS PROPUESTAS — NO EJECUTADAS, NO FORMAN PARTE DE LA MIGRACIÓN
-- ============================================================================
-- Todo dentro de BEGIN … ROLLBACK.
--
-- ⚠️ Cada notificación insertada dispara `notify_push_on_notification`, que
-- manda un push FCM REAL. El ROLLBACK lo contiene. NO hacer COMMIT.
--
-- Andamiaje: se puede correr como `postgres` (el trigger es SECURITY DEFINER y
-- no depende de auth.uid()); para probar el INSERT tal como lo hace la app,
-- usar además:
--   SELECT set_config('request.jwt.claims',
--          json_build_object('sub','<UUID_CANDIDATO>')::text, true);
--   SET LOCAL ROLE authenticated;
--
--
-- T1 · EL CASO QUE ORIGINÓ ESTA MIGRACIÓN
--      Empresa que EXISTE en public.users pero NO en public.profiles.
--      Elegir una así:
--        SELECT u.id FROM public.users u
--         WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = u.id)
--         LIMIT 1;
--      Crear una vacante suya, insertar una postulación y verificar:
--        → ANTES de 030: 0 notificaciones.
--        → DESPUÉS de 030: EXACTAMENTE 1 notificación para esa empresa.
--
-- T2 · sender_name correcto
--      Tras un INSERT real, la notificación debe traer:
--        sender_name = users.name del candidato (no NULL, no 'Un candidato'
--                      salvo que el usuario realmente no tenga nombre)
--        title       = '📩 Nueva postulación'
--        type        = 'jobAlert'
--        is_read     = false
--        body        contiene el nombre del candidato y el título de la vacante
--
-- T3 · company_id NULL
--      UPDATE public.jobs SET company_id = NULL WHERE id = <job>;  -- dentro del BEGIN
--      INSERT de la postulación →
--        · la fila de job_applications SE CREA;
--        · NO se inserta ninguna notificación;
--        · aparece el RAISE WARNING con el job_id.
--
-- T4 · ERROR DELIBERADO QUE NO DEBE ABORTAR LA POSTULACIÓN
--
--      ⚠️ ADVERTENCIA OPERATIVA — LEER ANTES DE CORRERLA
--      `ALTER TABLE … ADD CONSTRAINT` toma un lock ACCESS EXCLUSIVE sobre
--      `public.notifications`: mientras dure la transacción, TODA lectura y
--      escritura de notificaciones queda bloqueada, en toda la plataforma.
--      El DDL es transaccional, así que el ROLLBACK no deja ningún objeto
--      persistente — pero el LOCK sí dura lo que dure la sesión abierta.
--      Una sesión olvidada sin cerrar bloquea `notifications` indefinidamente.
--        · Ejecutar SÓLO fuera del horario pico.
--        · Cerrar INMEDIATAMENTE con ROLLBACK; no dejar la transacción abierta.
--        · El `lock_timeout` de abajo hace que, si la tabla está ocupada, el
--          ALTER falle en 2 segundos en vez de encolarse detrás de otros.
--
--      Forzar que el INSERT en notifications falle, sin tocar el esquema
--      permanentemente:
--        SET LOCAL lock_timeout = '2s';
--        ALTER TABLE public.notifications
--          ADD CONSTRAINT tmp_forzar_fallo CHECK (false) NOT VALID;
--      (NOT VALID sólo afecta a filas nuevas, así que no valida las existentes)
--      Después, INSERT de una postulación →
--        · la fila de job_applications SE CREA  ← lo que se está probando;
--        · 0 notificaciones;
--        · RAISE WARNING con SQLSTATE 23514.
--      Y a continuación, sin excepción:
--        ROLLBACK;
--      ANTES de 030 esta misma prueba abortaba el INSERT con error.
--
-- T5 · EXACTAMENTE UNA NOTIFICACIÓN POR INSERT REAL
--      Contar antes y después de un único INSERT:
--        SELECT count(*) FROM public.notifications
--         WHERE user_id = <empresa> AND type = 'jobAlert';
--      La diferencia debe ser 1 — ni 0 ni 2. Comprueba de paso que no quedó un
--      segundo trigger duplicado.
--
-- T6 · REGRESIÓN DE PERMISOS
--      Como `authenticated`, llamar la función directo debe fallar:
--        SELECT public.notify_job_application();   → 42501 permission denied
--      …y sin embargo el INSERT de una postulación debe seguir generando su
--      notificación. Es la prueba de que revocar EXECUTE no rompe el trigger.
-- ============================================================================
