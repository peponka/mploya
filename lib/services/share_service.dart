import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ShareService — Sharing de perfiles Mploya
//
// Genera links compartibles para perfiles y vacantes.
// Usa deep links con formato: https://mploya.ai/p/{userId}
//
// Utiliza share_plus para abrir la hoja de compartir nativa del sistema
// (WhatsApp, Instagram, Twitter/X, Telegram, Email, etc.)
// ─────────────────────────────────────────────────────────────────────────────

class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  /// Base URL para deep links. Cambiar cuando el dominio esté configurado.
  static const _baseUrl = 'https://mploya.ai';

  /// Genera URL para compartir un perfil de usuario.
  String profileUrl(String userId) => '$_baseUrl/p/$userId';

  /// Genera URL para compartir una vacante.
  String jobUrl(String jobId) => '$_baseUrl/j/$jobId';

  /// Genera texto de sharing para un candidato.
  String candidateShareText({
    required String name,
    required String headline,
    required String userId,
  }) {
    return '🎬 Mirá el Video-Pitch profesional de $name en Mploya.\n'
        '${headline.isNotEmpty ? '"$headline"\n' : ''}'
        '\n${profileUrl(userId)}';
  }

  /// Genera texto de sharing para una empresa.
  String companyShareText({
    required String name,
    required String headline,
    required String userId,
  }) {
    return '🏢 Conocé a $name en Mploya — la plataforma de video recruiting.\n'
        '${headline.isNotEmpty ? '"$headline"\n' : ''}'
        '\n${profileUrl(userId)}';
  }

  /// Texto genérico para invitar a alguien a la app.
  String inviteText() {
    return '📲 Probá Mploya — la app donde candidatos y empresas se conectan '
        'a través de video-pitches de 60 segundos. 100% gratis.\n'
        '\n$_baseUrl';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Métodos de sharing nativo (abre WhatsApp, Instagram, etc.)
  // ─────────────────────────────────────────────────────────────────────────

  /// Comparte un perfil usando la hoja nativa del sistema.
  Future<void> shareProfile({
    required String name,
    required String headline,
    required String userId,
    required String accountType,
  }) async {
    final text = (accountType == 'empresa' || accountType == 'headhunter')
        ? companyShareText(name: name, headline: headline, userId: userId)
        : candidateShareText(name: name, headline: headline, userId: userId);

    await Share.share(text, subject: 'Perfil de $name en Mploya');
  }

  /// Comparte una invitación a la app.
  Future<void> shareInvite() async {
    await Share.share(
      inviteText(),
      subject: 'Mploya — Video Recruiting',
    );
  }

  /// Copia al clipboard y retorna el link generado.
  Future<String> copyProfileLink(String userId) async {
    final url = profileUrl(userId);
    await Clipboard.setData(ClipboardData(text: url));
    return url;
  }
}
