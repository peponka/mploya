import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Service para Blind Hiring Mode.
///
/// Cuando una empresa activa blind_hiring_mode, los candidatos que
/// ven son anonimizados: sin nombre, sin foto, sin género.
/// Solo se muestran: skills, experiencia, Video-Pitch y badges.
class BlindHiringService {
  BlindHiringService._();
  static final instance = BlindHiringService._();

  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  // ── Nombres anónimos ──
  static const _anonymousNames = [
    'Candidato A', 'Candidato B', 'Candidato C', 'Candidato D',
    'Candidato E', 'Candidato F', 'Candidato G', 'Candidato H',
    'Candidato I', 'Candidato J', 'Candidato K', 'Candidato L',
  ];

  // ── Check if current user has blind mode on ──
  Future<bool> isBlindModeEnabled() async {
    if (_uid == null) return false;
    try {
      final row = await _supabase
          .from('users')
          .select('blind_hiring_mode')
          .eq('id', _uid!)
          .maybeSingle();
      return row?['blind_hiring_mode'] == true;
    } catch (e) {
      debugPrint('BlindHiring: Error checking mode: $e');
      return false;
    }
  }

  // ── Toggle blind mode ──
  Future<void> toggleBlindMode(bool enabled) async {
    if (_uid == null) return;
    try {
      await _supabase
          .from('users')
          .update({'blind_hiring_mode': enabled})
          .eq('id', _uid!);
    } catch (e) {
      debugPrint('BlindHiring: Error toggling: $e');
    }
  }

  // ── Anonymize a user profile ──
  /// Returns a copy of the user with identity info removed.
  /// Keeps: skills, experience (with anonymized company names), education,
  /// Video-Pitch URL, tags, badges, salary expectation, location (city only).
  NexUser anonymize(NexUser user, int index) {
    final anonName = index < _anonymousNames.length
        ? _anonymousNames[index]
        : 'Candidato ${index + 1}';

    return user.copyWith(
      name: anonName,
      avatarUrl: null,          // No avatar
      bannerUrl: null,          // No banner
      company: null,            // No company name
      // Keep: headline, skills, experience, education, videoUrl, tags,
      //       salaryExpectation, location, matchPercentage
      experience: user.experience.map((e) => Experience(
        role: e.role,
        company: '***',         // Anonymize company
        duration: e.duration,
        location: null,         // Remove work location
        description: e.description,
        isCurrent: e.isCurrent,
      )).toList(),
    );
  }

  // ── Anonymize a list of users ──
  List<NexUser> anonymizeList(List<NexUser> users) {
    return List.generate(users.length, (i) => anonymize(users[i], i));
  }
}
