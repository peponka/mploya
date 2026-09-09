import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/camera_screen.dart';
import 'ghost_apply_service.dart';
import 'my_profile_service.dart';

/// Flujo único de postulación para cualquier entrada a una vacante.
///
/// Una vacante puede abrirse desde el feed, los guardados o el perfil de una
/// empresa. Centralizar la acción evita que unas rutas permitan postularse y
/// otras dejen un botón sin respuesta.
class JobApplicationFlow {
  JobApplicationFlow._();

  static final _client = Supabase.instance.client;

  static Future<bool> apply({
    required BuildContext context,
    required String jobId,
    required String jobTitle,
  }) async {
    if (jobId.trim().isEmpty) {
      await _notice(
        context,
        title: 'Vacante no disponible',
        message:
            'No pudimos identificar esta vacante. Volvé a intentar desde Vacantes.',
      );
      return false;
    }
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      await _notice(
        context,
        title: 'Iniciá sesión',
        message: 'Necesitás iniciar sesión para postularte a esta vacante.',
      );
      return false;
    }

    Map<String, dynamic>? profile;
    try {
      profile = await loadMyProfile(client: _client);
    } catch (_) {
      if (context.mounted) {
        await _notice(
          context,
          title: 'No pudimos continuar',
          message: 'Revisá tu conexión e intentá de nuevo.',
        );
      }
      return false;
    }
    if (!context.mounted) return false;

    final accountType = profile?['account_type']?.toString().toLowerCase();
    if (accountType == 'empresa' || accountType == 'headhunter') {
      await _notice(
        context,
        title: 'Esta vacante es para candidatos',
        message: 'Cambiá a una cuenta de candidato para poder postularte.',
      );
      return false;
    }

    final hasPitch =
        (profile?['video_url']?.toString().trim().isNotEmpty ?? false);
    var recordNewPitch = !hasPitch;
    if (hasPitch) {
      final choice = await showCupertinoDialog<String>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('¿Cómo querés postularte?'),
          content: const Text(
            'Podés usar tu Video Pitch actual o grabar uno nuevo para esta vacante.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, 'new'),
              child: const Text('Grabar uno nuevo'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialogContext, 'saved'),
              child: const Text('Usar mi pitch'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
      if (choice == null || !context.mounted) return false;
      recordNewPitch = choice == 'new';
    }

    // Ghost requiere un pitch ya guardado: si eligió grabar uno nuevo, primero
    // se completa esa grabación y la postulación continúa con identidad.
    if (!recordNewPitch &&
        (accountType == 'confidencial' || accountType == 'stealth')) {
      final mode = await showCupertinoModalPopup<String>(
        context: context,
        builder: (sheetContext) => CupertinoActionSheet(
          title: const Text('Modo de postulación'),
          message: const Text('Podés postularte de forma confidencial.'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheetContext, 'ghost'),
              child: const Text('Postularme como Ghost'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheetContext, 'normal'),
              child: const Text('Postularme con identidad'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('Cancelar'),
          ),
        ),
      );
      if (mode == null || !context.mounted) return false;
      if (mode == 'ghost') {
        final error = await GhostApplyService.instance.ghostApply(
          jobId: jobId,
          jobTitle: jobTitle,
        );
        if (!context.mounted) return error == null;
        await _notice(
          context,
          title: error == null ? 'Postulación confidencial enviada' : 'Aviso',
          message: error ?? 'Tu perfil se envió de forma confidencial.',
        );
        return error == null;
      }
    }

    if (recordNewPitch) {
      final recorded = await Navigator.of(
        context,
      ).push<bool>(CupertinoPageRoute(builder: (_) => const CameraScreen()));
      if (recorded != true) return false;
    }

    try {
      await _client.from('job_applications').insert({
        'job_id': jobId,
        'candidate_id': userId,
      });
      if (context.mounted) {
        await _notice(
          context,
          title: 'Postulación enviada',
          message: 'Tu perfil fue enviado para “$jobTitle”.',
        );
      }
      return true;
    } on PostgrestException catch (error) {
      if (context.mounted) {
        await _notice(
          context,
          title: error.code == '23505'
              ? 'Ya te postulaste'
              : 'No pudimos enviarla',
          message: error.code == '23505'
              ? 'Ya existe una postulación para esta vacante.'
              : 'Probá de nuevo en un momento.',
        );
      }
      return error.code == '23505';
    } catch (_) {
      if (context.mounted) {
        await _notice(
          context,
          title: 'No pudimos enviarla',
          message: 'Probá de nuevo en un momento.',
        );
      }
      return false;
    }
  }

  static Future<void> _notice(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
