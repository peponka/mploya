const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export interface PaymentIntentDependencies {
  authenticate(jwt: string): Promise<string | null>;
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

export async function handleCreatePaymentIntent(
  req: Request,
  deps: PaymentIntentDependencies,
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

  // Do not parse client product, amount, currency or user fields. Payments stay
  // closed until a server-owned catalog and entitlement webhook exist.
  return json(503, {
    error: 'payments_unavailable',
    message: 'Premium estara disponible proximamente.',
  });
}
