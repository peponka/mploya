/// Pantalla de splash de mploya.ai
///
/// Muestra el logo animado y después navega al landing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mploya/config/theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future<void>.delayed(AnimDurations.splash);
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.white,
      body: Center(
        child: const MployaLogo(size: 100)
            .animate()
            .fadeIn(duration: 800.ms, curve: Curves.easeOut)
            .scale(
              begin: const Offset(0.7, 0.7),
              end: const Offset(1, 1),
              duration: 800.ms,
              curve: Curves.easeOutBack,
            ),
      ),
    );
  }
}
