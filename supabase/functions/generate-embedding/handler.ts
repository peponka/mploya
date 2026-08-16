export const EMBED_DIMS = 1536;
export const MAX_BODY_BYTES = 1024;
export const MAX_PROFILE_TEXT_CHARS = 12_000;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export interface ProfileForEmbedding {
  headline?: unknown;
  about?: unknown;
  tags?: unknown;
  skills?: unknown;
}

export interface GenerateEmbeddingDependencies {
  authenticate(jwt: string): Promise<string | null>;
  readOwnProfile(actorId: string): Promise<ProfileForEmbedding | null>;
  embed(profileText: string): Promise<unknown>;
  writeOwnEmbedding(actorId: string, embedding: number[]): Promise<void>;
}

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Cache-Control': 'no-store',
      'Content-Type': 'application/json',
    },
  });
}

function bearer(req: Request): string | null {
  const match = req.headers.get('Authorization')?.match(/^Bearer\s+(\S+)\s*$/i);
  return match?.[1] ?? null;
}

function safeString(value: unknown, max: number): string | null {
  if (value == null) return '';
  if (typeof value !== 'string' || value.length > max) return null;
  return value.trim();
}

function safeList(value: unknown): string[] | null {
  if (value == null) return [];
  if (!Array.isArray(value) || value.length > 100) return null;
  const result: string[] = [];
  for (const item of value) {
    const text = safeString(item, 200);
    if (text == null) return null;
    if (text) result.push(text);
  }
  return result;
}

function profileText(profile: ProfileForEmbedding): string | null {
  const headline = safeString(profile.headline, 500);
  const about = safeString(profile.about, 8_000);
  const tags = safeList(profile.tags);
  const skills = safeList(profile.skills);
  if (headline == null || about == null || tags == null || skills == null) return null;

  const result = [headline, about, ...tags, ...skills].filter(Boolean).join(' ');
  return result.length <= MAX_PROFILE_TEXT_CHARS ? result : null;
}

export async function handleGenerateEmbedding(
  req: Request,
  deps: GenerateEmbeddingDependencies,
): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json(405, { error: 'method_not_allowed' });

  const jwt = bearer(req);
  if (!jwt) return json(401, { error: 'not_authenticated' });

  let actorId: string | null;
  try {
    actorId = await deps.authenticate(jwt);
  } catch {
    actorId = null;
  }
  if (!actorId) return json(401, { error: 'not_authenticated' });

  const contentType = req.headers.get('Content-Type')?.toLowerCase() ?? '';
  if (!contentType.startsWith('application/json')) {
    return json(415, { error: 'invalid_request' });
  }

  const declaredSize = Number(req.headers.get('Content-Length') ?? 0);
  if (Number.isFinite(declaredSize) && declaredSize > MAX_BODY_BYTES) {
    return json(413, { error: 'request_too_large' });
  }

  let rawBody: string;
  try {
    rawBody = await req.text();
  } catch {
    return json(400, { error: 'invalid_request' });
  }
  if (new TextEncoder().encode(rawBody).byteLength > MAX_BODY_BYTES) {
    return json(413, { error: 'request_too_large' });
  }

  let body: unknown;
  try {
    body = JSON.parse(rawBody);
  } catch {
    return json(400, { error: 'invalid_request' });
  }
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return json(400, { error: 'invalid_request' });
  }
  const values = body as Record<string, unknown>;
  if (Object.keys(values).some((key) => key !== 'user_id')) {
    return json(400, { error: 'invalid_request' });
  }
  if (typeof values.user_id !== 'string' || !UUID.test(values.user_id)) {
    return json(400, { error: 'invalid_request' });
  }
  if (values.user_id.toLowerCase() !== actorId.toLowerCase()) {
    return json(404, { error: 'profile_not_available' });
  }

  try {
    const profile = await deps.readOwnProfile(actorId);
    if (!profile) return json(404, { error: 'profile_not_available' });

    const text = profileText(profile);
    if (text == null) return json(422, { error: 'profile_content_invalid' });
    if (!text) return json(400, { error: 'profile_incomplete' });

    const candidate = await deps.embed(text);
    if (
      !Array.isArray(candidate) ||
      candidate.length !== EMBED_DIMS ||
      candidate.some((value) => typeof value !== 'number' || !Number.isFinite(value))
    ) {
      return json(502, { error: 'embedding_unavailable' });
    }

    await deps.writeOwnEmbedding(actorId, candidate as number[]);
    return json(200, { success: true, dims: candidate.length });
  } catch {
    return json(503, { error: 'embedding_unavailable' });
  }
}
