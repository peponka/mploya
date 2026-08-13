-- ============================================================================
-- 029 — ATS canónico sobre job_applications (contrato B′)
-- ============================================================================
-- QUÉ RESUELVE
--
-- El sistema no podía registrar una contratación. `job_applications.status`
-- admitía sólo (pending|viewed|accepted|rejected) y la etapa "real" del ATS
-- vivía en `connections.ats_status` — una columna SIN CHECK, con vocabulario
-- en español (pendiente/revision/entrevista/contratar/rechazado) que NINGUNA
-- ruta productiva escribe, sobre una tabla que no tiene `job_id` y por lo tanto
-- no puede distinguir dos postulaciones del mismo candidato a dos vacantes de
-- la misma empresa.
--
-- Esta migración mueve la etapa a `job_applications`, que ya es la entidad
-- (candidato × vacante) con UNIQUE (job_id, candidate_id) y de la que se deriva
-- la empresa vía `jobs.company_id`. NO crea ninguna entidad nueva.
--
-- VOCABULARIO CANÓNICO (B′)
--   pending · viewed · interviewing · accepted · hired · rejected
--
-- Es aditivo: conserva los cuatro valores existentes y agrega los dos que
-- faltaban. Se eligió así porque las pantallas congeladas YA hablan este
-- vocabulario — `empresa_dashboard_data.dart:111-115` documenta el mapeo
-- Screening='viewed' / Oferta='accepted' / Contratados='hired'. Renombrar
-- habría roto tres pantallas congeladas sin ganar nada.
--
-- `accepted` = oferta / listo para contratar. NO es una contratación.
-- `hired`    = contratación consumada. Único estado que llena `hired_at`.
--
-- ============================================================================
-- 🚨 EL BLOQUEO QUE ESTA MIGRACIÓN CIERRA, Y POR QUÉ EL ORDEN NO ES OPCIONAL
-- ============================================================================
--
-- Auditado el 13/8/2026 contra la base real: `job_applications` tenía 28
-- políticas RLS, todas PERMISSIVE (o sea, combinadas con OR: manda la más
-- laxa). Dos de las cinco de UPDATE —`rls_ja_update` y `applications_update`—
-- incluían `auth.uid() = candidate_id`, y NINGUNA de las cinco tenía
-- `WITH CHECK`. En un UPDATE sin `WITH CHECK`, Postgres aplica el `USING`
-- también a la fila nueva.
--
-- Consecuencia: EL CANDIDATO PODÍA ESCRIBIR SU PROPIO `status`. Lo único que
-- lo frenaba era que el CHECK no admitía 'hired'. En el instante en que se
-- amplía el CHECK, cualquier candidato puede AUTO-CONTRATARSE con una llamada
-- PostgREST directa — sin cliente modificado. Y
-- `company_verification_service.dart:194` cuenta esas filas para otorgar el
-- nivel `trusted` a la empresa.
--
-- Y había un segundo agujero, en el INSERT: la política sólo exigía
-- `candidate_id = auth.uid()`, así que un candidato podía INSERTAR
-- directamente una fila con status='hired' y hired_at informado. El invariante
-- de coherencia no lo tapa: una fila con ambos campos puestos lo satisface.
--
-- POR ESO EL ORDEN ES: primero se cierra la escritura directa (§2 y §4),
-- DESPUÉS se amplía el CHECK (§6). En ningún momento coexisten un CHECK que
-- admita 'hired' y una política que permita auto-asignárselo.
--
-- El BEGIN/COMMIT explícito hace que nadie vea estados intermedios. Pero las
-- migraciones de este proyecto se aplican pegándolas en el SQL Editor (ver
-- cabeceras de 020, 027 y 028), donde es posible ejecutar por partes: el orden
-- §2→§6 protege incluso en ese caso. Las dos cosas, no una.
--
-- ============================================================================
-- DEPENDENCIAS VERIFICADAS EN VIVO (13/8/2026)
-- ============================================================================
--   · CHECK actual: `job_applications_status_check`
--       CHECK ((status = ANY (ARRAY['pending','viewed','accepted','rejected'])))
--   · job_applications (id, job_id, candidate_id, status, created_at,
--       is_favorite) · UNIQUE (job_id, candidate_id) · 1 fila (status='accepted')
--   · jobs (id, company_id → public.users) · 18 filas, 0 sin company_id,
--       12 empresas distintas, 18/18 son usuarios de auth
--   · `jobs.company_id` ES `auth.uid()` directamente. NO existe entidad
--       organización: una empresa es un usuario. Si alguna vez hay equipos,
--       esto se rompe y hará falta una tabla de membresías.
--   · Trigger existente: `trg_notify_job_application` AFTER INSERT → no
--       colisiona con el BEFORE UPDATE que se agrega acá.
--   · Escrituras reales a la tabla: UNA sola desde Dart —
--       `job_card.dart:98`, un INSERT que manda SÓLO job_id y candidate_id.
--       Cero UPDATE, cero DELETE, cero Edge Functions. Por eso revocar el
--       UPDATE directo no rompe ninguna ruta productiva.
--   · `update_application_status(uuid,text)` YA EXISTÍA con la firma correcta:
--       acá se reemplaza el cuerpo (CREATE OR REPLACE conserva owner y ACL).
--   · `toggle_candidate_favorite(uuid)` autoriza bien (j.company_id=auth.uid())
--       y no tiene NINGÚN consumidor en Dart. No se toca su cuerpo.
--
-- ============================================================================
-- ⚠️ DE QUÉ DEPENDE QUE ESTO FUNCIONE — LEER ANTES DE "ENDURECER" LA BASE
-- ============================================================================
--
-- `update_application_status`, `toggle_candidate_favorite` y
-- `get_company_candidates` son SECURITY DEFINER con owner `postgres`, que es
-- el dueño de `job_applications` y de `jobs`. Esas tablas tienen RLS ACTIVA
-- pero `relforcerowsecurity = false` (verificado), y la RLS no se aplica al
-- dueño salvo que se active FORCE. Eso es lo que permite que estas funciones
-- sigan escribiendo y leyendo después de que esta migración deje a
-- `job_applications` SIN NINGUNA política de UPDATE.
--
-- Si alguien ejecuta `ALTER TABLE public.job_applications FORCE ROW LEVEL
-- SECURITY` (o lo mismo sobre `jobs`), las tres funciones dejan de funcionar y
-- el ATS entero se cae. No es hipotético: es la clase de cambio que se hace
-- "por seguridad" sin ver qué depende de él.
--
-- MANTENIMIENTO: los `GRANT ALL ON ALL TABLES` por defecto de Supabase pueden
-- reponer los privilegios que esta migración revoca. Si alguien corre un
-- script genérico de permisos, hay que volver a aplicar el §5.
--
-- ============================================================================
-- FECHAS HISTÓRICAS: QUEDAN NULL, A PROPÓSITO
-- ============================================================================
--
-- `stage_changed_at` y `hired_at` se agregan NULLABLE, SIN DEFAULT y SIN
-- backfill. Un `NOT NULL DEFAULT now()` le estamparía la fecha de HOY a la
-- única fila existente, que tiene status='accepted' y se postuló hace más de
-- un día: sería una fecha inventada. Backfillear con `created_at` tampoco
-- sirve — afirmaría que pasó a "Oferta" el día que se postuló, y sabemos que
-- no fue así.
--
-- NULL significa "no se registró", que es verdad. El trigger las puebla desde
-- el primer cambio REAL de etapa. Las pantallas muestran "—" para las filas
-- anteriores a esta migración: hay exactamente UNA. `hired_at` arranca NULL en
-- todo, porque no existe ninguna contratación en el sistema.
--
-- Esto es una CORRECCIÓN de la propuesta de diseño previa, que decía
-- `stage_changed_at TIMESTAMPTZ NOT NULL DEFAULT now()`. Estaba mal.
--
-- ============================================================================
-- FUERA DE ALCANCE, A PROPÓSITO
-- ============================================================================
--   · estado `withdrawn` (retirarse como cambio de estado, no como DELETE)
--   · política de INSERT para sourcing (la empresa crea la candidatura)
--   · tabla de historial `job_application_events`
--   · cuerpos de get_company_candidates y toggle_candidate_favorite
--   · connections.ats_status / set_pipeline_status / get_my_pipeline (deprecar
--     después, cuando nada los lea)
--   · TODO Dart. Esta migración es sólo SQL.
--
-- CONSECUENCIA CONOCIDA de la política de DELETE: con UNIQUE (job_id,
-- candidate_id), un candidato en estado 'rejected' NO puede volver a postularse
-- a esa vacante, porque su fila no se borra. La solución principista es el
-- estado `withdrawn`, que queda como decisión de producto pendiente.
--
-- ============================================================================
-- DEUDA SEPARADA, ANOTADA ACÁ Y NO RESUELTA: notify_job_application()
-- ============================================================================
--
-- El trigger `trg_notify_job_application` (AFTER INSERT sobre esta misma tabla)
-- ejecuta `notify_job_application()`, que TODAVÍA condiciona el aviso a
-- `EXISTS (SELECT 1 FROM public.profiles WHERE id = v_company_id)`. Es el mismo
-- gate contra la tabla legacy que la migración 028 elimina de
-- `create_system_notification` — o sea que 028 cierra esa deuda sólo a medias.
-- Con 20 de 61 usuarios ausentes de `profiles` (dato de 027), hay empresas que
-- nunca se enteran de que alguien se postuló a su vacante, en silencio.
--
-- Dos problemas más de la misma función, del mismo diagnóstico:
--   · no escribe `sender_name`, aunque ya lee el nombre del candidato;
--   · no tiene bloque EXCEPTION, así que un fallo del aviso ABORTA el INSERT
--     de la postulación (a diferencia de notify_push_on_notification, que es
--     best-effort — ver 020:71-74).
--
-- SE RESOLVERÁ EN UNA MIGRACIÓN 030 SEPARADA. No pertenece al alcance ATS de
-- esta migración y NO la bloquea: 029 no toca ese trigger, no toca
-- `notifications` y no depende de que el aviso funcione. Verificado que los
-- GRANT por columna de §5 no afectan su ejecución — el registro NEW llega
-- completo al trigger y su INSERT corre como `postgres`.
--
-- 030 arrastra además un cambio en Dart que NO se hace acá: `jobs_screen.dart`
-- notifica sin insertar en job_applications, y `job_card.dart` inserta sin
-- notificar. Son dos caminos de postulación distintos. Ordenarlos es parte de
-- 030, no de 029.
--
-- NO se ejecuta como parte de este cambio. Ejecutar en: Supabase Dashboard →
-- SQL Editor. Idempotente: se puede correr dos veces sin daño.
-- ============================================================================


BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
-- §2 · CIERRE INMEDIATO DE LA ESCRITURA DIRECTA
--      Va PRIMERO. Nada de lo que sigue amplía el CHECK todavía.
-- ────────────────────────────────────────────────────────────────────────────

REVOKE INSERT, UPDATE, DELETE ON public.job_applications FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.job_applications FROM authenticated;

-- Las 5 políticas de UPDATE. Dos de ellas (rls_ja_update, applications_update)
-- son las que permitían al candidato escribir su propio status.
DROP POLICY IF EXISTS "Companies can update application status" ON public.job_applications;
DROP POLICY IF EXISTS "applications_update"                     ON public.job_applications;
DROP POLICY IF EXISTS "job_applications_update_company"         ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_update_company"                 ON public.job_applications;
DROP POLICY IF EXISTS "rls_ja_update"                           ON public.job_applications;


-- ────────────────────────────────────────────────────────────────────────────
-- §3 · COLUMNAS NUEVAS — nullable, sin DEFAULT, sin backfill (ver cabecera)
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.job_applications
  ADD COLUMN IF NOT EXISTS stage_changed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS hired_at         TIMESTAMPTZ;

COMMENT ON COLUMN public.job_applications.stage_changed_at IS
  'Momento del último cambio de `status`. NULL = fila anterior a la migración 029: no se registró. No se rellena con una fecha inventada.';
COMMENT ON COLUMN public.job_applications.hired_at IS
  'Momento de la contratación. NOT NULL si y sólo si status = ''hired'' (constraint job_applications_hired_at_coherente). Se limpia si se revierte la contratación.';


-- ────────────────────────────────────────────────────────────────────────────
-- §4 · RLS: eliminar las 23 duplicadas restantes y dejar exactamente TRES
--      (las 5 de UPDATE ya se eliminaron en §2 — total auditado: 28)
-- ────────────────────────────────────────────────────────────────────────────

-- SELECT (12) — todas son variantes de "candidato propio", "empresa dueña" o
-- el OR de ambas. Su unión es exactamente `ja_select`.
DROP POLICY IF EXISTS "Candidates can view own applications"         ON public.job_applications;
DROP POLICY IF EXISTS "Companies can view applications to own jobs"  ON public.job_applications;
DROP POLICY IF EXISTS "applications_select"                          ON public.job_applications;
DROP POLICY IF EXISTS "apps_read_own"                                ON public.job_applications;
DROP POLICY IF EXISTS "job_applications_select_company"              ON public.job_applications;
DROP POLICY IF EXISTS "job_applications_select_own_candidate"        ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_candidate_read"                      ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_company_read"                        ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_select"                              ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_select_company"                      ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_select_own"                          ON public.job_applications;
DROP POLICY IF EXISTS "rls_ja_select"                                ON public.job_applications;

-- INSERT (8) — las ocho son idénticas: WITH CHECK (auth.uid() = candidate_id).
-- Ninguna exigía status ni fechas: ése era el segundo agujero.
DROP POLICY IF EXISTS "Candidates can apply to jobs"                 ON public.job_applications;
DROP POLICY IF EXISTS "applications_insert"                          ON public.job_applications;
DROP POLICY IF EXISTS "apps_insert_own"                              ON public.job_applications;
DROP POLICY IF EXISTS "job_applications_insert_own"                  ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_candidate_insert"                    ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_insert"                              ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_insert_candidate"                    ON public.job_applications;
DROP POLICY IF EXISTS "rls_ja_insert"                                ON public.job_applications;

-- DELETE (3) — las tres idénticas: USING (auth.uid() = candidate_id), sin
-- restricción de etapa. Permitían borrar una contratación.
DROP POLICY IF EXISTS "Candidates can withdraw own applications"     ON public.job_applications;
DROP POLICY IF EXISTS "job_applications_delete_own"                  ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_delete_candidate"                    ON public.job_applications;

-- Las tres nuevas (drop previo para que la migración sea reejecutable).
DROP POLICY IF EXISTS ja_select            ON public.job_applications;
DROP POLICY IF EXISTS ja_insert_candidate  ON public.job_applications;
DROP POLICY IF EXISTS ja_delete_candidate  ON public.job_applications;

CREATE POLICY ja_select ON public.job_applications
  FOR SELECT TO authenticated
  USING (
    candidate_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.jobs j
      WHERE j.id = job_applications.job_id
        AND j.company_id = auth.uid()
    )
  );

-- El candidato sólo puede CREAR su postulación, y sólo en el estado inicial.
-- Las tres condiciones extra son las que cierran el agujero del INSERT.
CREATE POLICY ja_insert_candidate ON public.job_applications
  FOR INSERT TO authenticated
  WITH CHECK (
    candidate_id         = auth.uid()
    AND status           = 'pending'
    AND stage_changed_at IS NULL
    AND hired_at         IS NULL
  );

-- Retirarse sólo antes de que haya compromiso de la empresa. Una contratación
-- NO puede desaparecer por DELETE, ni del candidato ni de la empresa: la
-- empresa no recibe política de DELETE, así que le aplica deny-by-default.
CREATE POLICY ja_delete_candidate ON public.job_applications
  FOR DELETE TO authenticated
  USING (
    candidate_id = auth.uid()
    AND status IN ('pending', 'viewed')
  );

-- NINGUNA política de UPDATE, a propósito. RLS es deny-by-default: sin
-- política, todo UPDATE desde el cliente se rechaza. La única vía de cambio de
-- etapa es la RPC de §9.


-- ────────────────────────────────────────────────────────────────────────────
-- §5 · PRIVILEGIOS MÍNIMOS
--      El GRANT por columna es lo que vuelve inalcanzable el agujero del
--      INSERT: el cliente no puede siquiera NOMBRAR status ni las fechas, y
--      —clave— cualquier columna que se agregue en el futuro queda excluida
--      por omisión, en vez de heredarse como pasa con un GRANT de tabla.
-- ────────────────────────────────────────────────────────────────────────────

GRANT INSERT (job_id, candidate_id) ON public.job_applications TO authenticated;
GRANT DELETE                        ON public.job_applications TO authenticated;

-- anon no recupera nada: sin INSERT, sin UPDATE, sin DELETE.
-- authenticated NO recupera UPDATE: no existe ninguna ruta productiva que lo
-- necesite (verificado: cero `.update()` sobre esta tabla en todo lib/).
-- SELECT se deja intacto para ambos: lo acota la política ja_select.
--
-- ⚠️ CONTRATO PARA EL CLIENTE: al insertar una postulación NO se debe enviar
-- `status`, NI SIQUIERA con el valor por defecto 'pending'. El GRANT de arriba
-- sólo habilita `job_id` y `candidate_id`: nombrar cualquier otra columna hace
-- fallar el INSERT con "permission denied for column", ANTES de que la RLS
-- llegue a evaluarse — o sea que el mensaje de error no menciona la política y
-- el motivo real queda poco obvio. `status`, `id`, `created_at` e `is_favorite`
-- se resuelven solos por default. Así lo hace hoy `job_card.dart:98-101`, que
-- manda exactamente esos dos campos.


-- ────────────────────────────────────────────────────────────────────────────
-- §6 · CHECK ampliado — RECIÉN ACÁ, con la escritura directa ya cerrada
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.job_applications
  DROP CONSTRAINT IF EXISTS job_applications_status_check;

ALTER TABLE public.job_applications
  ADD CONSTRAINT job_applications_status_check
  CHECK (status IN ('pending', 'viewed', 'interviewing', 'accepted', 'hired', 'rejected'));


-- ────────────────────────────────────────────────────────────────────────────
-- §7 · INVARIANTE hired_at ↔ status
--      Valida contra la fila existente: status='accepted' y hired_at IS NULL
--      → (false) = (false) → pasa.
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.job_applications
  DROP CONSTRAINT IF EXISTS job_applications_hired_at_coherente;

ALTER TABLE public.job_applications
  ADD CONSTRAINT job_applications_hired_at_coherente
  CHECK ((status = 'hired') = (hired_at IS NOT NULL));


-- ────────────────────────────────────────────────────────────────────────────
-- §8 · TRIGGER BEFORE UPDATE — fechas de etapa
--      La cláusula WHEN expresa "actuar únicamente cuando status cambie": si
--      status no cambia, el trigger ni siquiera se dispara y las fechas quedan
--      intactas.
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.job_application_stage_dates()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  -- GUARDA REDUNDANTE, a propósito. La condición real vive en el WHEN del
  -- trigger, pero si alguien lo recreara sin ese WHEN —o reutilizara esta
  -- función en otro trigger— el cuerpo estamparía la fecha en CUALQUIER
  -- UPDATE. La invariante "las fechas sólo se mueven si cambió la etapa" tiene
  -- que sobrevivir a que le saquen el WHEN.
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.stage_changed_at := now();

    IF NEW.status = 'hired' THEN
      NEW.hired_at := now();
    ELSIF OLD.status = 'hired' THEN
      -- Se revierte una contratación: el invariante exige limpiar la fecha.
      -- Se PIERDE la fecha original de contratación. Ése es el costo de no
      -- tener tabla de historial, y es el criterio concreto para construirla:
      -- si auditar correcciones pasa a ser un requisito, deja de ser opcional.
      NEW.hired_at := NULL;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_job_application_stage_dates ON public.job_applications;
CREATE TRIGGER trg_job_application_stage_dates
  BEFORE UPDATE ON public.job_applications
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.job_application_stage_dates();


-- ────────────────────────────────────────────────────────────────────────────
-- §9 · RUTA PRODUCTIVA ÚNICA DE CAMBIO DE ETAPA
--      CREATE OR REPLACE: la firma no cambia, así que conserva owner y ACL.
--
--      MATRIZ APROBADA (✅ permitido · ❌ prohibido · ↩︎ retroceso de corrección)
--
--        De ↓ / A →     pending  viewed  interviewing  accepted  hired  rejected
--        pending           —       ✅         ✅           ✅       ❌      ✅
--        viewed           ↩︎        —         ✅           ✅       ❌      ✅
--        interviewing      ❌      ↩︎          —           ✅       ❌      ✅
--        accepted          ❌      ❌        ↩︎             —       ✅      ✅
--        hired             ❌      ❌         ❌          ↩︎         —      ✅
--        rejected          ✅      ✅         ✅           ✅       ❌       —
--
--      · A 'hired' SÓLO se llega desde 'accepted': toda contratación pasa por
--        la oferta. No se puede saltar.
--      · Desde 'hired' sólo se sale a 'accepted' (me equivoqué) o 'rejected'
--        (la contratación se cayó).
--      · 'rejected' se reabre a cualquier etapa MENOS 'hired'.
--      · Se puede saltar hacia adelante (equipos chicos no marcan cada etapa),
--        pero nunca hacia 'hired'.
--
--      DECISIÓN EXPLÍCITA, VETABLE: si p_status es igual al estado actual, la
--      función retorna sin error y sin tocar fechas (idempotencia, para que un
--      doble toque en la UI no reviente). La diagonal de la matriz es "—", así
--      que no es una transición: es un no-op.
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.update_application_status(
  p_application_id UUID,
  p_status         TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor   UUID := auth.uid();
  v_current TEXT;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'update_application_status: sin sesión activa'
      USING ERRCODE = '28000';
  END IF;

  IF p_application_id IS NULL THEN
    RAISE EXCEPTION 'update_application_status: p_application_id es obligatorio'
      USING ERRCODE = '22023';
  END IF;

  -- Lista blanca cerrada. El chequeo de NULL va aparte: `NULL NOT IN (...)`
  -- evalúa a NULL, que en un IF se comporta como falso y dejaría pasar un tipo
  -- nulo.
  IF p_status IS NULL
     OR p_status NOT IN ('pending','viewed','interviewing','accepted','hired','rejected')
  THEN
    RAISE EXCEPTION 'update_application_status: estado no permitido (%)', p_status
      USING ERRCODE = '22023';
  END IF;

  -- BLOQUEO ANTES DE DECIDIR LA TRANSICIÓN. Se bloquean LAS DOS filas, y cada
  -- una protege algo distinto:
  --
  --   · `ja` — evita carreras de ESTADO. Sin este bloqueo, dos llamadas
  --     concurrentes leerían el mismo `status` actual y aplicarían dos
  --     transiciones que por separado son válidas y juntas no lo son: por
  --     ejemplo accepted→hired dos veces, o accepted→rejected en paralelo con
  --     accepted→hired.
  --
  --   · `j`  — estabiliza la PROPIEDAD de la vacante. La autorización de esta
  --     función es `j.company_id = auth.uid()`, un dato que vive en `jobs`:
  --     bloquear sólo `ja` dejaría esa condición libre de cambiar entre la
  --     autorización y el UPDATE final.
  --
  -- `FOR UPDATE OF ja, j` es válido acá porque el JOIN es INNER: FOR UPDATE
  -- sólo está prohibido sobre el lado nullable de un OUTER JOIN. Ambas tablas
  -- se bloquean siempre en el mismo orden, así que estas llamadas no pueden
  -- deadlockear entre sí.
  SELECT ja.status INTO v_current
  FROM public.job_applications ja
  JOIN public.jobs j ON j.id = ja.job_id
  WHERE ja.id = p_application_id
    AND j.company_id = v_actor
  FOR UPDATE OF ja, j;

  -- "No existe" y "no pertenece" se CONFLACIONAN A PROPÓSITO, en un solo error
  -- con el mismo SQLSTATE. Distinguirlos convertiría a esta función en un
  -- oráculo de enumeración: cualquier empresa podría barrer UUIDs y descubrir
  -- qué postulaciones existen en el resto de la plataforma. El llamador
  -- legítimo no necesita la distinción — para él las dos significan lo mismo:
  -- "esta postulación no es tuya".
  IF NOT FOUND THEN
    RAISE EXCEPTION
      'update_application_status: la postulación % no existe o no pertenece a una vacante de la empresa autenticada',
      p_application_id
      USING ERRCODE = '42501';
  END IF;

  -- No-op idempotente (ver nota de la cabecera de §9).
  IF v_current = p_status THEN
    RETURN;
  END IF;

  IF NOT (
       (v_current = 'pending'      AND p_status IN ('viewed','interviewing','accepted','rejected'))
    OR (v_current = 'viewed'       AND p_status IN ('pending','interviewing','accepted','rejected'))
    OR (v_current = 'interviewing' AND p_status IN ('viewed','accepted','rejected'))
    OR (v_current = 'accepted'     AND p_status IN ('interviewing','hired','rejected'))
    OR (v_current = 'hired'        AND p_status IN ('accepted','rejected'))
    OR (v_current = 'rejected'     AND p_status IN ('pending','viewed','interviewing','accepted'))
  ) THEN
    RAISE EXCEPTION 'update_application_status: transición no permitida % → %',
      v_current, p_status
      USING ERRCODE = '42501';
  END IF;

  -- Las fechas las pone el trigger de §8, no esta función.
  --
  -- La propiedad se REVALIDA acá como DEFENSA ADICIONAL, no como el mecanismo
  -- principal: quien cierra la carrera es el `FOR UPDATE OF ja, j` de arriba,
  -- que mantiene bloqueada la vacante durante toda la transición. Este EXISTS
  -- no la elimina por sí solo — un UPDATE sin bloqueo previo seguiría teniendo
  -- una ventana entre su propia evaluación y la escritura. Lo que aporta es
  -- que la condición de autorización quede escrita también en la sentencia que
  -- escribe, de modo que si alguien quitara el bloqueo del SELECT la función no
  -- pase a autorizar por omisión. Cuesta un EXISTS.
  UPDATE public.job_applications ja
  SET status = p_status
  WHERE ja.id = p_application_id
    AND EXISTS (
      SELECT 1
      FROM public.jobs j
      WHERE j.id = ja.job_id
        AND j.company_id = v_actor
    );

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'update_application_status: la postulación % dejó de pertenecer a la empresa autenticada durante la transacción',
      p_application_id
      USING ERRCODE = '42501';
  END IF;
END;
$$;

COMMENT ON FUNCTION public.update_application_status(UUID, TEXT) IS
  'Única ruta productiva de cambio de etapa de una postulación. Sólo la empresa dueña de la vacante. Valida la matriz de transiciones y falla explícitamente. Ver migración 029.';


-- ────────────────────────────────────────────────────────────────────────────
-- §10 · ENDURECER LAS OTRAS DOS RPC SIN TOCAR SUS CUERPOS
--       Ambas son SECURITY DEFINER con owner `postgres` y NO tenían
--       search_path fijo, lo que las vuelve secuestrables creando objetos
--       homónimos en un esquema que el llamador controle.
-- ────────────────────────────────────────────────────────────────────────────

ALTER FUNCTION public.get_company_candidates(TEXT)    SET search_path = public, pg_temp;
ALTER FUNCTION public.toggle_candidate_favorite(UUID) SET search_path = public, pg_temp;


-- ────────────────────────────────────────────────────────────────────────────
-- §11 · EXECUTE: sólo authenticated
--       Las tres se apoyan en auth.uid(); con service_role es NULL y no
--       podrían hacer nada útil. Verificado el 13/8: ninguna función, trigger
--       ni Edge Function las llama con service_role.
-- ────────────────────────────────────────────────────────────────────────────

REVOKE EXECUTE ON FUNCTION public.update_application_status(UUID, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_application_status(UUID, TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.update_application_status(UUID, TEXT) FROM service_role;
GRANT  EXECUTE ON FUNCTION public.update_application_status(UUID, TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_company_candidates(TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_company_candidates(TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_company_candidates(TEXT) FROM service_role;
GRANT  EXECUTE ON FUNCTION public.get_company_candidates(TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.toggle_candidate_favorite(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.toggle_candidate_favorite(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION public.toggle_candidate_favorite(UUID) FROM service_role;
GRANT  EXECUTE ON FUNCTION public.toggle_candidate_favorite(UUID) TO authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';


-- ============================================================================
-- PRUEBAS PROPUESTAS — NO EJECUTADAS, NO FORMAN PARTE DE LA MIGRACIÓN
-- ============================================================================
-- Todo dentro de BEGIN … ROLLBACK. Andamiaje por caso:
--
--   BEGIN;
--   SELECT set_config('request.jwt.claims',
--          json_build_object('sub','<UUID>')::text, true);
--   SET LOCAL ROLE authenticated;
--   -- … caso …
--   ROLLBACK;
--
-- ── PERMITIDOS (la RPC no debe levantar excepción) ─────────────────────────
--  A1  empresa dueña: pending      → viewed          · stage_changed_at se puebla
--  A2  empresa dueña: pending      → accepted        · salto hacia adelante OK
--  A3  empresa dueña: interviewing → accepted
--  A4  empresa dueña: accepted     → hired           · hired_at se puebla
--  A5  empresa dueña: hired        → accepted        · hired_at vuelve a NULL
--  A6  empresa dueña: hired        → rejected        · hired_at vuelve a NULL
--  A7  empresa dueña: rejected     → interviewing    · reapertura
--  A8  empresa dueña: viewed       → viewed          · no-op, sin error y SIN
--                                                      tocar stage_changed_at
--  A9  candidato: INSERT (job_id, candidate_id)      · sigue funcionando igual
--                                                      que job_card.dart:98
-- A10  candidato: DELETE de su postulación en 'pending'
--
-- ── RECHAZADOS (SQLSTATE esperado) ─────────────────────────────────────────
--  R1  sin sesión (rol anon)                          42501 permission denied
--  R2  authenticated sin claims                       28000
--  R3  p_application_id NULL                          22023
--  R4  p_status NULL                                  22023
--  R5  p_status = 'contratado' (vocabulario viejo)    22023
--  R6  p_status = 'hired' desde 'pending'             42501 transición inválida
--  R7  p_status = 'hired' desde 'interviewing'        42501
--  R8  p_status = 'hired' desde 'rejected'            42501
--  R9  p_status = 'pending' desde 'hired'             42501
-- R10  postulación de OTRA empresa                    42501
-- R11  postulación inexistente (uuid random)          42501
--
-- ── EL BLOQUEO QUE ORIGINÓ ESTA MIGRACIÓN — probar SÍ o SÍ ─────────────────
-- R12  candidato: UPDATE directo `.update({status:'hired'})` sobre su propia
--      postulación                                    → debe fallar (sin
--      política de UPDATE y sin privilegio UPDATE)
-- R13  candidato: INSERT con status='hired' y hired_at=now()
--                                                     → debe fallar por
--      privilegio de columna ANTES de llegar a la RLS
-- R14  candidato: INSERT con status='viewed'          → debe fallar igual
-- R15  candidato: DELETE de una postulación en 'hired'
--                                                     → 0 filas afectadas
-- R16  candidato: DELETE de una postulación en 'accepted' o 'rejected'
--                                                     → 0 filas afectadas
--
-- ── INVARIANTES / REGRESIONES ──────────────────────────────────────────────
--  I1  UPDATE que NO cambia status (p. ej. is_favorite vía
--      toggle_candidate_favorite) → stage_changed_at y hired_at SIN cambios
--  I2  toggle_candidate_favorite sigue funcionando pese a no existir ninguna
--      política de UPDATE (depende de SECURITY DEFINER + ausencia de FORCE RLS)
--  I3  get_company_candidates sigue devolviendo las mismas columnas —
--      empresa_crear_entrevista_data.dart:63 la consume y esa pantalla está
--      fuera de alcance
--  I4  la fila preexistente conserva stage_changed_at IS NULL hasta su primer
--      cambio real de etapa
--  I5  company_verification_service (status='hired') empieza a poder contar
--      sin ningún cambio en Dart
-- ============================================================================
