import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';

const double mpTabletBreakpoint = 700;
const double mpDesktopBreakpoint = 1100;
const double mpExpandedNavigationBreakpoint = 1280;
const double mpWideBreakpoint = 1600;

enum MpViewport { mobile, tablet, desktop, wide }

MpViewport mpViewportForWidth(double width) {
  if (width >= mpWideBreakpoint) return MpViewport.wide;
  if (width >= mpDesktopBreakpoint) return MpViewport.desktop;
  if (width >= mpTabletBreakpoint) return MpViewport.tablet;
  return MpViewport.mobile;
}

MpViewport mpViewportOf(BuildContext context) =>
    mpViewportForWidth(MediaQuery.sizeOf(context).width);

extension MpViewportX on MpViewport {
  bool get isMobile => this == MpViewport.mobile;
  bool get isTablet => this == MpViewport.tablet;
  bool get isDesktop => this == MpViewport.desktop;
  bool get isWide => this == MpViewport.wide;
  bool get usesPersistentNavigation => !isMobile;
}

double mpPageGutter(double width) => switch (mpViewportForWidth(width)) {
  MpViewport.mobile => MpTokens.screenPadding,
  MpViewport.tablet => MpTokens.space20,
  MpViewport.desktop => MpTokens.space24,
  MpViewport.wide => MpTokens.space32,
};

double mpContentMaxWidth(double width) => switch (mpViewportForWidth(width)) {
  MpViewport.mobile => width,
  MpViewport.tablet => 1040,
  MpViewport.desktop => 1360,
  MpViewport.wide => 1440,
};

bool mpNavigationIsCompact(double width) =>
    width < mpExpandedNavigationBreakpoint;

double mpNavigationWidth(double width) =>
    mpNavigationIsCompact(width) ? 84 : 236;

/// Base opcional para pantallas anchas. No altera Mobile cuando [padMobile]
/// es falso, lo que permite adoptarla gradualmente sin mover lo aprobado.
class MpResponsiveContent extends StatelessWidget {
  final Widget child;
  final bool padMobile;
  final bool applyGutter;
  final double? maxWidth;

  const MpResponsiveContent({
    super.key,
    required this.child,
    this.padMobile = false,
    this.applyGutter = true,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final viewport = mpViewportForWidth(width);
    if (viewport.isMobile && !padMobile) return child;

    final gutter = applyGutter ? mpPageGutter(width) : 0.0;
    return Padding(
      padding: EdgeInsets.all(gutter),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? mpContentMaxWidth(width),
          ),
          child: child,
        ),
      ),
    );
  }
}
