import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TranscriptionService — Motor de subtítulos IA para Video Pitches
//
// Integra Deepgram (o Whisper) para transcribir automáticamente los
// video pitches de los usuarios y almacenar los segmentos en
// users.ai_transcript_json.
//
// Flujo:
//   1. Usuario sube video pitch → video_url se guarda en users
//   2. Se llama a transcribeAndSave(userId, videoUrl)
//   3. Deepgram procesa el audio
//   4. Los segmentos se guardan como JSON en ai_transcript_json
//   5. El frontend muestra subtítulos sincronizados durante la reproducción
// ─────────────────────────────────────────────────────────────────────────────

class TranscriptionService {
  TranscriptionService._();
  static final TranscriptionService instance = TranscriptionService._();

  final _supabase = Supabase.instance.client;

  /// API key de Deepgram (desde --dart-define)
  String get _deepgramApiKey => const String.fromEnvironment('DEEPGRAM_API_KEY');

  /// Deepgram REST API endpoint
  // ignore: unused_field
  static const _deepgramUrl = 'https://api.deepgram.com/v1/listen';

  /// Transcribe un video y guarda los segmentos en la base de datos.
  ///
  /// [userId] — ID del usuario dueño del video
  /// [videoUrl] — URL pública del video en Supabase Storage
  ///
  /// Retorna la lista de segmentos o lista vacía si falla.
  Future<List<Map<String, dynamic>>> transcribeAndSave(
    String userId,
    String videoUrl,
  ) async {
    if (_deepgramApiKey.isEmpty) {
      debugPrint('⚠️ DEEPGRAM_API_KEY no configurada. Skipping transcription.');
      return [];
    }

    try {
      debugPrint('🎤 Transcribiendo video: $videoUrl');

      // Llamar a Edge Function de Supabase que hace el request a Deepgram
      // (evita exponer API key en el cliente)
      final response = await _supabase.functions.invoke(
        'transcribe-video',
        body: {
          'video_url': videoUrl,
          'user_id': userId,
          'language': 'es', // Default a español
        },
      );

      if (response.status != 200) {
        debugPrint('❌ Transcription failed: ${response.status}');
        return [];
      }

      final data = response.data as Map<String, dynamic>?;
      final segments = List<Map<String, dynamic>>.from(
        data?['segments'] ?? [],
      );

      if (segments.isNotEmpty) {
        // Guardar en la base de datos
        await _supabase.from('users').update({
          'ai_transcript_json': segments,
        }).eq('id', userId);

        debugPrint('✅ Transcripción guardada: ${segments.length} segmentos');
      }

      return segments;
    } catch (e) {
      debugPrint('❌ TranscriptionService.transcribeAndSave: $e');
      return [];
    }
  }

  /// Transcripción via Edge Function proxy (Deepgram).
  /// La Edge Function usa su propio DEEPGRAM_API_KEY (configurado como secret
  /// en Supabase) — NO se envía la API key desde el cliente.
  Future<List<Map<String, dynamic>>> transcribeDirectly(String videoUrl) async {
    try {
      final response = await _supabase.functions.invoke(
        'deepgram-proxy',
        body: {
          'url': videoUrl,
          // La API key se lee desde el secret DEEPGRAM_API_KEY en la Edge Function.
          // NO enviar api_key desde el cliente para evitar exposición.
        },
      );

      if (response.status != 200) return [];

      final data = response.data as Map<String, dynamic>?;
      final results = data?['results'] as Map<String, dynamic>?;
      final utterances = results?['utterances'] as List?;

      if (utterances == null) return [];

      return utterances.map((u) {
        final m = u as Map<String, dynamic>;
        return {
          'start': m['start'] ?? 0.0,
          'end': m['end'] ?? 0.0,
          'text': m['transcript']?.toString() ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ TranscriptionService.transcribeDirectly: $e');
      return [];
    }
  }

  /// Obtiene la transcripción existente de un usuario
  Future<List<Map<String, dynamic>>> getTranscript(String userId) async {
    try {
      final result = await _supabase
          .from('users')
          .select('ai_transcript_json')
          .eq('id', userId)
          .maybeSingle();

      if (result == null) return [];

      final raw = result['ai_transcript_json'];
      if (raw == null || raw is! List) return [];

      return List<Map<String, dynamic>>.from(raw);
    } catch (e) {
      debugPrint('❌ TranscriptionService.getTranscript: $e');
      return [];
    }
  }

  /// Formatea un timestamp de segundos a MM:SS
  static String formatTimestamp(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Encuentra el segmento activo dado un timestamp de reproducción
  static Map<String, dynamic>? findActiveSegment(
    List<Map<String, dynamic>> segments,
    double currentTime,
  ) {
    for (final seg in segments) {
      final start = (seg['start'] as num?)?.toDouble() ?? 0;
      final end = (seg['end'] as num?)?.toDouble() ?? 0;
      if (currentTime >= start && currentTime <= end) {
        return seg;
      }
    }
    return null;
  }
}
