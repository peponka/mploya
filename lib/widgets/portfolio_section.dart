import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../services/portfolio_service.dart';
import '../theme/mploya_tokens.dart';
import '../widgets/ds/mp_surface.dart';
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
//
// CANDIDATO — TANDA 3: modernizado de `NexTheme` a `MpTokens`/`widgets/ds/*`
// (referencia: `portfolio.png` de FINAL_SCREENS_CODEX). Cero cambios de
// lógica: carga, subida, borrado y límite de 3 videos siguen exactamente
// igual — sólo color/tipografía.
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
    final s = context.mp;

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
        color: s.card,
        borderRadius: BorderRadius.circular(MpTokens.radiusMD),
        boxShadow: s.cardShadow,
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
                      colors: [MpTokens.premium, MpTokens.premiumBright],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(CupertinoIcons.film, size: 16, color: CupertinoColors.white),
                ),
                const SizedBox(width: 10),
                Text(
                  'Portfolio',
                  style: MpTokens.title.copyWith(fontSize: 17, color: s.text),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_videos.length}/${PortfolioService.maxPortfolioVideos}',
                  style: MpTokens.caption.copyWith(color: s.textTertiary, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                if (widget.isOwnProfile && _videos.length < PortfolioService.maxPortfolioVideos)
                  SpringInteraction(
                    onTap: _showAddVideoDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: s.tint(s.accent),
                        borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.plus, size: 14, color: s.accent),
                          const SizedBox(width: 4),
                          Text(
                            'Agregar',
                            style: MpTokens.label.copyWith(color: s.accent, fontWeight: FontWeight.w600),
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
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: s.tint(MpTokens.premium, alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MpTokens.premium.withValues(alpha: 0.18), width: 0.5),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [MpTokens.premium, MpTokens.premiumBright]),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: MpTokens.premium.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
                      ),
                      child: const Icon(CupertinoIcons.film_fill, size: 24, color: CupertinoColors.white),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Mostrá tu trabajo en acción',
                      style: MpTokens.title.copyWith(fontSize: 15.5, color: s.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Subí hasta 3 vídeos de 60s con proyectos,\nhabilidades o resultados.',
                      textAlign: TextAlign.center,
                      style: MpTokens.caption.copyWith(color: s.textSecondary, height: 1.4),
                    ),
                    if (widget.isOwnProfile) ...[
                      const SizedBox(height: 16),
                      SpringInteraction(
                        onTap: _showAddVideoDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          decoration: BoxDecoration(
                            gradient: s.accentGradient,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(CupertinoIcons.plus, size: 15, color: CupertinoColors.white),
                            SizedBox(width: 6),
                            Text('Agregar video', style: TextStyle(color: CupertinoColors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ],
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
                itemBuilder: (context, i) => _buildVideoCard(context, _videos[i], i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, PortfolioVideo video, int index) {
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
          color: MpTokens.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MpTokens.primary.withValues(alpha: 0.30),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: MpTokens.primary.withValues(alpha: 0.15),
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
                          gradient: MpTokens.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: MpTokens.primary.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(CupertinoIcons.play_fill, color: CupertinoColors.white, size: 20),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: MpTokens.primary.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: MpTokens.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${video.durationSeconds}s',
                          style: const TextStyle(
                            fontSize: 11,
                            color: MpTokens.darkText,
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
                      color: CupertinoColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(CupertinoIcons.eye, size: 12, color: CupertinoColors.white.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        '${video.viewCount}',
                        style: TextStyle(
                          fontSize: 11,
                          color: CupertinoColors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(CupertinoIcons.heart, size: 12, color: CupertinoColors.white.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        '${video.likeCount}',
                        style: TextStyle(
                          fontSize: 11,
                          color: CupertinoColors.white.withValues(alpha: 0.6),
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
                      color: CupertinoColors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.xmark, size: 12, color: CupertinoColors.white),
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
