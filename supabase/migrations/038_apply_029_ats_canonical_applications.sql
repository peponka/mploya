-- 038_apply_029_ats_canonical_applications.sql
--
-- ============================================================================
-- APLICADA A MANO CONTRA PRODUCCIÓN el 18/8/2026 (proyecto Supabase
-- "nexowork"), vía `supabase db query --linked -f` — no vía `db push`.
-- Este proyecto nunca usó el mecanismo de control de migraciones de
-- Supabase (ver investigación completa más abajo): supabase_migrations.
-- schema_migrations NO va a reflejar esta aplicación por sí sola. Si en
-- el futuro alguien corre `supabase migration list --linked` y ve 038
-- sin marca en "Remote", NO asuman que no se aplicó — verifiquen contra
-- los objetos vivos (igual que se hizo acá): CHECK de job_applications.
-- status debe admitir 'hired'/'interviewing', debe haber exactamente 3
-- políticas RLS en job_applications (ja_select/ja_insert_candidate/
-- ja_delete_candidate), y update_application_status debe tener la matriz
-- de transiciones en su cuerpo (pg_get_functiondef).
--
-- QUÉ REEMPLAZA RESPECTO AL 029 ORIGINAL: sólo la omisión de
-- get_company_candidates (§10/§11 de 029). Motivo: verificado en vivo
-- que esa RPC YA EXISTÍA en producción con una firma distinta a la que
-- 029 asumía — 029 esperaba get_company_candidates(TEXT), un solo
-- parámetro; la real es get_company_candidates(p_status text, p_job_id
-- uuid), dos parámetros con default NULL, escrita a mano por alguien
-- DESPUÉS del 13/8/2026 sin pasar por ningún archivo de migración. Ya
-- tenía search_path fijo y EXECUTE correctamente acotado a
-- authenticated+postgres, así que tocarla con la firma vieja del 029
-- habría hecho fallar la migración entera por "función inexistente" sin
-- aportar nada. Todo lo demás de 029 se aplicó tal cual.
--
-- Por qué importa dejarlo escrito: el código Dart (empresa_contrataciones_
-- screen.dart vía empresa_proceso_data.dart, y headhunter_pipeline_screen.
-- dart) ya asumía este esquema completo desde antes del 13/8 — "código
-- completo pero sin aplicar" es exactamente el patrón que ya causó
-- confusión repetida en este proyecto (ver mploya-fuga-pii-users y
-- mploya-privacidad-035-aplicada en la memoria de sesión). Que quede
-- registrado acá para que nadie vuelva a asumir que si el código está
-- escrito, el esquema ya está aplicado.
-- ============================================================================
--
-- Aplica 029_ats_canonical_applications.sql (13/8/2026), que nunca se había
-- ejecutado contra la base real (verificado el 18/8: `supabase migration list`
-- no tiene NINGUNA de las 001-037 marcada como aplicada en
-- supabase_migrations.schema_migrations — este proyecto siempre aplicó las
-- migraciones a mano, vía SQL Editor / `db query`, nunca con `db push`; el
-- mismatch no es evidencia de un revert deliberado, es que esa tabla de
-- control nunca reflejó nada).
--
-- ADAPTACIÓN respecto al archivo original: NO se toca `get_company_candidates`
-- (§10/§11 de 029). Verificado hoy que esa RPC ya existe en producción con una
-- firma distinta a la que 029 asume (`p_status text, p_job_id uuid`, no
-- `TEXT` a secas) — alguien la escribió a mano después del 13/8, ya tiene
-- `search_path` fijo y ya tiene EXECUTE acotado a `authenticated`/`postgres`.
-- Tocarla con la firma vieja habría hecho fallar toda la migración (función
-- inexistente) sin aportar nada, porque ya está bien.
--
-- Todo lo demás es igual al archivo original: cierre de escritura directa
-- primero (§2/§4/§5), CHECK ampliado recién después (§6), invariante
-- hired_at↔status (§7), trigger de fechas (§8), matriz de transiciones en
-- update_application_status (§9), y hardening de esa función +
-- toggle_candidate_favorite (§10/§11, sin get_company_candidates).

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
-- §2 · CIERRE INMEDIATO DE LA ESCRITURA DIRECTA
-- ────────────────────────────────────────────────────────────────────────────

REVOKE INSERT, UPDATE, DELETE ON public.job_applications FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.job_applications FROM authenticated;

DROP POLICY IF EXISTS "Companies can update application status" ON public.job_applications;
DROP POLICY IF EXISTS "applications_update"                     ON public.job_applications;
DROP POLICY IF EXISTS "job_applications_update_company"         ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_update_company"                 ON public.job_applications;
DROP POLICY IF EXISTS "rls_ja_update"                           ON public.job_applications;


-- ────────────────────────────────────────────────────────────────────────────
-- §3 · COLUMNAS NUEVAS
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.job_applications
  ADD COLUMN IF NOT EXISTS stage_changed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS hired_at         TIMESTAMPTZ;

COMMENT ON COLUMN public.job_applications.stage_changed_at IS
  'Momento del último cambio de `status`. NULL = fila anterior a la migración 029: no se registró.';
COMMENT ON COLUMN public.job_applications.hired_at IS
  'Momento de la contratación. NOT NULL si y sólo si status = ''hired'' (constraint job_applications_hired_at_coherente).';


-- ────────────────────────────────────────────────────────────────────────────
-- §4 · RLS: dejar exactamente TRES políticas
-- ────────────────────────────────────────────────────────────────────────────

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

DROP POLICY IF EXISTS "Candidates can apply to jobs"                 ON public.job_applications;
DROP POLICY IF EXISTS "applications_insert"                          ON public.job_applications;
DROP POLICY IF EXISTS "apps_insert_own"                              ON public.job_applications;
DROP POLICY IF EXISTS "job_applications_insert_own"                  ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_candidate_insert"                    ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_insert"                              ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_insert_candidate"                    ON public.job_applications;
DROP POLICY IF EXISTS "rls_ja_insert"                                ON public.job_applications;

DROP POLICY IF EXISTS "Candidates can withdraw own applications"     ON public.job_applications;
DROP POLICY IF EXISTS "job_applications_delete_own"                  ON public.job_applications;
DROP POLICY IF EXISTS "job_apps_delete_candidate"                    ON public.job_applications;

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

CREATE POLICY ja_insert_candidate ON public.job_applications
  FOR INSERT TO authenticated
  WITH CHECK (
    candidate_id         = auth.uid()
    AND status           = 'pending'
    AND stage_changed_at IS NULL
    AND hired_at         IS NULL
  );

CREATE POLICY ja_delete_candidate ON public.job_applications
  FOR DELETE TO authenticated
  USING (
    candidate_id = auth.uid()
    AND status IN ('pending', 'viewed')
  );

-- Sin política de UPDATE, a propósito (deny-by-default; única vía: la RPC de §9).


-- ────────────────────────────────────────────────────────────────────────────
-- §5 · PRIVILEGIOS MÍNIMOS
-- ────────────────────────────────────────────────────────────────────────────

GRANT INSERT (job_id, candidate_id) ON public.job_applications TO authenticated;
GRANT DELETE                        ON public.job_applications TO authenticated;


-- ────────────────────────────────────────────────────────────────────────────
-- §6 · CHECK ampliado
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.job_applications
  DROP CONSTRAINT IF EXISTS job_applications_status_check;

ALTER TABLE public.job_applications
  ADD CONSTRAINT job_applications_status_check
  CHECK (status IN ('pending', 'viewed', 'interviewing', 'accepted', 'hired', 'rejected'));


-- ────────────────────────────────────────────────────────────────────────────
-- §7 · INVARIANTE hired_at ↔ status
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.job_applications
  DROP CONSTRAINT IF EXISTS job_applications_hired_at_coherente;

ALTER TABLE public.job_applications
  ADD CONSTRAINT job_applications_hired_at_coherente
  CHECK ((status = 'hired') = (hired_at IS NOT NULL));


-- ────────────────────────────────────────────────────────────────────────────
-- §8 · TRIGGER BEFORE UPDATE — fechas de etapa
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.job_application_stage_dates()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.stage_changed_at := now();

    IF NEW.status = 'hired' THEN
      NEW.hired_at := now();
    ELSIF OLD.status = 'hired' THEN
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

  IF p_status IS NULL
     OR p_status NOT IN ('pending','viewed','interviewing','accepted','hired','rejected')
  THEN
    RAISE EXCEPTION 'update_application_status: estado no permitido (%)', p_status
      USING ERRCODE = '22023';
  END IF;

  SELECT ja.status INTO v_current
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
  'Única ruta productiva de cambio de etapa de una postulación. Sólo la empresa dueña de la vacante. Valida la matriz de transiciones y falla explícitamente. Ver migraciones 029 y 038.';


-- ────────────────────────────────────────────────────────────────────────────
-- §10 · toggle_candidate_favorite: search_path fijo (get_company_candidates
--       NO se toca — ver nota de cabecera)
-- ────────────────────────────────────────────────────────────────────────────

ALTER FUNCTION public.toggle_candidate_favorite(UUID) SET search_path = public, pg_temp;


-- ────────────────────────────────────────────────────────────────────────────
-- §11 · EXECUTE: sólo authenticated (get_company_candidates NO se toca, ya
--       está correctamente acotada)
-- ────────────────────────────────────────────────────────────────────────────

REVOKE EXECUTE ON FUNCTION public.update_application_status(UUID, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_application_status(UUID, TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.update_application_status(UUID, TEXT) FROM service_role;
GRANT  EXECUTE ON FUNCTION public.update_application_status(UUID, TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.toggle_candidate_favorite(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.toggle_candidate_favorite(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION public.toggle_candidate_favorite(UUID) FROM service_role;
GRANT  EXECUTE ON FUNCTION public.toggle_candidate_favorite(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
