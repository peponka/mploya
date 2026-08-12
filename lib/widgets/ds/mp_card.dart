import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'mp_surface.dart';

/// Contenedor base. Toda superficie agrupada de los mockups es esta tarjeta:
/// fondo de tarjeta, borde de 1px y, solo en claro, una sombra muy difusa.
class MpCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Pinta el borde con el color de acento. Para el estado seleccionado
  /// (tarjeta de rol activa, plan "Más popular", filtro aplicado).
  final bool highlighted;

  /// Sobrescribe el color de fondo sin perder borde ni radio.
  final Color? color;

  const MpCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(MpTokens.space16),
    this.radius = MpTokens.radiusLG,
    this.onTap,
    this.highlighted = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? s.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: highlighted ? s.accent : s.border,
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: s.cardShadow,
      ),
      child: child,
    );

    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}

/// Cuadrado de ícono con tinte de color. Es el elemento que abre casi todas las
/// tarjetas y filas de los dashboards.
class MpIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  /// Círculo en vez de cuadrado redondeado (tarjetas de rol, avatares de
  /// notificación).
  final bool circular;

  /// Relleno sólido en el color, con el ícono en blanco.
  final bool solid;

  const MpIconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.circular = false,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: solid ? color : s.tint(color),
        borderRadius: BorderRadius.circular(
          circular ? size / 2 : MpTokens.radiusSM,
        ),
      ),
      child: Icon(
        icon,
        size: size * 0.46,
        color: solid ? const Color(0xFFFFFFFF) : color,
      ),
    );
  }
}

/// Métrica de dashboard: ícono, número grande, etiqueta y un enlace opcional.
///
/// Es literalmente la fila "24 Vacantes activas / Ver todas" de
/// `dashboard empresa.png` y la grilla de `headhunter dashboard.png`.
class MpStatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  /// Enlace al pie ("Ver todas", "Ver pipeline").
  final String? linkLabel;
  final VoidCallback? onLinkTap;

  /// Delta contra el período anterior ("+2 vs. semana pasada").
  final String? delta;

  /// Versión angosta: en `dashboard empresa.png` entran cuatro KPIs en el
  /// ancho de un móvil, así que la tipografía y el ícono se achican.
  final bool compact;

  const MpStatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.linkLabel,
    this.onLinkTap,
    this.delta,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;

    return MpCard(
      onTap: onLinkTap,
      padding: EdgeInsets.all(compact ? MpTokens.space12 : MpTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MpIconTile(icon: icon, color: color, size: compact ? 32 : 38),
          SizedBox(height: compact ? MpTokens.space12 : MpTokens.space16),
          Text(
            value,
            style: MpTokens.stat.copyWith(
              color: s.text,
              fontSize: compact ? 25 : null,
            ),
          ),
          const SizedBox(height: MpTokens.space4),
          Text(
            label,
            style: MpTokens.caption.copyWith(
              color: s.textSecondary,
              fontSize: compact ? 11.5 : null,
              height: compact ? 1.25 : null,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: MpTokens.space4),
            Text(
              delta!,
              style: MpTokens.micro.copyWith(color: MpTokens.success),
            ),
          ],
          if (linkLabel != null) ...[
            SizedBox(height: compact ? MpTokens.space8 : MpTokens.space12),
            Row(
              children: [
                Flexible(
                  child: Text(
                    linkLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MpTokens.label.copyWith(
                      color: s.accent,
                      fontSize: compact ? 12 : null,
                    ),
                  ),
                ),
                const SizedBox(width: MpTokens.space4),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 12,
                  color: s.accent,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Encabezado de sección: título a la izquierda, acción a la derecha.
/// → "Pipeline general … Ver pipeline completo".
class MpSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const MpSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: MpTokens.h2.copyWith(color: s.text)),
              if (subtitle != null) ...[
                const SizedBox(height: MpTokens.space4),
                Text(
                  subtitle!,
                  style: MpTokens.caption.copyWith(color: s.textSecondary),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: MpTokens.space12),
          GestureDetector(
            onTap: onActionTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Text(
                  actionLabel!,
                  style: MpTokens.label.copyWith(color: s.accent),
                ),
                const SizedBox(width: MpTokens.space4),
                Icon(CupertinoIcons.chevron_right, size: 13, color: s.accent),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Banda hero rellena en violeta con métricas en blanco.
/// → la banda "Búsquedas activas 12 · Candidatos presentados 28 · Colocaciones 7"
/// de `headhunter dashboard.png`.
class MpHeroBand extends StatelessWidget {
  final List<MpHeroMetric> metrics;

  const MpHeroBand({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MpTokens.space16,
        vertical: MpTokens.space20,
      ),
      decoration: BoxDecoration(
        gradient: MpTokens.heroGradient,
        borderRadius: BorderRadius.circular(MpTokens.radiusXL),
        boxShadow: MpTokens.glow(MpTokens.primary),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < metrics.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 62,
                margin: const EdgeInsets.symmetric(
                  horizontal: MpTokens.space12,
                ),
                color: const Color(0x33FFFFFF),
              ),
            Expanded(child: _HeroMetricView(metric: metrics[i])),
          ],
        ],
      ),
    );
  }
}

class MpHeroMetric {
  final IconData icon;
  final String label;
  final String value;
  final String? delta;

  const MpHeroMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.delta,
  });
}

class _HeroMetricView extends StatelessWidget {
  final MpHeroMetric metric;

  const _HeroMetricView({required this.metric});

  @override
  Widget build(BuildContext context) {
    const white = Color(0xFFFFFFFF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(metric.icon, size: 18, color: white),
            const SizedBox(width: MpTokens.space8),
            Expanded(
              child: Text(
                metric.label,
                style: MpTokens.micro.copyWith(color: white, height: 1.25),
              ),
            ),
          ],
        ),
        const SizedBox(height: MpTokens.space8),
        Text(
          metric.value,
          style: MpTokens.stat.copyWith(color: white, fontSize: 26),
        ),
        if (metric.delta != null) ...[
          const SizedBox(height: MpTokens.space2),
          Text(
            metric.delta!,
            style: MpTokens.micro.copyWith(
              color: const Color(0xFF7DF5B0),
              fontSize: 10.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// Fila de lista: elemento adelante, título, subtítulo, valor y chevron.
/// Es el patrón de "Actividad reciente", del centro de notificaciones y de
/// todas las pantallas de ajustes.
class MpListRow extends StatelessWidget {
  /// Avatar, logo de empresa o [MpIconTile].
  final Widget? leading;

  final String title;
  final String? subtitle;

  /// Texto a la derecha ("Hace 2h", "11:35 AM").
  final String? trailingText;

  /// Widget a la derecha (un [MpButton] pequeño, un badge). Tiene prioridad
  /// sobre [trailingText].
  final Widget? trailing;

  final VoidCallback? onTap;
  final bool showChevron;

  /// Chip de tipo junto al título ("Entrevista", "Oferta").
  final Widget? badge;

  /// Líneas del título. Sigue en 1 por defecto para no mover las pantallas ya
  /// aprobadas; las listas con títulos largos (actividad) piden 2.
  final int titleMaxLines;

  const MpListRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.badge,
    this.titleMaxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MpTokens.space16,
          vertical: MpTokens.space12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: MpTokens.space12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: titleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: MpTokens.title.copyWith(color: s.text),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: MpTokens.space8),
                        badge!,
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: MpTokens.space2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MpTokens.caption.copyWith(
                        color: s.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: MpTokens.space12),
              trailing!,
            ] else if (trailingText != null) ...[
              const SizedBox(width: MpTokens.space12),
              Text(
                trailingText!,
                style: MpTokens.caption.copyWith(color: s.textTertiary),
              ),
            ],
            if (showChevron && trailing == null) ...[
              const SizedBox(width: MpTokens.space4),
              Icon(
                CupertinoIcons.chevron_right,
                size: 15,
                color: s.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Agrupa filas en una tarjeta con divisores finos entre ellas.
class MpRowGroup extends StatelessWidget {
  final List<Widget> rows;

  /// Sangría izquierda del divisor, para que arranque después del leading.
  final double dividerIndent;

  const MpRowGroup({
    super.key,
    required this.rows,
    this.dividerIndent = MpTokens.space16,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;

    return MpCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              Padding(
                padding: EdgeInsets.only(left: dividerIndent),
                child: Container(height: 1, color: s.border),
              ),
          ],
        ],
      ),
    );
  }
}
