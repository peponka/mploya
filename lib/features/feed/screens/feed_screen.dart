/// Feed vertical estilo TikTok con tarjetas de video-pitch.
///
/// Incluye barra superior con logo, historias, indicador de match
/// y un [PageView] vertical de tarjetas de candidatos/empresas.
library;

import 'dart:math';
import 'dart:ui';


import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mploya/core/widgets/platform_video_player.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/features/profile/models/company_profile_store.dart';
import 'package:mploya/core/models/video_model.dart';
import 'package:mploya/features/feed/providers/feed_provider.dart';
import 'package:mploya/features/payment/screens/payment_screen.dart';

// ─── Modelos mock ────────────────────────────────────────────────────

class _FeedItem {
  const _FeedItem({
    required this.name,
    required this.role,
    required this.company,
    required this.matchPercent,
    required this.hashtags,
    required this.avatarColor,
    required this.initial,
    required this.bgColor,
    required this.headlineText,
    this.userId = '',
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.isStealth = false,
    this.stealthTitle = '',
  });

  final String name;
  final String role;
  final String company;
  final int matchPercent;
  final List<String> hashtags;
  final Color avatarColor;
  final String initial;
  final Color bgColor;
  final String headlineText;
  final String userId;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool isStealth;
  final String stealthTitle;
}

const _userVideoItem = _FeedItem(
  name: 'Stealth · Tu Pitch',
  role: 'video de presentación',
  company: 'confidencial',
  matchPercent: 100,
  hashtags: ['#mipitch', '#presentación', '#nuevo'],
  avatarColor: Color(0xFF7C3AED),
  initial: '🎭',
  bgColor: Color(0xFF1E1033),
  headlineText: '¡TU VIDEO DE PRESENTACIÓN FUE PUBLICADO!',
  likeCount: 12,
  commentCount: 3,
  shareCount: 1,
  isStealth: true,
  stealthTitle: 'Tu Pitch Confidencial',
);

const _mockFeed = [
  _FeedItem(
    name: 'Carolina Méndez',
    role: 'ingeniero industrial',
    company: 'lenovo',
    matchPercent: 99,
    hashtags: ['#ingeniero', '#flutter', '#react'],
    avatarColor: Color(0xFF8B5CF6),
    initial: 'C',
    bgColor: Color(0xFF1E1B4B),
    headlineText: 'CON EXPERIENCIA EN TECNOLOGÍA Y DISEÑO',
    likeCount: 245,
    commentCount: 18,
    shareCount: 32,
  ),
  _FeedItem(
    name: 'Tomás Aguirre',
    role: 'desarrollador mobile',
    company: 'globant',
    matchPercent: 88,
    hashtags: ['#flutter', '#dart', '#mobile'],
    avatarColor: Color(0xFF10B981),
    initial: 'T',
    bgColor: Color(0xFF0F172A),
    headlineText: 'ESPECIALISTA EN APPS NATIVAS Y MULTIPLATAFORMA',
    likeCount: 189,
    commentCount: 24,
    shareCount: 15,
  ),
  // ── Stealth Card 1 ──
  _FeedItem(
    name: 'Stealth · VP Engineering',
    role: 'VP Engineering',
    company: 'confidencial',
    matchPercent: 95,
    hashtags: ['#leadership', '#fintech', '#scaleups'],
    avatarColor: Color(0xFF7C3AED),
    initial: '🎭',
    bgColor: Color(0xFF1E1033),
    headlineText: 'EJECUTIVO CON +15 AÑOS ESCALANDO EQUIPOS DE INGENIERÍA',
    likeCount: 0,
    commentCount: 0,
    shareCount: 0,
    isStealth: true,
    stealthTitle: 'VP Engineering',
  ),
  _FeedItem(
    name: 'Valentina Rojas',
    role: 'product manager',
    company: 'mercadolibre',
    matchPercent: 85,
    hashtags: ['#finanzas', '#product', '#agile'],
    avatarColor: Color(0xFFF97316),
    initial: 'V',
    bgColor: Color(0xFF18181B),
    headlineText: 'LIDERANDO EQUIPOS DE PRODUCTO EN FINTECH',
    likeCount: 312,
    commentCount: 41,
    shareCount: 28,
  ),
  _FeedItem(
    name: 'Matías López',
    role: 'full stack developer',
    company: 'ualá',
    matchPercent: 79,
    hashtags: ['#react', '#node', '#typescript'],
    avatarColor: Color(0xFF3B82F6),
    initial: 'M',
    bgColor: Color(0xFF1C1917),
    headlineText: 'CREANDO SOLUCIONES ESCALABLES EN LA NUBE',
    likeCount: 156,
    commentCount: 12,
    shareCount: 9,
  ),
  _FeedItem(
    name: 'Lucía Fernández',
    role: 'data scientist',
    company: 'google',
    matchPercent: 94,
    hashtags: ['#python', '#ml', '#datos'],
    avatarColor: Color(0xFFEC4899),
    initial: 'L',
    bgColor: Color(0xFF0C0A09),
    headlineText: 'TRANSFORMANDO DATOS EN DECISIONES INTELIGENTES',
    likeCount: 478,
    commentCount: 56,
    shareCount: 67,
  ),
  // ── Stealth Card 2 ──
  _FeedItem(
    name: 'Stealth · CTO Fintech',
    role: 'CTO',
    company: 'confidencial',
    matchPercent: 91,
    hashtags: ['#cto', '#blockchain', '#python', '#aws'],
    avatarColor: Color(0xFF7C3AED),
    initial: '🎭',
    bgColor: Color(0xFF1A0F2E),
    headlineText: 'ARQUITECTO DE PLATAFORMAS FINTECH CON EXIT DE USD 20M',
    likeCount: 0,
    commentCount: 0,
    shareCount: 0,
    isStealth: true,
    stealthTitle: 'CTO Fintech',
  ),
  _FeedItem(
    name: 'Nicolás Herrera',
    role: 'marketing digital',
    company: 'meta',
    matchPercent: 73,
    hashtags: ['#marketing', '#growth', '#seo'],
    avatarColor: Color(0xFFEAB308),
    initial: 'N',
    bgColor: Color(0xFF1A1A2E),
    headlineText: 'GROWTH HACKER CON FOCO EN RESULTADOS',
    likeCount: 93,
    commentCount: 7,
    shareCount: 4,
  ),
  _FeedItem(
    name: 'Sofía Castillo',
    role: 'devops engineer',
    company: 'amazon',
    matchPercent: 81,
    hashtags: ['#devops', '#cloud', '#docker'],
    avatarColor: Color(0xFF06B6D4),
    initial: 'S',
    bgColor: Color(0xFF111827),
    headlineText: 'INFRAESTRUCTURA CLOUD A ESCALA GLOBAL',
    likeCount: 134,
    commentCount: 19,
    shareCount: 11,
  ),
];

// ─── Stories mock ────────────────────────────────────────────────────

class _StoryUser {
  const _StoryUser(this.initial, this.color, {this.hasUnread = true});
  final String initial;
  final Color color;
  final bool hasUnread;
}

const _storyUsers = [
  _StoryUser('C', Color(0xFF8B5CF6)),
  _StoryUser('T', Color(0xFF10B981)),
  _StoryUser('V', Color(0xFFF97316), hasUnread: false),
  _StoryUser('A', Color(0xFFEF4444)),
  _StoryUser('L', Color(0xFFEC4899)),
  _StoryUser('R', Color(0xFF3B82F6), hasUnread: false),
];

// ─── Feed Screen ─────────────────────────────────────────────────────

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  String? _userVideoViewId;

  // ── Map VideoModel → _FeedItem ──
  static const _avatarColors = [
    Color(0xFF8B5CF6), Color(0xFF10B981), Color(0xFFF97316),
    Color(0xFF3B82F6), Color(0xFFEC4899), Color(0xFFEAB308),
    Color(0xFF06B6D4), Color(0xFFEF4444),
  ];
  static const _bgColors = [
    Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF18181B),
    Color(0xFF1C1917), Color(0xFF0C0A09), Color(0xFF1A1A2E),
    Color(0xFF111827), Color(0xFF1A0F2E),
  ];

  _FeedItem _mapVideoModelToFeedItem(VideoModel video, int index) {
    final colorIdx = index % _avatarColors.length;
    final initial = (video.userName != null && video.userName!.isNotEmpty)
        ? video.userName![0].toUpperCase()
        : '?';
    return _FeedItem(
      name: video.userName ?? 'Usuario',
      role: video.title ?? video.description ?? 'profesional',
      company: '',
      matchPercent: video.matchPercentage ?? (70 + (index * 7) % 30),
      hashtags: video.hashtags.isNotEmpty
          ? video.hashtags.map((h) => h.startsWith('#') ? h : '#$h').toList()
          : ['#pitch'],
      avatarColor: _avatarColors[colorIdx],
      initial: initial,
      bgColor: _bgColors[colorIdx],
      headlineText: (video.userHeadline ?? video.title ?? 'VIDEO PITCH').toUpperCase(),
      userId: video.userId,
      likeCount: video.likeCount,
      commentCount: 0,
      shareCount: 0,
    );
  }

  List<_FeedItem> get _feedItems {
    // 1) Try real provider data from Supabase
    final asyncVideos = ref.watch(feedVideosProvider);
    final providerItems = asyncVideos.whenOrNull<List<_FeedItem>>(
      data: (videos) {
        if (videos.isEmpty) return null; // fall through to mock
        return videos.asMap().entries.map((e) => _mapVideoModelToFeedItem(e.value, e.key)).toList();
      },
    );

    // 2) Base feed: provider data or mock fallback
    final baseFeed = providerItems ?? _mockFeed;

    // 3) Prepend user's published video card if available
    final blobUrl = ref.watch(videoPublishedProvider);
    if (blobUrl != null) {
      final userHashtags = ref.watch(userHashtagsProvider);
      final userTitle = ref.watch(userStealthTitleProvider);
      final userCompany = ref.watch(userCompanyProvider);

      final dynamicUserItem = _FeedItem(
        name: 'Stealth · ${userTitle.isNotEmpty ? userTitle : 'Tu Pitch'}',
        role: userTitle.isNotEmpty ? userTitle : 'video de presentación',
        company: userCompany.isNotEmpty ? userCompany : 'confidencial',
        matchPercent: 100,
        hashtags: userHashtags.isNotEmpty
            ? userHashtags
            : ['#mipitch', '#presentación', '#nuevo'],
        avatarColor: const Color(0xFF7C3AED),
        initial: '🎭',
        bgColor: const Color(0xFF1E1033),
        headlineText: '¡TU VIDEO DE PRESENTACIÓN FUE PUBLICADO!',
        likeCount: 12,
        commentCount: 3,
        shareCount: 1,
        isStealth: true,
        stealthTitle: userTitle.isNotEmpty ? userTitle : 'Tu Pitch Confidencial',
      );
      return [dynamicUserItem, ...baseFeed];
    }
    return baseFeed.toList();
  }

  String? get _userVideoBlobUrl => ref.watch(videoPublishedProvider);

  void _ensureUserVideoView(String blobUrl) {
    if (_userVideoViewId != null) return;
    _userVideoViewId = 'feed-user-video-${DateTime.now().millisecondsSinceEpoch}';
    // El widget PlatformVideoPlayer se construirá en el build
    // Solo marcamos el viewId como inicializado
  }

  /// Referencia al blob URL del usuario para construir el PlatformVideoPlayer.
  String? get _userBlobUrlCached => _userVideoBlobUrl;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Vertical video feed (TikTok-style) ──
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _feedItems.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                final items = _feedItems;
                final blobUrl = _userVideoBlobUrl;
                // First item is user's video if published
                if (index == 0 && blobUrl != null) {
                  _ensureUserVideoView(blobUrl);
                  return _FeedCard(
                    item: items[index],
                    videoViewId: _userVideoViewId,
                    videoBlobUrl: blobUrl,
                  );
                }
                return _FeedCard(item: items[index]);
              },
            ),

            // ── Top bar overlay ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        // ── Record story button ──
                        GestureDetector(
                          onTap: () => context.push('/video/new-story'),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: MployaColors.orangeGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: MployaColors.orange.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.videocam_rounded,
                              color: MployaColors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // ── Notification bell with badge ──
                        GestureDetector(
                          onTap: () => _showNotificationsSheet(context),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_outlined,
                                  color: MployaColors.white,
                                  size: 22,
                                ),
                              ),
                              // Badge count
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: MployaColors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '3',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: MployaColors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Notifications Bottom Sheet ──
  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Notificaciones',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MployaColors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _NotifTile(
              icon: Icons.visibility_rounded,
              iconColor: MployaColors.teal,
              title: 'TechCorp vio tu historia',
              subtitle: 'Hace 12 min',
            ),
            _NotifTile(
              icon: Icons.visibility_rounded,
              iconColor: MployaColors.teal,
              title: 'Globant vio tu historia',
              subtitle: 'Hace 1 hora',
            ),
            _NotifTile(
              icon: Icons.thumb_up_rounded,
              iconColor: MployaColors.orange,
              title: 'MercadoLibre le gustó tu pitch',
              subtitle: 'Hace 3 horas',
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

// ─── Feed Card ───────────────────────────────────────────────────────

class _FeedCard extends StatefulWidget {
  const _FeedCard({required this.item, this.videoViewId, this.videoBlobUrl});
  final _FeedItem item;
  final String? videoViewId;
  final String? videoBlobUrl;

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> with TickerProviderStateMixin {
  bool _isLiked = false;
  bool _isSaved = false;
  late int _likeCount;
  late int _commentCount;
  late int _shareCount;

  // Like scale animation
  late final AnimationController _likeAnimController;
  late final Animation<double> _likeScaleAnim;

  // Save scale animation
  late final AnimationController _saveAnimController;
  late final Animation<double> _saveScaleAnim;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.item.likeCount;
    _commentCount = widget.item.commentCount;
    _shareCount = widget.item.shareCount;

    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _likeScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _likeAnimController,
      curve: Curves.easeInOut,
    ));

    _saveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _saveScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _saveAnimController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _likeAnimController.dispose();
    _saveAnimController.dispose();
    super.dispose();
  }

  void _handleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    _likeAnimController.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  void _handleSave() {
    setState(() {
      _isSaved = !_isSaved;
    });
    _saveAnimController.forward(from: 0);
    HapticFeedback.lightImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border_rounded,
                color: MployaColors.white,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _isSaved ? 'Guardado en favoritos' : 'Eliminado de favoritos',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: MployaColors.white,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2D2D2D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
        ),
      );
    }
  }

  void _handleComment() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CommentSheet(
        item: widget.item,
        commentCount: _commentCount,
      ),
    );
  }

  void _handleShare() {
    final item = widget.item;
    final text = '${item.headlineText}\n\n'
        '${item.name} · ${item.role} @ ${item.company}\n'
        '${item.hashtags.join(" ")}\n\n'
        'Match ${item.matchPercent}% — Descubrí más en mploya.ai';
    Share.share(text);
    setState(() {
      _shareCount += 1;
    });
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Compartir',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MployaColors.white,
                ),
              ),
              const SizedBox(height: 20),
              _ShareOption(
                icon: Icons.share_rounded,
                label: 'Compartir externamente',
                onTap: () {
                  Navigator.pop(ctx);
                  _handleShare();
                },
              ),
              _ShareOption(
                icon: Icons.link,
                label: 'Copiar enlace',
                onTap: () {
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Enlace copiado',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor: const Color(0xFF2D2D2D),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
              _ShareOption(
                icon: Icons.message_rounded,
                label: 'Enviar por mensaje',
                onTap: () {
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Compartido por mensaje ✓',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor: const Color(0xFF2D2D2D),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    context.go('/home?tab=2');
                  }
                },
              ),
              _ShareOption(
                icon: Icons.mail_outline,
                label: 'Enviar por email',
                onTap: () {
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Link copiado al portapapeles 📋',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor: const Color(0xFF2D2D2D),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              _ShareOption(
                icon: Icons.flag_outlined,
                label: 'Reportar',
                onTap: () {
                  Navigator.pop(ctx);
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        backgroundColor: const Color(0xFF1C1C1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        title: Text(
                          '¿Estás seguro que querés reportar este contenido?',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: MployaColors.white,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Contenido reportado. Gracias por tu feedback.',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  backgroundColor: const Color(0xFF2D2D2D),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            },
                            child: Text(
                              'Reportar',
                              style: GoogleFonts.inter(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
                isDestructive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formats large numbers into compact strings (e.g. 1.2K)
  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    // ── Stealth card variant ──
    // Confidenciales siempre ocultan identidad hasta pagar premium
    if (item.isStealth) {
      return _buildStealthCard(context, item);
    }

    // ── Normal card ──
    return _buildNormalCard(context, item);
  }

  /// Builds the stealth/confidential card with purple accents and glassmorphism
  Widget _buildStealthCard(BuildContext context, _FeedItem item) {
    return Container(
      color: item.bgColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Real video playing behind blur (if available) ──
          if (widget.videoViewId != null && widget.videoBlobUrl != null)
            PlatformVideoPlayer(
              viewId: widget.videoViewId!,
              url: widget.videoBlobUrl!,
              transform: 'scaleX(-1) scale(1.3)',
              filter: 'blur(30px)',
              background: '#1E1033',
              muted: true,
            )
          else
            Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 80,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),

          // ── FROSTED OVERLAY — heavy blur so face is unrecognizable ──
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      radius: 0.9,
                      colors: [
                        const Color(0xFF1E1033).withValues(alpha: 0.75),
                        const Color(0xFF1E1033).withValues(alpha: 0.65),
                        const Color(0xFF0A0A0A).withValues(alpha: 0.55),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Centered anonymized silhouette
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Silhouette circle with mask
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF7C3AED).withValues(alpha: 0.6),
                        const Color(0xFFF97316).withValues(alpha: 0.6),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 44,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 2),
                      Icon(
                        Icons.visibility_off_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // "Identidad Protegida" text
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        size: 16,
                        color: const Color(0xFFD8B4FE).withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Identidad Protegida',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD8B4FE),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Purple left border accent ──
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF7C3AED),
                    Color(0xFFF97316),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom gradient ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 420,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF1E1033).withValues(alpha: 0.6),
                    const Color(0xFF1E1033).withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // ── Right side actions ──
          Positioned(
            right: AppSpacing.md,
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stealth avatar with glassmorphism
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF7C3AED),
                        Color(0xFFF97316),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.visibility_off_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Like (thumb up)
                _EngagementButton(
                  icon: _isLiked
                      ? Icons.thumb_up_rounded
                      : Icons.thumb_up_outlined,
                  label: _isLiked ? '1' : '—',
                  color: _isLiked
                      ? MployaColors.orange
                      : MployaColors.white,
                  onTap: _handleLike,
                  scaleAnimation: _likeScaleAnim,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Video Reply
                _EngagementButton(
                  icon: Icons.videocam_rounded,
                  label: 'Reply',
                  color: MployaColors.white,
                  onTap: () => context.push('/video/reply?name=${widget.item.name}'),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Bookmark
                _EngagementButton(
                  icon: _isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  label: _isSaved ? 'Guardado' : 'Guardar',
                  color: _isSaved
                      ? MployaColors.orange
                      : MployaColors.white,
                  onTap: _handleSave,
                  scaleAnimation: _saveScaleAnim,
                  labelFontSize: 10,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Share
                _EngagementButton(
                  icon: Icons.send_rounded,
                  label: '—',
                  color: Colors.white.withValues(alpha: 0.4),
                  onTap: _showShareSheet,
                ),
              ],
            ).animate().slideX(
                  begin: 0.3,
                  duration: 400.ms,
                  curve: Curves.easeOut,
                ),
          ),

          // ── Bottom left info (stealth variant) ──
          Positioned(
            left: AppSpacing.md,
            right: 80,
            bottom: AppSpacing.xxl + 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Headline
                Text(
                  item.headlineText,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: MployaColors.white,
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),

                // Hashtag chips
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: item.hashtags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Name + Confidential badge row
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Stealth · ${item.stealthTitle}',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: MployaColors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Confidential pill badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        '🔒 Confidencial',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD8B4FE),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // Match badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFF97316)],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Match ${item.matchPercent}%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MployaColors.white,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // Role (anonymized)
                Text(
                  '${item.role} · ${item.company}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(
                  begin: 0.1,
                  curve: Curves.easeOut,
                ),
          ),

          // ── Bottom premium unlock banner ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => _showPremiumDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.85),
                  border: Border(
                    top: BorderSide(
                      color: const Color(0xFFD8B4FE).withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '🔓',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Desbloquear Candidato',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 500.ms).slideY(
                  begin: 0.3,
                  end: 0,
                  curve: Curves.easeOut,
                ),
          ),
        ],
      ),
    );
  }

  void _showPremiumDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(
          'Perfil Premium 👑',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Para ver la identidad de este candidato confidencial necesitás Mploya Premium.\n\n'
          '💎 USD 99/mes\n\n'
          '✅ Ver candidatos confidenciales\n'
          '✅ Matches ilimitados\n'
          '✅ Chat prioritario',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Ahora no',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) {
                context.push(
                  '/payment',
                  extra: const PaymentProduct(
                    name: 'Mploya Premium',
                    description: 'Ver candidatos confidenciales, matches ilimitados, chat prioritario.',
                    price: 99.00,
                    duration: 'Mensual',
                    icon: Icons.workspace_premium_rounded,
                    color: Color(0xFF7C3AED),
                  ),
                );
              }
            },
            child: Text(
              'Suscribirme',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF7C3AED),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the normal (non-stealth) feed card
  Widget _buildNormalCard(BuildContext context, _FeedItem item) {
    return Container(
      color: item.bgColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video playback or placeholder ──
          if (widget.videoViewId != null && widget.videoBlobUrl != null)
            PlatformVideoPlayer(
              viewId: '${widget.videoViewId!}-normal',
              url: widget.videoBlobUrl!,
              mirror: true,
            )
          else
            Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 80,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),

          // ── Bottom gradient ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 380,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // ── Right side actions ──
          Positioned(
            right: AppSpacing.md,
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar with verified dot
                GestureDetector(
                  onTap: () => context.push('/profile/user?id=${Uri.encodeComponent(widget.item.userId)}'),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: item.avatarColor,
                        child: Text(
                          item.initial,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: MployaColors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: MployaColors.teal,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: item.bgColor,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: MployaColors.white,
                            size: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Like button (thumb up) ──
                _EngagementButton(
                  icon: _isLiked
                      ? Icons.thumb_up_rounded
                      : Icons.thumb_up_outlined,
                  label: _formatCount(_likeCount),
                  color: _isLiked
                      ? MployaColors.orange
                      : MployaColors.white,
                  onTap: _handleLike,
                  scaleAnimation: _likeScaleAnim,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Video Reply button ──
                _EngagementButton(
                  icon: Icons.videocam_rounded,
                  label: 'Reply',
                  color: MployaColors.white,
                  onTap: () => context.push('/video/reply?name=${widget.item.name}'),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Bookmark button ──
                _EngagementButton(
                  icon: _isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  label: _isSaved ? 'Guardado' : 'Guardar',
                  color: _isSaved
                      ? MployaColors.orange
                      : MployaColors.white,
                  onTap: _handleSave,
                  scaleAnimation: _saveScaleAnim,
                  labelFontSize: 10,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Share button ──
                _EngagementButton(
                  icon: Icons.send_rounded,
                  label: _formatCount(_shareCount),
                  color: MployaColors.white,
                  onTap: _showShareSheet,
                ),
              ],
            ).animate().slideX(
                  begin: 0.3,
                  duration: 400.ms,
                  curve: Curves.easeOut,
                ),
          ),

          // ── Bottom left info ──
          Positioned(
            left: AppSpacing.md,
            right: 80,
            bottom: AppSpacing.xxl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Headline text
                Text(
                  item.headlineText,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: MployaColors.white,
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),

                // Hashtag chips
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: item.hashtags
                      .map(
                        (tag) => GestureDetector(
                          onTap: () {
                            final cleanTag = tag.replaceFirst('#', '');
                            context.push('/hashtags/detail?tag=$cleanTag');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: MployaColors.white,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Name
                Text(
                  item.name,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: MployaColors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // Match badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: MployaColors.orangeGradient,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Match ${item.matchPercent}%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MployaColors.white,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // Role + company
                Text(
                  '${item.role} · ${item.company}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(
                  begin: 0.1,
                  curve: Curves.easeOut,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Engagement button with icon + counter label ─────────────────────

class _EngagementButton extends StatelessWidget {
  const _EngagementButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.scaleAnimation,
    this.labelFontSize = 11,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Animation<double>? scaleAnimation;
  final double labelFontSize;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? MployaColors.white;

    Widget iconWidget = Icon(
      icon,
      color: effectiveColor,
      size: 28,
    );

    // Wrap with scale animation if provided
    if (scaleAnimation != null) {
      iconWidget = AnimatedBuilder(
        animation: scaleAnimation!,
        builder: (context, child) => Transform.scale(
          scale: scaleAnimation!.value,
          child: child,
        ),
        child: iconWidget,
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: labelFontSize,
                fontWeight: FontWeight.w500,
                color: effectiveColor.withValues(alpha: 0.85),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Comment Bottom Sheet ────────────────────────────────────────────

class _CommentSheet extends StatefulWidget {
  const _CommentSheet({
    required this.item,
    required this.commentCount,
  });

  final _FeedItem item;
  final int commentCount;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _commentController = TextEditingController();
  final _focusNode = FocusNode();

  // Mock comments
  static final _mockComments = [
    _MockComment('María G.', 'M', '¡Excelente presentación! 👏', '2h',
        const Color(0xFFEC4899)),
    _MockComment('Juan P.', 'J', 'Muy buena experiencia, me interesa.', '5h',
        const Color(0xFF3B82F6)),
    _MockComment('Ana R.', 'A', 'Increíble perfil, sigue así 🚀', '1d',
        const Color(0xFF10B981)),
  ];

  final List<_MockComment> _comments = List.from(_mockComments);

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _comments.insert(
        0,
        _MockComment('Tú', '✓', text, 'ahora', MployaColors.orange),
      );
    });
    _commentController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Handle bar ──
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ──
          Text(
            '${_comments.length} comentarios',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MployaColors.white,
            ),
          ),
          const SizedBox(height: 12),
          Divider(
            color: Colors.white.withValues(alpha: 0.1),
            height: 1,
          ),

          // ── Comments list ──
          Expanded(
            child: _comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Sé el primero en comentar',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: _comments.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: comment.color,
                            child: Text(
                              comment.initial,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: MployaColors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      comment.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: MployaColors.white,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      comment.time,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.white
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  comment.text,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.white
                                        .withValues(alpha: 0.85),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // ── Comment input ──
          Container(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.sm,
              top: AppSpacing.sm,
              bottom: max(bottomInset, AppSpacing.md),
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                // User avatar
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: MployaColors.orange,
                  child: Text(
                    '✓',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MployaColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Text field
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _focusNode,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MployaColors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Agregar un comentario...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                // Send button
                GestureDetector(
                  onTap: _submitComment,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: MployaColors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: MployaColors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mock Comment Model ──────────────────────────────────────────────

class _MockComment {
  const _MockComment(this.name, this.initial, this.text, this.time, this.color);
  final String name;
  final String initial;
  final String text;
  final String time;
  final Color color;
}

// ─── Share option tile ───────────────────────────────────────────────

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final textColor = isDestructive
        ? const Color(0xFFEF4444)
        : MployaColors.white;
    return ListTile(
      leading: Icon(icon, color: textColor, size: 22),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
           color: textColor,
         ),
       ),
       onTap: onTap,
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(12),
       ),
     );
   }
 }

// ─── Notification Tile ─────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  const _NotifTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
