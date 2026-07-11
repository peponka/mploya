import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// web_ui — Sistema de diseño web reutilizable de Mploya.
//
// Componentes comunes para que TODAS las pantallas web tengan el mismo patrón:
// header de página (título + subtítulo + acciones), área de contenido con ancho
// máximo, tarjetas con profundidad, grilla responsive, botones con label y
// estados vacíos instructivos. Identidad naranja Mploya, fondo gris + tarjetas
// blancas con sombra. En móvil cae elegante a una columna.
// ─────────────────────────────────────────────────────────────────────────────

/// True si estamos en una pantalla ancha (web/desktop).
bool isWebWide(BuildContext context) =>
    kIsWeb && MediaQuery.of(context).size.width > 800;

/// Scaffold de página web: fondo gris + header consistente + contenido centrado
/// con ancho máximo. Usar como raíz de cada pantalla web.
class WebPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final double maxWidth;
  final Widget? leading;

  const WebPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.child,
    this.maxWidth = 1180,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final wide = isWebWide(context);
    return CupertinoPageScaffold(
      backgroundColor: context.bgColor,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(wide ? 32 : 18, wide ? 26 : 18, wide ? 32 : 18, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (leading != null) ...[leading!, const SizedBox(width: 12)],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: TextStyle(color: context.textPrimary, fontSize: wide ? 26 : 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                            if (subtitle != null) ...[
                              const SizedBox(height: 3),
                              Text(subtitle!, style: TextStyle(color: context.textTertiary, fontSize: 14)),
                            ],
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 18),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Azul y violeta secundarios (matchean la landing y los badges de la app:
/// "Contratando" azul, "Bio con IA" violeta).
const Color kMployaBlue = Color(0xFF2563EB);
const Color kMployaPurple = Color(0xFF6D48E5);

/// Botón tipo píldora (totalmente redondeado) con ícono/label y flecha opcional,
/// igual que la landing ("Busco trabajo →") y la app ("Ir al Feed"). `color`
/// permite el naranja (default), azul o violeta.
class WebButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool loading;
  final bool arrow;
  final Color? color;

  const WebButton({
    super.key,
    this.icon,
    required this.label,
    required this.onTap,
    this.filled = true,
    this.loading = false,
    this.arrow = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? MployaTheme.brandAccent;
    final bg = filled ? accent : context.cardColor;
    final fg = filled ? Colors.white : context.textPrimary;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: filled ? null : Border.all(color: context.dividerColor.withValues(alpha: 0.6), width: 0.5),
          boxShadow: filled
              ? [BoxShadow(color: accent.withValues(alpha: 0.30), blurRadius: 16, offset: const Offset(0, 6))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const CupertinoActivityIndicator(radius: 9, color: Colors.white)
            else if (icon != null)
              Icon(icon, size: 18, color: fg),
            if (icon != null || loading) const SizedBox(width: 8),
            Text(label, style: TextStyle(color: fg, fontSize: 14.5, fontWeight: FontWeight.w700)),
            if (arrow) ...[
              const SizedBox(width: 7),
              Icon(CupertinoIcons.arrow_right, size: 16, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}

/// Badge de ícono: cuadrado redondeado con tinte pastel + ícono de color, como
/// "Mis herramientas" o los pasos de la landing.
class WebIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const WebIconBadge({super.key, required this.icon, this.color = MployaTheme.brandAccent, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(size * 0.28)),
      child: Icon(icon, color: color, size: size * 0.46),
    );
  }
}

/// Badge/pill con punto de color y texto, como "Verificado" / "Contratando".
class WebBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const WebBadge({super.key, required this.label, this.color = MployaTheme.brandAccent, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 13, color: color)
          else
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Tarjeta blanca consistente con sombra (fondo gris hace que resalte).
class WebCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  const WebCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? context.dividerColor.withValues(alpha: 0.3), width: 0.5),
        boxShadow: context.cardShadow,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: card);
  }
}

/// Grilla responsive: 1 columna (móvil), 2 (web) o 3 (muy ancho).
class WebGrid extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const WebGrid({super.key, required this.children, this.gap = 16});

  @override
  Widget build(BuildContext context) {
    // Columnas según el ancho REAL disponible (no la pantalla completa, que
    // incluye el sidebar y suele ser mayor que el contenido efectivo).
    return LayoutBuilder(
      builder: (c, cons) {
        final w = cons.maxWidth;
        final cols = w > 1050 ? 3 : (w > 620 ? 2 : 1);
        if (cols <= 1) {
          return Column(
            children: [
              for (final child in children) Padding(padding: EdgeInsets.only(bottom: gap), child: child),
            ],
          );
        }
        final tileW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final child in children) SizedBox(width: tileW, child: child)],
        );
      },
    );
  }
}

/// Eyebrow de sección: mayúsculas con tracking, en color (naranja por defecto,
/// o azul/violeta), como "PARA CANDIDATOS" / "Paso 1" en la landing.
class WebSectionLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const WebSectionLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Text(text.toUpperCase(),
            style: TextStyle(color: color ?? MployaTheme.brandAccent, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.9)),
      );
}

/// Estado vacío instructivo: ícono + título + explicación + acción opcional.
class WebEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const WebEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68, height: 68,
              decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(18)),
              child: Icon(icon, color: MployaTheme.brandAccent, size: 32),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: context.textTertiary, fontSize: 14, height: 1.5)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              WebButton(icon: actionIcon, label: actionLabel!, onTap: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}
