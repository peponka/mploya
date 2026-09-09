-- ============================================================================
-- 051 — Ofertas laborales: el paso que faltaba para cerrar una contratación
-- ============================================================================
-- Bloque 1 · Etapa E2 del plan del 30/8/2026.
--
-- SOBRE EL NÚMERO. El plan llamaba 049 a esta migración y 050 al historial de
-- etapas, pero el historial se construyó y se aplicó primero. Para no dejar
-- dos migraciones con números fuera del orden en que se aplicaron, esta pasa
-- a ser la 051. El 049 queda sin usar a propósito.
--
-- QUÉ RESUELVE. Hasta hoy "oferta" no existía como dato: lo único real era
-- `job_applications.status = 'accepted'`, que es un estado del proceso, no
-- una oferta. Por eso la pantalla de Ofertas de Empresa dice en su propio
-- encabezado que no puede mostrar salario, vencimiento, beneficios ni
-- historial de negociación — nada de eso se guardaba en ningún lado, y el
-- candidato no tenía forma de aceptar ni rechazar.
--
-- DECISIONES TOMADAS (recomendadas en el plan, vetables):
--   · MONTO ÚNICO, no rango. Una oferta formal cierra un número; la
--     negociación vive en las versiones de la oferta, no en un rango difuso.
--   · PESOS Y DÓLARES, guardados por separado y SIN conversión automática.
--     Convertir sería inventar una cotización.
--   · CONTRATO Y FIRMA QUEDAN AFUERA. Necesitan un bucket privado (hoy el
--     único bucket de la app es público) y una decisión con asesoramiento
--     legal. Esta migración deja el modelo listo para engancharlos después.
--
-- LA REGLA QUE ATA TODO. Aceptar una oferta NO escribe `hired` por su
-- cuenta: pasa por la misma validación de transiciones y deja la misma fila
-- de historial que cualquier otro cambio de etapa. Ver §2.
-- ============================================================================

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
-- §1 · PRECONDICIONES
-- ────────────────────────────────────────────────────────────────────────────

DO $$
BEGIN
  IF to_regprocedure(
       'public.update_application_status(uuid,text,text,text)'
     ) IS NULL THEN
    RAISE EXCEPTION '051 precondición: falta aplicar la migración 050';
  END IF;

  IF to_regclass('public.job_application_stage_history') IS NULL THEN
    RAISE EXCEPTION '051 precondición: falta la tabla de historial (050)';
  END IF;
END;
$$;


-- ────────────────────────────────────────────────────────────────────────────
-- §2 · UNA SOLA PUERTA, DOS AUTORIZACIONES DISTINTAS
--
--      Hasta ahora `update_application_status` mezclaba dos cosas: QUIÉN
--      puede mover una postulación (la empresa dueña de la vacante) y CÓMO se
--      mueve (matriz de transiciones, bloqueo de filas, historial).
--
--      Cuando el candidato acepta una oferta también hay que mover la
--      postulación —a `hired`—, pero el candidato NO es la empresa: no puede
--      pasar por esa función. Copiar la matriz en la función de ofertas
--      sería tener dos verdades sobre lo mismo, que es exactamente el
--      problema que este bloque vino a arreglar.
--
--      Se separan las dos responsabilidades:
--
--        · `apply_application_status_change` — el CÓMO. Interna: valida la
--          matriz, bloquea, escribe historial. NO decide quién puede.
--          Revocada para `authenticated`: sólo la llaman otras funciones.
--        · `update_application_status`  — el QUIÉN, para la empresa.
--        · `respond_to_job_offer` (§6)  — el QUIÉN, para el candidato.
--
--      La matriz sigue viviendo en un solo lugar.
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.apply_application_status_change(
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
  v_current TEXT;
  v_reason  TEXT := NULLIF(btrim(COALESCE(p_reason, '')), '');
  v_notes   TEXT := NULLIF(btrim(COALESCE(p_notes,  '')), '');
BEGIN
  IF p_application_id IS NULL THEN
    RAISE EXCEPTION 'apply_application_status_change: p_application_id es obligatorio'
      USING ERRCODE = '22023';
  END IF;

  IF p_status IS NULL
     OR p_status NOT IN ('pending','viewed','interviewing','accepted','hired','rejected')
  THEN
    RAISE EXCEPTION 'apply_application_status_change: estado no permitido (%)', p_status
      USING ERRCODE = '22023';
  END IF;

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

  -- Bloqueo de la fila antes de decidir la transición: sin esto dos llamadas
  -- concurrentes leerían el mismo estado actual y aplicarían dos cambios que
  -- por separado son válidos y juntos no lo son.
  SELECT ja.status INTO v_current
  FROM public.job_applications ja
  WHERE ja.id = p_application_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'update_application_status: la postulación % no existe o no pertenece a una vacante de la empresa autenticada',
      p_application_id
      USING ERRCODE = '42501';
  END IF;

  -- No-op idempotente: un doble toque no revienta y tampoco deja historial,
  -- porque el trigger no llega a dispararse.
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

  -- Motivo y notas para el trigger de la 050. `true` = local a la
  -- transacción: se limpian solas y no se filtran a la llamada siguiente.
  PERFORM set_config('mploya.stage_reason', COALESCE(v_reason, ''), true);
  PERFORM set_config('mploya.stage_notes',  COALESCE(v_notes,  ''), true);

  UPDATE public.job_applications
  SET status = p_status
  WHERE id = p_application_id;
END;
$$;

ALTER FUNCTION public.apply_application_status_change(UUID, TEXT, TEXT, TEXT)
  OWNER TO postgres;
REVOKE ALL ON FUNCTION public.apply_application_status_change(UUID, TEXT, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated, service_role;

COMMENT ON FUNCTION public.apply_application_status_change(UUID, TEXT, TEXT, TEXT) IS
  'INTERNA. El CÓMO de un cambio de etapa: matriz de transiciones, bloqueo e historial. No autoriza a nadie — eso lo hace quien la llama. Ver migración 051 §2.';


-- La función pública de la empresa conserva su firma y su contrato; ahora
-- sólo hace lo suyo (autorizar) y delega el resto.
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
  v_actor UUID := auth.uid();
  v_ok    BOOLEAN;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'update_application_status: sin sesión activa'
      USING ERRCODE = '28000';
  END IF;

  -- Autorización + bloqueo de la vacante, que es donde vive la condición de
  -- propiedad. "No existe" y "no es tuya" se conflacionan a propósito: si no,
  -- esta función sería un oráculo para enumerar postulaciones ajenas.
  SELECT TRUE INTO v_ok
  FROM public.job_applications ja
  JOIN public.jobs j ON j.id = ja.job_id
  WHERE ja.id = p_application_id
    AND j.company_id = v_actor
  FOR UPDATE OF ja, j;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'update_application_status: la postulación % no existe o no pertenece a una vacante de la empresa autenticada',
      p_application_id
      USING ERRCODE = '42501';
  END IF;

  PERFORM public.apply_application_status_change(
    p_application_id, p_status, p_reason, p_notes
  );
END;
$$;

ALTER FUNCTION public.update_application_status(UUID, TEXT, TEXT, TEXT)
  OWNER TO postgres;
REVOKE ALL ON FUNCTION public.update_application_status(UUID, TEXT, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_application_status(UUID, TEXT, TEXT, TEXT)
  TO authenticated;


-- ────────────────────────────────────────────────────────────────────────────
-- §3 · job_offers
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.job_offers (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  application_id UUID NOT NULL
                   REFERENCES public.job_applications(id) ON DELETE CASCADE,

  -- Copiados de la postulación al crear la oferta. Se guardan acá para que
  -- las policies no tengan que hacer dos saltos en cada fila; las llena la
  -- función de creación, nunca el cliente.
  company_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  candidate_id   UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  job_id         UUID NOT NULL REFERENCES public.jobs(id)  ON DELETE CASCADE,

  status         TEXT NOT NULL DEFAULT 'draft'
                   CHECK (status IN (
                     'draft',             -- la empresa la está armando
                     'sent',              -- enviada al candidato
                     'viewed',            -- el candidato la abrió
                     'changes_requested', -- el candidato pidió cambios
                     'accepted',
                     'declined',
                     'withdrawn',         -- la empresa la retiró
                     'expired'
                   )),

  -- Monto único, no rango (ver decisiones en la cabecera).
  salary_amount   NUMERIC(14,2) CHECK (salary_amount IS NULL OR salary_amount > 0),
  salary_currency TEXT CHECK (salary_currency IS NULL OR salary_currency IN ('ARS','USD')),
  salary_period   TEXT NOT NULL DEFAULT 'mensual'
                    CHECK (salary_period IN ('mensual','anual','hora')),

  modalidad       TEXT CHECK (modalidad IS NULL OR modalidad IN ('presencial','hibrido','remoto')),

  -- Lista de beneficios en texto. Sin catálogo cerrado a propósito: no
  -- existe uno en el producto y armarlo acá sería inventarlo.
  benefits        JSONB NOT NULL DEFAULT '[]'::jsonb
                    CHECK (
                      jsonb_typeof(benefits) = 'array'
                      AND jsonb_array_length(benefits) <= 20
                    ),

  start_date      DATE,
  expires_at      TIMESTAMPTZ,

  -- Mensaje de la empresa al candidato que acompaña la oferta.
  message         TEXT,

  version         INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),

  decided_at      TIMESTAMPTZ,
  decline_reason  TEXT,

  created_by      UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.job_offers IS
  'Oferta laboral concreta sobre una postulación. Acompaña al estado de la postulación, no lo reemplaza. Ver migración 051.';

-- UNA SOLA OFERTA VIVA POR POSTULACIÓN. Las cerradas (rechazada, retirada,
-- vencida) quedan como historia y no bloquean una oferta nueva.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_job_offer_viva
  ON public.job_offers (application_id)
  WHERE status NOT IN ('declined', 'withdrawn', 'expired');

CREATE INDEX IF NOT EXISTS idx_job_offers_company   ON public.job_offers (company_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_job_offers_candidate ON public.job_offers (candidate_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_job_offers_job       ON public.job_offers (job_id);

ALTER TABLE public.job_offers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS jo_select ON public.job_offers;

-- El candidato NO ve los borradores: una oferta que la empresa todavía está
-- armando no existe para él.
CREATE POLICY jo_select ON public.job_offers
  FOR SELECT TO authenticated
  USING (
    company_id = auth.uid()
    OR (candidate_id = auth.uid() AND status <> 'draft')
  );

REVOKE INSERT, UPDATE, DELETE ON public.job_offers FROM authenticated, anon;

CREATE OR REPLACE FUNCTION public.job_offers_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_job_offers_updated_at ON public.job_offers;
CREATE TRIGGER trg_job_offers_updated_at
  BEFORE UPDATE ON public.job_offers
  FOR EACH ROW
  EXECUTE FUNCTION public.job_offers_touch_updated_at();


-- ────────────────────────────────────────────────────────────────────────────
-- §4 · job_offer_versions — la negociación, sin pisar nada
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.job_offer_versions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id    UUID NOT NULL REFERENCES public.job_offers(id) ON DELETE CASCADE,
  version     INTEGER NOT NULL,

  change_kind TEXT NOT NULL CHECK (change_kind IN (
    'creada', 'enviada', 'revisada', 'vista',
    'cambios_pedidos', 'aceptada', 'rechazada', 'retirada', 'vencida'
  )),

  -- Foto completa de la oferta en ese momento. Nunca se edita una versión
  -- anterior: así se puede reconstruir qué se ofreció exactamente y cuándo.
  snapshot    JSONB NOT NULL,

  message     TEXT,
  actor_id    UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_job_offer_versions_offer
  ON public.job_offer_versions (offer_id, created_at DESC);

ALTER TABLE public.job_offer_versions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS jov_select ON public.job_offer_versions;

CREATE POLICY jov_select ON public.job_offer_versions
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.job_offers o
      WHERE o.id = job_offer_versions.offer_id
        AND (
          o.company_id = auth.uid()
          OR (o.candidate_id = auth.uid() AND o.status <> 'draft')
        )
    )
  );

REVOKE INSERT, UPDATE, DELETE ON public.job_offer_versions FROM authenticated, anon;


-- ────────────────────────────────────────────────────────────────────────────
-- §5 · Ayudantes internos
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.job_offer_snapshot(p_offer_id UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT to_jsonb(o) - 'created_by' - 'updated_at'
  FROM public.job_offers o
  WHERE o.id = p_offer_id;
$$;

ALTER FUNCTION public.job_offer_snapshot(UUID) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.job_offer_snapshot(UUID)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.log_job_offer_version(
  p_offer_id    UUID,
  p_change_kind TEXT,
  p_message     TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.job_offer_versions (
    offer_id, version, change_kind, snapshot, message, actor_id
  )
  SELECT o.id, o.version, p_change_kind,
         public.job_offer_snapshot(o.id),
         NULLIF(btrim(COALESCE(p_message, '')), ''),
         auth.uid()
  FROM public.job_offers o
  WHERE o.id = p_offer_id;
END;
$$;

ALTER FUNCTION public.log_job_offer_version(UUID, TEXT, TEXT) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.log_job_offer_version(UUID, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated, service_role;

-- ────────────────────────────────────────────────────────────────────────────
-- §6 · FUNCIONES PÚBLICAS
--      Todas SECURITY DEFINER: `job_offers` no tiene policy de escritura para
--      nadie, así que estas son la única forma de tocar una oferta. Cada una
--      autoriza por su cuenta y después delega.
-- ────────────────────────────────────────────────────────────────────────────

-- ── Crear (queda en borrador; el candidato todavía no la ve) ────────────────

CREATE OR REPLACE FUNCTION public.create_job_offer(
  p_application_id  UUID,
  p_salary_amount   NUMERIC DEFAULT NULL,
  p_salary_currency TEXT    DEFAULT NULL,
  p_salary_period   TEXT    DEFAULT 'mensual',
  p_modalidad       TEXT    DEFAULT NULL,
  p_benefits        JSONB   DEFAULT '[]'::jsonb,
  p_start_date      DATE    DEFAULT NULL,
  p_expires_at      TIMESTAMPTZ DEFAULT NULL,
  p_message         TEXT    DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor     UUID := auth.uid();
  v_candidate UUID;
  v_job       UUID;
  v_estado    TEXT;
  v_offer     UUID;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'create_job_offer: sin sesión activa' USING ERRCODE = '28000';
  END IF;

  SELECT ja.candidate_id, ja.job_id, ja.status
  INTO v_candidate, v_job, v_estado
  FROM public.job_applications ja
  JOIN public.jobs j ON j.id = ja.job_id
  WHERE ja.id = p_application_id
    AND j.company_id = v_actor
  FOR UPDATE OF ja, j;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'create_job_offer: la postulación % no existe o no pertenece a una vacante de la empresa autenticada',
      p_application_id
      USING ERRCODE = '42501';
  END IF;

  IF v_estado = 'rejected' THEN
    RAISE EXCEPTION 'create_job_offer: no se le puede ofrecer a alguien que está descartado'
      USING ERRCODE = '42501';
  END IF;

  IF v_estado = 'hired' THEN
    RAISE EXCEPTION 'create_job_offer: esta persona ya está contratada'
      USING ERRCODE = '42501';
  END IF;

  -- El índice único ya lo impide, pero su error es ilegible. Mejor decirlo.
  IF EXISTS (
    SELECT 1 FROM public.job_offers o
    WHERE o.application_id = p_application_id
      AND o.status NOT IN ('declined', 'withdrawn', 'expired')
  ) THEN
    RAISE EXCEPTION 'create_job_offer: esta postulación ya tiene una oferta abierta'
      USING ERRCODE = '42501';
  END IF;

  IF jsonb_typeof(COALESCE(p_benefits, '[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'create_job_offer: los beneficios tienen que ser una lista'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.job_offers (
    application_id, company_id, candidate_id, job_id,
    salary_amount, salary_currency, salary_period, modalidad,
    benefits, start_date, expires_at, message, created_by
  ) VALUES (
    p_application_id, v_actor, v_candidate, v_job,
    p_salary_amount, p_salary_currency, COALESCE(p_salary_period, 'mensual'),
    p_modalidad, COALESCE(p_benefits, '[]'::jsonb), p_start_date,
    p_expires_at, NULLIF(btrim(COALESCE(p_message, '')), ''), v_actor
  )
  RETURNING id INTO v_offer;

  PERFORM public.log_job_offer_version(v_offer, 'creada', NULL);
  RETURN v_offer;
END;
$$;


-- ── Enviar ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.send_job_offer(p_offer_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor  UUID := auth.uid();
  v_oferta public.job_offers%ROWTYPE;
  v_estado TEXT;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'send_job_offer: sin sesión activa' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_oferta
  FROM public.job_offers
  WHERE id = p_offer_id AND company_id = v_actor
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'send_job_offer: la oferta % no existe o no es de tu empresa', p_offer_id
      USING ERRCODE = '42501';
  END IF;

  IF v_oferta.status NOT IN ('draft', 'changes_requested') THEN
    RAISE EXCEPTION 'send_job_offer: esta oferta ya fue enviada o está cerrada'
      USING ERRCODE = '42501';
  END IF;

  -- Una oferta sin monto, moneda, fecha de inicio o vencimiento no es una
  -- oferta: es un borrador. Se exige acá y no en la tabla para que el
  -- borrador pueda guardarse incompleto.
  IF v_oferta.salary_amount IS NULL
     OR v_oferta.salary_currency IS NULL
     OR v_oferta.start_date IS NULL
     OR v_oferta.expires_at IS NULL
  THEN
    RAISE EXCEPTION 'send_job_offer: faltan datos (monto, moneda, fecha de inicio o vencimiento)'
      USING ERRCODE = '22023';
  END IF;

  IF v_oferta.expires_at <= now() THEN
    RAISE EXCEPTION 'send_job_offer: el vencimiento tiene que ser posterior a ahora'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.job_offers SET status = 'sent' WHERE id = p_offer_id;
  PERFORM public.log_job_offer_version(p_offer_id, 'enviada', v_oferta.message);

  -- La postulación pasa a "Con oferta". No se toca si ya está ahí o más
  -- adelante, para no hacerla retroceder.
  SELECT status INTO v_estado
  FROM public.job_applications WHERE id = v_oferta.application_id;

  IF v_estado IS NOT NULL AND v_estado NOT IN ('accepted', 'hired') THEN
    PERFORM public.apply_application_status_change(
      v_oferta.application_id, 'accepted', NULL, 'Oferta enviada'
    );
  END IF;
END;
$$;


-- ── Revisar (nueva versión de una oferta ya enviada) ────────────────────────

CREATE OR REPLACE FUNCTION public.revise_job_offer(
  p_offer_id        UUID,
  p_salary_amount   NUMERIC DEFAULT NULL,
  p_salary_currency TEXT    DEFAULT NULL,
  p_salary_period   TEXT    DEFAULT NULL,
  p_modalidad       TEXT    DEFAULT NULL,
  p_benefits        JSONB   DEFAULT NULL,
  p_start_date      DATE    DEFAULT NULL,
  p_expires_at      TIMESTAMPTZ DEFAULT NULL,
  p_message         TEXT    DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor  UUID := auth.uid();
  v_estado TEXT;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'revise_job_offer: sin sesión activa' USING ERRCODE = '28000';
  END IF;

  SELECT status INTO v_estado
  FROM public.job_offers
  WHERE id = p_offer_id AND company_id = v_actor
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'revise_job_offer: la oferta % no existe o no es de tu empresa', p_offer_id
      USING ERRCODE = '42501';
  END IF;

  IF v_estado NOT IN ('sent', 'viewed', 'changes_requested') THEN
    RAISE EXCEPTION 'revise_job_offer: sólo se puede revisar una oferta abierta'
      USING ERRCODE = '42501';
  END IF;

  -- Sólo se pisan los campos que vienen con valor: revisar el salario no
  -- tiene por qué borrar los beneficios.
  UPDATE public.job_offers SET
    salary_amount   = COALESCE(p_salary_amount,   salary_amount),
    salary_currency = COALESCE(p_salary_currency, salary_currency),
    salary_period   = COALESCE(p_salary_period,   salary_period),
    modalidad       = COALESCE(p_modalidad,       modalidad),
    benefits        = COALESCE(p_benefits,        benefits),
    start_date      = COALESCE(p_start_date,      start_date),
    expires_at      = COALESCE(p_expires_at,      expires_at),
    message         = COALESCE(NULLIF(btrim(COALESCE(p_message, '')), ''), message),
    version         = version + 1,
    status          = 'sent'
  WHERE id = p_offer_id;

  PERFORM public.log_job_offer_version(p_offer_id, 'revisada', p_message);
END;
$$;


-- ── El candidato la abre ───────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.mark_job_offer_viewed(p_offer_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor  UUID := auth.uid();
  v_estado TEXT;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'mark_job_offer_viewed: sin sesión activa' USING ERRCODE = '28000';
  END IF;

  SELECT status INTO v_estado
  FROM public.job_offers
  WHERE id = p_offer_id AND candidate_id = v_actor
  FOR UPDATE;

  -- Silencioso a propósito: marcar como vista es un efecto secundario de
  -- abrir una pantalla, no una acción del usuario. Que falle no debería
  -- romperle la vista de la oferta.
  IF NOT FOUND OR v_estado <> 'sent' THEN
    RETURN;
  END IF;

  UPDATE public.job_offers SET status = 'viewed' WHERE id = p_offer_id;
  PERFORM public.log_job_offer_version(p_offer_id, 'vista', NULL);
END;
$$;


-- ── El candidato responde ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.respond_to_job_offer(
  p_offer_id UUID,
  p_decision TEXT,
  p_message  TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor  UUID := auth.uid();
  v_oferta public.job_offers%ROWTYPE;
  v_msg    TEXT := NULLIF(btrim(COALESCE(p_message, '')), '');
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'respond_to_job_offer: sin sesión activa' USING ERRCODE = '28000';
  END IF;

  IF p_decision IS NULL
     OR p_decision NOT IN ('accepted', 'declined', 'changes_requested') THEN
    RAISE EXCEPTION 'respond_to_job_offer: respuesta no permitida (%)', p_decision
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_oferta
  FROM public.job_offers
  WHERE id = p_offer_id AND candidate_id = v_actor
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'respond_to_job_offer: la oferta % no existe o no es tuya', p_offer_id
      USING ERRCODE = '42501';
  END IF;

  IF v_oferta.status NOT IN ('sent', 'viewed') THEN
    RAISE EXCEPTION 'respond_to_job_offer: esta oferta ya no está abierta'
      USING ERRCODE = '42501';
  END IF;

  -- El vencimiento se evalúa acá y no depende de ningún proceso programado:
  -- una oferta vencida no se puede aceptar aunque nadie la haya marcado.
  IF v_oferta.expires_at IS NOT NULL AND v_oferta.expires_at <= now() THEN
    UPDATE public.job_offers SET status = 'expired' WHERE id = p_offer_id;
    PERFORM public.log_job_offer_version(p_offer_id, 'vencida', NULL);
    RAISE EXCEPTION 'respond_to_job_offer: la oferta venció'
      USING ERRCODE = '42501';
  END IF;

  -- Rechazar o pedir cambios sin decir nada deja a la empresa sin nada que
  -- hacer con la respuesta. Aceptar no necesita mensaje.
  IF p_decision <> 'accepted' AND v_msg IS NULL THEN
    RAISE EXCEPTION 'respond_to_job_offer: hace falta un mensaje para rechazar o pedir cambios'
      USING ERRCODE = '22023';
  END IF;

  IF p_decision = 'accepted' THEN
    UPDATE public.job_offers
    SET status = 'accepted', decided_at = now()
    WHERE id = p_offer_id;

    PERFORM public.log_job_offer_version(p_offer_id, 'aceptada', v_msg);

    -- ACÁ SE CIERRA EL PROCESO. No se escribe `hired` a mano: pasa por la
    -- misma validación de transiciones y deja la misma fila de historial que
    -- cualquier otro cambio de etapa (ver §2).
    PERFORM public.apply_application_status_change(
      v_oferta.application_id, 'hired', NULL, 'El candidato aceptó la oferta'
    );

  ELSIF p_decision = 'declined' THEN
    UPDATE public.job_offers
    SET status = 'declined', decided_at = now(), decline_reason = v_msg
    WHERE id = p_offer_id;

    PERFORM public.log_job_offer_version(p_offer_id, 'rechazada', v_msg);

    -- LA POSTULACIÓN NO SE TOCA, a propósito. Que el candidato rechace una
    -- oferta no significa que la empresa lo descarte: puede mejorar la
    -- oferta o seguir con él en otra vacante. Esa decisión es de la empresa.

  ELSE
    UPDATE public.job_offers
    SET status = 'changes_requested'
    WHERE id = p_offer_id;

    PERFORM public.log_job_offer_version(p_offer_id, 'cambios_pedidos', v_msg);
  END IF;
END;
$$;


-- ── La empresa la retira ───────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.withdraw_job_offer(
  p_offer_id UUID,
  p_reason   TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor  UUID := auth.uid();
  v_estado TEXT;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'withdraw_job_offer: sin sesión activa' USING ERRCODE = '28000';
  END IF;

  SELECT status INTO v_estado
  FROM public.job_offers
  WHERE id = p_offer_id AND company_id = v_actor
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'withdraw_job_offer: la oferta % no existe o no es de tu empresa', p_offer_id
      USING ERRCODE = '42501';
  END IF;

  IF v_estado NOT IN ('draft', 'sent', 'viewed', 'changes_requested') THEN
    RAISE EXCEPTION 'withdraw_job_offer: esta oferta ya está cerrada'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.job_offers SET status = 'withdrawn' WHERE id = p_offer_id;
  PERFORM public.log_job_offer_version(p_offer_id, 'retirada', p_reason);
END;
$$;


-- ── Vencimiento en lote ────────────────────────────────────────────────────
--    NO HAY TAREA PROGRAMADA todavía. Esta función existe para engancharla a
--    una cuando se decida, pero la corrección no depende de ella: ninguna
--    oferta vencida se puede aceptar, porque `respond_to_job_offer` mira el
--    reloj por su cuenta.

CREATE OR REPLACE FUNCTION public.expire_stale_job_offers()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id    UUID;
  v_total INTEGER := 0;
BEGIN
  -- El UPDATE va dentro de un CTE para poder recorrer las filas que
  -- realmente cambiaron y dejarle una versión a cada una.
  FOR v_id IN
    WITH vencidas AS (
      UPDATE public.job_offers
      SET status = 'expired'
      WHERE status IN ('sent', 'viewed')
        AND expires_at IS NOT NULL
        AND expires_at <= now()
      RETURNING id
    )
    SELECT id FROM vencidas
  LOOP
    PERFORM public.log_job_offer_version(v_id, 'vencida', NULL);
    v_total := v_total + 1;
  END LOOP;

  RETURN v_total;
END;
$$;


-- ── Permisos ───────────────────────────────────────────────────────────────

DO $$
DECLARE
  v_fn TEXT;
BEGIN
  FOREACH v_fn IN ARRAY ARRAY[
    'public.create_job_offer(uuid,numeric,text,text,text,jsonb,date,timestamptz,text)',
    'public.send_job_offer(uuid)',
    'public.revise_job_offer(uuid,numeric,text,text,text,jsonb,date,timestamptz,text)',
    'public.mark_job_offer_viewed(uuid)',
    'public.respond_to_job_offer(uuid,text,text)',
    'public.withdraw_job_offer(uuid,text)'
  ] LOOP
    EXECUTE format('ALTER FUNCTION %s OWNER TO postgres', v_fn);
    EXECUTE format(
      'REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated, service_role', v_fn
    );
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', v_fn);
  END LOOP;
END;
$$;

-- El vencimiento en lote NO se le da a `authenticated`: es mantenimiento.
ALTER FUNCTION public.expire_stale_job_offers() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.expire_stale_job_offers()
  FROM PUBLIC, anon, authenticated, service_role;


NOTIFY pgrst, 'reload schema';

COMMIT;
