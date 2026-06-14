import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/content_moderation_service.dart';
import '../services/error_handler.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReelCardModerationMixin — Reportar / Bloquear / Moderar
//
// Extraído de tiktok_reel_card.dart para reducir el tamaño del god file.
// Se usa como mixin en _TikTokReelCardState.
// ─────────────────────────────────────────────────────────────────────────────

mixin ReelCardModerationMixin<T extends StatefulWidget> on State<T> {
  /// Menú principal de tres puntos (⋯): Reportar / Bloquear.
  void showMoreOptions(NexUser author) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          author.isConfidential
              ? 'Opciones para este perfil'
              : 'Opciones para ${author.name}',
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              showReportOptions(author);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.flag_fill, size: 18),
                SizedBox(width: 8),
                Text('Reportar video'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              confirmBlockUser(author);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.hand_raised_fill, size: 18),
                SizedBox(width: 8),
                Text('Bloquear usuario'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  /// Sub-menú con motivos de reporte.
  void showReportOptions(NexUser author, {String? contentId}) {
    const reasons = [
      'Contenido inapropiado o spam',
      'Acoso o bullying',
      'Discriminación u odio',
      'Información falsa o engañosa',
      'Violación de privacidad',
    ];

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('¿Por qué estás reportando este video?'),
        actions: reasons.map((reason) {
          return CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ContentModerationService.instance.reportContent(
                contentId: contentId ?? author.id,
                contentType: 'pitch',
                reason: reason,
              );
              if (mounted) {
                MployaErrorHandler.instance.showSuccess(
                  context,
                  ok
                      ? 'Reporte enviado. Gracias por ayudar a la comunidad.'
                      : 'No se pudo enviar el reporte. Inténtalo de nuevo.',
                );
              }
            },
            child: Text(reason),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  /// Diálogo de confirmación antes de bloquear a un usuario.
  void confirmBlockUser(NexUser author) {
    final displayName = author.isConfidential ? 'este usuario' : author.name;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('¿Bloquear a $displayName?'),
        content: const Text(
          'No verás más sus publicaciones y no podrá contactarte. '
          'Podés desbloquear desde Configuración › Privacidad.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await blockUser(author.id);
            },
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
  }

  /// Persiste el bloqueo en Supabase (tabla user_blocks).
  Future<void> blockUser(String blockedUserId) async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;
    try {
      await Supabase.instance.client.from('user_blocks').upsert(
        {'blocker_id': myId, 'blocked_id': blockedUserId},
        onConflict: 'blocker_id,blocked_id',
      );
      if (mounted) {
        MployaErrorHandler.instance.showSuccess(
          context,
          'Usuario bloqueado correctamente.',
        );
      }
    } catch (e) {
      debugPrint('❌ Error blocking user: $e');
    }
  }

  /// Detecta emails y teléfonos en texto para prevenir bypass de contacto.
  bool containsContactInfo(String text) {
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    final obfuscatedEmail = RegExp(
      r'(arroba|@|at)\s*.+\s*(punto|dot)\s*(com|net|org|io)',
      caseSensitive: false,
    );

    if (emailRegex.hasMatch(text) || obfuscatedEmail.hasMatch(text)) return true;

    final phoneCandidates = RegExp(r'\+?[\d][\d\s\-\.()]{7,}[\d]').allMatches(text);
    for (final m in phoneCandidates) {
      final digits = m.group(0)!.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.length >= 9) return true;
    }

    return false;
  }
}
