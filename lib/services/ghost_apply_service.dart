import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GhostApplyService — Aplicar de forma anónima a vacantes
//
// El candidato "confidencial" puede aplicar a una vacante sin revelar
// su identidad real. La empresa ve un perfil ciego (CV Ciego):
//   • Headline genérico (ej. "C-Level en Fintech")
//   • Skills/tags (sin nombres)
//   • Score de matching
//   • Logros clave sin company names
//
// Solo cuando la empresa paga 1 Token (o es Premium) puede desbloquear:
//   • Nombre completo
//   • Video-Pitch
//   • Historial de experiencia completo
//
// Esto convierte a Mploya en la primera plataforma que permite búsquedas
// confidenciales de C-Level sin riesgo para ninguna de las partes.
// ─────────────────────────────────────────────────────────────────────────────

class GhostApplication {
  final String id;
  final String jobId;
  final String candidateId;
  final String blindHeadline;
  final String blindAbout;
  final List<String> blindTags;
  final int matchScore;
  final DateTime appliedAt;
  final bool isUnlocked;
  final String status; // 'pending', 'reviewed', 'shortlisted', 'rejected', 'unlocked'

  const GhostApplication({
    required this.id,
    required this.jobId,
    required this.candidateId,
    required this.blindHeadline,
    required this.blindAbout,
    required this.blindTags,
    required this.matchScore,
    required this.appliedAt,
    this.isUnlocked = false,
    this.status = 'pending',
  });

  factory GhostApplication.fromJson(Map<String, dynamic> json) {
    return GhostApplication(
      id: json['id']?.toString() ?? '',
      jobId: json['job_id']?.toString() ?? '',
      candidateId: json['candidate_id']?.toString() ?? '',
      blindHeadline: json['blind_headline']?.toString() ?? '',
      blindAbout: json['blind_about']?.toString() ?? '',
      blindTags: (json['blind_tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      matchScore: (json['match_score'] as num?)?.toInt() ?? 0,
      appliedAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      isUnlocked: json['is_unlocked'] == true,
      status: json['status']?.toString() ?? 'pending',
    );
  }
}

class GhostApplyService {
  GhostApplyService._();
  static final GhostApplyService instance = GhostApplyService._();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Aplica de forma anónima a una vacante.
  ///
  /// Genera un perfil "ciego" del candidato extraído de sus datos
  /// en la bóveda Stealth y lo envía como ghost_application.
  ///
  /// Retorna null si fue exitoso, o un String con el error.
  Future<String?> ghostApply({
    required String jobId,
    required String jobTitle,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return 'No autenticado';

    try {
      // 1. Obtener datos del candidato
      final userData = await _supabase
          .from('users')
          .select('headline, about, tags, skills, account_type')
          .eq('id', uid)
          .single();

      final isConfidential = userData['account_type'] == 'confidencial' ||
          userData['account_type'] == 'stealth';

      if (!isConfidential) {
        return 'Ghost Apply solo está disponible para candidatos confidenciales.';
      }

      // 2. Generar perfil ciego
      final blindHeadline = _anonymizeHeadline(userData['headline']?.toString() ?? '');
      final blindAbout = _extractBlindCV(userData['about']?.toString() ?? '');
      final tags = (userData['tags'] as List?)?.map((e) => e.toString()).toList() ??
          (userData['skills'] as List?)?.map((e) => e.toString()).toList() ??
          [];

      // 3. Calcular match score básico
      final jobData = await _supabase
          .from('jobs')
          .select('tags, seniority')
          .eq('id', jobId)
          .maybeSingle();

      int matchScore = 65;
      if (jobData != null) {
        final jobTags = (jobData['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final commonTags = tags.where((t) =>
            jobTags.any((jt) => jt.toLowerCase() == t.toLowerCase())).length;
        matchScore = (65 + commonTags * 10).clamp(0, 100);

        // Bonus si es C-Level y la posición es senior
        if (jobData['seniority'] == 'clevel' || jobData['seniority'] == 'lead') {
          matchScore = (matchScore + 10).clamp(0, 100);
        }
      }

      // 4. Verificar que no ya haya aplicado
      final existing = await _supabase
          .from('ghost_applications')
          .select('id')
          .eq('candidate_id', uid)
          .eq('job_id', jobId)
          .maybeSingle();

      if (existing != null) {
        return 'Ya aplicaste de forma anónima a esta vacante.';
      }

      // 5. Insertar ghost application
      await _supabase.from('ghost_applications').insert({
        'candidate_id': uid,
        'job_id': jobId,
        'blind_headline': blindHeadline,
        'blind_about': blindAbout,
        'blind_tags': tags.take(8).toList(),
        'match_score': matchScore,
        'is_unlocked': false,
        'status': 'pending',
      });

      // 6. Notificar a la empresa
      try {
        final job = await _supabase
            .from('jobs')
            .select('company_id')
            .eq('id', jobId)
            .maybeSingle();

        if (job != null) {
          // Usa RPC SECURITY DEFINER — la política de notifications ahora
          // requiere actor_id = auth.uid(), pero aquí el actor es el candidato
          // y el user_id es la empresa (no coinciden).
          await _supabase.rpc('create_system_notification', params: {
            'p_user_id': job['company_id'],
            'p_type': 'jobAlert',
            'p_description': '👻 Un candidato senior aplicó en modo Ghost a "$jobTitle". '
                'Desbloqueá su identidad para ver su perfil completo.',
            'p_actor_id': uid,
          });
        }
      } catch (e) {
        debugPrint('Ghost notify error: $e');
      }

      return null; // éxito
    } catch (e) {
      debugPrint('Ghost apply error: $e');
      return 'Error al aplicar: $e';
    }
  }

  /// Obtiene las ghost applications para una vacante (vista empresa).
  Future<List<GhostApplication>> getGhostApplicationsForJob(String jobId) async {
    try {
      final res = await _supabase
          .from('ghost_applications')
          .select()
          .eq('job_id', jobId)
          .order('match_score', ascending: false);

      return List<Map<String, dynamic>>.from(res)
          .map((e) => GhostApplication.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Error fetching ghost apps: $e');
      return [];
    }
  }

  /// Desbloquea la identidad de un candidato Ghost (consume 1 token / Premium).
  Future<String?> unlockGhostCandidate(String applicationId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return 'No autenticado';

    try {
      // Verificar si es Premium
      final user = await _supabase
          .from('users')
          .select('is_premium')
          .eq('id', uid)
          .maybeSingle();

      if (user == null || user['is_premium'] != true) {
        return 'Necesitás una cuenta Premium para desbloquear candidatos Ghost.';
      }

      // Desbloquear
      await _supabase
          .from('ghost_applications')
          .update({
        'is_unlocked': true,
        'status': 'unlocked',
        'unlocked_at': DateTime.now().toIso8601String(),
        'unlocked_by': uid,
      }).eq('id', applicationId);

      return null;
    } catch (e) {
      return 'Error al desbloquear: $e';
    }
  }

  /// Anonimiza el headline para que no revele la empresa actual.
  String _anonymizeHeadline(String headline) {
    // Remover nombres de empresa comunes
    final cleanHeadline = headline
        .replaceAll(RegExp(r'\b(en|at|@)\s+[\w\s]+$', caseSensitive: false), '')
        .trim();

    if (cleanHeadline.isEmpty) return 'Profesional Senior';

    // Mantener solo el rol genérico
    return cleanHeadline;
  }

  /// Extrae el CV ciego del campo about (formato Bóveda Stealth).
  String _extractBlindCV(String about) {
    if (about.contains('||')) {
      // Formato bóveda: "sector || presupuesto || logros"
      return about;
    }
    // Para otros formatos, censurar nombres propios (simplificado)
    return about.replaceAll(RegExp(r'\b[A-Z][a-z]+\s+[A-Z][a-z]+\b'), '[Confidencial]');
  }
}
