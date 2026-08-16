import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import { handleCreatePaymentIntent } from './handler.ts';

const OWN = '11111111-1111-4111-8111-111111111111';

function request(body: Record<string, unknown>, token = 'valid-token'): Request {
  return new Request('https://example.test/create-payment-intent', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

test('rejects a request without a session', async () => {
  const req = new Request('https://example.test/create-payment-intent', { method: 'POST' });
  const response = await handleCreatePaymentIntent(req, { authenticate: async () => OWN });
  assert.equal(response.status, 401);
});

test('a valid session receives controlled unavailability', async () => {
  const response = await handleCreatePaymentIntent(request({}), { authenticate: async () => OWN });
  assert.equal(response.status, 503);
});

test('an invalid JWT is rejected', async () => {
  const response = await handleCreatePaymentIntent(request({}), { authenticate: async () => null });
  assert.equal(response.status, 401);
});

test('a foreign userId cannot change the closed result', async () => {
  const response = await handleCreatePaymentIntent(
    request({ userId: 'another-user' }),
    { authenticate: async () => OWN },
  );
  assert.equal(response.status, 503);
});

test('a manipulated amount cannot create a payment', async () => {
  const response = await handleCreatePaymentIntent(
    request({ amount: 1 }),
    { authenticate: async () => OWN },
  );
  assert.equal(response.status, 503);
});

test('a manipulated currency cannot create a payment', async () => {
  const response = await handleCreatePaymentIntent(
    request({ currency: 'attacker-controlled' }),
    { authenticate: async () => OWN },
  );
  assert.equal(response.status, 503);
});

test('the deployed entrypoint has no Stripe import or PaymentIntent call', () => {
  const index = readFileSync('supabase/functions/create-payment-intent/index.ts', 'utf8');
  assert.equal(index.includes('Stripe'), false);
  assert.equal(index.includes('paymentIntents.create'), false);
  assert.equal(index.includes('STRIPE_SECRET_KEY'), false);
});

test('the closed function never grants premium and returns a stable contract', async () => {
  const source = readFileSync('supabase/functions/create-payment-intent/handler.ts', 'utf8');
  assert.equal(source.includes('is_premium'), false);
  const response = await handleCreatePaymentIntent(
    request({ amount: 999999, currency: 'xxx', userId: 'other' }),
    { authenticate: async () => OWN },
  );
  assert.deepEqual(await response.json(), {
    error: 'payments_unavailable',
    message: 'Premium estara disponible proximamente.',
  });
});
