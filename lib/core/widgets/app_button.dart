/// Botones reutilizables de la aplicación mploya.
///
/// Proporciona tres variantes de [AppButton]:
/// - [AppButton.primary] — botón relleno con color primario.
/// - [AppButton.secondary] — botón con borde (outlined).
/// - [AppButton.text] — botón de texto sin fondo.
///
/// Todos soportan: estado de carga, deshabilitado, icono, ancho completo
/// y bordes redondeados con efecto ripple de Material 3.
library;

import 'package:flutter/material.dart';

import 'package:mploya/config/theme.dart';

/// Variante visual del botón.
enum _AppButtonVariant { primary, secondary, text }

/// Botón reutilizable con soporte para estados de carga, deshabilitado,
/// icono y ancho completo.
class AppButton extends StatelessWidget {
  const AppButton.primary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.isDisabled = false,
    this.height = 52,
    this.fontSize = 16,
    this.borderRadius,
    super.key,
  }) : _variant = _AppButtonVariant.primary;

  const AppButton.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.isDisabled = false,
    this.height = 52,
    this.fontSize = 16,
    this.borderRadius,
    super.key,
  }) : _variant = _AppButtonVariant.secondary;

  const AppButton.text({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.isDisabled = false,
    this.height = 44,
    this.fontSize = 15,
    this.borderRadius,
    super.key,
  }) : _variant = _AppButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final bool isDisabled;
  final double height;
  final double fontSize;
  final double? borderRadius;
  final _AppButtonVariant _variant;

  bool get _isEnabled => !isLoading && !isDisabled && onPressed != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius ?? AppRadius.md),
    );

    final textStyle = TextStyle(
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w600,
      fontSize: fontSize,
    );

    final minimumSize = Size(isFullWidth ? double.infinity : 120, height);

    Widget child;
    if (isLoading) {
      child = SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _variant == _AppButtonVariant.primary
              ? colorScheme.onPrimary
              : colorScheme.primary,
        ),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(label),
        ],
      );
    } else {
      child = Text(label);
    }

    // ── Construir variante ─────────────────────────────────────────────
    return switch (_variant) {
      _AppButtonVariant.primary => ElevatedButton(
          onPressed: _isEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            disabledBackgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
            disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
            minimumSize: minimumSize,
            shape: shape,
            textStyle: textStyle,
            elevation: AppElevation.sm,
            shadowColor: colorScheme.primary.withValues(alpha: 0.3),
          ),
          child: child,
        ),
      _AppButtonVariant.secondary => OutlinedButton(
          onPressed: _isEnabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.primary,
            side: BorderSide(
              color: _isEnabled
                  ? colorScheme.outline
                  : colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            minimumSize: minimumSize,
            shape: shape,
            textStyle: textStyle,
          ),
          child: child,
        ),
      _AppButtonVariant.text => TextButton(
          onPressed: _isEnabled ? onPressed : null,
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.primary,
            minimumSize: minimumSize,
            shape: shape,
            textStyle: textStyle,
          ),
          child: child,
        ),
    };
  }
}
