// ─────────────────────────────────────────────────────────────────────────────
// _shared/autorizacion.ts — Quién puede tocar una entrevista.
//
// POR QUÉ EXISTE (auditoría del 12/8/2026)
//
// `generate-interview-report` tomaba `interview_id` del body, usaba el cliente
// de service_role —que saltea RLS— y NO verificaba nunca quién llamaba. Con eso,
// cualquiera que consiguiera un interview_id podía:
//   · recibir en la respuesta el informe COMPLETO de un candidato ajeno
//     (summary, competencies, keywords, score, rationale);
//   · escribir en interview_reports y marcar la entrevista como completed;
//   · y, desde que existe la red de transcripción, hacer que descarguemos y
//     mandemos a Gemini los VIDEOS de esa entrevista ajena.
//
// El id es un uuid y las políticas RLS impiden leer entrevistas ajenas, así que
// conseguirlo no es trivial. Pero una autorización no puede depender de que un
// identificador sea difícil de adivinar.
//
// Esta comprobación vive suelta para que las dos funciones que tocan una
// entrevista apliquen LA MISMA regla, y para que agregar una tercera no vuelva a
// olvidarse de ella.
// ─────────────────────────────────────────────────────────────────────────────

import type { SupabaseClient } from 'npm:@supabase/supabase-js@2';

export interface Autorizacion {
  ok: boolean;
  /// Id del usuario que llamó, ya resuelto contra la base.
  uid?: string;
  /// Motivo, listo para devolver al cliente.
  error?: string;
  /// Código HTTP sugerido.
  status?: number;
}

/// El JWT del llamador, tal como lo manda `supabase.functions.invoke`.
export function jwtDeRequest(req: Request): string {
  return (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
}

/// ¿El usuario del JWT es parte legítima de esta entrevista?
///
/// Partes, según el modelo real (migración 007):
///   · el candidato — `interviews.candidate_id`;
///   · la empresa dueña de la vacante — `jobs.company_id`.
/// Es la misma condición que usa la función `is_interview_party` de la base.
///
/// El id del usuario NO se toma del body: se resuelve del JWT contra la base. Y
/// la relación se verifica leyendo las tablas, no creyéndole a quien llama.
///
/// Cuando no es parte devuelve el MISMO error que cuando la entrevista no
/// existe: un tercero no averigua si ese id corresponde a algo real.
export async function esParteDeLaEntrevista(
  supabase: SupabaseClient,
  jwt: string,
  interviewId: string,
): Promise<Autorizacion> {
  if (!jwt) return { ok: false, error: 'no_auth', status: 401 };

  const { data: quien, error: errAuth } = await supabase.auth.getUser(jwt);
  const uid = quien?.user?.id;
  if (errAuth || !uid) return { ok: false, error: 'no_auth', status: 401 };

  const { data: entrevista, error: errEnt } = await supabase
    .from('interviews')
    .select('id, candidate_id, job_id')
    .eq('id', interviewId)
    .maybeSingle();

  if (errEnt || !entrevista) {
    return { ok: false, error: 'entrevista_inexistente', status: 404 };
  }

  if (entrevista.candidate_id === uid) return { ok: true, uid };

  const { data: vacante } = await supabase
    .from('jobs')
    .select('company_id')
    .eq('id', entrevista.job_id)
    .maybeSingle();

  if (vacante?.company_id === uid) return { ok: true, uid };

  return { ok: false, error: 'entrevista_inexistente', status: 404 };
}
