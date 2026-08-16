import test from 'node:test';
import assert from 'node:assert/strict';

import {
  EMBED_DIMS,
  handleGenerateEmbedding,
  MAX_BODY_BYTES,
  type GenerateEmbeddingDependencies,
} from './handler.ts';

const OWN = '11111111-1111-4111-8111-111111111111';
const OTHER = '22222222-2222-4222-8222-222222222222';
const MISSING = '33333333-3333-4333-8333-333333333333';

function request(body: string, token = 'valid-token', extra: HeadersInit = {}): Request {
  return new Request('https://example.test/generate-embedding', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...extra,
    },
    body,
  });
}

function doubles(options: { actor?: string | null; profile?: Record<string, unknown> | null } = {}) {
  const calls: string[] = [];
  const deps: GenerateEmbeddingDependencies = {
    authenticate: async () => {
      calls.push('authenticate');
      return options.actor === undefined ? OWN : options.actor;
    },
    readOwnProfile: async (id) => {
      calls.push(`read:${id}`);
      return options.profile === undefined
        ? { headline: 'Flutter developer', about: 'Mobile applications', tags: ['Dart'], skills: ['Flutter'] }
        : options.profile;
    },
    embed: async () => {
      calls.push('embed');
      return Array.from({ length: EMBED_DIMS }, () => 0.25);
    },
    writeOwnEmbedding: async (id) => {
      calls.push(`write:${id}`);
    },
  };
  return { calls, deps };
}

test('rejects requests without Authorization before any privileged work', async () => {
  const { calls, deps } = doubles();
  const req = new Request('https://example.test/generate-embedding', {
    method: 'POST', body: JSON.stringify({ user_id: OWN }),
  });
  const response = await handleGenerateEmbedding(req, deps);
  assert.equal(response.status, 401);
  assert.deepEqual(calls, []);
});

test('rejects an invalid JWT before reading a profile', async () => {
  const { calls, deps } = doubles({ actor: null });
  const response = await handleGenerateEmbedding(request(JSON.stringify({ user_id: OWN })), deps);
  assert.equal(response.status, 401);
  assert.deepEqual(calls, ['authenticate']);
});

test('generates and writes only the authenticated user embedding', async () => {
  const { calls, deps } = doubles();
  const response = await handleGenerateEmbedding(request(JSON.stringify({ user_id: OWN })), deps);
  assert.equal(response.status, 200);
  assert.deepEqual(calls, ['authenticate', `read:${OWN}`, 'embed', `write:${OWN}`]);
  assert.deepEqual(await response.json(), { success: true, dims: EMBED_DIMS });
});

test('an authenticated user cannot target another UUID', async () => {
  const { calls, deps } = doubles();
  const response = await handleGenerateEmbedding(request(JSON.stringify({ user_id: OTHER })), deps);
  assert.equal(response.status, 404);
  assert.deepEqual(await response.json(), { error: 'profile_not_available' });
  assert.deepEqual(calls, ['authenticate']);
});

test('an unrelated nonexistent UUID has the same non-enumerating response', async () => {
  const { calls, deps } = doubles();
  const response = await handleGenerateEmbedding(request(JSON.stringify({ user_id: MISSING })), deps);
  assert.equal(response.status, 404);
  assert.deepEqual(await response.json(), { error: 'profile_not_available' });
  assert.deepEqual(calls, ['authenticate']);
});

test('rejects malformed bodies and arbitrary fields', async () => {
  const wrongType = doubles();
  const plainText = request(JSON.stringify({ user_id: OWN }), 'valid-token', {
    'Content-Type': 'text/plain',
  });
  assert.equal((await handleGenerateEmbedding(plainText, wrongType.deps)).status, 415);
  const malformed = doubles();
  assert.equal((await handleGenerateEmbedding(request('{'), malformed.deps)).status, 400);
  const arbitrary = doubles();
  const body = JSON.stringify({ user_id: OWN, profile: 'client supplied' });
  assert.equal((await handleGenerateEmbedding(request(body), arbitrary.deps)).status, 400);
  assert.deepEqual(arbitrary.calls, ['authenticate']);
});

test('rejects oversized request and profile content', async () => {
  const body = JSON.stringify({ user_id: OWN });
  const declared = doubles();
  const oversizedRequest = request(body, 'valid-token', {
    'Content-Length': String(MAX_BODY_BYTES + 1),
  });
  assert.equal((await handleGenerateEmbedding(oversizedRequest, declared.deps)).status, 413);

  const profile = doubles({ profile: { headline: 'x'.repeat(501) } });
  assert.equal(
    (await handleGenerateEmbedding(request(body), profile.deps)).status,
    422,
  );
  assert.equal(profile.calls.includes('embed'), false);
});

test('errors and logs never include tokens, PII, profiles or embeddings', async () => {
  const pii = 'secret.person@example.test';
  const { deps } = doubles({ profile: { headline: pii } });
  deps.embed = async () => {
    throw new Error(`provider leaked ${pii}`);
  };
  const originalError = console.error;
  const originalLog = console.log;
  const logs: unknown[] = [];
  console.error = (...args) => logs.push(args);
  console.log = (...args) => logs.push(args);
  try {
    const response = await handleGenerateEmbedding(
      request(JSON.stringify({ user_id: OWN }), 'private-jwt'),
      deps,
    );
    assert.equal(response.status, 503);
    assert.equal((await response.text()).includes(pii), false);
    assert.deepEqual(logs, []);
  } finally {
    console.error = originalError;
    console.log = originalLog;
  }
});

test('no write occurs unless authorization, profile validation and embedding succeed', async () => {
  const invalid = doubles();
  invalid.deps.embed = async () => [1, 2, 3];
  const response = await handleGenerateEmbedding(
    request(JSON.stringify({ user_id: OWN })),
    invalid.deps,
  );
  assert.equal(response.status, 502);
  assert.equal(invalid.calls.some((call) => call.startsWith('write:')), false);
});
