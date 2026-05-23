/// Pantalla de perfil del usuario con 3 tabs.
///
/// Header: avatar, badges, stats. Tabs: Sobre mí, Portfolio, Herramientas.
/// Cada tab tiene contenido completamente diferente según el diseño original.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/features/auth/models/user_model.dart';
import 'package:mploya/features/auth/providers/auth_provider.dart';

// ─── Default hashtags ────────────────────────────────────────────────

const _defaultHashtags = [
  ('#flutter', 9),
  ('#react', 3),
];

class _PortfolioVideo {
  const _PortfolioVideo({
    required this.title,
    required this.duration,
    required this.views,
    required this.likes,
  });
  final String title;
  final String duration;
  final int views;
  final int likes;
}

final _defaultPortfolioVideos = [
  const _PortfolioVideo(
    title: 'Mi presentación',
    duration: '30s',
    views: 12,
    likes: 3,
  ),
  const _PortfolioVideo(
    title: 'Proyecto Flutter',
    duration: '30s',
    views: 8,
    likes: 1,
  ),
];

// ─── Profile Screen ──────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;

  // ── Profile data from provider ──
  UserProfile? get _profile => ref.watch(currentProfileProvider);
  String get _userName => _profile?.displayName ?? 'Usuario';
  String get _userInitial => _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U';
  String get _userHeadline => _profile?.headline ?? 'Profesional';
  int get _connections => 1;
  int get _views => 0;
  int get _matches => 0;
  late final List<_PortfolioVideo> _portfolioVideos =
      List.of(_defaultPortfolioVideos);

  // ── Personality analysis state ──
  // 0 = not started, 1 = loading, 2 = done
  int _analysisState = 0;
  late AnimationController _scoreAnimController;
  late Animation<double> _scoreAnim;

  // ── Mutable hashtags ──
  late final List<(String, int)> _hashtags =
      List.of(_defaultHashtags);



  @override
  void initState() {
    super.initState();
    _scoreAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnim = Tween<double>(begin: 0, end: 92).animate(
      CurvedAnimation(
        parent: _scoreAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _scoreAnimController.dispose();
    super.dispose();
  }

  Future<void> _runPersonalityAnalysis() async {
    if (_analysisState != 0) return;
    setState(() => _analysisState = 1);
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    setState(() => _analysisState = 2);
    _scoreAnimController.forward();
  }

  static const _tabIcons = [
    Icons.person_outlined,
    Icons.play_circle_outline,
    Icons.auto_awesome_outlined,
  ];

  static const _tabLabels = ['Sobre mí', 'Portfolio', 'Herramientas'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),

              // ── Avatar ──
              _buildAvatar()
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(begin: const Offset(0.9, 0.9)),

              const SizedBox(height: AppSpacing.md),

              // ── Name ──
              Text(
                _userName,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: MployaColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),

              // ── Role ──
              Text(
                _userHeadline,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MployaColors.textSecondary,
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Badges ──
              _buildBadges()
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms),

              const SizedBox(height: AppSpacing.md),

              // ── Action buttons ──
              _buildActionButtons()
                  .animate()
                  .fadeIn(delay: 150.ms, duration: 400.ms),

              const SizedBox(height: AppSpacing.lg),

              // ── Stats ──
              _buildStats()
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms),

              const SizedBox(height: AppSpacing.lg),

              // ── Tab selector ──
              _buildTabs()
                  .animate()
                  .fadeIn(delay: 250.ms, duration: 400.ms),

              const SizedBox(height: AppSpacing.xl),

              // ── Tab content ──
              AnimatedSwitcher(
                duration: AnimDurations.normal,
                child: _buildTabContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Avatar with camera overlay ────────────────────────────────────

  Widget _buildAvatar() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: MployaColors.orange,
            child: Text(
              _userInitial,
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: MployaColors.white,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: MployaColors.teal,
                shape: BoxShape.circle,
                border: Border.all(color: MployaColors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: MployaColors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Badges row ────────────────────────────────────────────────────

  Widget _buildBadges() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Verified badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: MployaColors.teal),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  color: MployaColors.teal, size: 14),
              const SizedBox(width: 4),
              Text(
                'Verificado',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MployaColors.teal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Active badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: MployaColors.orange),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: MployaColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Activo',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MployaColors.orange,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Action buttons ────────────────────────────────────────────────

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.go('/profile/edit'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: MployaColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              icon: const Icon(
                Icons.edit,
                size: 16,
                color: MployaColors.textPrimary,
              ),
              label: Text(
                'Editar perfil',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MployaColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.push('/tools/ai-resume'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: MployaColors.orange),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              icon: const Icon(
                Icons.auto_awesome,
                size: 16,
                color: MployaColors.orange,
              ),
              label: Text(
                'Bio con IA',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MployaColors.orange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats row ─────────────────────────────────────────────────────

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _StatColumn(
              value: '$_connections',
              label: 'Conexiones',
            ),
            const VerticalDivider(
              color: MployaColors.borderLight,
              width: AppSpacing.xl,
              thickness: 1,
            ),
            _StatColumn(
              value: '$_views',
              label: 'Vistas',
            ),
            const VerticalDivider(
              color: MployaColors.borderLight,
              width: AppSpacing.xl,
              thickness: 1,
            ),
            _StatColumn(
              value: '$_matches',
              label: 'Matches',
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tabs ──────────────────────────────────────────────────────────

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: List.generate(_tabLabels.length, (i) {
          final isSelected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(
                  right: i < _tabLabels.length - 1 ? AppSpacing.sm : 0,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:
                      isSelected ? MployaColors.orange : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: isSelected
                        ? MployaColors.orange
                        : MployaColors.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _tabIcons[i],
                      size: 16,
                      color: isSelected
                          ? MployaColors.white
                          : MployaColors.textPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _tabLabels[i],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? MployaColors.white
                            : MployaColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Tab Content Router ────────────────────────────────────────────

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildSobreMi();
      case 1:
        return _buildPortfolio();
      case 2:
        return _buildHerramientas();
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 1: SOBRE MÍ
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSobreMi() {
    return Column(
      key: const ValueKey('sobre_mi'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildVideoPitch(),
        const SizedBox(height: AppSpacing.xl),
        _buildAIAnalysis(),
        const SizedBox(height: AppSpacing.xl),
        _buildHashtags(),
      ],
    );
  }

  Widget _buildVideoPitch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Video-Pitch',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MployaColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/onboarding/video'),
                child: Text(
                  'Grabar nuevo',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Dark video card
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Stack(
              children: [
                // Center play
                const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    size: 56,
                    color: Colors.white38,
                  ),
                ),
                // Top left: Video tag
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Video',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MployaColors.white,
                      ),
                    ),
                  ),
                ),
                // Top right: points badge
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: MployaColors.orangeGradient,
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '92 pts',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: MployaColors.white,
                      ),
                    ),
                  ),
                ),
                // Top right: 3-dot menu
                Positioned(
                  top: AppSpacing.sm + 28,
                  right: AppSpacing.sm,
                  child: GestureDetector(
                    onTap: () async {
                      final result = await showMenu<String>(
                        context: context,
                        position: const RelativeRect.fromLTRB(1000, 120, 16, 0),
                        items: [
                          const PopupMenuItem(value: 'share', child: Text('Compartir perfil')),
                          const PopupMenuItem(value: 'settings', child: Text('Configuración')),
                        ],
                      );
                      if (!mounted || result == null) return;
                      if (result == 'settings') {
                        context.push('/settings');
                      } else if (result == 'share') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link de perfil copiado 📋')),
                        );
                      }
                    },
                    child: Icon(
                      Icons.more_vert,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 22,
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

  Widget _buildAIAnalysis() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: MployaColors.orange,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Análisis de Personalidad IA',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MployaColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Soft skills analizadas por Gemini',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MployaColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── State-based content ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _analysisState == 0
                ? _buildAnalysisInitial()
                : _analysisState == 1
                    ? _buildAnalysisLoading()
                    : _buildAnalysisResults(),
          ),
        ],
      ),
    );
  }

  /// Initial state: CTA button to start analysis
  Widget _buildAnalysisInitial() {
    return Container(
      key: const ValueKey('analysis_initial'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: MployaColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: MployaColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_outlined,
              color: Color(0xFF8B5CF6),
              size: 32,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Descubrí tu perfil de personalidad',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MployaColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Nuestra IA analiza tu video-pitch para detectar tus soft skills más fuertes',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MployaColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          GestureDetector(
            onTap: _runPersonalityAnalysis,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFA78BFA), Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, color: MployaColors.white, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Analizar mi Personalidad',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MployaColors.white,
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

  /// Loading state: pulsing animation while analyzing
  Widget _buildAnalysisLoading() {
    return Container(
      key: const ValueKey('analysis_loading'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: MployaColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: MployaColors.borderLight),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF8B5CF6).withValues(alpha: 0.6),
                    ),
                    backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  ),
                ),
                const Icon(Icons.psychology, color: Color(0xFF8B5CF6), size: 32),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 1500.ms,
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
              ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Analizando tu personalidad...',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MployaColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Gemini está evaluando tus soft skills',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MployaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Results state: animated score circle + skill bars
  Widget _buildAnalysisResults() {
    const skills = [
      ('🗣', 'Comunicación', 85),
      ('👑', 'Liderazgo', 78),
      ('⚡', 'Energía', 90),
      ('😻', 'Empatía', 82),
    ];

    return Container(
      key: const ValueKey('analysis_results'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MployaColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: MployaColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row: badge + animated score circle
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: const Color(0xFF8B5CF6)),
                      ),
                      child: Text(
                        'Empático Comunicador',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Tu perfil destaca en soft skills de comunicación y empatía',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MployaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Animated score circle
              AnimatedBuilder(
                animation: _scoreAnim,
                builder: (context, child) {
                  return SizedBox(
                    width: 72,
                    height: 72,
                    child: CustomPaint(
                      painter: _ScoreCirclePainter(
                        score: _scoreAnim.value,
                        maxScore: 100,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_scoreAnim.value.toInt()}',
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: MployaColors.orange,
                              ),
                            ),
                            Text(
                              'pts',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: MployaColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Skill bars with staggered animations
          ...List.generate(skills.length, (i) {
            final s = skills[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Text(s.$1, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.$2,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: MployaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: SizedBox(
                            height: 8,
                            child: Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  color: const Color(0xFFF3F4F6),
                                ),
                                FractionallySizedBox(
                                  widthFactor: s.$3 / 100.0,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFFA78BFA),
                                          Color(0xFF8B5CF6),
                                          Color(0xFF7C3AED),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${s.$3}',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MployaColors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: (200 + i * 100).ms, duration: 400.ms)
                .slideX(begin: 0.05, end: 0);
          }),

          const SizedBox(height: AppSpacing.sm),

          // "Ver Análisis" button (post-analysis)
          GestureDetector(
            onTap: () => context.push('/profile/analysis'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: MployaColors.textPrimary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Center(
                child: Text(
                  'Ver Análisis',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildHashtags() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Hashtags',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MployaColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/hashtags/trending'),
                child: Text(
                  '🔥 Trending',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.orange,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              GestureDetector(
                onTap: () => context.push('/hashtags/edit'),
                child: Text(
                  'Editar',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ..._hashtags.map(
                (h) => GestureDetector(
                  onTap: () {
                    final name = h.$1.replaceAll('#', '');
                    context.push('/hashtags/detail?name=$name');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: MployaColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                      border:
                          Border.all(color: MployaColors.borderLight),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${h.$1} ${h.$2}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: MployaColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: MployaColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // + agregar pill
              GestureDetector(
                onTap: _showAddHashtagDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '+ agregar',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MployaColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddHashtagDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Agregar Hashtag',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MployaColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Escribí un hashtag para agregar a tu perfil',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MployaColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '#miHashtag',
                  prefixIcon: const Icon(Icons.tag, color: MployaColors.orange, size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: const BorderSide(color: MployaColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: const BorderSide(color: MployaColors.orange, width: 1.5),
                  ),
                ),
                style: GoogleFonts.inter(fontSize: 15),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: MployaColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MployaColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final text = controller.text.trim();
                        if (text.isNotEmpty) {
                          final tag = text.startsWith('#') ? text : '#$text';
                          setState(() => _hashtags.add((tag, 0)));
                          Navigator.pop(ctx);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: MployaColors.orangeGradient,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Center(
                          child: Text(
                            'Agregar',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: MployaColors.white,
                            ),
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
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 2: PORTFOLIO
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPortfolio() {
    return Column(
      key: const ValueKey('portfolio'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Portfolio header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Portfolio ${_portfolioVideos.length}/3',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MployaColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => _showAddVideoSheet(),
                child: Text(
                  '+ Agregar',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Video grid (2 columns)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.md,
            children: List.generate(_portfolioVideos.length, (i) {
              final v = _portfolioVideos[i];
              return SizedBox(
                width: (MediaQuery.of(context).size.width -
                        AppSpacing.md * 2 -
                        AppSpacing.sm) /
                    2,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Video thumbnail
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                        child: Stack(
                          children: [
                            // Play button
                            Center(
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: MployaColors.orange,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: MployaColors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            // Duration badge
                            Positioned(
                              bottom: AppSpacing.sm,
                              left: AppSpacing.sm,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black
                                      .withValues(alpha: 0.6),
                                  borderRadius:
                                      BorderRadius.circular(
                                          AppRadius.xs),
                                ),
                                child: Text(
                                  v.duration,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: MployaColors.white,
                                  ),
                                ),
                              ),
                            ),
                            // Close button
                            Positioned(
                              top: AppSpacing.sm,
                              right: AppSpacing.sm,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _portfolioVideos.removeAt(i);
                                  });
                                },
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: MployaColors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        v.title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: MployaColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.visibility_outlined,
                              size: 12,
                              color: MployaColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            '${v.views}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: MployaColors.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.favorite_outline,
                              size: 12,
                              color: MployaColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            '${v.likes}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: MployaColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
            }),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Skill Badges section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '✅ Skill Badges',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MployaColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/tools/skill-assessment'),
                    child: Text(
                      '+ Tomar Test',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MployaColors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Empty state
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 48,
                      color: MployaColors.textTertiary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Validá tus skills',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: MployaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tomá un rápido de 5 preguntas',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MployaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHerramientas() {
    const profileCompletionPercent = 83;
    const profileCompletionCount = 5;
    const profileCompletionTotal = 6;

    return Column(
      key: const ValueKey('herramientas'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── SECTION 1: PROGRESO ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PROGRESO',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MployaColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Perfil completo',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: MployaColors.textPrimary,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$profileCompletionPercent',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: MployaColors.orange,
                        ),
                      ),
                      Text(
                        ' %',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: MployaColors.orange,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '$profileCompletionCount de $profileCompletionTotal',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MployaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: const LinearProgressIndicator(
                  value: profileCompletionPercent / 100,
                  minHeight: 8,
                  backgroundColor: Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    MployaColors.orange,
                  ),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.05, end: 0),

        const SizedBox(height: AppSpacing.xl),

        // ── SECTION 2: Herramientas IA ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🤖', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Herramientas IA',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MployaColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF97316), Color(0xFF8B5CF6)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'PRO',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: MployaColors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Potenciá tu carrera con inteligencia artificial',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MployaColors.textSecondary,
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 100.ms, duration: 400.ms)
            .slideY(begin: 0.05, end: 0),

        const SizedBox(height: AppSpacing.md),

        // ── Card 1: Skill Assessment (full width, large) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: GestureDetector(
            onTap: () => context.push('/tools/skill-assessment'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Left icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: MployaColors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Skill Assessment',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: MployaColors.white,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: MployaColors.orange,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                'NUEVO',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: MployaColors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Evaluá tus habilidades con IA y obtené un certificado verificable',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Right chevron circle
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: MployaColors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right,
                      color: MployaColors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .slideY(begin: 0.05, end: 0),

        const SizedBox(height: AppSpacing.sm),

        // ── Cards 2 & 3: Side by side ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              // Card 2: Interview Prep
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/tools/interview-prep'),
                  child: Container(
                    height: 150,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF97316).withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: MployaColors.white,
                            size: 20,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Interview\nPrep',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: MployaColors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Empezar >',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              // Card 3: CV con IA
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/tools/ai-resume'),
                  child: Container(
                    height: 150,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF047857)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            color: MployaColors.white,
                            size: 20,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'CV con IA',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: MployaColors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Empezar >',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 300.ms, duration: 400.ms)
            .slideY(begin: 0.05, end: 0),

        const SizedBox(height: AppSpacing.xl),

        // ── SECTION 3: Crecimiento ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'Crecimiento',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MployaColors.textPrimary,
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 400.ms, duration: 400.ms)
            .slideY(begin: 0.05, end: 0),

        const SizedBox(height: AppSpacing.md),

        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              _buildCrecimientoItem(
                icon: Icons.rocket_launch,
                label: 'Boost',
                bgColor: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFF97316),
                onTap: () => context.push('/tools/boost'),
              ),
              const SizedBox(width: AppSpacing.md),
              _buildCrecimientoItem(
                icon: Icons.local_fire_department,
                label: 'Challenge',
                bgColor: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFEF4444),
                onTap: () => context.push('/tools/pitch-challenge'),
              ),
              const SizedBox(width: AppSpacing.md),
              _buildCrecimientoItem(
                icon: Icons.visibility,
                label: 'Vistas',
                bgColor: const Color(0xFFDBEAFE),
                iconColor: const Color(0xFF3B82F6),
                onTap: () => context.push('/tools/vistas'),
              ),
              const SizedBox(width: AppSpacing.md),
              _buildCrecimientoItem(
                icon: Icons.bar_chart,
                label: 'Analytics',
                bgColor: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF8B5CF6),
                onTap: () => context.push('/tools/analytics'),
              ),
              const SizedBox(width: AppSpacing.md),
              _buildCrecimientoItem(
                icon: Icons.people,
                label: 'Invita',
                bgColor: const Color(0xFFD1FAE5),
                iconColor: const Color(0xFF10B981),
                onTap: () => context.push('/tools/invite'),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 500.ms, duration: 400.ms)
            .slideY(begin: 0.05, end: 0),

        const SizedBox(height: AppSpacing.xl),

        // ── SECTION 4: Cuenta ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cuenta',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MployaColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: MployaColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: MployaColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: MployaColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.settings,
                      color: MployaColors.textSecondary,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Configuración',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: MployaColors.textPrimary,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: MployaColors.textSecondary,
                    size: 22,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  onTap: () => context.push('/settings'),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 600.ms, duration: 400.ms)
            .slideY(begin: 0.05, end: 0),
      ],
    );
  }

  /// Helper for the Crecimiento horizontal scroll items.
  Widget _buildCrecimientoItem({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: MployaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Add Video Bottom Sheet ──────────────────────────────────────

  void _showAddVideoSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: MployaColors.borderLight,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                Text(
                  'Agregar video',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: MployaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: MployaColors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.videocam,
                      color: MployaColors.orange,
                    ),
                  ),
                  title: Text(
                    'Grabar video',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: MployaColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Grabá un nuevo video desde la cámara',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MployaColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: MployaColors.textTertiary,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addMockVideo('Video grabado');
                  },
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.upload_file,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  title: Text(
                    'Subir video',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: MployaColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Seleccioná un video de tu galería',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MployaColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: MployaColors.textTertiary,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addMockVideo('Video subido');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addMockVideo(String title) {
    setState(() {
      _portfolioVideos.add(_PortfolioVideo(
        title: title,
        duration: '30s',
        views: 0,
        likes: 0,
      ));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$title" agregado al portfolio'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        backgroundColor: MployaColors.teal,
      ),
    );
  }

}

// ─── Stat Column helper ──────────────────────────────────────────────

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: MployaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MployaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Score Circle Painter ────────────────────────────────────────────

class _ScoreCirclePainter extends CustomPainter {
  _ScoreCirclePainter({required this.score, required this.maxScore});
  final double score;
  final double maxScore;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Track
    final trackPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final sweepAngle = (score / maxScore) * 2 * math.pi;
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    // Gradient shader
    final rect = Rect.fromCircle(center: center, radius: radius);
    progressPaint.shader = const SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [
        Color(0xFFFB923C),
        Color(0xFFF97316),
        Color(0xFFEA580C),
      ],
    ).createShader(rect);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreCirclePainter oldDelegate) =>
      oldDelegate.score != score;
}
