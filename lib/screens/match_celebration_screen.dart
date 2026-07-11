import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/nex_avatar.dart';
import 'profile_screen.dart';

/// Pantalla de celebración "¡Nuevo Match!" (render #3).
///
/// Fondo naranja full, avatar grande, mensaje de compatibilidad y CTA para
/// revisar el perfil completo. Se muestra cuando hay un match/interés mutuo.
class MatchCelebrationScreen extends StatefulWidget {
  final NexUser user;
  final int? matchPct;

  const MatchCelebrationScreen({super.key, required this.user, this.matchPct});

  /// Helper para lanzarla como overlay a pantalla completa.
  static Future<void> show(BuildContext context, NexUser user, {int? matchPct}) {
    HapticFeedback.mediumImpact();
    return Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => MatchCelebrationScreen(user: user, matchPct: matchPct),
      ),
    );
  }

  @override
  State<MatchCelebrationScreen> createState() => _MatchCelebrationScreenState();
}

class _MatchCelebrationScreenState extends State<MatchCelebrationScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.user.name.trim().split(RegExp(r'\s+')).first;
    return CupertinoPageScaffold(
      backgroundColor: MployaTheme.brandAccent,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 4, right: 4,
              child: CupertinoButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 24),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ScaleTransition(
                  scale: CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                        child: const Icon(CupertinoIcons.bolt_fill, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 22),
                      const Text('¡Nuevo Match!', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 28),
                      // Avatar grande con anillo blanco
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10))],
                        ),
                        child: NexAvatar(user: widget.user, size: 116),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Tu perfil es compatible con $firstName',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, height: 1.4),
                      ),
                      if (widget.matchPct != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 15),
                            const SizedBox(width: 6),
                            Text('${widget.matchPct}% de compatibilidad', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 34),
                      // CTA blanco
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: widget.user)));
                        },
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                          child: const Text('Revisar perfil completo', style: TextStyle(color: Color(0xFF9A3412), fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      CupertinoButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Seguir explorando', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
