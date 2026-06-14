import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PitchChallengeService — Pitch Challenge Semanal
//
// Cada semana se publica un desafío temático:
//   • "Presentate en 30 segundos"
//   • "¿Cuál fue tu mayor logro?"
//   • "Vendenos tu idea en 15 segundos"
//
// Los candidatos suben un video-pitch respondiendo al challenge.
// Los mejores (más likes/views) ganan visibilidad y badges.
//
// Esto genera:
//   1. Engagement: contenido fresco semanal
//   2. Retención: loop de competencia amigable
//   3. Visibilidad: los ganadores son destacados en el feed
// ─────────────────────────────────────────────────────────────────────────────

class PitchChallenge {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final int maxDurationSeconds;
  final DateTime startsAt;
  final DateTime endsAt;
  final int participantCount;
  final bool isActive;
  final String? winnerUserId;
  final String? winnerName;
  final String? prizeDescription;

  const PitchChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    this.maxDurationSeconds = 30,
    required this.startsAt,
    required this.endsAt,
    this.participantCount = 0,
    this.isActive = true,
    this.winnerUserId,
    this.winnerName,
    this.prizeDescription,
  });

  bool get isOngoing => DateTime.now().isBefore(endsAt) && DateTime.now().isAfter(startsAt);
  int get daysRemaining => endsAt.difference(DateTime.now()).inDays;

  factory PitchChallenge.fromJson(Map<String, dynamic> json) {
    return PitchChallenge(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '🎯',
      maxDurationSeconds: (json['max_duration_seconds'] as num?)?.toInt() ?? 30,
      startsAt: DateTime.tryParse(json['starts_at']?.toString() ?? '') ?? DateTime.now(),
      endsAt: DateTime.tryParse(json['ends_at']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 7)),
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] != false,
      winnerUserId: json['winner_user_id']?.toString(),
      winnerName: json['winner_name']?.toString(),
      prizeDescription: json['prize_description']?.toString(),
    );
  }
}

class ChallengeEntry {
  final String id;
  final String challengeId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String videoUrl;
  final int likes;
  final int views;
  final DateTime submittedAt;

  const ChallengeEntry({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.videoUrl,
    this.likes = 0,
    this.views = 0,
    required this.submittedAt,
  });

  factory ChallengeEntry.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    return ChallengeEntry(
      id: json['id']?.toString() ?? '',
      challengeId: json['challenge_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: user?['name']?.toString() ?? json['user_name']?.toString() ?? 'Participante',
      userAvatar: user?['avatar_url']?.toString(),
      videoUrl: json['video_url']?.toString() ?? '',
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      views: (json['views'] as num?)?.toInt() ?? 0,
      submittedAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class PitchChallengeService {
  PitchChallengeService._();
  static final PitchChallengeService instance = PitchChallengeService._();

  final _supabase = Supabase.instance.client;

  // ── Predefined challenges pool ──
  static const _challengeTemplates = [
    {
      'title': 'Presentate en 30 segundos',
      'description': '¿Quién sos y qué te hace único? Contalo en 30 seg.',
      'emoji': '👋',
      'max_duration_seconds': 30,
    },
    {
      'title': '¿Cuál fue tu mayor logro?',
      'description': 'Contanos ese momento del que estás más orgulloso/a.',
      'emoji': '🏆',
      'max_duration_seconds': 45,
    },
    {
      'title': 'Vendenos tu idea en 15 seg',
      'description': 'Elevator pitch relámpago: ¿qué podrías aportar?',
      'emoji': '⚡',
      'max_duration_seconds': 15,
    },
    {
      'title': '¿Por qué deberían contratarte?',
      'description': 'Convencé a tu próximo empleador en un minuto.',
      'emoji': '🎯',
      'max_duration_seconds': 60,
    },
    {
      'title': 'Tu superpoder profesional',
      'description': '¿Qué habilidad te define? Demostralo en video.',
      'emoji': '💪',
      'max_duration_seconds': 30,
    },
    {
      'title': 'El error que más te enseñó',
      'description': 'La vulnerabilidad conecta. Compartí tu aprendizaje.',
      'emoji': '💡',
      'max_duration_seconds': 45,
    },
    {
      'title': '¿Cómo liderás un equipo?',
      'description': 'Mostrá tu estilo de liderazgo con un ejemplo real.',
      'emoji': '👥',
      'max_duration_seconds': 45,
    },
    {
      'title': 'Tu pitch para una startup',
      'description': '¿Podrías convencer a un founder? ¡Intentalo!',
      'emoji': '🚀',
      'max_duration_seconds': 30,
    },
  ];

  /// Obtiene el challenge activo de esta semana.
  Future<PitchChallenge?> getCurrentChallenge() async {
    try {
      final res = await _supabase
          .from('pitch_challenges')
          .select('*, challenge_entries(count)')
          .eq('is_active', true)
          .lte('starts_at', DateTime.now().toIso8601String())
          .gte('ends_at', DateTime.now().toIso8601String())
          .order('starts_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null) {
        return PitchChallenge.fromJson(res);
      }

      // No active challenge found — create one from templates (dev mode)
      return _getLocalFallbackChallenge();
    } catch (e) {
      debugPrint('Error getting challenge: $e');
      return _getLocalFallbackChallenge();
    }
  }

  /// Obtiene challenges pasados con sus ganadores.
  Future<List<PitchChallenge>> getPastChallenges({int limit = 5}) async {
    try {
      final res = await _supabase
          .from('pitch_challenges')
          .select()
          .lt('ends_at', DateTime.now().toIso8601String())
          .order('ends_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(res)
          .map((e) => PitchChallenge.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Error getting past challenges: $e');
      return [];
    }
  }

  /// Envía un video como entrada al challenge activo.
  Future<String?> submitEntry({
    required String challengeId,
    required String videoUrl,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return 'No autenticado';

    try {
      // Ensure the challenge exists in DB (upsert if local fallback)
      final challenge = _getLocalFallbackChallenge();
      if (challengeId == challenge.id) {
        await _supabase.from('pitch_challenges').upsert({
          'id': challenge.id,
          'title': challenge.title,
          'description': challenge.description,
          'emoji': challenge.emoji,
          'max_duration_seconds': challenge.maxDurationSeconds,
          'starts_at': challenge.startsAt.toIso8601String(),
          'ends_at': challenge.endsAt.toIso8601String(),
          'participant_count': 0,
          'is_active': true,
        }, onConflict: 'id');
      }

      // Check if already submitted
      final existing = await _supabase
          .from('challenge_entries')
          .select('id')
          .eq('challenge_id', challengeId)
          .eq('user_id', uid)
          .maybeSingle();

      if (existing != null) {
        return 'Ya participaste en este challenge.';
      }

      await _supabase.from('challenge_entries').insert({
        'challenge_id': challengeId,
        'user_id': uid,
        'video_url': videoUrl,
        'likes': 0,
        'views': 0,
      });

      // Update participant count
      await _supabase.rpc('increment_challenge_participants', params: {
        'p_challenge_id': challengeId,
      }).catchError((_) {}); // Non-critical

      return null; // éxito
    } catch (e) {
      return 'Error al enviar: $e';
    }
  }

  /// Obtiene las entradas del challenge actual ordenadas por likes.
  Future<List<ChallengeEntry>> getEntries(String challengeId, {int limit = 20}) async {
    try {
      final res = await _supabase
          .from('challenge_entries')
          .select('*, users:user_id(name, avatar_url)')
          .eq('challenge_id', challengeId)
          .order('likes', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(res)
          .map((e) => ChallengeEntry.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Error getting entries: $e');
      return [];
    }
  }

  /// Like a una entrada del challenge.
  Future<bool> likeEntry(String entryId) async {
    try {
      await _supabase.rpc('increment_challenge_likes', params: {
        'p_entry_id': entryId,
      });
      return true;
    } catch (e) {
      debugPrint('Error liking entry: $e');
      return false;
    }
  }

  /// Verifica si el usuario ya participó en el challenge activo.
  Future<bool> hasParticipated(String challengeId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return false;

    try {
      final res = await _supabase
          .from('challenge_entries')
          .select('id')
          .eq('challenge_id', challengeId)
          .eq('user_id', uid)
          .maybeSingle();

      return res != null;
    } catch (e) {
      return false;
    }
  }

  /// Fallback local para cuando no hay challenges en DB.
  PitchChallenge _getLocalFallbackChallenge() {
    final now = DateTime.now();
    final weekOfYear = (now.difference(DateTime(now.year, 1, 1)).inDays / 7).floor();
    final template = _challengeTemplates[weekOfYear % _challengeTemplates.length];
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59));

    // Generate a deterministic UUID from the week identifier
    final seed = 'pitch_challenge_${now.year}_week_$weekOfYear';
    final h1 = seed.hashCode.toRadixString(16).padLeft(8, '0');
    final h2 = (seed.length * 31 + weekOfYear * 7919).toRadixString(16).padLeft(8, '0');
    final h3 = (now.year * 10000 + weekOfYear).toRadixString(16).padLeft(8, '0');
    final hex = '$h1$h2${h3}00000000';
    final uuid = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-a${hex.substring(17, 20)}-${hex.substring(20, 32)}';

    return PitchChallenge(
      id: uuid,
      title: template['title'] as String,
      description: template['description'] as String,
      emoji: template['emoji'] as String,
      maxDurationSeconds: template['max_duration_seconds'] as int,
      startsAt: monday,
      endsAt: sunday,
      participantCount: 0,
      isActive: true,
    );
  }
}
