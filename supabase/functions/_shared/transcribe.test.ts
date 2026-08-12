// Tests del módulo de transcripción, EJECUTABLES sin tocar Supabase ni Gemini.
//
//     node --test supabase/functions/_shared/transcribe.test.ts
//
// Se usa `node:test` porque en esta máquina no hay Deno instalado y el módulo
// no depende de ningún global de Deno: son funciones puras más un cliente de
// Supabase que acá se reemplaza por un doble. La red se corta sustituyendo
// `fetch`, así que ninguna prueba gasta un token de Gemini.

import test from 'node:test';
import assert from 'node:assert/strict';

import {
  detectarMime,
  esTranscripcionReal,
  MARCA_SIN_AUDIO,
  PLACEHOLDER_LEGADO,
  rutaDeStorage,
  transcribirRespuesta,
} from './transcribe.ts';

// ── Doble del cliente de Supabase ───────────────────────────────────────────

interface Fila {
  id: string;
  video_url: string | null;
  transcript: string | null;
}

/// Doble de `SupabaseClient` que modela lo que de verdad importa: el UPDATE es
/// CONDICIONAL, así que sólo "escribe" si la condición se cumple contra el
/// estado actual de la fila. Eso permite simular carreras de verdad.
///
/// `opciones.errorRelectura` fuerza que la lectura previa al UPDATE falle.
/// `opciones.pisar` simula que otra llamada escribió mientras Gemini trabajaba.
function clienteFalso(
  fila: Fila | null,
  opciones: {
    descarga?: Uint8Array;
    errorRelectura?: string;
    pisar?: string;
  } = {},
) {
  const registro = {
    updates: [] as string[],
    descargas: 0,
    lecturas: 0,
    condicionesFallidas: 0,
  };

  const constructor = () => {
    const op: {
      tipo: 'select' | 'update';
      payload?: Record<string, unknown>;
      cond?: { col: string; valor: unknown; modo: 'is' | 'eq' };
    } = { tipo: 'select' };

    const b: Record<string, unknown> = {
      select: () => b,
      order: () => b,
      limit: () => b,
      update: (payload: Record<string, unknown>) => {
        op.tipo = 'update';
        op.payload = payload;
        return b;
      },
      eq: (col: string, valor: unknown) => {
        if (op.tipo === 'update' && col === 'transcript') {
          op.cond = { col, valor, modo: 'eq' };
        }
        return b;
      },
      is: (col: string, valor: unknown) => {
        if (op.tipo === 'update' && col === 'transcript') {
          op.cond = { col, valor, modo: 'is' };
        }
        return b;
      },
      maybeSingle: () => {
        registro.lecturas++;
        // La segunda lectura es la relectura previa al UPDATE.
        if (registro.lecturas >= 2) {
          if (opciones.errorRelectura) {
            return Promise.resolve({
              data: null,
              error: { message: opciones.errorRelectura },
            });
          }
          if (opciones.pisar && fila) fila.transcript = opciones.pisar;
        }
        return Promise.resolve({ data: fila, error: null });
      },
      then: (res: (v: unknown) => unknown) => {
        if (op.tipo !== 'update') {
          return Promise.resolve(res({ data: null, error: null }));
        }
        const actual = fila?.transcript ?? null;
        const cumple = op.cond === undefined
            ? true // update sin condición: el camino de rescate
            : op.cond.modo === 'is'
            ? actual === null
            : actual === op.cond.valor;

        if (!cumple) {
          registro.condicionesFallidas++;
          return Promise.resolve(res({ data: [], error: null }));
        }
        const texto = String(op.payload?.transcript ?? '');
        registro.updates.push(texto);
        if (fila) fila.transcript = texto;
        return Promise.resolve(res({ data: [{ id: fila?.id }], error: null }));
      },
    };
    return b;
  };

  return {
    registro,
    cliente: {
      from: () => constructor(),
      storage: {
        from: () => ({
          download: async () => {
            registro.descargas++;
            const bytes = opciones.descarga ?? new Uint8Array([0x1a, 0x45, 0xdf, 0xa3, 1, 2, 3, 4]);
            return {
              data: {
                arrayBuffer: async () => bytes.buffer.slice(
                  bytes.byteOffset,
                  bytes.byteOffset + bytes.byteLength,
                ),
                type: 'video/webm',
              },
              error: null,
            };
          },
        }),
      },
    },
  };
}

/// Sustituye `fetch` y cuenta cuántas veces se llamó a Gemini.
function conGemini(
  respuesta: { ok: boolean; texto?: string },
  fn: (contador: () => number) => Promise<void>,
) {
  const original = globalThis.fetch;
  let llamadas = 0;

  globalThis.fetch = (async (url: string) => {
    if (String(url).includes('generativelanguage')) {
      llamadas++;
      if (!respuesta.ok) {
        return new Response('quota exceeded', { status: 429 });
      }
      return new Response(JSON.stringify({
        candidates: [{ content: { parts: [{ text: respuesta.texto ?? '' }] } }],
      }), { status: 200 });
    }
    throw new Error(`fetch inesperado a ${url}`);
  }) as typeof fetch;

  return fn(() => llamadas).finally(() => {
    globalThis.fetch = original;
  });
}

const TEXTO_REAL =
  'Trabajé cuatro años como desarrollador Flutter, sobre todo optimizando '
  + 'listas grandes y moviendo cálculos pesados a isolates.';

// ── Qué cuenta como transcripción real ──────────────────────────────────────

test('el placeholder legacy NO es una transcripción', () => {
  assert.equal(esTranscripcionReal(PLACEHOLDER_LEGADO), false);
});

test('null, vacío y espacios NO son transcripción', () => {
  assert.equal(esTranscripcionReal(null), false);
  assert.equal(esTranscripcionReal(undefined), false);
  assert.equal(esTranscripcionReal(''), false);
  assert.equal(esTranscripcionReal('      '), false);
});

test('una marca sola entre corchetes NO es transcripción', () => {
  // Es lo que devuelve el modelo cuando no hay voz en el video.
  assert.equal(esTranscripcionReal('[inaudible]'), false);
  assert.equal(esTranscripcionReal('  [sin audio]  '), false);
});

test('un texto real SÍ es transcripción', () => {
  assert.equal(esTranscripcionReal(TEXTO_REAL), true);
});

test('un texto con [inaudible] adentro sigue siendo válido', () => {
  assert.equal(
    esTranscripcionReal('Trabajé en varios proyectos [inaudible] durante tres años.'),
    true,
  );
});

// ── MIME por bytes, no por extensión ────────────────────────────────────────

test('detecta WebM por cabecera EBML aunque el nombre diga .mp4', () => {
  const webm = new Uint8Array([0x1a, 0x45, 0xdf, 0xa3, 0, 0, 0, 0]);
  assert.equal(detectarMime(webm, 'video/mp4', 'x/y.mp4'), 'video/webm');
});

test('detecta MP4 por el box ftyp aunque el nombre diga .webm', () => {
  const mp4 = new Uint8Array([
    0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6d, 0x70, 0x34, 0x32,
  ]);
  assert.equal(detectarMime(mp4, 'video/webm', 'x/y.webm'), 'video/mp4');
});

test('sin cabecera reconocible cae al Content-Type', () => {
  const raro = new Uint8Array([9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9]);
  assert.equal(detectarMime(raro, 'video/webm', 'x/y'), 'video/webm');
});

test('sin cabecera ni Content-Type cae a la extensión', () => {
  const raro = new Uint8Array([9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9]);
  assert.equal(detectarMime(raro, null, 'x/y.webm'), 'video/webm');
});

// ── Ruta de Storage ─────────────────────────────────────────────────────────

test('extrae bucket y ruta de una URL pública de Storage', () => {
  const r = rutaDeStorage(
    'https://abc.supabase.co/storage/v1/object/public/videos/interviews/i1_q1.webm',
  );
  assert.deepEqual(r, { bucket: 'videos', path: 'interviews/i1_q1.webm' });
});

test('una URL que no es de Storage no rompe: devuelve null', () => {
  assert.equal(rutaDeStorage('https://ejemplo.com/video.mp4'), null);
});

// ── Idempotencia y errores ──────────────────────────────────────────────────

test('con transcripción real ya guardada NO se llama a Gemini', async () => {
  const { cliente, registro } = clienteFalso({
    id: 'a1', video_url: 'https://x/storage/v1/object/public/videos/i_q.webm',
    transcript: TEXTO_REAL,
  });

  await conGemini({ ok: true }, async (llamadas) => {
    const r = await transcribirRespuesta(cliente as never, 'K', 'i', 'q');
    assert.equal(r.ok, true);
    assert.equal(r.estado, 'ya_transcripta');
    assert.equal(llamadas(), 0, 'no debe gastar tokens');
    assert.equal(registro.descargas, 0, 'ni siquiera baja el video');
  });
});

test('con el placeholder viejo SÍ transcribe y guarda', async () => {
  const { cliente, registro } = clienteFalso({
    id: 'a1', video_url: 'https://x/storage/v1/object/public/videos/i_q.webm',
    transcript: PLACEHOLDER_LEGADO,
  });

  await conGemini({ ok: true, texto: TEXTO_REAL }, async (llamadas) => {
    const r = await transcribirRespuesta(cliente as never, 'K', 'i', 'q');
    assert.equal(r.ok, true);
    assert.equal(r.estado, 'transcripta');
    assert.equal(llamadas(), 1);
    assert.deepEqual(registro.updates, [TEXTO_REAL]);
  });
});

test('con transcript NULL transcribe y guarda', async () => {
  const { cliente, registro } = clienteFalso({
    id: 'a1', video_url: 'https://x/storage/v1/object/public/videos/i_q.webm',
    transcript: null,
  });

  await conGemini({ ok: true, texto: TEXTO_REAL }, async () => {
    const r = await transcribirRespuesta(cliente as never, 'K', 'i', 'q');
    assert.equal(r.estado, 'transcripta');
    assert.equal(registro.updates[0], TEXTO_REAL);
  });
});

test('si Gemini falla NO se inventa ni se escribe nada', async () => {
  const { cliente, registro } = clienteFalso({
    id: 'a1', video_url: 'https://x/storage/v1/object/public/videos/i_q.webm',
    transcript: null,
  });

  await conGemini({ ok: false }, async () => {
    const r = await transcribirRespuesta(cliente as never, 'K', 'i', 'q');
    assert.equal(r.ok, false);
    assert.equal(r.estado, 'error');
    assert.match(r.error ?? '', /429/);
    assert.deepEqual(registro.updates, [], 'la columna queda intacta');
  });
});

test('si Gemini devuelve vacío NO se guarda un texto falso', async () => {
  const { cliente, registro } = clienteFalso({
    id: 'a1', video_url: 'https://x/storage/v1/object/public/videos/i_q.webm',
    transcript: null,
  });

  await conGemini({ ok: true, texto: '   ' }, async () => {
    const r = await transcribirRespuesta(cliente as never, 'K', 'i', 'q');
    assert.equal(r.ok, false);
    assert.equal(r.error, 'gemini_no_devolvio_transcripcion');
    assert.deepEqual(registro.updates, []);
  });
});

test('si Gemini sólo devuelve [inaudible] tampoco se guarda', async () => {
  const { cliente, registro } = clienteFalso({
    id: 'a1', video_url: 'https://x/storage/v1/object/public/videos/i_q.webm',
    transcript: null,
  });

  await conGemini({ ok: true, texto: '[inaudible]' }, async () => {
    const r = await transcribirRespuesta(cliente as never, 'K', 'i', 'q');
    assert.equal(r.ok, false);
    assert.deepEqual(registro.updates, []);
  });
});

test('sin video_url da un error claro y no llama a Gemini', async () => {
  const { cliente } = clienteFalso({ id: 'a1', video_url: null, transcript: null });

  await conGemini({ ok: true }, async (llamadas) => {
    const r = await transcribirRespuesta(cliente as never, 'K', 'i', 'q');
    assert.equal(r.ok, false);
    assert.equal(r.error, 'sin_video');
    assert.equal(llamadas(), 0);
  });
});

test('si no existe la respuesta se dice, no se inventa', async () => {
  const { cliente } = clienteFalso(null);

  await conGemini({ ok: true }, async (llamadas) => {
    const r = await transcribirRespuesta(cliente as never, 'K', 'i', 'q');
    assert.equal(r.ok, false);
    assert.equal(r.error, 'respuesta_inexistente');
    assert.equal(llamadas(), 0);
  });
});

// ── Video sin audio ─────────────────────────────────────────────────────────

test('SIN_AUDIO no cuenta como transcripción', () => {
  assert.equal(esTranscripcionReal(MARCA_SIN_AUDIO), false);
  assert.equal(esTranscripcionReal('  sin_audio  '), false);
});

test('si el video no tiene voz NO se guarda nada', async () => {
  const { cliente, registro } = clienteFalso({
    id: 'a1', video_url: 'https://x/storage/v1/object/public/videos/i_q.webm',
    transcript: null,
  });

  await conGemini({ ok: true, texto: MARCA_SIN_AUDIO }, async () => {
    const r = await transcribirRespuesta(cliente as never, 'K', 'i', 'q');
    assert.equal(r.ok, false);
    assert.equal(r.error, 'video_sin_voz');
    assert.deepEqual(registro.updates, []);
  });
});

test('el prompt le prohíbe describir lo que ve', async () => {
  // Sin esta instrucción, un video mudo puede volver como
  // "Una persona sentada frente a la cámara", que parece una respuesta.
  const { cliente } = clienteFalso({
    id: 'a1', video_url: 'https://x/storage/v1/object/public/videos/i_q.webm',
    transcript: null,
  });

  let prompt = '';
  const original = globalThis.fetch;
  globalThis.fetch = (async (url: string, init: RequestInit) => {
    prompt = String(init.body);
    return new Response(JSON.stringify({
      candidates: [{ content: { parts: [{ text: TEXTO_REAL }] } }],
    }), { status: 200 });
  }) as typeof fetch;

  try {
    await transcribirRespuesta(cliente as never, 'K', 'i', 'q');
  } finally {
    globalThis.fetch = original;
  }

  assert.match(prompt, /No describas lo que se ve en el video/);
  assert.match(prompt, /SIN_AUDIO/);
});

// ── Relectura y escritura condicional ───────────────────────────────────────

test('si la relectura previa falla NO se escribe', async () => {
  const { cliente, registro } = clienteFalso(
    {
      id: 'a1', video_url: 'https://x/storage/v1/object/public/videos/i_q.webm',
      transcript: null,
    },
    { errorRelectura: 'conexión caída' },
  );

  await conGemini({ ok: true, texto: TEXTO_REAL }, async () => {
    const r = await transcribirRespuesta(cliente as never, 'K', 'i', 'q');
    assert.equal(r.ok, false);
    assert.match(r.error ?? '', /relectura/);
    assert.deepEqual(registro.updates, [], 'no se toca la columna a ciegas');
  });
});

test('si otra llamada gana la carrera, NO se pisa su transcripción', async () => {
  const OTRA = 'Esta es la transcripción que escribió la otra llamada primero.';
  const { cliente, registro } = clienteFalso(
    {
      id: 'a1', video_url: 'https://x/storage/v1/object/public/videos/i_q.webm',
      transcript: null,
    },
    { pisar: OTRA },
  );

  await conGemini({ ok: true, texto: TEXTO_REAL }, async () => {
    const r = await transcribirRespuesta(cliente as never, 'K', 'i', 'q');
    assert.equal(r.ok, true);
    assert.equal(r.estado, 'ya_transcripta');
    assert.equal(r.transcript, OTRA);
    assert.deepEqual(registro.updates, [], 'no se sobrescribe lo ajeno');
  });
});

test('el UPDATE es condicional sobre el valor leído', async () => {
  // Con transcript NULL, la condición tiene que ser `is null`; el doble sólo
  // deja pasar la escritura si la fila sigue en ese estado.
  const { cliente, registro } = clienteFalso({
    id: 'a1', video_url: 'https://x/storage/v1/object/public/videos/i_q.webm',
    transcript: null,
  });

  await conGemini({ ok: true, texto: TEXTO_REAL }, async () => {
    const r = await transcribirRespuesta(cliente as never, 'K', 'i', 'q');
    assert.equal(r.estado, 'transcripta');
    assert.equal(registro.condicionesFallidas, 0);
    assert.deepEqual(registro.updates, [TEXTO_REAL]);
  });
});

test('desde el placeholder, la condición compara contra el placeholder', async () => {
  const { cliente, registro } = clienteFalso({
    id: 'a1', video_url: 'https://x/storage/v1/object/public/videos/i_q.webm',
    transcript: PLACEHOLDER_LEGADO,
  });

  await conGemini({ ok: true, texto: TEXTO_REAL }, async () => {
    const r = await transcribirRespuesta(cliente as never, 'K', 'i', 'q');
    assert.equal(r.estado, 'transcripta');
    assert.equal(registro.condicionesFallidas, 0);
    assert.deepEqual(registro.updates, [TEXTO_REAL]);
  });
});

test('reintentar después de transcribir no vuelve a procesar', async () => {
  const { cliente, registro } = clienteFalso({
    id: 'a1', video_url: 'https://x/storage/v1/object/public/videos/i_q.webm',
    transcript: null,
  });

  await conGemini({ ok: true, texto: TEXTO_REAL }, async (llamadas) => {
    const primera = await transcribirRespuesta(cliente as never, 'K', 'i', 'q');
    assert.equal(primera.estado, 'transcripta');
    assert.equal(llamadas(), 1);

    // El doble deja la transcripción escrita en la fila, igual que la base.
    const segunda = await transcribirRespuesta(cliente as never, 'K', 'i', 'q');
    assert.equal(segunda.estado, 'ya_transcripta');
    assert.equal(llamadas(), 1, 'no se gastan tokens dos veces');
    assert.equal(registro.updates.length, 1);
  });
});
