import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CompanyVerificationService — Verificación de empresas
//
// Genera confianza en la plataforma verificando la legitimidad
// de las empresas que publican vacantes.
//
// Niveles de verificación:
//   1. BASIC:    Email corporativo verificado (automático)
//   2. VERIFIED: Documentación legal confirmada (manual review)
//   3. TRUSTED:  Historial de contrataciones exitosas (automático)
//
// La empresa sube documentación (RFC, registro mercantil, etc.)
// y un moderador la aprueba. Las vacantes de empresas verificadas
// obtienen un badge de confianza visible para los candidatos.
// ─────────────────────────────────────────────────────────────────────────────

enum VerificationLevel {
  none,
  basic,      // Email corporativo verificado
  verified,   // Documentación legal confirmada
  trusted,    // +5 contrataciones exitosas en la plataforma
}

class VerificationRequest {
  final String id;
  final String companyId;
  final String companyName;
  final VerificationLevel level;
  final String status;      // 'pending', 'approved', 'rejected'
  final DateTime requestedAt;
  final String? reviewNote;
  final List<String> documentUrls;

  const VerificationRequest({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.level,
    required this.status,
    required this.requestedAt,
    this.reviewNote,
    this.documentUrls = const [],
  });

  factory VerificationRequest.fromJson(Map<String, dynamic> json) {
    return VerificationRequest(
      id: json['id']?.toString() ?? '',
      companyId: json['company_id']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? '',
      level: _parseLevel(json['level']?.toString()),
      status: json['status']?.toString() ?? 'pending',
      requestedAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      reviewNote: json['review_note']?.toString(),
      documentUrls: (json['document_urls'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  static VerificationLevel _parseLevel(String? level) {
    switch (level) {
      case 'basic': return VerificationLevel.basic;
      case 'verified': return VerificationLevel.verified;
      case 'trusted': return VerificationLevel.trusted;
      default: return VerificationLevel.none;
    }
  }
}

class CompanyVerificationService {
  CompanyVerificationService._();
  static final CompanyVerificationService instance = CompanyVerificationService._();

  final _supabase = Supabase.instance.client;

  /// Obtiene el nivel de verificación actual de la empresa.
  Future<VerificationLevel> getVerificationLevel(String companyId) async {
    try {
      final res = await _supabase
          .from('company_verifications')
          .select('level, status')
          .eq('company_id', companyId)
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res == null) return VerificationLevel.none;
      return VerificationRequest._parseLevel(res['level']?.toString());
    } catch (e) {
      debugPrint('Error getting verification: $e');
      return VerificationLevel.none;
    }
  }

  /// Cerrado hasta tener validación administrativa server-side.
  Future<bool> autoVerifyEmail() async {
    return false;
  }

  /// Envía una solicitud de verificación con documentos.
  Future<String?> requestVerification({
    required String companyName,
    required List<String> documentUrls,
    String notes = '',
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return 'No autenticado';

    // El esquema/RLS no está versionado. La futura RPC deberá derivar
    // company_id de auth.uid() y forzar status = pending.
    return 'Las solicitudes de verificación estarán disponibles próximamente.';
  }

  /// El nivel trusted deberá calcularse server-side.
  Future<void> checkTrustedStatus(String companyId) async {
    return;
  }

  /// Retorna info de verificación para mostrar en el perfil/badge.
  static String levelLabel(VerificationLevel level) {
    switch (level) {
      case VerificationLevel.none: return '';
      case VerificationLevel.basic: return 'Email Verificado';
      case VerificationLevel.verified: return 'Empresa Verificada';
      case VerificationLevel.trusted: return 'Empresa de Confianza';
    }
  }

  static String levelIcon(VerificationLevel level) {
    switch (level) {
      case VerificationLevel.none: return '';
      case VerificationLevel.basic: return '✉️';
      case VerificationLevel.verified: return '✅';
      case VerificationLevel.trusted: return '🏆';
    }
  }
}
