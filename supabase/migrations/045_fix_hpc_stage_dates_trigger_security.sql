-- Corrige un bug de la migración 044: al extender el trigger
-- `trg_hpc_stage_dates` para además insertar en
-- `headhunter_pipeline_stage_history`, la función no se marcó
-- `SECURITY DEFINER`. Como esa tabla no tiene policy de INSERT para
-- `authenticated` a propósito (sólo el trigger debe escribir ahí — ver el
-- doc-comment de la migración 044), la función corría con los privilegios
-- del headhunter y RLS bloqueaba su propio INSERT con 403 — lo que hacía
-- fallar CUALQUIER cambio de etapa del pipeline (`setPipelineCandidateStage`),
-- no sólo el paso a "colocado". Confirmado en vivo el 19/8 al probar el
-- flujo de "Registrar colocación".
--
-- SECURITY DEFINER es seguro acá: el trigger sólo inserta valores que ya
-- salen de la fila que se está actualizando (NEW.id/OLD.stage/NEW.stage), y
-- el UPDATE que lo dispara sigue protegido por la policy `hpc_update`
-- (USING/WITH CHECK `headhunter_id = auth.uid()`), evaluada por el executor
-- independientemente del contexto de seguridad del trigger.

CREATE OR REPLACE FUNCTION public.headhunter_pipeline_candidates_stage_dates()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.stage IS DISTINCT FROM OLD.stage THEN
    NEW.stage_changed_at := now();
    INSERT INTO public.headhunter_pipeline_stage_history (pipeline_candidate_id, from_stage, to_stage)
    VALUES (NEW.id, OLD.stage, NEW.stage);
  END IF;
  RETURN NEW;
END;
$function$;
