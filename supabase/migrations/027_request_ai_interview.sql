-- ============================================================================
-- 027 — request_ai_interview: pedir una entrevista con IA, del lado del servidor
-- ============================================================================
-- PROBLEMA QUE RESUELVE (diagnosticado el 12/8/2026 contra la base REAL)
--
-- Empresa creaba la entrevista desde Flutter y después intentaba insertar la
-- notificación del candidato con un INSERT directo:
--
--     client.from('notifications').insert({...})
--
-- Ese INSERT **nunca pudo funcionar**. Verificado en la base:
--   · pg_class.relrowsecurity = true  → RLS activa en public.notifications
--   · pg_policies              → sólo notifications_select_own (SELECT)
--                                y   notifications_update_own (UPDATE)
--   · NO existe ninguna política de INSERT.
--
-- RLS es deny-by-default: sin política que autorice, todo INSERT se rechaza con
-- 42501 (new row violates row-level security policy). O sea: la entrevista se
-- creaba y el candidato NUNCA se enteraba. El circuito moría ahí.
--
-- POR QUÉ NO SE ABRE UNA POLÍTICA DE INSERT, QUE SERÍA LO OBVIO
--
-- public.notifications tiene el trigger notify_push_on_notification, que dispara
-- un push FCM real en cada INSERT. Una política de INSERT para `authenticated`
-- no sería "dejar escribir una fila": sería darle a cualquier usuario logueado
-- la capacidad de mandarle un push con título y cuerpo ARBITRARIOS a cualquier
-- otro usuario. Es un vector de phishing dentro de la app. Y no se arregla
-- haciendo la política más estrecha: cualquier condición expresable sobre la
-- fila deja igual al cliente eligiendo destinatario, título y cuerpo.
--
-- Por eso la escritura se mueve acá adentro, donde el servidor decide TODO.
-- Las políticas de notifications NO se tocan.
--
-- POR QUÉ TAMPOCO SIRVE create_system_notification, QUE YA EXISTE
--   1. Su firma no acepta `data` jsonb, que es justo donde viaja el
--      interview_id. Avisaría "tenés una entrevista" sin poder abrirla.
--   2. Está guardada contra public.profiles, una tabla legacy que la app
--      abandonó (escribe en public.users). De 61 usuarios, 20 no están en
--      profiles: para ésos hace RETURN en silencio y no inserta nada.
--
-- ATOMICIDAD. Entrevista + invitación entran en la misma transacción: no puede
-- quedar una entrevista sin su aviso. La generación de preguntas (Gemini) NO
-- entra acá: es una llamada HTTP y no tiene por qué mantener abierta una
-- transacción SQL. La dispara el cliente después, con el id que devuelve esta
-- función.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor. Idempotente.
-- ============================================================================


-- ── Esquema real contra el que se escribió (verificado, NO copiado de schema.sql)
--
--   public.jobs              (id, company_id → users.id, title, company_name, …)
--   public.job_applications  (id, job_id, candidate_id, status, created_at,
--                             UNIQUE (job_id, candidate_id))
--   public.interviews        (id, job_id, candidate_id, status, created_at,
--                             completed_at)   -- status CHECK: pending |
--                                             -- in_progress | completed
--   public.notifications     (id, user_id, type, title, body, is_read, data
--                             jsonb, sender_name, sender_avatar_url,
--                             sender_headline, company_name, avatar_url,
--                             created_at)
--                             ⚠️ NO tiene actor_id ni description, aunque
--                             schema.sql los declare (ver migración 020).

CREATE OR REPLACE FUNCTION public.request_ai_interview(
  p_job_id       UUID,
  p_candidate_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
-- search_path fijo: sin esto, una función SECURITY DEFINER es secuestrable
-- creando objetos homónimos en un esquema que el llamador controle.
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_me         UUID := auth.uid();
  v_company    UUID;
  v_titulo     TEXT;
  v_interview  UUID;
  v_creada     BOOLEAN := false;
BEGIN
  -- ── 1. Sesión ─────────────────────────────────────────────────────────────
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_auth');
  END IF;

  -- ── 2. Nadie se entrevista a sí mismo ─────────────────────────────────────
  IF p_candidate_id IS NULL OR p_candidate_id = v_me THEN
    RETURN jsonb_build_object('ok', false, 'error', 'autoentrevista');
  END IF;

  -- ── 3. La vacante existe ──────────────────────────────────────────────────
  --
  -- Se distingue "no existe" de "es de otro" a propósito: public.jobs tiene la
  -- política "Jobs are viewable by everyone" (SELECT USING true), así que la
  -- existencia de una vacante NO es información privada y separar los dos casos
  -- no filtra nada. Lo que sí se cuida más abajo es no devolver ningún DATO de
  -- una vacante ajena.
  SELECT j.company_id, j.title
    INTO v_company, v_titulo
    FROM public.jobs j
   WHERE j.id = p_job_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'vacante_inexistente');
  END IF;

  -- ── 4. La vacante es de la empresa autenticada ────────────────────────────
  --
  -- `jobs.company_id` es la relación real de propiedad (FK a users.id); es la
  -- misma que usan las políticas RLS de jobs. La respuesta de error no incluye
  -- el título ni ningún otro campo: quien no es dueño no se lleva datos.
  IF v_company IS DISTINCT FROM v_me THEN
    RETURN jsonb_build_object('ok', false, 'error', 'vacante_ajena');
  END IF;

  -- ── 5. El candidato se postuló A ESA vacante ──────────────────────────────
  --
  -- Ésta es la garantía que hoy sólo daba la UI: la pantalla listaba
  -- postulantes reales, pero nada impedía llamar con cualquier par. Ahora lo
  -- exige el servidor. `job_applications` es la tabla real del "swipe to apply"
  -- y tiene UNIQUE (job_id, candidate_id).
  IF NOT EXISTS (
    SELECT 1
      FROM public.job_applications ja
     WHERE ja.job_id       = p_job_id
       AND ja.candidate_id = p_candidate_id
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no_postulado');
  END IF;

  -- El candidato tiene que tener perfil en public.users: interviews.candidate_id
  -- es FK a esa tabla. Sin este chequeo el INSERT fallaría con un error de FK
  -- crudo en vez de un motivo legible.
  IF NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = p_candidate_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'candidato_inexistente');
  END IF;

  -- ── 6. Sin duplicados ─────────────────────────────────────────────────────
  --
  -- DECISIÓN TOMADA: todavía NO se crea UNIQUE INDEX sobre
  -- interviews (job_id, candidate_id). Sin esa restricción, un SELECT seguido de
  -- un INSERT es una condición de carrera clásica: dos llamadas simultáneas para
  -- el mismo par podrían pasar las dos por el SELECT vacío y crear dos
  -- entrevistas con dos invitaciones.
  --
  -- Mitigación sin DDL sobre la tabla: un lock consultivo de transacción sobre
  -- el par (job_id, candidate_id). Serializa las llamadas concurrentes a ESTA
  -- función y se libera solo al terminar la transacción.
  --
  -- LÍMITE HONESTO de esta mitigación: sólo protege a quien toma el mismo lock.
  -- `AIInterviewService.createInterview` (que sigue vivo para el ATS legacy)
  -- inserta en interviews sin pasar por acá, así que una carrera ENTRE ese
  -- camino y éste todavía puede duplicar. La garantía dura de verdad es el
  -- UNIQUE INDEX, que quedó postergado a propósito.
  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_job_id::text || ':' || p_candidate_id::text, 0)
  );

  SELECT i.id
    INTO v_interview
    FROM public.interviews i
   WHERE i.job_id       = p_job_id
     AND i.candidate_id = p_candidate_id
   ORDER BY i.created_at
   LIMIT 1;

  -- ── 7. Alta: entrevista + invitación, en la misma transacción ─────────────
  IF v_interview IS NULL THEN
    INSERT INTO public.interviews (job_id, candidate_id, status)
    VALUES (p_job_id, p_candidate_id, 'pending')
    RETURNING id INTO v_interview;

    v_creada := true;

    -- LA INVITACIÓN. Todo lo que la compone se arma acá: el destinatario es el
    -- candidato ya validado, el tipo es fijo, y el título y el cuerpo los
    -- redacta el servidor. El cliente no puede elegir ninguno de los cuatro.
    --
    -- El interview_id viaja en `data` (jsonb) porque es lo que lee
    -- `interviewIdDeNotificacion` en notifications_screen.dart para abrir
    -- InterviewFlowScreen. Si estas tres claves cambian de nombre, el candidato
    -- vuelve a recibir un aviso que no lleva a ninguna parte.
    --
    -- Se insertan sólo las cinco columnas imprescindibles. `sender_name`,
    -- `company_name` y `avatar_url` existen en la tabla, pero la pantalla de
    -- notificaciones NO las lee (usa title/body/type/created_at), y cada columna
    -- de más es otra chance de romper el INSERT entero — que es exactamente la
    -- falla que esta migración viene a arreglar.
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      p_candidate_id,
      'interview_request',
      'Te invitaron a una entrevista con IA',
      'Respondé cuando puedas para la vacante "' || COALESCE(v_titulo, 'sin título') || '".',
      jsonb_build_object(
        'interview_id', v_interview,
        'job_id',       p_job_id,
        'from_user_id', v_me
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'ok',           true,
    'interview_id', v_interview,
    'ya_existia',   NOT v_creada
  );
END;
$function$;


-- ── Permisos ────────────────────────────────────────────────────────────────
-- La función corre con los privilegios de su dueño y saltea RLS: quién puede
-- ejecutarla es parte de su seguridad. Se revoca primero (CREATE OR REPLACE no
-- limpia grants viejos) y se concede sólo a usuarios con sesión. `anon` no la
-- necesita: sin auth.uid() devolvería 'no_auth' igual, pero no tiene por qué
-- poder invocarla.
REVOKE ALL ON FUNCTION public.request_ai_interview(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.request_ai_interview(UUID, UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.request_ai_interview(UUID, UUID) TO authenticated;

COMMENT ON FUNCTION public.request_ai_interview(UUID, UUID) IS
  'Crea (o reutiliza) una entrevista con IA y avisa al candidato en la misma '
  'transacción. Valida que la vacante sea de la empresa autenticada y que el '
  'candidato se haya postulado a ella. Es la ÚNICA vía por la que Empresa puede '
  'escribir en notifications: la tabla no tiene política de INSERT y no debe '
  'tenerla.';

NOTIFY pgrst, 'reload schema';
