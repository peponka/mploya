/// Utilidades responsive para mploya web.
///
/// Provee breakpoints y widgets para adaptar la UI
/// a mobile, tablet y desktop.
library;

import 'package:flutter/material.dart';

// ─── Breakpoints ────────────────────────────────────────────────────

/// Breakpoints de diseño para layouts responsive.
abstract final class Breakpoints {
  /// Ancho máximo para layout mobile (< 768px).
  static const double mobile = 768;

  /// Ancho máximo para layout tablet (< 1200px).
  static const double tablet = 1200;

  /// Ancho mínimo para layout desktop (>= 1200px).
  static const double desktop = 1200;
}

/// Tipo de dispositivo basado en el ancho de pantalla.
enum DeviceType { mobile, tablet, desktop }

/// Retorna el [DeviceType] actual según el ancho de [context].
DeviceType getDeviceType(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < Breakpoints.mobile) return DeviceType.mobile;
  if (width < Breakpoints.tablet) return DeviceType.tablet;
  return DeviceType.desktop;
}

/// `true` si el ancho actual es >= [Breakpoints.desktop].
bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.desktop;

/// `true` si el ancho actual es < [Breakpoints.mobile].
bool isMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width < Breakpoints.mobile;

/// `true` si el ancho actual es >= [Breakpoints.mobile] y < [Breakpoints.tablet].
bool isTablet(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width >= Breakpoints.mobile && width < Breakpoints.tablet;
}

// ─── Responsive Layout Widget ───────────────────────────────────────

/// Widget que muestra diferentes layouts según el ancho de pantalla.
///
/// ```dart
/// ResponsiveLayout(
///   mobile: MobileView(),
///   tablet: TabletView(),   // opcional, usa mobile si no se provee
///   desktop: DesktopView(),
/// )
/// ```
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.mobile,
    required this.desktop,
    this.tablet,
    super.key,
  });

  /// Layout para pantallas < 768px.
  final Widget mobile;

  /// Layout para pantallas entre 768px y 1200px.
  /// Si es null, usa [mobile].
  final Widget? tablet;

  /// Layout para pantallas >= 1200px.
  final Widget desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Breakpoints.desktop) {
          return desktop;
        }
        if (constraints.maxWidth >= Breakpoints.mobile) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }
}

// ─── Constrained Content ────────────────────────────────────────────

/// Centra el contenido con un ancho máximo.
///
/// Útil para pantallas que en desktop no deberían estirarse
/// a todo el ancho (profile, alerts, settings).
class ConstrainedContent extends StatelessWidget {
  const ConstrainedContent({
    required this.child,
    this.maxWidth = 900,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
