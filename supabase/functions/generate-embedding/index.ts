import { createClient } from 'npm:@supabase/supabase-js@2';

import {
  EMBED_DIMS,
  handleGenerateEmbedding,
  type ProfileForEmbedding,
} from './handler.ts';

const GEMINI_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent';

// Deployment dependency: 032_safe_user_profile_access.sql must be applied
// before this function is deployed. There is intentionally no users fallback.
Deno.serve((req) =>
  handleGenerateEmbedding(req, {
    authenticate: async (jwt) => {
      const client = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? '',
        { global: { headers: { Authorization: `Bearer ${jwt}` } } },
      );
      const { data, error } = await client.auth.getUser(jwt);
      return error ? null : data.user?.id ?? null;
    },
    readOwnProfile: async () => {
      const authHeader = req.headers.get('Authorization') ?? '';
      const client = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? '',
        { global: { headers: { Authorization: authHeader } } },
      );
      // get_my_profile derives its only row from auth.uid(); no body UUID is
      // passed to the RPC or used as profile-read authority.
      const { data, error } = await client.rpc('get_my_profile');
      if (error) throw new Error('profile_read_failed');
      if (!Array.isArray(data) || data.length === 0) return null;
      return data[0] as ProfileForEmbedding;
    },
    embed: async (profileText) => {
      const geminiKey = Deno.env.get('GEMINI_API_KEY');
      if (!geminiKey) throw new Error('embedding_provider_unavailable');

      const response = await fetch(GEMINI_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': geminiKey,
        },
        body: JSON.stringify({
          content: { parts: [{ text: profileText }] },
          outputDimensionality: EMBED_DIMS,
        }),
      });
      if (!response.ok) throw new Error('embedding_provider_failed');

      const payload = await response.json();
      return payload?.embedding?.values;
    },
    writeOwnEmbedding: async (actorId, embedding) => {
      // The elevated client exists only for the final derived-column write.
      const serviceClient = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      );
      const { error } = await serviceClient
        .from('users')
        .update({ profile_embedding: JSON.stringify(embedding) })
        .eq('id', actorId);
      if (error) throw new Error('embedding_write_failed');
    },
  })
);
