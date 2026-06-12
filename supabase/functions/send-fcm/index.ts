import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import admin from "npm:firebase-admin@11.11.1"

// ─────────────────────────────────────────────────────────────────────────────
// send-fcm — Edge Function para enviar Push Notifications vía FCM
//
// Soporta DOS modos:
//   1. Webhook (desde Database Webhooks de Supabase) — triggered automáticamente
//   2. Invocación directa (desde el cliente Flutter) — para mensajes de chat
//
// Eventos soportados:
//   • connections.UPDATE → status='accepted' → "¡Nuevo match!"
//   • connections.INSERT → "Solicitud de conexión"
//   • messages.INSERT → "Nuevo mensaje"
//   • pitch_reactions.INSERT → "Reacción a tu pitch"
//   • Invocación directa con { target_user_id, title, body, data }
// ─────────────────────────────────────────────────────────────────────────────

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  record: any;
  old_record: any;
}

interface DirectPayload {
  target_user_id: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

// ── Firebase Admin init (singleton) ──────────────────────────────────────────

function ensureFirebaseInit() {
  if (!admin.apps.length) {
    const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!serviceAccountStr) throw new Error("Falta secreto FIREBASE_SERVICE_ACCOUNT");
    const serviceAccount = JSON.parse(serviceAccountStr);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
  }
}

// ── Supabase Admin client ────────────────────────────────────────────────────

function getSupabaseAdmin() {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );
}

// ── Enviar notificación a un usuario por ID ──────────────────────────────────

async function sendPushToUser(
  userId: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<{ success: boolean; messageId?: string; error?: string }> {
  const supabase = getSupabaseAdmin();

  // Consultar fcm_token Y preferencia de push del usuario
  const { data: user, error } = await supabase
    .from('users')
    .select('fcm_token, push_enabled')
    .eq('id', userId)
    .single();

  if (error || !user?.fcm_token) {
    console.log(`Usuario ${userId} no tiene fcm_token. Skip.`);
    return { success: false, error: 'no_fcm_token' };
  }

  // Respetar preferencia del usuario — si desactivó push, no enviar
  if (user.push_enabled === false) {
    console.log(`Usuario ${userId} tiene push desactivado. Skip.`);
    return { success: false, error: 'push_disabled' };
  }

  ensureFirebaseInit();

  try {
    const messageId = await admin.messaging().send({
      token: user.fcm_token,
      notification: { title, body },
      data: data ?? {},
      android: {
        priority: 'high' as const,
        notification: {
          channelId: 'mploya_default',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    });

    console.log(`✅ Push sent to ${userId}: ${messageId}`);
    return { success: true, messageId };
  } catch (fcmError: any) {
    // Token inválido → limpiar de la DB
    if (fcmError.code === 'messaging/registration-token-not-registered' ||
        fcmError.code === 'messaging/invalid-registration-token') {
      console.log(`🧹 Token inválido para ${userId}, limpiando...`);
      await supabase.from('users').update({ fcm_token: null }).eq('id', userId);
    }
    console.error(`❌ FCM error for ${userId}:`, fcmError.message);
    return { success: false, error: fcmError.message };
  }
}

// ── Obtener nombre del usuario (para personalizar notificaciones) ────────────

async function getUserName(userId: string): Promise<string> {
  const supabase = getSupabaseAdmin();
  const { data } = await supabase
    .from('users')
    .select('name')
    .eq('id', userId)
    .single();
  return data?.name ?? 'Alguien';
}

// ── Handler principal ────────────────────────────────────────────────────────

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  // Preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const payload = await req.json();

    // ═══════════════════════════════════════════════════════════════════════
    // MODO 1: Invocación directa (desde Flutter)
    //   Body: { target_user_id, title, body, data? }
    // ═══════════════════════════════════════════════════════════════════════
    if (payload.target_user_id) {
      const { target_user_id, title, body, data } = payload as DirectPayload;
      const result = await sendPushToUser(target_user_id, title, body, data);
      return new Response(JSON.stringify(result), {
        status: result.success ? 200 : 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MODO 2: Database Webhook (automático desde Supabase)
    //   Body: { type, table, record, old_record }
    // ═══════════════════════════════════════════════════════════════════════
    const { type, table, record, old_record } = payload as WebhookPayload;

    // ── connections ── Match aceptado o solicitud nueva ──────────────────
    if (table === 'connections') {

      // Solicitud aceptada → notificar al que pidió la conexión
      if (type === 'UPDATE' && record.status === 'accepted' && old_record?.status !== 'accepted') {
        const requesterName = await getUserName(record.addressee_id);
        await sendPushToUser(
          record.requester_id,
          '¡Nuevo Match! 🎉',
          `${requesterName} aceptó tu solicitud de conexión.`,
          { route: 'matches', connection_id: record.id?.toString() ?? '' }
        );
        return new Response(JSON.stringify({ status: 'push_sent', event: 'connection_accepted' }), {
          status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Solicitud nueva → notificar al receptor
      if (type === 'INSERT' && record.status === 'pending') {
        const senderName = await getUserName(record.requester_id);
        await sendPushToUser(
          record.addressee_id,
          'Nueva solicitud de conexión',
          `${senderName} quiere conectar contigo.`,
          { route: 'network', requester_id: record.requester_id }
        );
        return new Response(JSON.stringify({ status: 'push_sent', event: 'connection_request' }), {
          status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }

    // ── messages ── Nuevo mensaje en chat ─────────────────────────────────
    if (table === 'messages' && type === 'INSERT') {
      const senderName = await getUserName(record.sender_id);
      const preview = (record.content ?? '').substring(0, 60) || '📎 Archivo adjunto';
      await sendPushToUser(
        record.receiver_id,
        senderName,
        preview,
        { route: 'chat', sender_id: record.sender_id }
      );
      return new Response(JSON.stringify({ status: 'push_sent', event: 'new_message' }), {
        status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // ── pitch_reactions ── Alguien reaccionó a tu pitch ──────────────────
    if (table === 'pitch_reactions' && type === 'INSERT') {
      const reactorName = await getUserName(record.user_id);
      const emoji = record.reaction_type === 'fire' ? '🔥' :
                    record.reaction_type === 'clap' ? '👏' :
                    record.reaction_type === 'heart' ? '❤️' : '⚡';
      await sendPushToUser(
        record.target_user_id,
        `${reactorName} reaccionó ${emoji}`,
        'Le gustó tu video pitch.',
        { route: 'profile', reactor_id: record.user_id }
      );
      return new Response(JSON.stringify({ status: 'push_sent', event: 'pitch_reaction' }), {
        status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // ── pitch_comments ── Nuevo comentario en tu pitch ───────────────────
    if (table === 'pitch_comments' && type === 'INSERT') {
      const commenterName = await getUserName(record.author_id);
      // Necesitamos saber de quién es el pitch → buscar en users por video
      // El target se determina por el campo target_user_id si existe
      if (record.target_user_id && record.author_id !== record.target_user_id) {
        const preview = (record.content ?? '').substring(0, 50) || 'Comentó en tu pitch';
        await sendPushToUser(
          record.target_user_id,
          `${commenterName} comentó 💬`,
          preview,
          { route: 'profile' }
        );
      }
      return new Response(JSON.stringify({ status: 'push_sent', event: 'pitch_comment' }), {
        status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // ── Evento no manejado ───────────────────────────────────────────────
    return new Response(JSON.stringify({ status: 'ignored', table, type }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (err: any) {
    console.error("Error global send-fcm:", err.message);
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
