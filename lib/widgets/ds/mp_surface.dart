import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// SUPERFICIES
///
/// Los 87 FINAL_SCREENS no son "una app clara con modo oscuro". Son TRES
/// superficies con reglas propias, y cuál se usa depende de la pantalla, no de
/// la preferencia del sistema operativo:
///
///   MpSurfaceKind.auth   claro + NARANJA de marca
///                        → bienvenida, iniciar sesión, crear cuenta
///
///   MpSurfaceKind.light  claro + VIOLETA de producto
///                        → empresa, headhunter, formularios, perfil, ajustes
///
///   MpSurfaceKind.dark   negro azulado + VIOLETA de producto
///                        → feed de video, notificaciones, historias, llamada
///
/// Por eso los componentes de este sistema NO leen `CupertinoTheme.brightnessOf`:
/// leen `MpSurface.of(context)`. Si un widget se pinta según el brillo del
/// sistema, el feed se vuelve blanco cuando el usuario tiene el móvil en claro,
/// que es exactamente lo que los mockups no hacen.
/// ─────────────────────────────────────────────────────────────────────────────

enum MpSurfaceKind { auth, light, dark }

@immutable
class MpSurfaceStyle {
  final MpSurfaceKind kind;

  /// Fondo de la pantalla.
  final Color bg;

  /// Superficie de tarjeta / panel.
  final Color card;

  /// Relleno sutil: inputs en reposo, chips inactivos, filas alternas.
  final Color fill;

  /// Borde de tarjeta e input.
  final Color border;

  /// Borde más marcado: divisores, foco en reposo.
  final Color borderStrong;

  final Color text;
  final Color textSecondary;
  final Color textTertiary;

  /// Color de acción de ESTA superficie: naranja en auth, violeta en producto.
  final Color accent;

  /// Degradado del CTA lleno de esta superficie.
  final LinearGradient accentGradient;

  /// Sombra de tarjeta. Vacía en oscuro: ahí separa el borde, no la sombra.
  final List<BoxShadow> cardShadow;

  const MpSurfaceStyle({
    required this.kind,
    required this.bg,
    required this.card,
    required this.fill,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentGradient,
    required this.cardShadow,
  });

  bool get isDark => kind == MpSurfaceKind.dark;

  /// Superficie de entrada: blanca, con el naranja de marca como acción.
  static const MpSurfaceStyle auth = MpSurfaceStyle(
    kind: MpSurfaceKind.auth,
    bg: MpTokens.lightCard,
    card: MpTokens.lightCard,
    fill: MpTokens.lightFill,
    border: MpTokens.lightBorder,
    borderStrong: MpTokens.lightBorderStrong,
    text: MpTokens.lightText,
    textSecondary: MpTokens.lightTextSecondary,
    textTertiary: MpTokens.lightTextTertiary,
    accent: MpTokens.brandOrange,
    accentGradient: MpTokens.brandGradient,
    cardShadow: [],
  );

  /// Superficie de producto clara: empresa, headhunter, formularios.
  static final MpSurfaceStyle light = MpSurfaceStyle(
    kind: MpSurfaceKind.light,
    bg: MpTokens.lightBg,
    card: MpTokens.lightCard,
    fill: MpTokens.lightFill,
    border: MpTokens.lightBorder,
    borderStrong: MpTokens.lightBorderStrong,
    text: MpTokens.lightText,
    textSecondary: MpTokens.lightTextSecondary,
    textTertiary: MpTokens.lightTextTertiary,
    accent: MpTokens.primary,
    accentGradient: MpTokens.primaryGradient,
    cardShadow: MpTokens.cardShadow,
  );

  /// Superficie de producto oscura: feed, notificaciones, video.
  static const MpSurfaceStyle dark = MpSurfaceStyle(
    kind: MpSurfaceKind.dark,
    bg: MpTokens.darkBg,
    card: MpTokens.darkCard,
    fill: MpTokens.darkElevated,
    border: MpTokens.darkBorder,
    borderStrong: MpTokens.darkBorder,
    text: MpTokens.darkText,
    textSecondary: MpTokens.darkTextSecondary,
    textTertiary: MpTokens.darkTextTertiary,
    accent: MpTokens.primary,
    accentGradient: MpTokens.primaryGradient,
    cardShadow: [],
  );

  static MpSurfaceStyle forKind(MpSurfaceKind kind) => switch (kind) {
        MpSurfaceKind.auth => auth,
        MpSurfaceKind.light => light,
        MpSurfaceKind.dark => dark,
      };

  /// Un color de acento sobre el fondo de esta superficie, al alfa correcto
  /// para cada modo. Es el relleno de los chips y de los cuadrados de ícono.
  Color tint(Color color, {double? alpha}) =>
      color.withValues(alpha: alpha ?? (isDark ? 0.18 : 0.10));
}

/// Propaga la superficie activa hacia abajo en el árbol.
class MpSurface extends InheritedWidget {
  final MpSurfaceStyle style;

  const MpSurface({super.key, required this.style, required super.child});

  /// Superficie activa. Si no hay ninguna declarada arriba, cae en la clara de
  /// producto — el caso más común y el que menos sorprende visualmente.
  static MpSurfaceStyle of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<MpSurface>();
    return widget?.style ?? MpSurfaceStyle.light;
  }

  @override
  bool updateShouldNotify(MpSurface oldWidget) => oldWidget.style != style;
}

/// Azúcar: `MpSurface.of(context)` en cada build es ruidoso.
extension MpSurfaceContext on BuildContext {
  MpSurfaceStyle get mp => MpSurface.of(this);
}

/// Página del sistema: declara la superficie, pinta su fondo y la propaga.
///
/// Reemplaza el par `CupertinoPageScaffold(backgroundColor: ...)` + colores
/// sueltos por pantalla, que es de donde vienen las inconsistencias.
class MpScaffold extends StatelessWidget {
  final MpSurfaceKind surface;
  final Widget child;

  /// Fondo propio (p. ej. un video a pantalla completa en el feed). Se dibuja
  /// por debajo de [child] y reemplaza al color plano de la superficie.
  final Widget? background;

  /// Barra inferior fija, típicamente [MpBottomNav].
  final Widget? bottomBar;

  /// Envolver en SafeArea. Se apaga en pantallas de video a sangre completa.
  final bool safeArea;

  const MpScaffold({
    super.key,
    required this.surface,
    required this.child,
    this.background,
    this.bottomBar,
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = MpSurfaceStyle.forKind(surface);

    Widget content = child;
    if (safeArea) {
      // El bottom lo maneja la propia barra: si lo tomara también el SafeArea,
      // quedaría un doble margen bajo la nav.
      content = SafeArea(bottom: bottomBar == null, child: content);
    }

    if (bottomBar != null) {
      content = Column(
        children: [
          Expanded(child: content),
          bottomBar!,
        ],
      );
    }

    return MpSurface(
      style: style,
      child: CupertinoPageScaffold(
        backgroundColor: style.bg,
        child: background == null
            ? content
            : Stack(
                fit: StackFit.expand,
                children: [background!, content],
              ),
      ),
    );
  }
}
