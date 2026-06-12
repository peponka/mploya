// supabase/functions/weekly-engagement/index.ts
// ═════════════════════════════════════════════════════════════════════════════
// Edge Function: weekly-engagement
//
// Loop de retención semanal. Envía push notifications personalizadas:
//
// Para CANDIDATOS:
//   "🏢 X empresas vieron tu perfil esta semana"
//   "📈 Tu Video-Pitch fue visto Y veces — ¡seguí así!"
//
// Para EMPRESAS:
//   "🎯 Hay X nuevos candidatos en tu industria esta semana"
//
// Trigger: Cron job semanal (lunes 10:00 AM UTC-3)
//   SELECT cron.schedule('weekly-engagement', '0 13 * * 1',
//     $$SELECT net.http_post(
//       'https://qclipzefqndcefwwixdy.supabase.co/functions/v1/weekly-engagement',
//       '{}', 'application/json',
//       ARRAY[http_header('Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'))]
//     )$$
//   );
// ═════════════════════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  // CORS
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
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const oneWeekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
    let notificationsSent = 0;

    // ── 1. Candidatos: "X empresas vieron tu perfil" ──────────────────────
    // Buscar profile_views de la última semana agrupados por viewed_id
    const { data: viewsByUser } = await admin
      .from("profile_views")
      .select("viewed_id, viewer_id")
      .gte("created_at", oneWeekAgo);

    if (viewsByUser && viewsByUser.length > 0) {
      // Agrupar por viewed_id y contar viewers únicos
      const viewCounts: Record<string, Set<string>> = {};
      for (const v of viewsByUser) {
        const uid = v.viewed_id;
        if (!viewCounts[uid]) viewCounts[uid] = new Set();
        viewCounts[uid].add(v.viewer_id);
      }

      // Enviar notificación a cada candidato con views
      for (const [userId, viewers] of Object.entries(viewCounts)) {
        const count = viewers.size;
        if (count === 0) continue;

        // Verificar que el usuario es candidato
        const { data: user } = await admin
          .from("users")
          .select("account_type, fcm_token")
          .eq("id", userId)
          .single();

        if (!user || (user.account_type !== "candidato" && user.account_type !== "confidencial")) continue;

        // Crear notificación in-app
        await admin.from("notifications").insert({
          user_id: userId,
          type: "engagement",
          description: `🏢 ${count} empresa${count > 1 ? "s" : ""} ${count > 1 ? "vieron" : "vio"} tu perfil esta semana. ¡Tu Video-Pitch está generando interés!`,
          is_read: false,
        });

        // Push notification via FCM (si tiene token)
        if (user.fcm_token) {
          try {
            await sendFCM(user.fcm_token, {
              title: "📊 Tu reporte semanal",
              body: `${count} empresa${count > 1 ? "s" : ""} ${count > 1 ? "vieron" : "vio"} tu perfil esta semana.`,
            });
          } catch (e) {
            console.error(`FCM error for ${userId}:`, e);
          }
        }

        notificationsSent++;
      }
    }

    // ── 2. Empresas: "X nuevos candidatos esta semana" ────────────────────
    // Contar candidatos que se registraron en la última semana
    const { count: newCandidates } = await admin
      .from("users")
      .select("id", { count: "exact", head: true })
      .in_("account_type", ["candidato", "confidencial"])
      .gte("created_at", oneWeekAgo);

    if (newCandidates && newCandidates > 0) {
      // Buscar todas las empresas activas
      const { data: companies } = await admin
        .from("users")
        .select("id, fcm_token")
        .in_("account_type", ["empresa", "headhunter"]);

      if (companies) {
        for (const company of companies) {
          await admin.from("notifications").insert({
            user_id: company.id,
            type: "engagement",
            description: `🎯 ${newCandidates} nuevo${newCandidates > 1 ? "s" : ""} candidato${newCandidates > 1 ? "s" : ""} se ${newCandidates > 1 ? "registraron" : "registró"} esta semana. ¡Explorá sus Video-Pitches!`,
            is_read: false,
          });

          if (company.fcm_token) {
            try {
              await sendFCM(company.fcm_token, {
                title: "🎯 Nuevos candidatos",
                body: `${newCandidates} nuevo${newCandidates > 1 ? "s" : ""} talento${newCandidates > 1 ? "s" : ""} esta semana.`,
              });
            } catch (e) {
              console.error(`FCM error for company ${company.id}:`, e);
            }
          }

          notificationsSent++;
        }
      }
    }

    console.log(`✅ weekly-engagement: ${notificationsSent} notificaciones enviadas.`);

    return new Response(
      JSON.stringify({
        success: true,
        notifications_sent: notificationsSent,
        timestamp: new Date().toISOString(),
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("weekly-engagement error:", err);
    return new Response(
      JSON.stringify({ error: "Error interno." }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

// ── Helper: Enviar push via FCM HTTP v1 ─────────────────────────────────────
async function sendFCM(token: string, notification: { title: string; body: string }) {
  // Usa la Edge Function send-fcm existente (ya deployada)
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  await fetch(`${supabaseUrl}/functions/v1/send-fcm`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${serviceRoleKey}`,
    },
    body: JSON.stringify({
      token: token,
      title: notification.title,
      body: notification.body,
    }),
  });
}
