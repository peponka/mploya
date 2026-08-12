import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'mp_surface.dart';

/// Estado de una entidad, como píldora con punto de color.
/// → "● Activo" (verde), "● En pausa" (ámbar), "● Finalizado" (gris) en
///   `headhunter clientes.png`.
enum MpStatus { active, paused, finished, danger, info, neutral }

extension MpStatusColor on MpStatus {
  Color get color => switch (this) {
        MpStatus.active => MpTokens.successDeep,
        MpStatus.paused => MpTokens.premium,
        MpStatus.finished => const Color(0xFF9A9AAC),
        MpStatus.danger => MpTokens.danger,
        MpStatus.info => MpTokens.infoDeep,
        MpStatus.neutral => const Color(0xFF9A9AAC),
      };
}

class MpStatusBadge extends StatelessWidget {
  final String label;
  final MpStatus status;

  /// Punto sólido a la izquierda. Presente en todos los mockups de estado.
  final bool showDot;

  const MpStatusBadge({
    super.key,
    required this.label,
    required this.status,
    this.showDot = true,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final color = status.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: s.tint(color, alpha: s.isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(MpTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(label, style: MpTokens.micro.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// Chip de categoría o de tipo, sin punto.
/// → "Entrevista", "Oferta", "Recomendación" del centro de notificaciones;
///   "Vacante confidencial" del feed.
class MpTypeChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  /// Relleno sólido con texto blanco.
  final bool solid;

  const MpTypeChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final foreground = solid ? const Color(0xFFFFFFFF) : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: solid ? color : s.tint(color, alpha: s.isDark ? 0.20 : 0.11),
        borderRadius: BorderRadius.circular(MpTokens.radiusXS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: MpTokens.micro.copyWith(color: foreground, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Chip de habilidad / etiqueta, con contorno y borrado opcional.
/// → "Figma ×", "UI Design ×", "+ Agregar habilidad" en `crear vacante.png`.
class MpTagChip extends StatelessWidget {
  final String label;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  /// Variante de acción ("+ Agregar habilidad"): borde punteado en el mockup,
  /// acá borde sólido tenue con ícono de suma.
  final bool isAction;

  const MpTagChip({
    super.key,
    required this.label,
    this.onRemove,
    this.onTap,
    this.isAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final color = s.accent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: s.tint(color, alpha: s.isDark ? 0.16 : 0.07),
          borderRadius: BorderRadius.circular(MpTokens.radiusXS),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAction) ...[
              Icon(CupertinoIcons.add, size: 13, color: color),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: MpTokens.micro.copyWith(color: color, fontSize: 12.5),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 7),
              GestureDetector(
                onTap: onRemove,
                child: Icon(CupertinoIcons.xmark, size: 11, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Contador junto a una etiqueta de filtro. → "Todos (18)", "Activos (12)".
class MpCountBadge extends StatelessWidget {
  final int count;
  final bool active;

  const MpCountBadge({super.key, required this.count, this.active = false});

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final color = active ? s.accent : s.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: s.tint(color, alpha: active ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(MpTokens.radiusPill),
      ),
      child: Text(
        '$count',
        style: MpTokens.micro.copyWith(color: color, fontSize: 11),
      ),
    );
  }
}

/// Un filtro de una fila de filtros.
class MpFilterOption {
  final String label;
  final int? count;

  const MpFilterOption(this.label, {this.count});
}

/// Fila de filtros dentro de una cápsula. El activo se eleva sobre una tarjeta
/// blanca; los inactivos quedan planos sobre el relleno.
/// → "Todos 18 | Activos 12 | En pausa 3 | Finalizados 3".
class MpSegmentedFilter extends StatelessWidget {
  final List<MpFilterOption> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Desplazamiento horizontal cuando hay más filtros que ancho disponible
  /// (el centro de notificaciones tiene 7).
  final bool scrollable;

  const MpSegmentedFilter({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;

    final children = <Widget>[
      for (int i = 0; i < options.length; i++)
        _segment(context, options[i], i == selectedIndex, () => onChanged(i)),
    ];

    final bar = Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: s.fill,
        borderRadius: BorderRadius.circular(MpTokens.radiusLG),
        border: Border.all(color: s.border),
      ),
      child: scrollable
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: children),
            )
          : Row(
              children: [
                for (final child in children) Expanded(child: child),
              ],
            ),
    );

    return bar;
  }

  Widget _segment(
    BuildContext context,
    MpFilterOption option,
    bool active,
    VoidCallback onTap,
  ) {
    final s = context.mp;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: scrollable ? 16 : 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: active ? s.card : const Color(0x00000000),
          borderRadius: BorderRadius.circular(MpTokens.radiusMD),
          boxShadow: active ? s.cardShadow : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: MpTokens.label.copyWith(
                  color: active ? s.accent : s.textSecondary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (option.count != null) ...[
              const SizedBox(width: 6),
              MpCountBadge(count: option.count!, active: active),
            ],
          ],
        ),
      ),
    );
  }
}

/// Conmutador de dos posiciones para auth ("Iniciar sesión" / "Crear cuenta").
/// Se distingue del filtro: el activo va tintado con el naranja de marca.
class MpAuthToggle extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;

  const MpAuthToggle({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.rightSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;

    Widget half(String label, bool active, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? s.accent.withValues(alpha: 0.10)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(MpTokens.radiusPill),
            ),
            child: Text(
              label,
              style: MpTokens.bodyStrong.copyWith(
                color: active ? s.accent : s.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(MpTokens.radiusPill),
        border: Border.all(color: s.border),
      ),
      child: Row(
        children: [
          half(leftLabel, !rightSelected, () => onChanged(false)),
          half(rightLabel, rightSelected, () => onChanged(true)),
        ],
      ),
    );
  }
}
