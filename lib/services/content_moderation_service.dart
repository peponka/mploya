import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ContentModerationService — Filtro de contenido + moderación IA
//
// Capas de moderación:
//   1. Client-side: Filtro de keywords + patrones (instantáneo)
//   2. Server-side: Edge Function con modelo IA (async, para validación profunda)
//
// Se usa en:
//   • Chat (messaging_screen.dart) → antes de enviar mensaje
//   • Comentarios (tiktok_reel_card.dart) → antes de publicar comentario
//   • Títulos de vacantes (create_job_screen.dart) → opcional
//
// Política:
//   • BLOCK = No se envía + alerta al usuario
//   • FLAG  = Se envía pero se reporta para revisión manual
//   • CLEAN = Se envía normalmente
// ─────────────────────────────────────────────────────────────────────────────

enum ModerationResult { clean, flagged, blocked }

class ModerationResponse {
  final ModerationResult result;
  final String? reason;
  final String? category;

  const ModerationResponse({
    required this.result,
    this.reason,
    this.category,
  });

  bool get isBlocked => result == ModerationResult.blocked;
  bool get isFlagged => result == ModerationResult.flagged;
  bool get isClean => result == ModerationResult.clean;
}

class ContentModerationService {
  ContentModerationService._();
  static final ContentModerationService instance = ContentModerationService._();

  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  // ── Listas de palabras bloqueadas (client-side) ─────────────────────────

  /// Insultos / hate speech / discriminación
  static const _blockedPatterns = <String>[
    // Insultos graves (ES)
    'hijo de puta', 'hdp', 'la concha', 'pelotudo', 'boludo de mierda',
    'negro de mierda', 'negra de mierda', 'sudaca', 'bolita',
    'maricón', 'maricon', 'puto', 'trolo',
    // Discriminación
    'volvete a tu país', 'andate a tu pais', 'fuera extranjeros',
    // Amenazas
    'te voy a matar', 'te voy a cagar a tiros', 'voy a buscarte',
    // Insultos graves (EN)
    'fuck you', 'go fuck yourself', 'piece of shit',
    'kill yourself', 'kys',
    // Insultos graves (PT)
    'filho da puta', 'vai se foder', 'desgraçado',
  ];

  /// Spam / solicitudes fuera de contexto
  static const _spamPatterns = <String>[
    'ganá dinero fácil', 'gana dinero facil',
    'trabaja desde casa', 'multinivel', 'mlm',
    'bitcoin gratis', 'crypto gratis', 'inversión garantizada',
    'inversion garantizada', 'haz click aquí', 'haz click aca',
    'enviame tu cv a', 'mandame tu cv a',
    'whatsapp', 'whats app', 'wa.me', 't.me/telegram',
    'onlyfans', 'only fans',
  ];

  /// Contenido sexual / NSFW
  static const _nsfwPatterns = <String>[
    'nudes', 'pack', 'fotos hot', 'contenido adulto',
    'sexo', 'porno', 'xxx',
  ];

  // ── Método principal: moderación completa ──────────────────────────────

  /// Modera un texto con filtro local + IA (si está disponible).
  ///
  /// [text] — El texto a moderar
  /// [context] — 'chat', 'comment', 'job_title' (para IA contextual)
  ///
  /// Retorna un [ModerationResponse] con el resultado.
  Future<ModerationResponse> moderate(
    String text, {
    String context = 'chat',
  }) async {
    // Paso 1: Filtro local (instantáneo)
    final localResult = moderateLocal(text);
    if (localResult.isBlocked) return localResult;

    // Paso 2: Filtro IA (si Edge Function está disponible)
    try {
      final aiResult = await _moderateWithAI(text, context);
      if (aiResult != null) return aiResult;
    } catch (e) {
      debugPrint('⚠️ AI moderation unavailable, using local only: $e');
    }

    // Si la IA no está disponible, devolver resultado local
    return localResult;
  }

  // ── Filtro local (keywords + regex) ────────────────────────────────────

  /// Moderación local instantánea sin red.
  ModerationResponse moderateLocal(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return const ModerationResponse(result: ModerationResult.clean);

    // Check insultos / hate speech → BLOCK
    for (final pattern in _blockedPatterns) {
      if (lower.contains(pattern)) {
        return const ModerationResponse(
          result: ModerationResult.blocked,
          reason: 'Este mensaje contiene lenguaje inapropiado para una red profesional.',
          category: 'hate_speech',
        );
      }
    }

    // Check NSFW → BLOCK
    for (final pattern in _nsfwPatterns) {
      if (lower.contains(pattern)) {
        return const ModerationResponse(
          result: ModerationResult.blocked,
          reason: 'Mploya es una red profesional. Este tipo de contenido no está permitido.',
          category: 'nsfw',
        );
      }
    }

    // Check spam → FLAG (se envía pero se reporta)
    for (final pattern in _spamPatterns) {
      if (lower.contains(pattern)) {
        return const ModerationResponse(
          result: ModerationResult.flagged,
          reason: 'Contenido marcado como posible spam.',
          category: 'spam',
        );
      }
    }

    // Check repetición excesiva (señal de spam/troll)
    if (_isExcessiveRepetition(lower)) {
      return const ModerationResponse(
        result: ModerationResult.flagged,
        reason: 'Mensaje marcado por repetición excesiva.',
        category: 'spam',
      );
    }

    // Check ALL CAPS (agresividad)
    if (text.length > 10 && text == text.toUpperCase() && text.contains(RegExp(r'[A-Z]'))) {
      return const ModerationResponse(
        result: ModerationResult.flagged,
        reason: 'Por favor, evitá escribir todo en mayúsculas.',
        category: 'style',
      );
    }

    return const ModerationResponse(result: ModerationResult.clean);
  }

  /// Detecta repetición excesiva de caracteres o palabras.
  bool _isExcessiveRepetition(String text) {
    // "jajajajajajajajajaja" o "hhhhhhhhhh" 
    if (RegExp(r'(.)\1{7,}').hasMatch(text)) return true;

    // Misma palabra repetida 5+ veces
    final words = text.split(RegExp(r'\s+'));
    if (words.length >= 5) {
      final freq = <String, int>{};
      for (final w in words) {
        freq[w] = (freq[w] ?? 0) + 1;
        if (freq[w]! >= 5) return true;
      }
    }

    return false;
  }

  // ── Filtro IA (via Edge Function) ──────────────────────────────────────

  /// Llama a la Edge Function `moderate-content` para análisis semántico.
  ///
  /// La Edge Function usa un modelo de moderación (ej: OpenAI moderation API,
  /// Google Cloud NLP, o modelo custom) para detectar:
  ///   • Toxicidad / acoso
  ///   • Contenido sexual
  ///   • Incitación a violencia
  ///   • Spam / solicitudes comerciales no deseadas
  ///   • Discriminación
  ///
  /// Retorna null si la Edge Function no está disponible.
  Future<ModerationResponse?> _moderateWithAI(
    String text,
    String context,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'moderate-content',
        body: {
          'text': text,
          'context': context, // 'chat', 'comment', 'job_title'
          'user_id': _uid,
          'language': 'es',
        },
      );

      if (response.status != 200) return null;

      final data = response.data as Map<String, dynamic>?;
      if (data == null) return null;

      final action = data['action']?.toString() ?? 'clean';
      final reason = data['reason']?.toString();
      final category = data['category']?.toString();

      switch (action) {
        case 'block':
          return ModerationResponse(
            result: ModerationResult.blocked,
            reason: reason ?? 'Contenido bloqueado por la IA de moderación.',
            category: category,
          );
        case 'flag':
          return ModerationResponse(
            result: ModerationResult.flagged,
            reason: reason,
            category: category,
          );
        default:
          return const ModerationResponse(result: ModerationResult.clean);
      }
    } catch (e) {
      debugPrint('❌ ContentModerationService._moderateWithAI: $e');
      return null;
    }
  }

  // ── Reporte manual ─────────────────────────────────────────────────────

  /// Reporta un mensaje o comentario para revisión manual.
  Future<bool> reportContent({
    required String contentId,
    required String contentType, // 'message', 'comment', 'job'
    required String reason,
    String? details,
  }) async {
    if (_uid == null) return false;

    try {
      await _supabase.from('content_reports').insert({
        'reporter_id': _uid,
        'content_id': contentId,
        'content_type': contentType,
        'reason': reason,
        'details': details,
      });
      return true;
    } catch (e) {
      debugPrint('❌ ContentModerationService.reportContent: $e');
      return false;
    }
  }

  // ── Auto-moderación de mensajes flagged ────────────────────────────────

  /// Guarda un log de contenido flagged para revisión posterior.
  Future<void> logFlaggedContent(
    String text,
    String category,
    String context,
  ) async {
    if (_uid == null) return;

    try {
      await _supabase.from('moderation_log').insert({
        'user_id': _uid,
        'text_snippet': text.length > 200 ? '${text.substring(0, 200)}...' : text,
        'category': category,
        'context': context,
        'action': 'flagged',
      });
    } catch (e) {
      debugPrint('❌ ContentModerationService.logFlaggedContent: $e');
    }
  }
}
