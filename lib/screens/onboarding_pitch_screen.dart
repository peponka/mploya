import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import 'onboarding_tour_screen.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'camera_screen.dart';
// Grabador web (getUserMedia + MediaRecorder). En móvil usa el stub.
import 'micro_pitch_web_stub.dart'
    if (dart.library.html) 'micro_pitch_web_recorder.dart';

class OnboardingPitchScreen extends StatefulWidget {
  final bool isCompany;

  const OnboardingPitchScreen({
    super.key,
    required this.isCompany,
  });

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
      // Auto-creamos la vacante silenciosamente
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          final userData = await Supabase.instance.client
              .from('users')
              .select('headline, about, tags, location, company, name')
              .eq('id', user.id)
              .maybeSingle();

          if (userData != null) {
            final title = userData['headline']?.toString().isEmpty ?? true ? 'Nueva Vacante' : userData['headline'];
            final companyName = userData['company'] ?? userData['name'] ?? 'Empresa Confidencial';

            await Supabase.instance.client.from('jobs').insert({
              'company_id': user.id,
              'company_name': companyName,
              'title': title,
              'description': userData['about'] ?? 'Oferta publicada desde onboarding.',
              'location': userData['location'] ?? 'Remoto',
              'modality': 'remote',
              'seniority': 'mid',
              'salary_range': 'A convenir',
            });
            debugPrint('✅ Vacante auto-creada en onboarding (direct insert sin tags).');
          }
        } catch (e) {
          debugPrint('❌ Error auto-creando vacante directa: $e');
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
                  )
                ],
              ),
            );
          }
        }
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => OnboardingTourScreen(accountType: widget.isCompany ? 'empresa' : 'candidato'),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    } else {
      Navigator.of(context, rootNavigator: true).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => OnboardingTourScreen(accountType: widget.isCompany ? 'empresa' : 'candidato'),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  void _showPitchSuccessDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('¡Pitch Excelente! 🎉'),
        content: const Text('Ya queremos que la red te escuche. ¿Listo para entrar a Mploya?'),
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
            child: const Text('¡Entrar a Mploya!'),
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

  /// Sube el video a Supabase y guarda la URL en el perfil.
  /// Solo muestra el diálogo de éxito si todo va bien.
  Future<void> _handleVideoReady(XFile file) async {
    final user = Supabase.instance.client.auth.currentUser;

    setState(() => _isUploading = true);

    try {
      // ── 1. Subir al bucket "videos" ──
      final videoUrl = await StorageService.instance.uploadPitchVideo(
        user?.id ?? 'anonymous',
        file,
      );

      if (!mounted) return;

      if (videoUrl == null) {
        setState(() => _isUploading = false);
        _showErrorDialog(
          StorageService.instance.lastError ?? 'Error desconocido al subir el video.',
          onRetry: () => _handleVideoReady(file),
        );
        return;
      }

      // ── 2. Guardar URL en public.users (solo si hay sesión activa) ──
      if (user != null) {
        final profileError = await AuthService.instance.updatePitchUrl(user.id, videoUrl);
        if (!mounted) return;
        if (profileError != null) {
          // No bloqueamos el flujo — el video ya subió. Solo avisamos.
          setState(() => _isUploading = false);
          _showErrorDialog(
            'El video se subió, pero no se pudo guardar en tu perfil: $profileError',
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
    // ── Web: grabar con la webcam (getUserMedia + MediaRecorder) ──
    // El plugin `camera` no soporta startVideoRecording en web, así que
    // usamos el grabador nativo del browser y reutilizamos el mismo flujo
    // de subida que la opción "Subir MP4".
    if (kIsWeb) {
      final file = await WebRecorderHelper.recordVideo(context);
      if (!mounted) return;
      if (file != null) {
        await _handleVideoReady(file);
      }
      return;
    }

    // ── Móvil: CameraScreen con preview real (devuelve true si subió) ──
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(builder: (_) => const CameraScreen()),
    );

    if (!mounted) return;

    if (result == true) {
      _showPitchSuccessDialog();
    }
  }

  Future<void> _pickFromGallery() async {
    // Mostramos opciones: Cámara o Galería
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Añadir Video Pitch'),
        message: const Text('¿De dónde quieres obtener el video?'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final camStatus = await Permission.camera.request();
              final micStatus = await Permission.microphone.request();
              if (camStatus.isGranted && micStatus.isGranted) {
                final picker = ImagePicker();
                final file = await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 60));
                if (file != null && mounted) {
                  await _handleVideoReady(file);
                }
              } else {
                _showValidationAlert('Se requieren permisos de cámara y micrófono.');
              }
            },
            child: const Text('Grabar con la Cámara'),
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
            child: const Text('Subir desde Galería'),
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
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // ── Fondo de Cámara Simulada ──
          Positioned.fill(
            child: Container(
              color: const Color(0xFF151515),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.video_camera, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                ],
              ),
            ),
          ),

          // ── Capa de Texto Amable y Guía ──
          if (!_isRecording && !_isUploading)
            Positioned(
              top: 100,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¡Hola! 👋\nQueremos escucharte.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isCompany
                        ? 'En Mploya, los currículums de papel no existen. Las empresas y los candidatos se conectan a través de Videos. \n\nGraba tu primer Pitch contando:\n1. Qué ofreces como empresa.\n2. A quién estás buscando.'
                        : 'En Mploya, los currículums de papel no existen. Las empresas quieren ver tu energía real. \n\nGraba tu primer Pitch contando:\n1. Qué sabes hacer (lo que ofreces).\n2. El tipo de empleo que buscas.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(CupertinoIcons.info_circle_fill, color: MployaTheme.brandAccent, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Es obligatorio tener un Video-Pitch para poder ver los perfiles de los demás.',
                            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

          // ── Controles Inferiores (ocultos durante la subida) ──
          if (!_isUploading)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 160,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedOpacity(
                      opacity: _isRecording ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onTap: _pickFromGallery,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.folder_fill, color: Colors.white.withValues(alpha: 0.8), size: 30),
                            const SizedBox(height: 6),
                            Text('Subir MP4', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
                          ],
                        ),
                      ),
                    ),

                    // Botón central: Grabar (móvil) o Subir (web)
                    GestureDetector(
                      onTap: _toggleRecording,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isRecording ? MployaTheme.danger.withValues(alpha: 0.4) : Colors.white,
                            width: _isRecording ? 6 : 4,
                          ),
                        ),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: _isRecording ? 36 : 68,
                            height: _isRecording ? 36 : 68,
                            decoration: BoxDecoration(
                              color: MployaTheme.danger,
                              borderRadius: BorderRadius.circular(_isRecording ? 8 : 40),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Botón Video Test ELIMINADO — solo se graba video real.
                    const SizedBox(width: 48), // placeholder para mantener el layout centrado
                  ],
                ),
              ),
            ),

          // ── Timer / Badge durante la grabación ──
          if (_isRecording && !_isUploading)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: MployaTheme.danger.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatTime(_seconds),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),

          // ── Overlay de Carga ──
          if (_isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.75),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CupertinoActivityIndicator(
                      radius: 18,
                      color: MployaTheme.brandAccent,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Subiendo tu Pitch...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Esto puede tardar unos segundos.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}