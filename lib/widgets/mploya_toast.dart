import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MployaToast — Sistema global de feedback visual no intrusivo
//
// Uso:
//   MployaToast.show(context, message: 'Trabajo guardado', icon: CupertinoIcons.bookmark_fill);
//   MployaToast.success(context, 'Aplicación enviada');
//   MployaToast.error(context, 'Error al conectar');
//   MployaToast.info(context, 'Video-Pitch subido');
// ─────────────────────────────────────────────────────────────────────────────

class MployaToast {
  MployaToast._();

  /// Toast genérico con ícono personalizable
  static void show(
    BuildContext context, {
    required String message,
    IconData icon = CupertinoIcons.checkmark_circle_fill,
    Color? iconColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        icon: icon,
        iconColor: iconColor ?? MployaTheme.brandAccent,
        duration: duration,
      ),
    );
    overlay.insert(entry);
    Future.delayed(duration + const Duration(milliseconds: 400), () {
      entry.remove();
    });
  }

  /// Toast de éxito (verde)
  static void success(BuildContext context, String message) {
    show(
      context,
      message: message,
      icon: CupertinoIcons.checkmark_circle_fill,
      iconColor: const Color(0xFF057642),
    );
  }

  /// Toast de error (rojo)
  static void error(BuildContext context, String message) {
    show(
      context,
      message: message,
      icon: CupertinoIcons.exclamationmark_circle_fill,
      iconColor: MployaTheme.danger,
    );
  }

  /// Toast informativo (brand accent)
  static void info(BuildContext context, String message) {
    show(
      context,
      message: message,
      icon: CupertinoIcons.info_circle_fill,
      iconColor: MployaTheme.brandAccent,
    );
  }

  /// Toast para acción de guardar (bookmark)
  static void saved(BuildContext context, String message) {
    show(
      context,
      message: message,
      icon: CupertinoIcons.bookmark_fill,
      iconColor: MployaTheme.brandAccent,
    );
  }

  /// Toast para acción de eliminar
  static void removed(BuildContext context, String message) {
    show(
      context,
      message: message,
      icon: CupertinoIcons.trash_fill,
      iconColor: MployaTheme.danger,
    );
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Duration duration;

  const _ToastWidget({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.duration,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Auto-dismiss
    Future.delayed(widget.duration, () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPad + 8,
      left: 24,
      right: 24,
      child: Semantics(
        liveRegion: true,
        label: widget.message,
        child: SlideTransition(
          position: _slideAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: context.isDark
                    ? const Color(0xF01C1C1E)
                    : const Color(0xF0FFFFFF),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: context.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Icon(widget.icon, size: 22, color: widget.iconColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
