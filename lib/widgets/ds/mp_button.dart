import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'mp_surface.dart';

/// Jerarquía de botones tal como aparece en FINAL_SCREENS.
enum MpButtonVariant {
  /// Relleno con el degradado de la superficie. Una sola por vista.
  /// → "Crear cuenta", "Iniciar sesión", "Elegir plan", "Activar ahora".
  primary,

  /// Contorno del color de acento, fondo transparente o tinte suave.
  /// → "Ver detalles", "Ver oferta", "Contactar ventas".
  outline,

  /// Superficie neutra con borde. Acción secundaria de igual peso visual.
  /// → "Continuar con Google", "Filtrar", "Este mes".
  neutral,

  /// Solo texto en color de acento.
  /// → "Ver todas", "Marcar todas como leídas", "¿Olvidaste tu contraseña?".
  ghost,
}

enum MpButtonSize {
  /// 52pt — CTA principal a ancho completo (pantallas de auth).
  large,

  /// 44pt — el tamaño por defecto dentro del producto.
  medium,

  /// 34pt — acciones dentro de una fila o una tarjeta.
  small,
}

/// Botón del sistema de diseño.
///
/// El color sale de la superficie activa: el mismo `MpButton.primary` es naranja
/// en una pantalla de auth y violeta dentro del producto. Eso es intencional y
/// es lo que evita el error de meter naranja de marca en pantallas de producto.
class MpButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final MpButtonVariant variant;
  final MpButtonSize size;

  /// Ícono a la izquierda del texto.
  final IconData? icon;

  /// Flecha "→" a la derecha, como en los CTA de auth.
  final bool trailingArrow;

  /// Ocupa todo el ancho disponible.
  final bool expand;

  /// Fuerza un color distinto al de la superficie (p. ej. [MpTokens.danger]
  /// para una acción destructiva, o [MpTokens.successDeep] para "Ver oferta").
  final Color? color;

  /// Píldora completa en vez del radio estándar.
  final bool pill;

  /// Muestra un spinner y bloquea el toque.
  final bool loading;

  const MpButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = MpButtonVariant.primary,
    this.size = MpButtonSize.medium,
    this.icon,
    this.trailingArrow = false,
    this.expand = false,
    this.color,
    this.pill = false,
    this.loading = false,
  });

  double get _height => switch (size) {
        MpButtonSize.large => 52,
        MpButtonSize.medium => 44,
        MpButtonSize.small => 34,
      };

  double get _fontSize => switch (size) {
        MpButtonSize.large => 16,
        MpButtonSize.medium => 14.5,
        MpButtonSize.small => 13,
      };

  double get _iconSize => switch (size) {
        MpButtonSize.large => 19,
        MpButtonSize.medium => 17,
        MpButtonSize.small => 15,
      };

  double get _padding => switch (size) {
        MpButtonSize.large => 24,
        MpButtonSize.medium => 18,
        MpButtonSize.small => 14,
      };

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final accent = color ?? s.accent;
    final enabled = onPressed != null && !loading;
    final radius = pill ? MpTokens.radiusPill : MpTokens.radiusMD;

    late final Color foreground;
    late final BoxDecoration decoration;

    switch (variant) {
      case MpButtonVariant.primary:
        foreground = const Color(0xFFFFFFFF);
        decoration = BoxDecoration(
          // Con color propio no hay degradado definido: se rellena plano.
          gradient: color == null ? s.accentGradient : null,
          color: color,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: enabled ? MpTokens.glow(accent) : null,
        );

      case MpButtonVariant.outline:
        foreground = accent;
        decoration = BoxDecoration(
          color: s.tint(accent, alpha: s.isDark ? 0.14 : 0.06),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
        );

      case MpButtonVariant.neutral:
        foreground = s.text;
        decoration = BoxDecoration(
          color: s.card,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: s.borderStrong),
        );

      case MpButtonVariant.ghost:
        foreground = accent;
        decoration = const BoxDecoration();
    }

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          CupertinoActivityIndicator(radius: _iconSize / 2, color: foreground),
          SizedBox(width: MpTokens.space8),
        ] else if (icon != null) ...[
          Icon(icon, size: _iconSize, color: foreground),
          SizedBox(width: MpTokens.space8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: _fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (trailingArrow) ...[
          SizedBox(width: MpTokens.space12),
          Icon(CupertinoIcons.arrow_right, size: _iconSize, color: foreground),
        ],
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: enabled ? onPressed : null,
        child: Container(
          height: _height,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: variant == MpButtonVariant.ghost ? 0 : _padding,
          ),
          alignment: Alignment.center,
          decoration: decoration,
          child: content,
        ),
      ),
    );
  }
}

/// Botón de proveedor de identidad. Aparece en las 3 pantallas de auth y su
/// estilo es fijo: Google en blanco con borde, Apple en negro relleno.
enum MpSocialProvider { google, apple, email }

class MpSocialButton extends StatelessWidget {
  final MpSocialProvider provider;
  final String label;
  final VoidCallback? onPressed;

  const MpSocialButton({
    super.key,
    required this.provider,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final isApple = provider == MpSocialProvider.apple;

    final background = isApple ? const Color(0xFF0A0A0F) : s.card;
    final foreground = isApple ? const Color(0xFFFFFFFF) : s.text;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(MpTokens.radiusMD),
          border: isApple ? null : Border.all(color: s.borderStrong),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // El logo va anclado a la izquierda y el texto centrado en el botón,
            // como en los mockups — no son un Row centrado juntos.
            Positioned(
              left: 20,
              child: _ProviderMark(provider: provider, color: foreground),
            ),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderMark extends StatelessWidget {
  final MpSocialProvider provider;
  final Color color;

  const _ProviderMark({required this.provider, required this.color});

  @override
  Widget build(BuildContext context) {
    switch (provider) {
      case MpSocialProvider.apple:
        return Icon(CupertinoIcons.person_fill, size: 22, color: color);
      case MpSocialProvider.email:
        return Icon(CupertinoIcons.mail_solid, size: 20, color: color);
      case MpSocialProvider.google:
        // La "G" de Google es multicolor y no existe en Cupertino: se dibuja.
        return const _GoogleG(size: 22);
    }
  }
}

/// "G" de Google dibujada a mano — cuatro arcos de color sobre un anillo.
class _GoogleG extends StatelessWidget {
  final double size;

  const _GoogleG({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Arcos en sentido horario desde la derecha, replicando el logotipo.
    void arc(double startDeg, double sweepDeg, Color color) {
      paint.color = color;
      canvas.drawArc(
        rect,
        startDeg * 3.1415926535 / 180,
        sweepDeg * 3.1415926535 / 180,
        false,
        paint,
      );
    }

    arc(-40, -95, _red); // arriba
    arc(-135, -80, _yellow); // izquierda
    arc(145, 80, _green); // abajo
    arc(-40, 80, _blue); // derecha

    // Barra horizontal central del logotipo.
    final barPaint = Paint()..color = _blue;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.5,
        size.height * 0.42,
        size.width * 0.5 - stroke / 2,
        stroke * 0.92,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
