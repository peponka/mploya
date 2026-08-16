import { createClient } from 'npm:@supabase/supabase-js@2';

import { handleCreatePaymentIntent } from './handler.ts';

Deno.serve((req) =>
  handleCreatePaymentIntent(req, {
    authenticate: async (jwt) => {
      const client = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? '',
        { global: { headers: { Authorization: `Bearer ${jwt}` } } },
      );
      const { data, error } = await client.auth.getUser(jwt);
      return error ? null : data.user?.id ?? null;
    },
  })
);
