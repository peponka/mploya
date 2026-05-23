/// Campo de texto reutilizable de mploya.
///
/// Proporciona un [TextFormField] estilizado con borde outlined,
/// soporte para label, hint, iconos prefix/suffix, estado de error,
/// ocultación de texto (contraseñas con toggle de visibilidad) y validación.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mploya/config/theme.dart';

/// Campo de texto reutilizable con estilo coherente en toda la app.
///
/// ```dart
/// AppTextField(
///   label: 'Correo electrónico',
///   hint: 'tu@email.com',
///   prefixIcon: Icons.email_outlined,
///   keyboardType: TextInputType.emailAddress,
///   validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
/// )
///
/// AppTextField(
///   label: 'Contraseña',
///   hint: '••••••••',
///   obscureText: true,
///   prefixIcon: Icons.lock_outline,
/// )
/// ```
class AppTextField extends StatefulWidget {
  /// Crea una instancia de [AppTextField].
  const AppTextField({
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.focusNode,
    this.fillColor,
    this.contentPadding,
    this.borderRadius,
    super.key,
  });

  /// Controlador de texto.
  final TextEditingController? controller;

  /// Etiqueta (label) que se muestra sobre el campo.
  final String? label;

  /// Texto de sugerencia que aparece cuando el campo está vacío.
  final String? hint;

  /// Texto de ayuda debajo del campo.
  final String? helperText;

  /// Texto de error. Si no es `null`, el campo se muestra en estado de error.
  final String? errorText;

  /// Icono que se muestra al inicio del campo.
  final IconData? prefixIcon;

  /// Icono que se muestra al final del campo.
  /// Si [obscureText] es `true`, se genera automáticamente un icono de toggle.
  final IconData? suffixIcon;

  /// Callback al tocar el icono suffix.
  final VoidCallback? onSuffixTap;

  /// Si es `true`, oculta el texto y muestra un toggle de visibilidad.
  final bool obscureText;

  /// Si es `false`, el campo se muestra deshabilitado.
  final bool enabled;

  /// Si es `true`, el campo es de solo lectura.
  final bool readOnly;

  /// Si es `true`, el campo obtiene foco automáticamente.
  final bool autofocus;

  /// Número máximo de líneas.
  final int? maxLines;

  /// Número mínimo de líneas.
  final int? minLines;

  /// Longitud máxima de caracteres.
  final int? maxLength;

  /// Tipo de teclado.
  final TextInputType? keyboardType;

  /// Acción del teclado (done, next, search…).
  final TextInputAction? textInputAction;

  /// Capitalización del texto.
  final TextCapitalization textCapitalization;

  /// Formateadores de entrada (e.g. para números).
  final List<TextInputFormatter>? inputFormatters;

  /// Función de validación para [FormField].
  final String? Function(String?)? validator;

  /// Callback cuando el valor cambia.
  final ValueChanged<String>? onChanged;

  /// Callback cuando se envía (submit) desde el teclado.
  final ValueChanged<String>? onFieldSubmitted;

  /// Callback al tocar el campo. Útil para campos de solo lectura que abren
  /// un picker (fecha, hora…).
  final VoidCallback? onTap;

  /// Nodo de foco personalizado.
  final FocusNode? focusNode;

  /// Color de relleno personalizado.
  final Color? fillColor;

  /// Padding interno del campo.
  final EdgeInsetsGeometry? contentPadding;

  /// Radio de borde personalizado.
  final double? borderRadius;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  /// Controla la visibilidad del texto cuando [obscureText] es `true`.
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia la prop obscureText externamente, sincronizar.
    if (widget.obscureText != oldWidget.obscureText) {
      _isObscured = widget.obscureText;
    }
  }

  void _toggleVisibility() {
    setState(() => _isObscured = !_isObscured);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveBorderRadius =
        BorderRadius.circular(widget.borderRadius ?? AppRadius.md);

    // ── Suffix icon ──────────────────────────────────────────────────
    Widget? suffixWidget;
    if (widget.obscureText) {
      suffixWidget = IconButton(
        onPressed: _toggleVisibility,
        icon: Icon(
          _isObscured
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
        splashRadius: 20,
        tooltip: _isObscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
      );
    } else if (widget.suffixIcon != null) {
      suffixWidget = IconButton(
        onPressed: widget.onSuffixTap,
        icon: Icon(widget.suffixIcon, size: 20),
        splashRadius: 20,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Label externo ──────────────────────────────────────────────
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: widget.errorText != null
                  ? colorScheme.error
                  : colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
        ],

        // ── Campo de texto ────────────────────────────────────────────
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          obscureText: _isObscured,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          autofocus: widget.autofocus,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          inputFormatters: widget.inputFormatters,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          onTap: widget.onTap,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helperText,
            errorText: widget.errorText,
            fillColor: widget.fillColor,
            contentPadding: widget.contentPadding,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, size: 20)
                : null,
            suffixIcon: suffixWidget,
            border: OutlineInputBorder(borderRadius: effectiveBorderRadius),
            enabledBorder: OutlineInputBorder(
              borderRadius: effectiveBorderRadius,
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: effectiveBorderRadius,
              borderSide: BorderSide(
                color: colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: effectiveBorderRadius,
              borderSide: BorderSide(color: colorScheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: effectiveBorderRadius,
              borderSide: BorderSide(
                color: colorScheme.error,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: effectiveBorderRadius,
              borderSide: BorderSide(
                color: colorScheme.onSurface.withValues(alpha: 0.12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
