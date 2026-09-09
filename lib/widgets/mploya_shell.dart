import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;

import '../theme/app_theme.dart';

class MployaShellCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;

  const MployaShellCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.color,
    this.borderColor,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.cardColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? context.shellBorder,
        ),
        boxShadow: boxShadow ?? context.cardShadow,
      ),
      child: child,
    );
  }
}

class MployaGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? color;

  const MployaGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.blur = 18,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? context.glassColor,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: context.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

// FIX (Pedro, 30/8/2026): Crashlytics reportaba un RenderFlex overflow
// (._handleFlutterError, ~15 crashes / 8 usuarios en 1.0.24) causado por
// estos botones — el Row interno (mainAxisSize.min) con ícono + Text sin
// límite se desbordaba cuando el label era largo (ej. "Invitar a
// entrevista") dentro de un botón angosto (Expanded en la barra inferior
// del perfil). Se envuelve el Text en Flexible + ellipsis para que trunque
// en vez de desbordar.
class MployaPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool compact;

  const MployaPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        height: compact ? 42 : 48,
        padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 20),
        decoration: BoxDecoration(
          gradient: context.primaryGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: context.primaryAccent.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: compact ? 16 : 18, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 13.5 : 14.5,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MployaSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const MployaSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: context.shellBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: context.textPrimary),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MployaPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool active;

  const MployaPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? context.primaryAccent;
    final foreground = active ? Colors.white : baseColor;
    final background = active
        ? baseColor
        : baseColor.withValues(alpha: context.isDark ? 0.18 : 0.10);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? baseColor.withValues(alpha: 0.28)
              : baseColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class MployaStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final IconData icon;
  final Color color;

  const MployaStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return MployaShellCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              if (delta != null)
                Text(
                  delta!,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class MployaSectionTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;

  const MployaSectionTitle({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: context.primaryAccent,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
