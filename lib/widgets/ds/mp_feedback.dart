import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'mp_button.dart';
import 'mp_card.dart';
import 'mp_surface.dart';

/// Barra de progreso simple. → "Screening 2.4 días", "Tiempo promedio por etapa".
class MpProgressBar extends StatelessWidget {
  /// 0.0 – 1.0
  final double value;
  final Color? color;
  final double height;

  const MpProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 7,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final tint = color ?? s.accent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(MpTokens.radiusPill),
      child: Stack(
        children: [
          Container(height: height, color: s.fill),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(MpTokens.radiusPill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un tramo de la barra de embudo.
class MpFunnelSegment {
  final double fraction;
  final Color color;

  const MpFunnelSegment({required this.fraction, required this.color});
}

/// Barra segmentada multicolor del embudo de contratación.
/// → la barra "100% · 31% · 21% · 8% · 5%" bajo el pipeline de
///   `dashboard empresa.png`.
class MpFunnelBar extends StatelessWidget {
  final List<MpFunnelSegment> segments;
  final double height;

  const MpFunnelBar({super.key, required this.segments, this.height = 9});

  @override
  Widget build(BuildContext context) {
    final s = context.mp;

    // En `dashboard empresa.png` cada tramo es una PÍLDORA redondeada propia,
    // pegada a la siguiente — no un bloque único recortado. La muesca entre
    // píldoras es parte del diseño.
    final visible =
        segments.where((seg) => seg.fraction > 0).toList(growable: false);

    if (visible.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: s.fill,
          borderRadius: BorderRadius.circular(MpTokens.radiusPill),
        ),
      );
    }

    final covered =
        visible.fold<double>(0, (sum, seg) => sum + seg.fraction).clamp(0.0, 1.0);

    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (final seg in visible)
            Expanded(
              flex: (seg.fraction * 1000).round().clamp(1, 1000000),
              child: Container(
                height: height,
                margin: const EdgeInsets.only(right: 1),
                decoration: BoxDecoration(
                  color: seg.color,
                  borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                ),
              ),
            ),
          // Cola gris con el resto sin cubrir.
          if (covered < 1)
            Expanded(
              flex: ((1 - covered) * 1000).round().clamp(1, 1000000),
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: s.fill,
                  borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Anillo de porcentaje. → el "92% IA Match" del feed y el "240 Utilizados
/// este mes" de créditos.
class MpProgressRing extends StatelessWidget {
  /// 0.0 – 1.0
  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Widget? center;

  const MpProgressRing({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 6,
    this.color,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          stroke: stroke,
          color: color ?? s.accent,
          track: s.fill,
        ),
        child: center == null ? null : Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double stroke;
  final Color color;
  final Color track;

  const _RingPainter({
    required this.value,
    required this.stroke,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, 6.2831853, false, base);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -1.5707963, 6.2831853 * value, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color;
}

/// Tarjeta de aviso / promoción al pie de una lista.
/// → "Sumá nuevos clientes … [+ Agregar cliente]" y "Activa notificaciones
///   inteligentes … [Activar ahora]".
class MpBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  /// Color del acento del aviso. Por defecto el de la superficie.
  final Color? color;

  const MpBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final tint = color ?? s.accent;

    return Container(
      padding: const EdgeInsets.all(MpTokens.space16),
      decoration: BoxDecoration(
        color: s.tint(tint, alpha: s.isDark ? 0.14 : 0.06),
        borderRadius: BorderRadius.circular(MpTokens.radiusXL),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MpIconTile(icon: icon, color: tint, size: 44, circular: true),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: MpTokens.title.copyWith(color: s.text)),
                const SizedBox(height: MpTokens.space4),
                Text(
                  message,
                  style: MpTokens.caption.copyWith(color: s.textSecondary),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: MpTokens.space12),
                  MpButton(
                    label: actionLabel!,
                    onPressed: onAction,
                    size: MpButtonSize.small,
                    icon: CupertinoIcons.add,
                    color: tint,
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: MpTokens.space8),
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 16,
                  color: s.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tarjeta de IA: fondo violeta tenue, chispa y etiqueta opcional.
/// → "Asistente IA (BETA)" de `crear vacante.png`, "¿Por qué ves esta vacante?"
///   del feed, "Análisis IA del candidato".
///
/// El violeta acá NO es decoración: en todo el set marca "esto lo hizo la IA".
class MpAiCard extends StatelessWidget {
  final String title;
  final String? tag;
  final Widget child;

  const MpAiCard({
    super.key,
    required this.title,
    required this.child,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    const tint = MpTokens.primary;

    return Container(
      padding: const EdgeInsets.all(MpTokens.space16),
      decoration: BoxDecoration(
        color: s.tint(tint, alpha: s.isDark ? 0.12 : 0.05),
        borderRadius: BorderRadius.circular(MpTokens.radiusXL),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.sparkles, size: 18, color: tint),
              const SizedBox(width: MpTokens.space8),
              Expanded(
                child: Text(
                  title,
                  style: MpTokens.title.copyWith(color: tint, fontSize: 16),
                ),
              ),
              if (tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: s.tint(tint, alpha: 0.14),
                    borderRadius: BorderRadius.circular(MpTokens.radiusXS),
                  ),
                  child: Text(
                    tag!,
                    style: MpTokens.micro.copyWith(color: tint, fontSize: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: MpTokens.space12),
          child,
        ],
      ),
    );
  }
}

/// Estado vacío centrado.
class MpEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MpEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(MpTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MpIconTile(icon: icon, color: s.accent, size: 64, circular: true),
              const SizedBox(height: MpTokens.space20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: MpTokens.h2.copyWith(color: s.text),
              ),
              const SizedBox(height: MpTokens.space8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: MpTokens.body.copyWith(color: s.textSecondary),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: MpTokens.space20),
                MpButton(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
