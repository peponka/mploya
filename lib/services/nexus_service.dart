import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NexusService — Motor del sistema de conexión bidireccional
//
// Responsabilidades:
//  • Enviar señales de interés (⚡) y micro-pitch (🎬)
//  • Aceptar / rechazar señales recibidas
//  • Stream de señales pendientes para el ATS Dashboard
//  • Detectar matches y notificar
// ─────────────────────────────────────────────────────────────────────────────

class NexusService {
  NexusService._();
  static final NexusService instance = NexusService._();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  // ── Enviar señal de interés (double-tap ⚡) ──────────────────────────────

  /// Envía un interés rápido. Retorna null si OK, o un error string.
  Future<String?> sendInterest(String receiverId) async {
    if (_uid == null) return 'Sin sesión activa';
    if (_uid == receiverId) return null;

    try {
      // Verificar si ya existe una señal (no degradar micro_pitch → interest)
      final existing = await _client
          .from('nexus_signals')
          .select('id, signal_type')
          .eq('sender_id', _uid!)
          .eq('receiver_id', receiverId)
          .maybeSingle();

      if (existing != null) {
        // Ya existe señal — no hacer nada (no degradar)
        return null;
      }

      await _client.from('nexus_signals').insert({
        'sender_id': _uid,
        'receiver_id': receiverId,
        'signal_type': 'interest',
        'status': 'pending',
      });

      // ── Notificación al receptor ──
      try {
        final senderData = await _client
            .from('users')
            .select('name')
            .eq('id', _uid!)
            .maybeSingle();
        final senderName = senderData?['name'] ?? 'Alguien';
        await _client.rpc('create_system_notification', params: {
          'p_user_id': receiverId,
          'p_type': 'connection',
          'p_description': '⚡ $senderName mostró interés en tu perfil.',
          'p_actor_id': _uid,
        });
      } catch (e) {
        debugPrint('⚠️ NexusService notification error: $e');
      }

      return null;
    } catch (e) {
      debugPrint('NexusService.sendInterest error: $e');
      return 'Error al enviar interés';
    }
  }

  // ── Enviar micro-pitch (video de 15 seg) ─────────────────────────────────

  /// Envía un micro-pitch con URL de video.
  Future<String?> sendMicroPitch(String receiverId, String videoUrl) async {
    if (_uid == null) return 'Sin sesión activa';

    try {
      // Micro-pitch siempre upgradea — usar upsert aquí sí es correcto
      await _client.from('nexus_signals').upsert({
        'sender_id': _uid,
        'receiver_id': receiverId,
        'signal_type': 'micro_pitch',
        'video_url': videoUrl,
        'status': 'pending',
      }, onConflict: 'sender_id,receiver_id');

      // ── Notificación al receptor ──
      try {
        final senderData = await _client
            .from('users')
            .select('name')
            .eq('id', _uid!)
            .maybeSingle();
        final senderName = senderData?['name'] ?? 'Alguien';
        await _client.rpc('create_system_notification', params: {
          'p_user_id': receiverId,
          'p_type': 'comment',
          'p_description': '🎬 $senderName te envió un Video Reply. ¡Miralo en tu perfil!',
          'p_actor_id': _uid,
        });
      } catch (e) {
        debugPrint('⚠️ NexusService micro-pitch notification error: $e');
      } // No bloquear si falla la notificación

      return null;
    } catch (e) {
      debugPrint('NexusService.sendMicroPitch error: $e');
      return 'Error al enviar micro-pitch';
    }
  }

  // ── Aceptar señal (genera NEXUS MATCH) ───────────────────────────────────

  /// La empresa acepta la señal → match bidireccional.
  Future<bool> acceptSignal(String signalId) async {
    try {
      // Obtener datos de la señal antes de actualizarla
      final signal = await _client
          .from('nexus_signals')
          .select('sender_id, receiver_id')
          .eq('id', signalId)
          .maybeSingle();

      await _client.from('nexus_signals').update({
        'status': 'matched',
      }).eq('id', signalId);

      // ── Notificación al sender: ¡Match! ──
      if (signal != null) {
        try {
          final receiverData = await _client
              .from('users')
              .select('name')
              .eq('id', signal['receiver_id'])
              .maybeSingle();
          final receiverName = receiverData?['name'] ?? 'Una empresa';
          await _client.rpc('create_system_notification', params: {
            'p_user_id': signal['sender_id'],
            'p_type': 'connection',
            'p_description': '🎉 ¡Match! $receiverName aceptó tu solicitud. Conectá ahora.',
            'p_actor_id': _uid,
          });
        } catch (e) {
          debugPrint('⚠️ NexusService match notification error: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('NexusService.acceptSignal error: $e');
      return false;
    }
  }

  // ── Rechazar señal ───────────────────────────────────────────────────────

  Future<bool> declineSignal(String signalId) async {
    try {
      await _client.from('nexus_signals').update({
        'status': 'declined',
      }).eq('id', signalId);
      return true;
    } catch (e) {
      debugPrint('NexusService.declineSignal error: $e');
      return false;
    }
  }

  // ── Streams ──────────────────────────────────────────────────────────────

  /// Stream de señales recibidas pendientes (para el ATS/Empresa)
  Stream<List<Map<String, dynamic>>> get pendingSignalsStream {
    if (_uid == null) return const Stream.empty();
    return _client
        .from('nexus_signals')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', _uid!)
        .order('created_at', ascending: false)
        .limit(50);
  }

  /// Stream de señales enviadas (para saber si ya mostré interés)
  Stream<List<Map<String, dynamic>>> get sentSignalsStream {
    if (_uid == null) return const Stream.empty();
    return _client
        .from('nexus_signals')
        .stream(primaryKey: ['id'])
        .eq('sender_id', _uid!)
        .order('created_at', ascending: false)
        .limit(50);
  }

  // ── Queries puntuales ────────────────────────────────────────────────────

  /// Verifica si ya envié una señal a este usuario
  Future<bool> hasSignalTo(String receiverId) async {
    if (_uid == null) return false;
    try {
      final res = await _client
          .from('nexus_signals')
          .select('id')
          .eq('sender_id', _uid!)
          .eq('receiver_id', receiverId)
          .maybeSingle();
      return res != null;
    } catch (e) {
      debugPrint('❌ NexusService.hasSignalTo: $e');
      return false;
    }
  }

  /// Obtiene el estado de mi señal a un usuario específico
  Future<String?> getSignalStatus(String receiverId) async {
    if (_uid == null) return null;
    try {
      final res = await _client
          .from('nexus_signals')
          .select('status')
          .eq('sender_id', _uid!)
          .eq('receiver_id', receiverId)
          .maybeSingle();
      return res?['status']?.toString();
    } catch (e) {
      debugPrint('❌ NexusService.getSignalStatus: $e');
      return null;
    }
  }
}
