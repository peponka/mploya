// ─────────────────────────────────────────────────────────────────────────────
// _shared/transcribe.ts — Transcripción REAL del audio de una respuesta de
// entrevista, con Gemini, del lado del servidor.
//
// POR QUÉ ESTE MÓDULO ES COMPARTIDO Y NO UNA LLAMADA HTTP ENTRE FUNCIONES
//
// Lo usan tres Edge Functions:
//   · transcribe-interview-answer  → lo dispara el candidato al subir cada
//                                    respuesta (con su JWT, autorizado).
//   · generate-interview-report    → red de seguridad: transcribe lo que falte
//                                    antes de evaluar.
//   · analyze-video-pitch          → reutiliza `descargarVideo` y
//                                    `transcribirConGemini` (exportadas más
//                                    abajo) para transcribir el video pitch
//                                    de perfil (users.video_url), que no
//                                    tiene interview_id/question_id — por
//                                    eso usa las dos piezas sueltas en vez de
//                                    `transcribirRespuesta`, que sí está
//                                    atada a `interview_answers`.
//
// Si el informe invocara por HTTP a la otra función tendría que autenticarse
// con el service_role, y esa función exige un JWT de usuario real. Importar el
// módulo evita ese agujero, evita un salto de red y garantiza que las dos vías
// apliquen EXACTAMENTE las mismas reglas.
//
// Los archivos que empiezan con `_` no se despliegan como función: se empaquetan
// dentro de quien los importa.
// ─────────────────────────────────────────────────────────────────────────────

import type { SupabaseClient } from 'npm:@supabase/supabase-js@2';

// ── Modelo ───────────────────────────────────────────────────────────────────
//
// Se usa el MISMO modelo que ya usan generate-interview-questions y
// generate-interview-report: es el que está probado contra la GEMINI_API_KEY de
// este proyecto. La documentación actual menciona modelos más nuevos; cambiarlo
// es tocar esta constante y nada más.
const MODELO = 'gemini-2.5-flash';
const GEMINI = 'https://generativelanguage.googleapis.com/v1beta';

// ── Cuándo dejar de mandar el archivo inline ────────────────────────────────
//
// La documentación de Gemini fija el límite en 20 MB de REQUEST TOTAL (archivo
// + prompt + todo lo demás), y recomienda la Files API por encima de eso.
//
// El archivo no viaja crudo: va en base64, que infla los bytes en 4/3. O sea que
// el techo real de bytes de video es 20 MB × 3/4 ≈ 15 MB. Se corta en 14 MB para
// dejar margen al prompt y al JSON del sobre.
//
// No es un "20 MB" copiado: es el límite del endpoint traducido a bytes de
// entrada.
const LIMITE_INLINE_BYTES = 14 * 1024 * 1024;

// Tope de espera a que la Files API termine de procesar el video. Las Edge
// Functions tienen un límite de tiempo de pared; es preferible fallar con un
// motivo claro antes de que la mate el runtime.
const ESPERA_MAX_MS = 60_000;
const ESPERA_PASO_MS = 2_000;

/// Lo que escribía el cliente antes de que existiera la transcripción real.
/// Sigue vivo en filas viejas de `interview_answers`.
export const PLACEHOLDER_LEGADO = '[Respuesta grabada en video]';

/// Lo que el modelo debe devolver cuando el video no tiene voz.
///
/// EL PROBLEMA QUE RESUELVE. Gemini no sólo escucha: también VE los cuadros. Si
/// el video no tiene audio —micrófono mudo, permiso denegado, grabación
/// fallida—, un modelo al que se le pide "transcribí" puede ponerse a describir
/// lo que ve: "Una persona sentada frente a la cámara en una oficina". Ese texto
/// pasa cualquier control de largo y quedaría guardado como si fuera lo que el
/// candidato dijo. Sería exactamente el mismo defecto que el placeholder que
/// vinimos a eliminar, pero más difícil de detectar, porque suena plausible.
///
/// Por eso se le da al modelo una salida explícita y se la rechaza acá.
export const MARCA_SIN_AUDIO = 'SIN_AUDIO';

const PROMPT_TRANSCRIPCION = `Transcribí literalmente el audio de este video.
No resumas.
No corrijas el contenido.
No inventes palabras.
Conservá el idioma original.
Si una parte no se entiende, marcala como [inaudible].
No describas lo que se ve en el video: transcribí únicamente lo que se escucha.
Si el video no tiene voz audible en ninguna parte, devolvé exactamente ${MARCA_SIN_AUDIO} y nada más.
Devolvé únicamente la transcripción, sin comentarios ni encabezados.`;

// ── Qué cuenta como transcripción de verdad ─────────────────────────────────

/// Una transcripción sirve sólo si tiene contenido del candidato.
///
/// Rechaza, además de null y vacío:
///   · el placeholder que escribía el cliente;
///   · la marca `SIN_AUDIO`, con la que el modelo avisa que no hay voz;
///   · cualquier texto que sea SÓLO una marca entre corchetes —`[inaudible]`,
///     `[sin audio]`—, que es lo que devuelve el modelo cuando no hay voz;
///   · textos absurdamente cortos, que no son una respuesta a una pregunta de
///     entrevista.
///
/// Es la MISMA regla en la transcripción y en el informe: lo que acá no pasa,
/// allá no se evalúa. Y como `SIN_AUDIO` nunca se guarda, tampoco puede quedar
/// una fila en ese estado: se la trata como "sin transcribir".
export function esTranscripcionReal(t: string | null | undefined): boolean {
  const s = (t ?? '').trim();
  if (s.length === 0) return false;
  if (s === PLACEHOLDER_LEGADO) return false;
  if (s.toUpperCase() === MARCA_SIN_AUDIO) return false;
  if (/^\[[^\]]*\]$/.test(s)) return false;
  return s.length >= 10;
}

// ── Resultado ────────────────────────────────────────────────────────────────

export type EstadoTranscripcion =
  | 'transcripta'      // se llamó a Gemini y se guardó
  | 'ya_transcripta'   // ya había texto real: no se gastó un token
  | 'error';

export interface ResultadoTranscripcion {
  ok: boolean;
  estado: EstadoTranscripcion;
  transcript?: string;
  error?: string;
}

// ── Descarga del video ───────────────────────────────────────────────────────

/// Saca bucket y ruta de una URL pública de Supabase Storage.
///
/// Formato: `.../storage/v1/object/public/<bucket>/<ruta...>`
export function rutaDeStorage(
  url: string,
): { bucket: string; path: string } | null {
  const m = url.match(/\/storage\/v1\/object\/(?:public\/|sign\/)?([^/]+)\/(.+)$/);
  if (!m) return null;
  const path = m[2].split('?')[0];
  return { bucket: m[1], path: decodeURIComponent(path) };
}

/// MIME real del archivo, mirando los bytes.
///
/// La extensión NO alcanza: en la web el navegador graba WebM y hubo casos de
/// WebM subido con nombre .mp4 (ya documentado en StorageService). Se decide por
/// cabecera mágica y sólo se cae al Content-Type o a la extensión si los bytes
/// no dicen nada.
export function detectarMime(
  bytes: Uint8Array,
  contentType?: string | null,
  url?: string,
): string {
  // Matroska / WebM: 1A 45 DF A3
  if (
    bytes.length >= 4 &&
    bytes[0] === 0x1a && bytes[1] === 0x45 &&
    bytes[2] === 0xdf && bytes[3] === 0xa3
  ) {
    return 'video/webm';
  }

  // ISO-BMFF / MP4: los bytes 4..8 son 'ftyp'
  if (
    bytes.length >= 12 &&
    bytes[4] === 0x66 && bytes[5] === 0x74 &&
    bytes[6] === 0x79 && bytes[7] === 0x70
  ) {
    return 'video/mp4';
  }

  const ct = (contentType ?? '').split(';')[0].trim().toLowerCase();
  if (ct === 'video/webm' || ct === 'video/mp4') return ct;

  const u = (url ?? '').toLowerCase();
  if (u.includes('.webm')) return 'video/webm';
  if (u.includes('.mp4')) return 'video/mp4';

  // Último recurso: el formato que más produce la app.
  return 'video/mp4';
}

/// Baja el video con el cliente de service_role.
///
/// Primero por la API de Storage, que funciona **con el bucket público o
/// privado**. Sólo si la URL no se puede descomponer se cae a un fetch directo,
/// que depende de que el bucket siga siendo público.
///
/// Esto es a propósito: cuando el bucket `videos` pase a privado (tarea
/// aparte), esta función sigue andando sin tocar una línea.
export async function descargarVideo(
  supabase: SupabaseClient,
  videoUrl: string,
): Promise<{ bytes: Uint8Array; mime: string }> {
  const ref = rutaDeStorage(videoUrl);

  if (ref) {
    const { data, error } = await supabase.storage
      .from(ref.bucket)
      .download(ref.path);
    if (!error && data) {
      const bytes = new Uint8Array(await data.arrayBuffer());
      return { bytes, mime: detectarMime(bytes, data.type, videoUrl) };
    }
  }

  const res = await fetch(videoUrl);
  if (!res.ok) {
    throw new Error(`no se pudo descargar el video (HTTP ${res.status})`);
  }
  const bytes = new Uint8Array(await res.arrayBuffer());
  return {
    bytes,
    mime: detectarMime(bytes, res.headers.get('content-type'), videoUrl),
  };
}

// ── Gemini ───────────────────────────────────────────────────────────────────

function aBase64(bytes: Uint8Array): string {
  // Por bloques: `String.fromCharCode(...bytes)` de un archivo entero revienta
  // la pila de argumentos.
  let bin = '';
  const paso = 0x8000;
  for (let i = 0; i < bytes.length; i += paso) {
    bin += String.fromCharCode(...bytes.subarray(i, i + paso));
  }
  return btoa(bin);
}

const dormir = (ms: number) => new Promise((r) => setTimeout(r, ms));

/// Sube el video por la Files API y devuelve su URI, ya en estado ACTIVE.
async function subirPorFilesApi(
  bytes: Uint8Array,
  mime: string,
  key: string,
  nombre: string,
): Promise<string> {
  const inicio = await fetch(`${GEMINI}/files`, {
    method: 'POST',
    headers: {
      'x-goog-api-key': key,
      'X-Goog-Upload-Protocol': 'resumable',
      'X-Goog-Upload-Command': 'start',
      'X-Goog-Upload-Header-Content-Length': String(bytes.length),
      'X-Goog-Upload-Header-Content-Type': mime,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ file: { display_name: nombre } }),
  });

  const destino = inicio.headers.get('x-goog-upload-url');
  if (!inicio.ok || !destino) {
    throw new Error(`Files API no aceptó la subida (HTTP ${inicio.status})`);
  }

  const subida = await fetch(destino, {
    method: 'POST',
    headers: {
      'Content-Length': String(bytes.length),
      'X-Goog-Upload-Offset': '0',
      'X-Goog-Upload-Command': 'upload, finalize',
    },
    body: bytes,
  });
  if (!subida.ok) {
    throw new Error(`Files API falló al subir (HTTP ${subida.status})`);
  }

  const cuerpo = await subida.json();
  let archivo = cuerpo?.file ?? cuerpo;
  if (!archivo?.uri) throw new Error('Files API no devolvió uri');

  // El video no se puede usar hasta que Google termine de procesarlo.
  let esperado = 0;
  while (archivo.state === 'PROCESSING' && esperado < ESPERA_MAX_MS) {
    await dormir(ESPERA_PASO_MS);
    esperado += ESPERA_PASO_MS;
    const r = await fetch(archivo.uri, { headers: { 'x-goog-api-key': key } });
    if (!r.ok) break;
    const j = await r.json();
    archivo = j?.file ?? j;
  }

  if (archivo.state === 'FAILED') {
    throw new Error('Gemini no pudo procesar el video');
  }
  if (archivo.state === 'PROCESSING') {
    throw new Error('el video sigue procesándose: reintentá en un momento');
  }

  return archivo.uri as string;
}

/// Manda el video a Gemini y devuelve el texto crudo de la transcripción.
export async function transcribirConGemini(
  bytes: Uint8Array,
  mime: string,
  key: string,
  nombre: string,
): Promise<string> {
  const parteMedia = bytes.length > LIMITE_INLINE_BYTES
    ? { fileData: { mimeType: mime, fileUri: await subirPorFilesApi(bytes, mime, key, nombre) } }
    : { inlineData: { mimeType: mime, data: aBase64(bytes) } };

  const res = await fetch(`${GEMINI}/models/${MODELO}:generateContent`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': key },
    body: JSON.stringify({
      contents: [{ parts: [{ text: PROMPT_TRANSCRIPCION }, parteMedia] }],
      // temperature 0: acá no se quiere creatividad, se quiere lo que se dijo.
      generationConfig: { temperature: 0 },
    }),
  });

  if (!res.ok) {
    throw new Error(`Gemini error ${res.status}: ${(await res.text()).slice(0, 300)}`);
  }

  const j = await res.json();
  const partes = j?.candidates?.[0]?.content?.parts ?? [];
  return partes.map((p: { text?: string }) => p?.text ?? '').join('').trim();
}

// ── Entrada principal ────────────────────────────────────────────────────────

/// Transcribe UNA respuesta y deja el texto en `interview_answers.transcript`.
///
/// Idempotente: si la fila ya tiene texto real, devuelve `ya_transcripta` sin
/// tocar Gemini.
///
/// NUNCA escribe un placeholder ni un texto inventado. Si algo falla, la
/// columna queda como estaba (NULL o vacía) y se devuelve el motivo: el estado
/// "sin transcribir" tiene que seguir siendo detectable.
///
/// CONCURRENCIA. El candidato dispara esta función al subir cada respuesta, y
/// generate-interview-report puede intentar lo mismo si algo faltó. Tres
/// defensas, ninguna de las cuales necesita SQL nuevo:
///
///   1. se sale temprano si la fila ya tiene texto real (no se gasta ni una
///      descarga);
///   2. se relee justo antes de escribir, controlando el error: si no se puede
///      saber en qué estado está la fila, no se escribe;
///   3. el UPDATE es CONDICIONAL sobre el valor leído (compare-and-swap): sólo
///      escribe si `transcript` sigue siendo exactamente el que se leyó. Si otra
///      llamada ganó, no se actualiza ninguna fila y se acepta la ajena.
///
/// GARANTÍA: una transcripción real NUNCA se sobrescribe, ni por otra llamada
/// simultánea ni por una que venga demorada.
///
/// LO QUE SÍ PUEDE PASAR: que dos llamadas para la misma respuesta paguen los
/// tokens de Gemini en paralelo antes de que una gane el CAS. Es gasto, no
/// corrupción. Evitarlo del todo exigiría un `transcript_status` con lock, o sea
/// una migración, y no compensa para un caso tan infrecuente.
export async function transcribirRespuesta(
  supabase: SupabaseClient,
  geminiKey: string,
  interviewId: string,
  questionId: string,
): Promise<ResultadoTranscripcion> {
  try {
    // `submitAnswer` inserta (no upsert), así que un candidato que reintenta
    // puede dejar más de una fila para la misma pregunta. Vale la última.
    const { data: fila, error } = await supabase
      .from('interview_answers')
      .select('id, video_url, transcript')
      .eq('interview_id', interviewId)
      .eq('question_id', questionId)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) {
      return { ok: false, estado: 'error', error: `lectura: ${error.message}` };
    }
    if (!fila) {
      return { ok: false, estado: 'error', error: 'respuesta_inexistente' };
    }

    if (esTranscripcionReal(fila.transcript)) {
      return { ok: true, estado: 'ya_transcripta', transcript: fila.transcript };
    }

    if (!fila.video_url) {
      return { ok: false, estado: 'error', error: 'sin_video' };
    }

    const { bytes, mime } = await descargarVideo(supabase, fila.video_url);
    if (bytes.length === 0) {
      return { ok: false, estado: 'error', error: 'video_vacio' };
    }

    const texto = await transcribirConGemini(
      bytes,
      mime,
      geminiKey,
      `${interviewId}_${questionId}`,
    );

    // El video no tenía voz: el modelo lo avisa con la marca convenida. NO se
    // guarda nada — una descripción de lo que se ve no es lo que dijo nadie.
    if (texto.trim().toUpperCase() === MARCA_SIN_AUDIO) {
      return { ok: false, estado: 'error', error: 'video_sin_voz' };
    }

    // El modelo puede devolver vacío o sólo `[inaudible]`. Eso NO se guarda:
    // un informe sobre eso sería igual de falso que uno sobre el placeholder.
    if (!esTranscripcionReal(texto)) {
      return {
        ok: false,
        estado: 'error',
        error: 'gemini_no_devolvio_transcripcion',
      };
    }

    // Relectura antes de escribir: si otra vía la transcribió mientras tanto,
    // gana la que ya está y no se pisa nada. El error se controla: si no se
    // puede saber en qué estado está la fila, NO se escribe.
    const { data: reciente, error: errRelectura } = await supabase
      .from('interview_answers')
      .select('transcript')
      .eq('id', fila.id)
      .maybeSingle();

    if (errRelectura) {
      return {
        ok: false,
        estado: 'error',
        error: `relectura: ${errRelectura.message}`,
      };
    }

    if (esTranscripcionReal(reciente?.transcript)) {
      return {
        ok: true,
        estado: 'ya_transcripta',
        transcript: reciente!.transcript,
      };
    }

    // ── ESCRITURA CONDICIONAL (compare-and-swap, sin migración) ─────────────
    //
    // El UPDATE no dice sólo "esta fila": dice "esta fila, Y SÓLO SI su
    // transcript sigue siendo exactamente el que leí". Si otra llamada escribió
    // entre la relectura y este momento, la condición no se cumple, no se
    // actualiza ninguna fila y no se pisa nada.
    //
    // Es más fuerte que un "escribí si está NULL o vacío o placeholder": no
    // depende de enumerar los valores no-válidos, y además se expresa con
    // filtros simples (`is` / `eq`) en vez de un `or` con comillas, que es
    // frágil de escapar.
    const escritura = supabase
      .from('interview_answers')
      .update({ transcript: texto })
      .eq('id', fila.id);

    const { data: filasEscritas, error: errUpdate } = await (
      fila.transcript === null || fila.transcript === undefined
        ? escritura.is('transcript', null)
        : escritura.eq('transcript', fila.transcript)
    ).select('id');

    if (errUpdate) {
      return { ok: false, estado: 'error', error: `guardado: ${errUpdate.message}` };
    }

    if (filasEscritas && filasEscritas.length > 0) {
      return { ok: true, estado: 'transcripta', transcript: texto };
    }

    // No se escribió ninguna fila: alguien la tocó en el ínterin. Se mira qué
    // quedó antes de decidir nada.
    const { data: final, error: errFinal } = await supabase
      .from('interview_answers')
      .select('transcript')
      .eq('id', fila.id)
      .maybeSingle();

    if (errFinal) {
      return { ok: false, estado: 'error', error: `relectura: ${errFinal.message}` };
    }

    if (esTranscripcionReal(final?.transcript)) {
      // Ganó la otra llamada. Su texto es una transcripción del MISMO video, así
      // que no hay nada que corregir: se acepta y se descarta el propio.
      return {
        ok: true,
        estado: 'ya_transcripta',
        transcript: final!.transcript,
      };
    }

    // La fila sigue sin transcripción real y la condición igual falló. Pasa,
    // por ejemplo, si el valor previo era una cadena vacía, que PostgREST no
    // siempre filtra igual. Acá SÍ se escribe sin condición, pero recién
    // después de haber comprobado —en la línea de arriba— que no hay ninguna
    // transcripción real que perder.
    const { error: errForzado } = await supabase
      .from('interview_answers')
      .update({ transcript: texto })
      .eq('id', fila.id);

    if (errForzado) {
      return { ok: false, estado: 'error', error: `guardado: ${errForzado.message}` };
    }

    return { ok: true, estado: 'transcripta', transcript: texto };
  } catch (e) {
    return { ok: false, estado: 'error', error: (e as Error).message };
  }
}
