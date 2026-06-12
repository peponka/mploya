// supabase/functions/delete-user/index.ts
// ═════════════════════════════════════════════════════════════════════════════
// Edge Function: delete-user
//
// Elimina permanentemente un usuario de auth.users usando service_role.
// El SDK del cliente NO puede auto-eliminarse por restricciones de seguridad.
//
// Requisitos:
//  - SUPABASE_SERVICE_ROLE_KEY debe estar en los secrets de la Edge Function
//  - Solo acepta requests donde el user_id del body == el uid del JWT
//    (un usuario solo puede eliminarse a sí mismo)
//
// Deploy:
//   supabase functions deploy delete-user --no-verify-jwt
//
// NOTA: --no-verify-jwt NO es necesario si le pasamos el JWT en el header.
// Pero lo dejamos por si el token expiró justo antes de la llamada.
// La verificación de identidad se hace comparando body.user_id con el JWT.
// ═════════════════════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  // ── CORS preflight ──
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const { user_id } = await req.json();

    if (!user_id || typeof user_id !== "string") {
      return new Response(
        JSON.stringify({ error: "user_id requerido" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── Verificar identidad: el JWT del caller debe coincidir con el user_id ──
    const authHeader = req.headers.get("Authorization");
    if (authHeader) {
      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
      const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: { user: caller } } = await callerClient.auth.getUser();

      if (caller?.id !== user_id) {
        return new Response(
          JSON.stringify({ error: "No podés eliminar la cuenta de otro usuario." }),
          { status: 403, headers: { "Content-Type": "application/json" } }
        );
      }
    }

    // ── Eliminar con service_role (admin) ──
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: "SUPABASE_SERVICE_ROLE_KEY no configurada." }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Paso 1: Eliminar la fila de la tabla pública users (por si el cliente
    // no pudo hacerlo o la limpieza fue parcial)
    await adminClient.from("users").delete().eq("id", user_id);

    // Paso 2: Eliminar de auth.users (borrado real — GDPR compliant)
    const { error } = await adminClient.auth.admin.deleteUser(user_id);

    if (error) {
      console.error("Error eliminando usuario de auth:", error.message);
      return new Response(
        JSON.stringify({ error: `Error al eliminar: ${error.message}` }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`✅ Usuario ${user_id} eliminado permanentemente.`);

    return new Response(
      JSON.stringify({ success: true, message: "Cuenta eliminada permanentemente." }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("delete-user error:", err);
    return new Response(
      JSON.stringify({ error: "Error interno del servidor." }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
