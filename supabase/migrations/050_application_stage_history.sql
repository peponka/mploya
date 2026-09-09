-- ============================================================================
-- 050 — Historial de etapas de una postulación (quién, cuándo y por qué)
-- ============================================================================
-- Bloque 1 · Etapa E1 del plan del 30/8/2026.
--
-- POR QUÉ AHORA. La migración 029 dejó escrito el criterio para construir
-- esta tabla, en el cuerpo del trigger `job_application_stage_dates`:
--
--     "Se PIERDE la fecha original de contratación. Ése es el costo de no
--      tener tabla de historial, y es el criterio concreto para construirla:
--      si auditar correcciones pasa a ser un requisito, deja de ser opcional."
--
-- Pasó a ser requisito: sin historial no hay forma de saber quién movió a un
-- candidato ni por qué se lo rechazó, y el Pipeline de Empresa no puede
-- ofrecer una acción de cambio de etapa responsable.
--
-- QUÉ NO CAMBIA. Nada del vocabulario de estados ni de la matriz de
-- transiciones de la 029. Los seis estados siguen siendo los mismos, las
-- transiciones permitidas son exactamente las mismas, el bloqueo de filas
-- `FOR UPDATE OF ja, j` se conserva palabra por palabra y la autorización
-- sigue siendo "empresa dueña de la vacante". Esta migración sólo AGREGA
-- registro y dos parámetros opcionales.
--
-- POR QUÉ EL HISTORIAL LO ESCRIBE EL TRIGGER Y NO LA RPC. Si lo escribiera
-- la RPC, cualquier futura función SECURITY DEFINER que actualice `status`
-- por otra vía dejaría un hueco silencioso en la auditoría. En el trigger la
-- invariante es del motor: no hay UPDATE de `status` sin fila de historial.
-- El motivo y las notas, que la RPC sí conoce y el trigger no, viajan por
-- dos variables locales a la transacción (`set_config(..., true)`), que se
-- limpian solas al terminar la transacción.
--
-- SECURITY DEFINER EN EL TRIGGER, A PROPÓSITO. Misma lección que la
-- migración 045: la tabla de historial NO tiene policy de INSERT para
-- `authenticated` (sólo el trigger escribe ahí), así que un trigger
-- SECURITY INVOKER se bloquearía a sí mismo con RLS y haría fallar TODO
-- cambio de etapa. Es seguro porque el trigger sólo inserta valores que
-- salen de la fila que se está actualizando, y el UPDATE que lo dispara
-- sigue autorizado por la propia RPC.
--
-- DECISIÓN EXPLÍCITA Y VETABLE · QUIÉN VE EL HISTORIAL. Por ahora sólo la
-- empresa dueña de la vacante. El candidato NO lo ve. Motivo: el motivo de
-- rechazo y las notas son criterio interno de selección, y comunicarle algo
-- al candidato es una decisión editorial de la empresa (el bloque 3 del plan
-- tiene "rechazo respetuoso con plantilla" justamente para eso), no un
-- volcado crudo de la auditoría. Si se decide lo contrario, se agrega una
-- policy de SELECT para `candidate_id` y se separan `reason` (comunicable)
-- de `notes` (interna) — la tabla ya viene con esa separación hecha.
--
-- Se aplica a mano contra producción (proyecto Supabase "nexowork"), igual
-- que 038 a 049. Ver la nota de la 038 sobre por qué este proyecto no usa el
-- control de migraciones de Supabase.
-- ============================================================================

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
-- §1 · PRECONDICIONES — fallar cerrado si la 029/038 no está aplicada
-- ────────────────────────────────────────────────────────────────────────────

DO $$
BEGIN
  IF to_regprocedure('public.update_application_status(uuid,text)') IS NULL THEN
    RAISE EXCEPTION
      '050 precondición: update_application_status(uuid,text) no existe — falta aplicar 029/038';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'job_applications'
      AND column_name  = 'stage_changed_at'
  ) THEN
    RAISE EXCEPTION
      '050 precondición: job_applications.stage_changed_at no existe — falta aplicar 029/038';
  END IF;

  IF to_regprocedure('public.job_application_stage_dates()') IS NULL THEN
    RAISE EXCEPTION
      '050 precondición: el trigger de fechas de la 029 no existe';
  END IF;
END;
$$;


-- ────────────────────────────────────────────────────────────────────────────
-- §2 · TABLA DE HISTORIAL
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.job_application_stage_history (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL
                   REFERENCES public.job_applications(id) ON DELETE CASCADE,

  from_status    TEXT,          -- NULL sólo si algún día se registra el alta
  to_status      TEXT NOT NULL,

  -- Quién. NULLABLE a propósito: un cambio hecho por un script de
  -- mantenimiento con service_role no tiene `auth.uid()`, y preferimos
  -- registrar el cambio con actor desconocido antes que perderlo.
  changed_by     UUID REFERENCES public.users(id) ON DELETE SET NULL,

  -- Por qué. `reason` es el motivo corto y estructurado (obligatorio al
  -- rechazar). `notes` es texto libre interno. Se guardan separados para que
  -- en el futuro se pueda mostrar uno sin el otro.
  reason         TEXT,
  notes          TEXT,

  changed_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.job_application_stage_history IS
  'Una fila por cada cambio de `job_applications.status`. La escribe únicamente el trigger trg_job_application_stage_dates. Ver migración 050.';

COMMENT ON COLUMN public.job_application_stage_history.reason IS
  'Motivo corto del cambio. Obligatorio cuando to_status = rejected (lo exige update_application_status).';

CREATE INDEX IF NOT EXISTS idx_jash_application
  ON public.job_application_stage_history (application_id, changed_at DESC);


-- ────────────────────────────────────────────────────────────────────────────
-- §3 · RLS — lectura para la empresa dueña de la vacante, escritura para nadie
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.job_application_stage_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS jash_select_company ON public.job_application_stage_history;

CREATE POLICY jash_select_company ON public.job_application_stage_history
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.job_applications ja
      JOIN public.jobs j ON j.id = ja.job_id
      WHERE ja.id = job_application_stage_history.application_id
        AND j.company_id = auth.uid()
    )
  );

-- Sin policy de INSERT/UPDATE/DELETE a propósito: la única escritura
-- legítima es la del trigger de §4, que corre como SECURITY DEFINER.
REVOKE INSERT, UPDATE, DELETE
  ON public.job_application_stage_history
  FROM authenticated, anon;


-- ────────────────────────────────────────────────────────────────────────────
-- §4 · TRIGGER — se amplía el de la 029 sin cambiar lo que ya hacía
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.job_application_stage_dates()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_reason TEXT;
  v_notes  TEXT;
BEGIN
  -- GUARDA REDUNDANTE, a propósito (texto original de la 029). La condición
  -- real vive en el WHEN del trigger, pero si alguien lo recreara sin ese
  -- WHEN —o reutilizara esta función en otro trigger— el cuerpo estamparía
  -- la fecha en CUALQUIER UPDATE. La invariante "las fechas sólo se mueven
  -- si cambió la etapa" tiene que sobrevivir a que le saquen el WHEN.
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.stage_changed_at := now();

    IF NEW.status = 'hired' THEN
      NEW.hired_at := now();
    ELSIF OLD.status = 'hired' THEN
      -- Se revierte una contratación. Se sigue limpiando `hired_at` para no
      -- romper la invariante de la 029, pero desde esta migración la fecha
      -- original NO se pierde: queda en la fila de historial que se inserta
      -- acá abajo. Ése era exactamente el costo que la 029 documentó.
      NEW.hired_at := NULL;
    END IF;

    -- Motivo y notas: los pone `update_application_status` en variables
    -- locales a la transacción. El segundo argumento `true` de
    -- current_setting hace que devuelva NULL en vez de fallar si la variable
    -- nunca se seteó (cambio hecho por otra vía).
    v_reason := NULLIF(btrim(COALESCE(current_setting('mploya.stage_reason', true), '')), '');
    v_notes  := NULLIF(btrim(COALESCE(current_setting('mploya.stage_notes',  true), '')), '');

    INSERT INTO public.job_application_stage_history (
      application_id, from_status, to_status, changed_by, reason, notes
    ) VALUES (
      NEW.id, OLD.status, NEW.status, auth.uid(), v_reason, v_notes
    );
  END IF;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.job_application_stage_dates() OWNER TO postgres;

-- El trigger de la 029 sigue siendo el mismo; se recrea sólo para garantizar
-- que apunta a esta versión de la función y conserva su WHEN.
DROP TRIGGER IF EXISTS trg_job_application_stage_dates ON public.job_applications;
CREATE TRIGGER trg_job_application_stage_dates
  BEFORE UPDATE ON public.job_applications
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.job_application_stage_dates();


-- ────────────────────────────────────────────────────────────────────────────
-- §5 · RPC — mismos estados y mismas transiciones, más motivo y notas
--
--      HAY QUE BORRAR LA VIEJA. Postgres no permite cambiar la firma de una
--      función con CREATE OR REPLACE. Y si se dejaran conviviendo la de dos
--      parámetros y la de cuatro con DEFAULT, una llamada de dos argumentos
--      quedaría ambigua ("function is not unique"). Por eso se borra.
--
--      Las llamadas existentes NO se rompen: PostgREST resuelve por nombre
--      de parámetro, así que `{p_application_id, p_status}` sigue matcheando
--      esta función y `p_reason`/`p_notes` toman su default.
-- ────────────────────────────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.update_application_status(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.update_application_status(
  p_application_id UUID,
  p_status         TEXT,
  p_reason         TEXT DEFAULT NULL,
  p_notes          TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor   UUID := auth.uid();
  v_current TEXT;
  v_reason  TEXT := NULLIF(btrim(COALESCE(p_reason, '')), '');
  v_notes   TEXT := NULLIF(btrim(COALESCE(p_notes,  '')), '');
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
  -- evalúa a NULL, que en un IF se comporta como falso y dejaría pasar un
  -- tipo nulo.
  IF p_status IS NULL
     OR p_status NOT IN ('pending','viewed','interviewing','accepted','hired','rejected')
  THEN
    RAISE EXCEPTION 'update_application_status: estado no permitido (%)', p_status
      USING ERRCODE = '22023';
  END IF;

  -- NUEVO EN LA 050. Rechazar sin motivo deja de estar permitido: un
  -- pipeline sin motivos de rechazo no se puede auditar ni convertir después
  -- en una comunicación decente al candidato. El límite de 240 caracteres es
  -- para que sea un motivo y no un ensayo; el texto largo va en `p_notes`.
  IF p_status = 'rejected' AND v_reason IS NULL THEN
    RAISE EXCEPTION 'update_application_status: hace falta un motivo para rechazar'
      USING ERRCODE = '22023';
  END IF;

  IF length(COALESCE(v_reason, '')) > 240 THEN
    RAISE EXCEPTION 'update_application_status: el motivo no puede pasar de 240 caracteres'
      USING ERRCODE = '22023';
  END IF;

  IF length(COALESCE(v_notes, '')) > 4000 THEN
    RAISE EXCEPTION 'update_application_status: las notas no pueden pasar de 4000 caracteres'
      USING ERRCODE = '22023';
  END IF;

  -- BLOQUEO ANTES DE DECIDIR LA TRANSICIÓN (texto y razones de la 029). Se
  -- bloquean LAS DOS filas: `ja` evita carreras de estado, `j` estabiliza la
  -- propiedad de la vacante, que es la condición de autorización.
  SELECT ja.status INTO v_current
  FROM public.job_applications ja
  JOIN public.jobs j ON j.id = ja.job_id
  WHERE ja.id = p_application_id
    AND j.company_id = v_actor
  FOR UPDATE OF ja, j;

  -- "No existe" y "no pertenece" se CONFLACIONAN A PROPÓSITO, en un solo
  -- error con el mismo SQLSTATE: distinguirlos convertiría a esta función en
  -- un oráculo de enumeración de postulaciones ajenas.
  IF NOT FOUND THEN
    RAISE EXCEPTION
      'update_application_status: la postulación % no existe o no pertenece a una vacante de la empresa autenticada',
      p_application_id
      USING ERRCODE = '42501';
  END IF;

  -- No-op idempotente: un doble toque en la UI no revienta y TAMPOCO deja
  -- una fila de historial, porque el trigger no llega a dispararse.
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

  -- Motivo y notas para el trigger. `true` = local a la transacción: se
  -- limpian solas al terminar, no hay que resetearlas a mano y no se filtran
  -- a la siguiente llamada de la misma conexión. Se setean SIEMPRE (con
  -- cadena vacía cuando no hay valor) para que una segunda llamada dentro de
  -- la misma transacción no herede el motivo de la anterior.
  PERFORM set_config('mploya.stage_reason', COALESCE(v_reason, ''), true);
  PERFORM set_config('mploya.stage_notes',  COALESCE(v_notes,  ''), true);

  -- La propiedad se REVALIDA acá como defensa adicional, no como el
  -- mecanismo principal: quien cierra la carrera es el FOR UPDATE de arriba.
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

ALTER FUNCTION public.update_application_status(UUID, TEXT, TEXT, TEXT)
  OWNER TO postgres;
REVOKE ALL ON FUNCTION public.update_application_status(UUID, TEXT, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_application_status(UUID, TEXT, TEXT, TEXT)
  TO authenticated;

COMMENT ON FUNCTION public.update_application_status(UUID, TEXT, TEXT, TEXT) IS
  'Única ruta productiva de cambio de etapa de una postulación. Sólo la empresa dueña de la vacante. Valida la matriz de transiciones de la 029 y exige motivo para rechazar. El historial lo escribe el trigger. Ver migraciones 029 y 050.';


-- ────────────────────────────────────────────────────────────────────────────
-- §6 · NO SE HACE BACKFILL, A PROPÓSITO
--      Las postulaciones que ya existen no tienen historial y no se les
--      inventa uno: no sabemos quién las movió ni cuándo, y una fila
--      sintética con actor desconocido y fecha de hoy sería peor que la
--      ausencia. La pantalla de historial muestra estado vacío y lo explica.
-- ────────────────────────────────────────────────────────────────────────────

NOTIFY pgrst, 'reload schema';

COMMIT;
