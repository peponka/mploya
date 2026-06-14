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

  /// Verifica automáticamente si el email es corporativo.
  ///
  /// Un email corporativo es aquel que NO usa dominios públicos
  /// como gmail, hotmail, yahoo, etc.
  Future<bool> autoVerifyEmail() async {
    final uid = _supabase.auth.currentUser?.id;
    final email = _supabase.auth.currentUser?.email;
    if (uid == null || email == null) return false;

    final publicDomains = [
      'gmail.com', 'hotmail.com', 'outlook.com', 'yahoo.com',
      'live.com', 'icloud.com', 'protonmail.com', 'aol.com',
      'mail.com', 'zoho.com', 'yandex.com', 'gmx.com',
    ];

    final domain = email.split('@').last.toLowerCase();
    final isCorporate = !publicDomains.contains(domain);

    if (isCorporate) {
      try {
        // Check if already verified
        final existing = await _supabase
            .from('company_verifications')
            .select('id')
            .eq('company_id', uid)
            .eq('level', 'basic')
            .maybeSingle();

        if (existing != null) return true;

        await _supabase.from('company_verifications').insert({
          'company_id': uid,
          'company_name': email.split('@').last.split('.').first,
          'level': 'basic',
          'status': 'approved',
          'review_note': 'Auto-verificado: email corporativo ($domain)',
        });

        // Update user verified flag
        await _supabase.from('users').update({
          'is_verified': true,
        }).eq('id', uid);

        return true;
      } catch (e) {
        debugPrint('Auto-verify error: $e');
        return false;
      }
    }

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

    try {
      await _supabase.from('company_verifications').insert({
        'company_id': uid,
        'company_name': companyName,
        'level': 'verified',
        'status': 'pending',
        'document_urls': documentUrls,
        'notes': notes,
      });

      return null; // éxito
    } catch (e) {
      return 'Error al enviar solicitud: $e';
    }
  }

  /// Verifica automáticamente si la empresa tiene +5 contrataciones exitosas.
  Future<void> checkTrustedStatus(String companyId) async {
    try {
      // Count successful hires (connections from jobs)
      final jobs = await _supabase
          .from('jobs')
          .select('id')
          .eq('company_id', companyId);

      final jobIds = List<Map<String, dynamic>>.from(jobs)
          .map((j) => j['id'].toString())
          .toList();

      if (jobIds.isEmpty) return;

      final applications = await _supabase
          .from('job_applications')
          .select('id')
          .inFilter('job_id', jobIds)
          .eq('status', 'hired');

      if ((applications as List).length >= 5) {
        // Auto-upgrade to trusted
        final existing = await _supabase
            .from('company_verifications')
            .select('id')
            .eq('company_id', companyId)
            .eq('level', 'trusted')
            .maybeSingle();

        if (existing == null) {
          await _supabase.from('company_verifications').insert({
            'company_id': companyId,
            'company_name': '',
            'level': 'trusted',
            'status': 'approved',
            'review_note': 'Auto-verificado: +5 contrataciones exitosas',
          });
        }
      }
    } catch (e) {
      debugPrint('Check trusted status error: $e');
    }
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
