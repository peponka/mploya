import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'mp_surface.dart';

/// Etiqueta de campo. Siempre encima del campo, nunca flotante — así están
/// todos los formularios de FINAL_SCREENS.
class MpFieldLabel extends StatelessWidget {
  final String text;
  final String? helper;

  const MpFieldLabel(this.text, {super.key, this.helper});

  @override
  Widget build(BuildContext context) {
    final s = context.mp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: MpTokens.label.copyWith(
            color: s.text,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: MpTokens.space2),
          Text(
            helper!,
            style: MpTokens.caption.copyWith(color: s.textTertiary),
          ),
        ],
        const SizedBox(height: MpTokens.space8),
      ],
    );
  }
}

/// Campo de texto del sistema.
///
/// En las pantallas de auth el ícono va separado del texto por un divisor
/// vertical fino ([iconDivider]); dentro del producto el campo va limpio.
class MpTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? placeholder;
  final IconData? icon;
  final bool obscure;

  /// Ícono de acción a la derecha (ojo de contraseña, pin de ubicación).
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;

  /// Contador "19/80" dentro del campo, a la derecha.
  final String? counter;

  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  /// Divisor vertical entre el ícono y el texto (patrón de auth).
  final bool iconDivider;

  /// Mensaje de error debajo; pinta el borde en rojo.
  final String? errorText;

  const MpTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.icon,
    this.obscure = false,
    this.trailingIcon,
    this.onTrailingTap,
    this.counter,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.enabled = true,
    this.iconDivider = false,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final hasError = errorText != null;

    final field = Container(
      constraints: BoxConstraints(minHeight: maxLines > 1 ? 96 : 54),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(MpTokens.radiusMD),
        border: Border.all(
          color: hasError ? MpTokens.danger : s.borderStrong,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Padding(
              padding: EdgeInsets.only(top: maxLines > 1 ? 16 : 0),
              child: Icon(icon, size: 20, color: s.textTertiary),
            ),
            if (iconDivider) ...[
              const SizedBox(width: 12),
              Container(width: 1, height: 26, color: s.border),
              const SizedBox(width: 12),
            ] else
              const SizedBox(width: 10),
          ],
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              obscureText: obscure,
              maxLines: maxLines,
              minLines: maxLines > 1 ? maxLines : null,
              keyboardType: keyboardType,
              onChanged: onChanged,
              enabled: enabled,
              padding: EdgeInsets.symmetric(vertical: maxLines > 1 ? 16 : 14),
              decoration: const BoxDecoration(),
              style: MpTokens.body.copyWith(color: s.text),
              placeholderStyle: MpTokens.body.copyWith(color: s.textTertiary),
              cursorColor: s.accent,
            ),
          ),
          if (counter != null) ...[
            const SizedBox(width: 8),
            Padding(
              padding: EdgeInsets.only(top: maxLines > 1 ? 16 : 0),
              child: Text(
                counter!,
                style: MpTokens.micro.copyWith(color: s.textTertiary),
              ),
            ),
          ],
          if (trailingIcon != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onTrailingTap,
              behavior: HitTestBehavior.opaque,
              child: Icon(trailingIcon, size: 20, color: s.textSecondary),
            ),
          ],
        ],
      ),
    );

    if (!hasError) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        const SizedBox(height: MpTokens.space4),
        Text(
          errorText!,
          style: MpTokens.caption.copyWith(color: MpTokens.danger),
        ),
      ],
    );
  }
}

/// Campo de selección: ícono, valor y chevron. Visualmente igual al de texto,
/// para que un formulario mixto no se vea desparejo.
class MpSelectField extends StatelessWidget {
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isPlaceholder;

  const MpSelectField({
    super.key,
    required this.value,
    this.icon,
    this.onTap,
    this.isPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: s.card,
          borderRadius: BorderRadius.circular(MpTokens.radiusMD),
          border: Border.all(color: s.borderStrong),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: s.textSecondary),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MpTokens.body.copyWith(
                  color: isPlaceholder ? s.textTertiary : s.text,
                ),
              ),
            ),
            Icon(CupertinoIcons.chevron_down, size: 15, color: s.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Casilla cuadrada. → "Permitir candidatos de otras ubicaciones".
class MpCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;

  const MpCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;

    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? s.accent : const Color(0x00000000),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? s.accent : s.borderStrong,
                width: 1.5,
              ),
            ),
            child: value
                ? const Icon(
                    CupertinoIcons.check_mark,
                    size: 13,
                    color: Color(0xFFFFFFFF),
                  )
                : null,
          ),
          if (label != null) ...[
            const SizedBox(width: MpTokens.space8),
            Flexible(
              child: Text(
                label!,
                style: MpTokens.body.copyWith(
                  color: s.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta de opción seleccionable con ícono.
/// → "Tiempo completo / Medio tiempo / Contrato / Prácticas" y las tarjetas de
///   rol de la bienvenida. Seleccionada: borde de acento, fondo tintado y un
///   check en círculo arriba a la derecha.
class MpOptionCard extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  /// Color del ícono cuando NO está seleccionada (tarjetas de rol: cada una
  /// tiene el suyo). Si es nulo usa el acento de la superficie.
  final Color? iconColor;

  /// Ícono en círculo relleno de color, como en las tarjetas de rol.
  final bool solidIcon;

  const MpOptionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.subtitle,
    this.iconColor,
    this.solidIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final tint = iconColor ?? s.accent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(MpTokens.space16),
        decoration: BoxDecoration(
          color: selected ? s.tint(s.accent, alpha: 0.06) : s.card,
          borderRadius: BorderRadius.circular(MpTokens.radiusLG),
          border: Border.all(
            color: selected ? s.accent : s.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Container(
                    width: solidIcon ? 52 : 38,
                    height: solidIcon ? 52 : 38,
                    decoration: BoxDecoration(
                      color: solidIcon
                          ? tint
                          : tint.withValues(alpha: s.isDark ? 0.18 : 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: solidIcon ? 26 : 19,
                      color: solidIcon ? const Color(0xFFFFFFFF) : tint,
                    ),
                  ),
                  const SizedBox(height: MpTokens.space12),
                ],
                Text(
                  label,
                  style: MpTokens.title.copyWith(color: s.text, fontSize: 15.5),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: MpTokens.space2),
                  Text(
                    subtitle!,
                    style: MpTokens.caption.copyWith(color: s.textSecondary),
                  ),
                ],
              ],
            ),
            if (selected)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: s.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.check_mark,
                    size: 12,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un paso del asistente multi-paso.
class MpStep {
  final String label;
  final IconData? icon;

  const MpStep(this.label, {this.icon});
}

/// Indicador de progreso por pasos con conectores.
/// → la fila "1 Información — 2 Descripción — 3 Requisitos — 4 Compensación —
///   5 Publicar" de `crear vacante.png`.
class MpStepper extends StatelessWidget {
  final List<MpStep> steps;
  final int currentIndex;
  final ValueChanged<int>? onStepTap;

  const MpStepper({
    super.key,
    required this.steps,
    required this.currentIndex,
    this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 19),
                child: Container(
                  height: 2,
                  color: i <= currentIndex ? s.accent : s.border,
                ),
              ),
            ),
          _StepDot(
            step: steps[i],
            index: i,
            state: i < currentIndex
                ? _StepState.done
                : (i == currentIndex ? _StepState.current : _StepState.pending),
            onTap: onStepTap == null ? null : () => onStepTap!(i),
          ),
        ],
      ],
    );
  }
}

enum _StepState { done, current, pending }

class _StepDot extends StatelessWidget {
  final MpStep step;
  final int index;
  final _StepState state;
  final VoidCallback? onTap;

  const _StepDot({
    required this.step,
    required this.index,
    required this.state,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final isActive = state != _StepState.pending;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 74,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isActive ? s.accent : s.card,
                shape: BoxShape.circle,
                border: isActive ? null : Border.all(color: s.borderStrong),
                boxShadow:
                    state == _StepState.current ? MpTokens.glow(s.accent) : null,
              ),
              child: Center(
                child: state == _StepState.done
                    ? const Icon(
                        CupertinoIcons.check_mark,
                        size: 17,
                        color: Color(0xFFFFFFFF),
                      )
                    : (step.icon != null && state == _StepState.current
                        ? Icon(
                            step.icon,
                            size: 18,
                            color: const Color(0xFFFFFFFF),
                          )
                        : Text(
                            '${index + 1}',
                            style: MpTokens.bodyStrong.copyWith(
                              color: isActive
                                  ? const Color(0xFFFFFFFF)
                                  : s.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          )),
              ),
            ),
            const SizedBox(height: MpTokens.space8),
            Text(
              step.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: MpTokens.micro.copyWith(
                color: isActive ? s.accent : s.textSecondary,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
