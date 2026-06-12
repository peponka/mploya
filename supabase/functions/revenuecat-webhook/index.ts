// supabase/functions/revenuecat-webhook/index.ts
// Este webhook escucha las compras exitosas en RevenueCat y acredita Tokens Headhunter a la empresa.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

console.log("RevenueCat Webhook en línea.")

serve(async (req) => {
  // 1. Autorización Básica
  const authHeader = req.headers.get('Authorization')
  // Compara esto con un Webhook Auth Token que pongas en tu RevenueCat Dashboard
  if (authHeader !== `Bearer ${Deno.env.get('REVENUECAT_WEBHOOK_KEY')}`) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
  }

  try {
    const body = await req.json()
    const event = body.event

    // 2. Solo nos interesan Nuevas Compras de Tokens B2B
    if (event.type === 'NON_RENEWING_PURCHASE' || event.type === 'INITIAL_PURCHASE') {
      const app_user_id = event.app_user_id // Este es el UUID de Supabase de la empresa
      const product_id = event.product_id

      // Inicializar Supabase Service Role Client
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      )

      // Identificar cantidad de Tokens según el producto comprado en Apple/Google
      let creditsToAdd = 0;
      if (product_id === 'token_1') creditsToAdd = 1;
      else if (product_id === 'token_5') creditsToAdd = 5;
      else if (product_id === 'token_10') creditsToAdd = 10;
      else if (product_id === 'premium_headhunter') creditsToAdd = 1; // Alias general

      if (creditsToAdd > 0) {
        // Ejecutar un RPC de carga de saldo directa, porque no podemos hacer UPDATE por RLS.
        // O mejor, invocar el servicio Service Role para saltarnos el RLS:
        const { data, error } = await supabase.rpc('add_headhunter_credits', {
          p_company_id: app_user_id,
          p_credits: creditsToAdd
        });

        if (error) throw error;

        console.log(`Otorgados ${creditsToAdd} tokens a la empresa ${app_user_id}`);
      }
    }

    return new Response(JSON.stringify({ received: true }), { status: 200 })
  } catch (err) {
    console.error('Error procesando webhook:', err)
    return new Response(JSON.stringify({ error: 'Internal Server Error' }), { status: 500 })
  }
})
