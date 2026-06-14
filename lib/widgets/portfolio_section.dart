import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/portfolio_service.dart';
import '../widgets/spring_interaction.dart';
import 'profile_video_widgets.dart';
// Grabador web (getUserMedia + MediaRecorder). En móvil resuelve al stub que usa
// ImagePicker. Mismo patrón que micro_pitch_camera.dart.
import '../screens/micro_pitch_web_stub.dart'
    if (dart.library.html) '../screens/micro_pitch_web_recorder.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PortfolioSection — Sección de portfolio en el perfil
//
// Muestra hasta 3 vídeos de portfolio del usuario en una galería horizontal.
// Si es perfil propio, permite agregar/eliminar vídeos.
// ─────────────────────────────────────────────────────────────────────────────

class PortfolioSection extends StatefulWidget {
  final String userId;
  final bool isOwnProfile;

  const PortfolioSection({
    super.key,
    required this.userId,
    required this.isOwnProfile,
  });

  @override
  State<PortfolioSection> createState() => _PortfolioSectionState();
}

class _PortfolioSectionState extends State<PortfolioSection> {
  List<PortfolioVideo> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    setState(() => _isLoading = true);
    try {
      final videos = widget.isOwnProfile
          ? await PortfolioService.instance.getMyPortfolio()
          : await PortfolioService.instance.getPortfolioFor(widget.userId);
      if (mounted) {
        setState(() {
          _videos = videos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CupertinoActivityIndicator(radius: 12)),
      );
    }

    if (_videos.isEmpty && !widget.isOwnProfile) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(NexTheme.radiusMD),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [NexTheme.premiumStart, NexTheme.premiumEnd],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(CupertinoIcons.film, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(
                  'Portfolio',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_videos.length}/${PortfolioService.maxPortfolioVideos}',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (widget.isOwnProfile && _videos.length < PortfolioService.maxPortfolioVideos)
                  SpringInteraction(
                    onTap: _showAddVideoDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: NexTheme.brandAccent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(NexTheme.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.plus, size: 14, color: context.brandAccent),
                          const SizedBox(width: 4),
                          Text(
                            'Agregar',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.brandAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Videos Grid ──
          if (_videos.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: NexTheme.brandAccent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: NexTheme.brandAccent.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      CupertinoIcons.film,
                      size: 36,
                      color: NexTheme.brandAccent.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Mostrá tu trabajo en acción',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Subí hasta 3 vídeos de 60s mostrando\nproyectos, habilidades o resultados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _videos.length,
                itemBuilder: (context, i) => _buildVideoCard(_videos[i], i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(PortfolioVideo video, int index) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        showCupertinoModalPopup<void>(
          context: context,
          builder: (_) => VideoPlayerModal(
            videoUrl: video.videoUrl,
            index: index,
          ),
        );
      },
      child: Container(
        width: 200,
        margin: EdgeInsets.only(right: index < _videos.length - 1 ? 12 : 0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A0A00), Color(0xFF3D1800)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: NexTheme.brandAccent.withValues(alpha: 0.30),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: NexTheme.brandAccent.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [NexTheme.brandAccent, NexTheme.premiumEnd],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: NexTheme.brandAccent.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 20),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: NexTheme.brandAccent.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: NexTheme.brandAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${video.durationSeconds}s',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFFFBB8A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    video.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(CupertinoIcons.eye, size: 12, color: Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        '${video.viewCount}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(CupertinoIcons.heart, size: 12, color: Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        '${video.likeCount}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Delete button (own profile only)
            if (widget.isOwnProfile)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => _confirmDelete(video),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.xmark, size: 12, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddVideoDialog() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Agregar Video de Portfolio'),
        message: const Text('Grabá un video nuevo o seleccioná uno de tu galería (máx 60s)'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickVideo(fromCamera: true);
            },
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(CupertinoIcons.videocam_fill, color: CupertinoColors.activeBlue),
              SizedBox(width: 10),
              Text('Grabar Video'),
            ]),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickVideo(fromCamera: false);
            },
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(CupertinoIcons.photo_fill, color: CupertinoColors.activeOrange),
              SizedBox(width: 10),
              Text('Elegir de Galería'),
            ]),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          isDestructiveAction: true,
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Future<void> _pickVideo({required bool fromCamera}) async {
    try {
      final XFile? video;
      if (fromCamera) {
        // En web la cámara de image_picker no graba video; usamos el grabador
        // nativo del navegador (MediaRecorder). En móvil va por ImagePicker.
        if (kIsWeb) {
          video = await WebRecorderHelper.recordVideo(context);
        } else {
          video = await ImagePicker()
              .pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 60));
        }
      } else {
        video = await ImagePicker().pickVideo(source: ImageSource.gallery);
      }

      if (video == null) return;

      // Ask for title
      if (!mounted) return;
      final titleController = TextEditingController();
      final title = await showCupertinoDialog<String>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Título del video'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _TitleDialogTextField(
              controller: titleController,
              placeholder: 'Ej: Mi proyecto de diseño',
            ),
          ),
          actions: [
            CupertinoDialogAction(child: const Text('Cancelar'), onPressed: () => Navigator.pop(ctx)),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Subir'),
              onPressed: () => Navigator.pop(ctx, titleController.text.trim()),
            ),
          ],
        ),
      );

      if (title == null || title.isEmpty) return;

      // Show uploading indicator
      if (!mounted) return;
      setState(() {});

      // Upload
      final result = await PortfolioService.instance.uploadVideo(
        file: video,
        title: title,
        durationSeconds: 30, // Default; real duration from video metadata
      );

      if (result != null) {
        await _loadPortfolio();
        if (mounted) {
          showCupertinoDialog(context: context, builder: (c) => CupertinoAlertDialog(
            title: const Text('Video subido ✓'),
            content: const Text('Tu video fue agregado al portfolio.'),
            actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
          ));
        }
      } else {
        if (mounted) {
          showCupertinoDialog(context: context, builder: (c) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: const Text('No se pudo subir el video. Verificá tu conexión e intentá de nuevo.'),
            actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
          ));
        }
      }
    } catch (e) {
      debugPrint('Portfolio pick video error: $e');
      if (mounted) {
        showCupertinoDialog(context: context, builder: (c) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('No se pudo acceder a la cámara/galería: $e'),
          actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ));
      }
    }
  }

  void _confirmDelete(PortfolioVideo video) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Eliminar video'),
        content: Text('¿Eliminar "${video.title}" del portfolio?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Eliminar'),
            onPressed: () async {
              Navigator.pop(ctx);
              await PortfolioService.instance.deleteVideo(video.id);
              await _loadPortfolio();
            },
          ),
        ],
      ),
    );
  }
}

class _TitleDialogTextField extends StatefulWidget {
  final TextEditingController controller;
  final String placeholder;

  const _TitleDialogTextField({
    required this.controller,
    required this.placeholder,
  });

  @override
  State<_TitleDialogTextField> createState() => _TitleDialogTextFieldState();
}

class _TitleDialogTextFieldState extends State<_TitleDialogTextField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: widget.controller,
      focusNode: _focusNode,
      placeholder: widget.placeholder,
      padding: const EdgeInsets.all(12),
      textCapitalization: TextCapitalization.sentences,
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(
          CupertinoColors.systemBackground,
          context,
        ),
        border: Border.all(
          color: CupertinoDynamicColor.resolve(
            CupertinoColors.systemGrey4,
            context,
          ),
          width: 0.5,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
      ),
    );
  }
}
