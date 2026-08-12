import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'camera_screen.dart';
import 'micro_pitch_web_stub.dart'
    if (dart.library.html) 'micro_pitch_web_recorder.dart';
import 'onboarding_tour_screen.dart';
import 'talent_onboarding_complete_screen.dart';

class OnboardingPitchScreen extends StatefulWidget {
  final bool isCompany;

  const OnboardingPitchScreen({super.key, required this.isCompany});

  @override
  State<OnboardingPitchScreen> createState() => _OnboardingPitchScreenState();
}

class _OnboardingPitchScreenState extends State<OnboardingPitchScreen> {
  final bool _isRecording = false;
  bool _isUploading = false;
  int _seconds = 0;
  Timer? _timer;

  void _finishAndEnterMploya() async {
    _timer?.cancel();

    if (widget.isCompany) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          final userData = await Supabase.instance.client
              .from('users')
              .select('headline, about, tags, location, company, name')
              .eq('id', user.id)
              .maybeSingle();

          if (userData != null) {
            final title = userData['headline']?.toString().isEmpty ?? true
                ? 'Nueva Vacante'
                : userData['headline'];
            final companyName =
                userData['company'] ??
                userData['name'] ??
                'Empresa Confidencial';

            await Supabase.instance.client.from('jobs').insert({
              'company_id': user.id,
              'company_name': companyName,
              'title': title,
              'description':
                  userData['about'] ?? 'Oferta publicada desde onboarding.',
              'location': userData['location'] ?? 'Remoto',
              'modality': 'remote',
              'seniority': 'mid',
              'salary_range': 'A convenir',
            });
            debugPrint(
              'Vacante auto-creada en onboarding (direct insert sin tags).',
            );
          }
        } catch (e) {
          debugPrint('Error auto-creando vacante directa: $e');
          if (mounted) {
            await showCupertinoDialog(
              context: context,
              builder: (ctx) => CupertinoAlertDialog(
                title: const Text('Error al crear vacante'),
                content: Text(e.toString()),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('Entendido'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            );
          }
        }
      }

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              OnboardingTourScreen(accountType: 'empresa'),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
      return;
    }

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const TalentOnboardingCompleteScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _showPitchSuccessDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Pitch excelente'),
        content: const Text(
          'Tu pitch ya quedo listo. Ahora te mostramos el cierre de onboarding antes de entrar a Mploya.',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _seconds = 0);
            },
            child: const Text('Grabar de nuevo'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _finishAndEnterMploya();
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message, {required VoidCallback onRetry}) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error al subir el video'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              onRetry();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  void _showValidationAlert(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Completar Perfil'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVideoReady(XFile file) async {
    final user = Supabase.instance.client.auth.currentUser;

    setState(() => _isUploading = true);

    try {
      final videoUrl = await StorageService.instance.uploadPitchVideo(
        user?.id ?? 'anonymous',
        file,
      );

      if (!mounted) return;

      if (videoUrl == null) {
        setState(() => _isUploading = false);
        _showErrorDialog(
          StorageService.instance.lastError ??
              'Error desconocido al subir el video.',
          onRetry: () => _handleVideoReady(file),
        );
        return;
      }

      if (user != null) {
        final profileError = await AuthService.instance.updatePitchUrl(
          user.id,
          videoUrl,
        );
        if (!mounted) return;
        if (profileError != null) {
          setState(() => _isUploading = false);
          _showErrorDialog(
            'El video se subio, pero no se pudo guardar en tu perfil: $profileError',
            onRetry: () async {
              setState(() => _isUploading = true);
              await AuthService.instance.updatePitchUrl(user.id, videoUrl);
              if (mounted) setState(() => _isUploading = false);
              if (mounted) _showPitchSuccessDialog();
            },
          );
          return;
        }
      }

      setState(() => _isUploading = false);
      _showPitchSuccessDialog();
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showErrorDialog(
          'Error inesperado: ${e.toString()}',
          onRetry: () => _handleVideoReady(file),
        );
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (kIsWeb) {
      final file = await WebRecorderHelper.recordVideo(context);
      if (!mounted) return;
      if (file != null) {
        await _handleVideoReady(file);
      }
      return;
    }

    final result = await Navigator.of(
      context,
    ).push<bool>(CupertinoPageRoute(builder: (_) => const CameraScreen()));

    if (!mounted) return;

    if (result == true) {
      _showPitchSuccessDialog();
    }
  }

  Future<void> _pickFromGallery() async {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Anadir Video Pitch'),
        message: const Text('De donde quieres obtener el video?'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final camStatus = await Permission.camera.request();
              final micStatus = await Permission.microphone.request();
              if (camStatus.isGranted && micStatus.isGranted) {
                final picker = ImagePicker();
                final file = await picker.pickVideo(
                  source: ImageSource.camera,
                  maxDuration: const Duration(seconds: 60),
                );
                if (file != null && mounted) {
                  await _handleVideoReady(file);
                }
              } else {
                _showValidationAlert(
                  'Se requieren permisos de camara y microfono.',
                );
              }
            },
            child: const Text('Grabar con la Camara'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final picker = ImagePicker();
              final file = await picker.pickVideo(source: ImageSource.gallery);
              if (file != null && mounted) {
                await _handleVideoReady(file);
              }
            },
            child: const Text('Subir desde Galeria'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int sec) {
    final m = (sec / 60).floor().toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        onPressed: _isUploading
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE3DAFF)),
                          ),
                          child: const Icon(
                            CupertinoIcons.chevron_back,
                            color: Color(0xFF15163D),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5B3DF5), Color(0xFF7E66FF)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Asistente A4',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        onPressed: _isUploading
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE3DAFF)),
                          ),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            color: Color(0xFF15163D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Video de presentacion',
                            style: TextStyle(
                              color: Color(0xFF15163D),
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.isCompany
                                ? 'Mostra en un minuto que hace especial a tu empresa y a quien estas buscando.'
                                : 'Mostra en un minuto tu energia, tu foco y el tipo de oportunidad que estas buscando.',
                            style: const TextStyle(
                              color: Color(0xFF69708F),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const _PitchProgressRow(),
                          const SizedBox(height: 22),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: const Color(0xFFE3DAFF),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.lightbulb_fill,
                                      color: Color(0xFF5B3DF5),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Guia rapida',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF15163D),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _GuideBullet(
                                  text: widget.isCompany
                                      ? 'Conta que ofrece tu empresa y el tipo de talento que queres sumar.'
                                      : 'Conta que sabes hacer y donde generas mas valor.',
                                ),
                                const SizedBox(height: 10),
                                _GuideBullet(
                                  text: widget.isCompany
                                      ? 'Habla con claridad, buena luz y una propuesta concreta.'
                                      : 'Menciona el tipo de rol, industria o modalidad que estas buscando.',
                                ),
                                const SizedBox(height: 10),
                                const _GuideBullet(
                                  text:
                                      'El video pitch es obligatorio para activar la experiencia completa en Mploya.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF201642), Color(0xFF3B2F6A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF5B3DF5,
                                  ).withValues(alpha: 0.18),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        _isUploading
                                            ? 'Subiendo...'
                                            : _isRecording
                                            ? _formatTime(_seconds)
                                            : 'Max 60 segundos',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.10,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        kIsWeb
                                            ? 'Web recorder'
                                            : 'Camara nativa',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.82,
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      color: Colors.white.withValues(
                                        alpha: 0.06,
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.10,
                                        ),
                                      ),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Positioned.fill(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white.withValues(
                                                    alpha: 0.04,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.01,
                                                  ),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 94,
                                              height: 94,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white.withValues(
                                                  alpha: 0.10,
                                                ),
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 3,
                                                ),
                                              ),
                                              child: Center(
                                                child: Container(
                                                  width: _isRecording ? 38 : 74,
                                                  height: _isRecording
                                                      ? 38
                                                      : 74,
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFFF5A5F,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          _isRecording
                                                              ? 10
                                                              : 40,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            Text(
                                              _isUploading
                                                  ? 'Estamos subiendo tu video pitch'
                                                  : kIsWeb
                                                  ? 'Graba desde la webcam o sube un video existente'
                                                  : 'Graba ahora o usa un video desde tu galeria',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              widget.isCompany
                                                  ? 'Queremos entender tu cultura, tu propuesta y el perfil que necesitas.'
                                                  : 'Queremos verte como te presentarias ante una empresa real.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.74,
                                                ),
                                                fontSize: 14,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: const Color(0xFFE3DAFF),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.sparkles,
                                      color: Color(0xFF5B3DF5),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Idea sugerida por IA',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF15163D),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  widget.isCompany
                                      ? '"Somos una empresa en crecimiento que valora accion, claridad y ganas de construir. Hoy buscamos sumar a alguien que pueda generar impacto desde el primer mes."'
                                      : '"Soy una persona proactiva, con foco en resultados y ganas de crecer en un entorno donde pueda aportar criterio, ejecucion y buena energia."',
                                  style: const TextStyle(
                                    color: Color(0xFF4A5073),
                                    fontSize: 15,
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _isUploading
                              ? null
                              : () => Navigator.of(context).maybePop(),
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE3DAFF),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Atras',
                              style: TextStyle(
                                color: Color(0xFF5B3DF5),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _isUploading
                              ? null
                              : (kIsWeb ? _toggleRecording : _pickFromGallery),
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF5B3DF5), Color(0xFF7E66FF)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF5B3DF5,
                                  ).withValues(alpha: 0.25),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: _isUploading
                                ? const CupertinoActivityIndicator(
                                    color: Colors.white,
                                  )
                                : Text(
                                    kIsWeb ? 'Grabar ahora' : 'Subir ahora',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PitchProgressRow extends StatelessWidget {
  const _PitchProgressRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (index) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF5B3DF5),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _GuideBullet extends StatelessWidget {
  final String text;

  const _GuideBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          decoration: const BoxDecoration(
            color: Color(0xFFF2EEFF),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.check_mark,
            size: 14,
            color: Color(0xFF5B3DF5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF4A5073),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
