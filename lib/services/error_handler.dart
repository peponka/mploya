import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

// ─────────────────────────────────────────────────────────────────────────────
// MployaErrorHandler — Manejo centralizado de errores de la app.
//
// Provee:
//  • showError()       — Toast elegante con blur para errores no-fatales
//  • showSuccess()     — Toast de éxito
//  • wrapAsync()       — Try/catch wrapper que muestra error automático
//  • handleSupabase()  — Traduce errores de Supabase a mensajes amigables
// ─────────────────────────────────────────────────────────────────────────────

class MployaErrorHandler {
  MployaErrorHandler._();
  static final MployaErrorHandler instance = MployaErrorHandler._();

  /// Muestra un toast flotante de error con blur glass.
  void showError(BuildContext context, String message) {
    _showToast(context, message, isError: true);
  }

  /// Muestra un toast flotante de éxito.
  void showSuccess(BuildContext context, String message) {
    _showToast(context, message, isError: false);
  }

  /// Envuelve un Future con manejo automático de errores.
  /// Si falla, muestra un toast de error y retorna null.
  Future<T?> wrapAsync<T>(
    BuildContext context,
    Future<T> Function() action, {
    String? errorMessage,
    String? successMessage,
  }) async {
    try {
      final result = await action();
      if (successMessage != null && context.mounted) {
        showSuccess(context, successMessage);
      }
      return result;
    } catch (e) {
      if (context.mounted) {
        final friendly = errorMessage ?? handleSupabase(e);
        showError(context, friendly);
      }
      return null;
    }
  }

  /// Traduce errores comunes de Supabase a mensajes amigables en español.
  String handleSupabase(Object error) {
    final msg = error.toString().toLowerCase();

    if (msg.contains('pgrst301') || msg.contains('jwt')) {
      return 'Tu sesión expiró. Reiniciá la app.';
    }
    if (msg.contains('42501') || msg.contains('rls') || msg.contains('policy')) {
      return 'No tenés permiso para esta acción.';
    }
    if (msg.contains('23505') || msg.contains('duplicate')) {
      return 'Este registro ya existe.';
    }
    if (msg.contains('23503') || msg.contains('foreign key')) {
      return 'Referencia no encontrada en la base de datos.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'La conexión tardó demasiado. Intentá de nuevo.';
    }
    if (msg.contains('socket') || msg.contains('network') || msg.contains('connection')) {
      return 'Sin conexión a Internet. Verificá tu red.';
    }
    if (msg.contains('storage') || msg.contains('bucket')) {
      return 'Error al subir el archivo. Intentá de nuevo.';
    }
    if (msg.contains('email') && msg.contains('already')) {
      return 'Este email ya está registrado.';
    }

    return 'Algo salió mal. Intentá de nuevo.';
  }

  void _showToast(BuildContext context, String message, {required bool isError}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        isError: isError,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _opacity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.isError
                      ? const Color(0xE6FF3B30).withValues(alpha: 0.85)
                      : const Color(0xE634C759).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.isError
                          ? CupertinoIcons.exclamationmark_triangle_fill
                          : CupertinoIcons.checkmark_circle_fill,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: '.SF Pro Text',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
