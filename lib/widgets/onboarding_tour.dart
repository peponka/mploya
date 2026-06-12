import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OnboardingTourOverlay — Guía premium de primera vez para nuevos usuarios
//
// Features:
//  • 7 steps con animaciones únicas por step
//  • Floating particles animadas con gradientes
//  • Progreso guardado por step (retoma donde dejó si cierra la app)
//  • Swipe horizontal para navegar entre steps
//  • Parallax micro-animations en emoji/título
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingTourOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingTourOverlay({super.key, required this.onComplete});

  /// Muestra el tour solo la primera vez. Retorna true si se mostró.
  static Future<bool> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_tour_seen') ?? false;
    if (seen) return false;

    if (!context.mounted) return false;

    await showCupertinoModalPopup(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OnboardingTourOverlay(
        onComplete: () {
          prefs.setBool('onboarding_tour_seen', true);
          prefs.remove('onboarding_tour_step'); // Clean up
          Navigator.of(ctx).pop();
        },
      ),
    );
    return true;
  }

  @override
  State<OnboardingTourOverlay> createState() => _OnboardingTourOverlayState();
}

class _OnboardingTourOverlayState extends State<OnboardingTourOverlay>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _fadeController;
  late AnimationController _floatController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _pulseAnim;
  late PageController _pageController;

  static const _steps = [
    _TourStep(
      icon: CupertinoIcons.videocam_fill,
      emoji: '🎬',
      title: 'Tu Video-Pitch de 60"',
      description:
          'Grabá un video corto contando quién sos y qué buscás. Las empresas te descubren por tu pitch, no por un PDF.',
      gradient: [Color(0xFF5F3DC4), Color(0xFFAE3EC9)],
      tip: 'Los perfiles con video reciben 3x más visitas',
    ),
    _TourStep(
      icon: CupertinoIcons.bolt_fill,
      emoji: '⚡',
      title: 'Doble-Tap = Interés',
      description:
          'Tocá dos veces un video que te interese. Si el otro también lo hace, ¡hacen Match! y se desbloquea el chat directo.',
      gradient: [NexTheme.brandAccent, NexTheme.premiumEnd],
      tip: 'Funciona como Tinder pero para trabajo',
    ),
    _TourStep(
      icon: CupertinoIcons.number,
      emoji: '🏷️',
      title: 'Hashtags Inteligentes',
      description:
          'Cada perfil tiene hashtags (#marketing, #fintech, #remoto). Tocá cualquiera para descubrir candidatos con las mismas habilidades.',
      gradient: [Color(0xFF1565C0), Color(0xFF42A5F5)],
      tip: 'Las empresas buscan talento por hashtags',
    ),
    _TourStep(
      icon: CupertinoIcons.arrow_right_arrow_left,
      emoji: '🤝',
      title: 'Conectá y Chateá',
      description:
          'Enviá solicitudes de conexión. Una vez aceptadas, chateá directamente para coordinar entrevistas o cerrar propuestas.',
      gradient: [Color(0xFF00897B), Color(0xFF26A69A)],
      tip: 'Sin intermediarios, todo dentro de Mploya',
    ),
    _TourStep(
      icon: CupertinoIcons.map_fill,
      emoji: '🗺️',
      title: 'Mapa Explore',
      description:
          'Descubrí talento cerca tuyo con el mapa GPS interactivo. Filtrá por ubicación, industria y hashtags.',
      gradient: [Color(0xFF0077B6), Color(0xFF00B4D8)],
      tip: 'Ideal para empresas buscando talento local',
    ),
    _TourStep(
      icon: CupertinoIcons.flame_fill,
      emoji: '🔥',
      title: 'Trending & Descubrimiento',
      description:
          'Explorá los hashtags más populares y descubrí talento por tendencias. El algoritmo aprende tus preferencias para mostrarte los mejores perfiles.',
      gradient: [Color(0xFFE65100), Color(0xFFFF6D00)],
      tip: 'El feed se adapta a ti con cada interacción',
    ),
    _TourStep(
      icon: CupertinoIcons.shield_fill,
      emoji: '🔒',
      title: 'Modo Confidencial',
      description:
          'Protegé tu identidad activando el modo Stealth. Las empresas ven tu pitch y skills, pero tu nombre queda oculto hasta hacer match.',
      gradient: [Color(0xFFB8860B), Color(0xFFDAA520)],
      tip: 'Perfecto si estás en búsqueda activa sin que se entere tu empresa actual',
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Fade + Scale for content transitions
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutBack),
    );

    // Floating animation for emoji
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Pulse animation for glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pageController = PageController();
    _loadSavedStep();
    _fadeController.forward();
  }

  Future<void> _loadSavedStep() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('onboarding_tour_step') ?? 0;
    if (saved > 0 && saved < _steps.length && mounted) {
      setState(() => _currentStep = saved);
      _pageController = PageController(initialPage: saved);
    }
  }

  Future<void> _saveStep(int step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('onboarding_tour_step', step);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    _fadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _currentStep = step);
      _saveStep(step);
      _fadeController.forward();
    });
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      _goToStep(_currentStep + 1);
    } else {
      widget.onComplete();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  void _skip() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;
    final isFirst = _currentStep == 0;

    return Material(
      color: Colors.black,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < -100) _nextStep();
          if (details.primaryVelocity! > 100) _prevStep();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black,
                step.gradient.first.withValues(alpha: 0.18),
                step.gradient.last.withValues(alpha: 0.08),
                Colors.black,
              ],
              stops: const [0.0, 0.35, 0.65, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // ── Floating Particles ──
              ..._buildParticles(step),

              // ── Content ──
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 2),

                          // ── Animated Icon with Glow ──
                          AnimatedBuilder(
                            animation: Listenable.merge([_floatAnim, _pulseAnim]),
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _floatAnim.value),
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        step.gradient.first.withValues(alpha: 0.25),
                                        step.gradient.last.withValues(alpha: 0.15),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: step.gradient.first.withValues(alpha: _pulseAnim.value),
                                        blurRadius: 50,
                                        spreadRadius: 15,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Icon
                                        Icon(
                                          step.icon,
                                          size: 42,
                                          color: Colors.white.withValues(alpha: 0.9),
                                        ),
                                        // Emoji overlay
                                        Positioned(
                                          right: 18,
                                          top: 18,
                                          child: Text(
                                            step.emoji,
                                            style: const TextStyle(fontSize: 28),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 40),

                          // ── Title ──
                          Text(
                            step.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              height: 1.1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),

                          // ── Description ──
                          Text(
                            step.description,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 16,
                              height: 1.55,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // ── Pro Tip Card ──
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            decoration: BoxDecoration(
                              color: step.gradient.first.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: step.gradient.first.withValues(alpha: 0.25),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: step.gradient),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text('💡', style: TextStyle(fontSize: 14)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    step.tip,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 36),

                          // ── Progress Bar (continuous) ──
                          _buildProgressBar(step),

                          const SizedBox(height: 8),
                          Text(
                            '${_currentStep + 1} de ${_steps.length}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const Spacer(),

                          // ── Action Buttons ──
                          Row(
                            children: [
                              // Back button
                              if (!isFirst)
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: _prevStep,
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.back,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              if (!isFirst) const SizedBox(width: 12),

                              // Main CTA
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: step.gradient),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: step.gradient.first.withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: CupertinoButton(
                                    borderRadius: BorderRadius.circular(16),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    onPressed: _nextStep,
                                    child: Text(
                                      isLast ? '🚀 ¡Comenzar!' : 'Siguiente →',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Skip
                          if (!isLast)
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              onPressed: _skip,
                              child: Text(
                                'Saltar tour',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                          const SizedBox(height: 40),
                        ],
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

  /// Continuous progress bar instead of dots.
  Widget _buildProgressBar(_TourStep step) {
    final progress = (_currentStep + 1) / _steps.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 4,
        width: double.infinity,
        child: Stack(
          children: [
            Container(color: Colors.white.withValues(alpha: 0.1)),
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              widthFactor: progress,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: step.gradient),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generates floating particle decorations themed to the current step.
  List<Widget> _buildParticles(_TourStep step) {
    final particles = <Widget>[];
    final rng = Random(_currentStep * 42); // Deterministic per step

    for (int i = 0; i < 8; i++) {
      final x = rng.nextDouble();
      final y = rng.nextDouble();
      final size = 4.0 + rng.nextDouble() * 12;
      final opacity = 0.03 + rng.nextDouble() * 0.08;

      particles.add(
        AnimatedBuilder(
          animation: _floatAnim,
          builder: (context, child) {
            return Positioned(
              left: x * MediaQuery.of(context).size.width,
              top: y * MediaQuery.of(context).size.height +
                  _floatAnim.value * (i.isEven ? 1 : -1),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      step.gradient.first.withValues(alpha: opacity),
                      step.gradient.last.withValues(alpha: opacity * 0.5),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
      );
    }

    return particles;
  }
}

class _TourStep {
  final IconData icon;
  final String emoji;
  final String title;
  final String description;
  final List<Color> gradient;
  final String tip;

  const _TourStep({
    required this.icon,
    required this.emoji,
    required this.title,
    required this.description,
    required this.gradient,
    required this.tip,
  });
}
