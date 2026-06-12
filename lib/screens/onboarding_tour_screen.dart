import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../navigation/main_navigation.dart';
import '../l10n/app_strings.dart';

/// Premium onboarding tour — 5 slides, segmented by role (candidato / empresa).
/// White background, brand accent highlights, premium micro-animations.
///
/// v2: Added bounce animations, parallax icon movement, interactive demo hints,
///     animated progress bar, and haptic-like visual feedback.
class OnboardingTourScreen extends StatefulWidget {
  final String? accountType;

  const OnboardingTourScreen({super.key, this.accountType});

  static const String _prefKey = 'onboarding_tour_seen';

  static Future<bool> hasSeenTour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  static Future<void> markTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  @override
  State<OnboardingTourScreen> createState() => _OnboardingTourScreenState();
}

class _OnboardingTourScreenState extends State<OnboardingTourScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeController;
  late AnimationController _bounceController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnim;
  late Animation<double> _bounceAnim;
  late Animation<double> _pulseAnim;
  late List<_SlideData> _slides;

  // ── Role-specific slides ──────────────────────────────────────────────────

  static const _candidateSlides = [
    _SlideData(
      icon: CupertinoIcons.videocam_fill,
      title: AppStrings.tourCandidateTitle1,
      subtitle: AppStrings.tourCandidateBody1,
      accent: Color(0xFFFF6B35),
      secondaryIcon: CupertinoIcons.timer,
      proTip: 'Los perfiles con video reciben 3x más visitas',
      semanticLabel: 'Paso 1: Grabá tu video pitch de 60 segundos',
    ),
    _SlideData(
      icon: CupertinoIcons.bolt_fill,
      title: AppStrings.tourCandidateTitle2,
      subtitle: AppStrings.tourCandidateBody2,
      accent: Color(0xFF5F3DC4),
      secondaryIcon: CupertinoIcons.heart_fill,
      proTip: 'Funciona como Tinder pero para trabajo',
      semanticLabel: 'Paso 2: Hacé match con doble-tap',
    ),
    _SlideData(
      icon: CupertinoIcons.number,
      title: 'Hashtags Inteligentes',
      subtitle: 'Cada perfil tiene hashtags (#marketing, #fintech). Tocá cualquiera para descubrir profesionales con las mismas habilidades.',
      accent: Color(0xFF1565C0),
      secondaryIcon: CupertinoIcons.search,
      proTip: 'Las empresas buscan talento por hashtags',
      semanticLabel: 'Paso 3: Descubrí talento por hashtags',
    ),
    _SlideData(
      icon: CupertinoIcons.checkmark_seal_fill,
      title: AppStrings.tourCandidateTitle3,
      subtitle: AppStrings.tourCandidateBody3,
      accent: Color(0xFF057642),
      secondaryIcon: CupertinoIcons.star_fill,
      proTip: 'Los badges verificados multiplican tus chances',
      semanticLabel: 'Paso 4: Verificá tus habilidades con IA',
    ),
    _SlideData(
      icon: CupertinoIcons.rocket_fill,
      title: AppStrings.tourCandidateTitle4,
      subtitle: AppStrings.tourCandidateBody4,
      accent: Color(0xFFFF6B35),
      secondaryIcon: CupertinoIcons.sparkles,
      proTip: '¡Tu aventura profesional empieza ahora!',
      semanticLabel: 'Paso 5: Todo listo, empezá a conectar',
    ),
  ];

  static const _companySlides = [
    _SlideData(
      icon: CupertinoIcons.play_rectangle_fill,
      title: AppStrings.tourCompanyTitle1,
      subtitle: AppStrings.tourCompanyBody1,
      accent: Color(0xFFFF6B35),
      secondaryIcon: CupertinoIcons.hand_draw,
      proTip: 'Evaluá fit cultural en segundos, no en semanas',
      semanticLabel: 'Paso 1: Explorá candidatos en el feed de video',
    ),
    _SlideData(
      icon: CupertinoIcons.briefcase_fill,
      title: AppStrings.tourCompanyTitle2,
      subtitle: AppStrings.tourCompanyBody2,
      accent: Color(0xFF1565C0),
      secondaryIcon: CupertinoIcons.tag_fill,
      proTip: 'Publicá en 30 segundos con IA',
      semanticLabel: 'Paso 2: Publicá vacantes y recibí aplicaciones',
    ),
    _SlideData(
      icon: CupertinoIcons.number,
      title: 'Hashtags & Descubrimiento',
      subtitle: 'Buscá talento por hashtags trending. El algoritmo aprende tus preferencias para mostrarte los mejores candidatos.',
      accent: Color(0xFFE65100),
      secondaryIcon: CupertinoIcons.flame_fill,
      proTip: 'El feed se adapta a vos con cada interacción',
      semanticLabel: 'Paso 3: Descubrí talento por hashtags',
    ),
    _SlideData(
      icon: CupertinoIcons.shield_fill,
      title: AppStrings.tourCompanyTitle3,
      subtitle: AppStrings.tourCompanyBody3,
      accent: Color(0xFFB8860B),
      secondaryIcon: CupertinoIcons.lock_fill,
      proTip: 'Accedé a talento C-Level con identidad protegida',
      semanticLabel: 'Paso 4: Descubrí talento confidencial',
    ),
    _SlideData(
      icon: CupertinoIcons.rocket_fill,
      title: AppStrings.tourCompanyTitle4,
      subtitle: AppStrings.tourCompanyBody4,
      accent: Color(0xFFFF6B35),
      secondaryIcon: CupertinoIcons.sparkles,
      proTip: '¡Tu workspace de reclutamiento está listo!',
      semanticLabel: 'Paso 5: Tu workspace de reclutamiento está listo',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    // Bounce animation for icon
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: -12.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: -12.0, end: 0.0).chain(CurveTween(curve: Curves.bounceOut)), weight: 70),
    ]).animate(_bounceController);

    // Pulse animation for glow ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _bounceController.forward();

    // Determine role-based slides
    final type = widget.accountType?.toLowerCase() ?? '';
    _slides = (type == 'empresa' || type == 'ats' || type == 'headhunter')
        ? _companySlides
        : _candidateSlides;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _bounceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _finish() async {
    await OnboardingTourScreen.markTourSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    // Re-trigger bounce animation on page change
    _bounceController.reset();
    _bounceController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // ── Skip button ──
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
                  child: Semantics(
                    button: true,
                    label: 'Saltar tour de bienvenida',
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      onPressed: _finish,
                      child: Text(
                        isLast ? '' : 'Saltar',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Page content ──
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return _SlideView(
                      data: slide,
                      bounceAnim: _bounceAnim,
                      pulseAnim: _pulseAnim,
                      isActive: index == _currentPage,
                    );
                  },
                ),
              ),

              // ── Animated progress bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: _buildProgressBar(),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Paso ${_currentPage + 1} de ${_slides.length}',
                child: Text(
                  '${_currentPage + 1} de ${_slides.length}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFAEAEB2), fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 20),

              // ── CTA button ──
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: SizedBox(
                  width: double.infinity,
                  child: Semantics(
                    button: true,
                    label: isLast ? 'Empezar a usar Mploya' : 'Ir al siguiente paso',
                    child: CupertinoButton(
                      color: _slides[_currentPage].accent,
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      onPressed: _next,
                      child: Text(
                        isLast ? '🚀 ¡Empezar!' : 'Siguiente →',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: CupertinoColors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentPage + 1) / _slides.length;
    final accent = _slides[_currentPage].accent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 4,
        width: double.infinity,
        child: Stack(
          children: [
            Container(color: const Color(0xFFF2F2F7)),
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              widthFactor: progress,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Slide Data ──
class _SlideData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final IconData secondaryIcon;
  final String proTip;
  final String semanticLabel;

  const _SlideData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.secondaryIcon,
    required this.proTip,
    required this.semanticLabel,
  });
}

// ── Slide View with Premium Animations ──
class _SlideView extends StatelessWidget {
  final _SlideData data;
  final Animation<double> bounceAnim;
  final Animation<double> pulseAnim;
  final bool isActive;

  const _SlideView({
    required this.data,
    required this.bounceAnim,
    required this.pulseAnim,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: data.semanticLabel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Animated Icon Circle with Glow ──
            AnimatedBuilder(
              animation: Listenable.merge([bounceAnim, pulseAnim]),
              builder: (context, child) {
                final glowOpacity = 0.08 + (pulseAnim.value * 0.12);
                return Transform.translate(
                  offset: Offset(0, isActive ? bounceAnim.value : 0),
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: data.accent.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: data.accent.withValues(alpha: glowOpacity),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(data.icon, size: 52, color: data.accent),
                        // Secondary icon floating
                        Positioned(
                          right: 12,
                          top: 14,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: data.accent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(data.secondaryIcon, size: 16, color: data.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 44),

            // Title
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.8,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),

            // Subtitle
            Text(
              data.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6C6C70),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // ── Pro Tip Card ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: data.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: data.accent.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: data.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(CupertinoIcons.lightbulb_fill, size: 14, color: data.accent),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      data.proTip,
                      style: TextStyle(
                        color: data.accent.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
