import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'mp_surface.dart';

/// Un destino de la barra inferior.
class MpNavItem {
  final IconData icon;
  final String label;

  /// Contador rojo sobre el ícono (mensajes sin leer).
  final int badge;

  const MpNavItem({required this.icon, required this.label, this.badge = 0});
}

/// Barra inferior de 5 posiciones con acción central elevada.
///
/// Es la misma estructura en los tres roles, solo cambian las etiquetas —
/// medido en los mockups:
///   Candidato   Inicio · Explorar · (+) · Mensajes · Perfil
///   Empresa     Inicio · Candidatos · (+) · Mensajes · Empresa
///   Headhunter  Dashboard · Clientes · (+) · Búsquedas · Talent Pool
///
/// Por eso [items] debe traer exactamente 4 elementos: la acción central no es
/// una pestaña, es un botón de creación.
class MpBottomNav extends StatelessWidget {
  final List<MpNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Acción central (publicar / crear).
  final VoidCallback? onCenterTap;

  /// Etiqueta bajo el botón central. En algunos mockups aparece ("Publicar") y
  /// en otros el botón va sin texto.
  final String? centerLabel;

  final IconData centerIcon;

  const MpBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.onCenterTap,
    this.centerLabel,
    this.centerIcon = CupertinoIcons.add,
  }) : assert(items.length == 4, 'La barra lleva 4 pestañas + acción central');

  /// Cuánto sobresale el botón central por encima del borde de la barra.
  /// En los mockups el FAB no está contenido en la barra: la pisa.
  static const double _overhang = 16;

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: MpTokens.navBarHeight + _overhang + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Barra propiamente dicha, anclada abajo.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MpTokens.navBarHeight + bottomInset,
            child: Container(
              padding: EdgeInsets.only(bottom: bottomInset),
              decoration: BoxDecoration(
                color: s.card,
                // El mockup no dibuja línea divisoria: la barra se separa por
                // una sombra muy suave hacia arriba.
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A0A0F).withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(child: _tab(context, 0)),
                  Expanded(child: _tab(context, 1)),
                  // Hueco reservado para el botón central.
                  const SizedBox(width: 76),
                  Expanded(child: _tab(context, 2)),
                  Expanded(child: _tab(context, 3)),
                ],
              ),
            ),
          ),
          // Botón central, elevado sobre la barra.
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset + (centerLabel != null ? 6 : 14),
            child: Center(child: _centerButton(context)),
          ),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, int index) {
    final s = context.mp;
    final item = items[index];
    final active = index == currentIndex;
    // Medido en `dashboard empresa.png`: los destinos inactivos NO son gris
    // claro, son casi tan oscuros como el texto principal. Sólo el activo se
    // tiñe de violeta.
    final color = active ? s.accent : s.textSecondary;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(item.icon, size: 23, color: color),
              if (item.badge > 0)
                Positioned(
                  top: -5,
                  right: -9,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 17),
                    decoration: BoxDecoration(
                      // El contador de la barra es VIOLETA en el mockup, no
                      // rojo: no comunica error, comunica novedad.
                      color: MpTokens.primary,
                      borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                      border: Border.all(color: s.card, width: 1.5),
                    ),
                    child: Text(
                      '${item.badge}',
                      textAlign: TextAlign.center,
                      style: MpTokens.micro.copyWith(
                        color: const Color(0xFFFFFFFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MpTokens.micro.copyWith(
              color: color,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerButton(BuildContext context) {
    final s = context.mp;

    return GestureDetector(
      onTap: onCenterTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: MpTokens.fabSize,
            height: MpTokens.fabSize,
            decoration: BoxDecoration(
              gradient: MpTokens.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: MpTokens.glow(MpTokens.primary),
            ),
            child: Icon(centerIcon, size: 27, color: const Color(0xFFFFFFFF)),
          ),
          if (centerLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              centerLabel!,
              style: MpTokens.micro.copyWith(color: s.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Botón cuadrado suave. Es el "atrás" y el de acciones del encabezado móvil:
/// 40×40, radio 14, relleno tenue — no un chevron desnudo.
class MpIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  /// Relleno sólido en el acento, con el ícono en blanco (el "+" del header de
  /// `headhunter clientes.png`).
  final bool solid;

  final Color? color;
  final double size;

  const MpIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.solid = false,
    this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final tint = color ?? s.accent;

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: solid ? tint : s.tint(tint, alpha: s.isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(MpTokens.radiusMD),
        ),
        child: Icon(
          icon,
          size: size * 0.45,
          color: solid ? const Color(0xFFFFFFFF) : (s.isDark ? s.text : tint),
        ),
      ),
    );
  }
}

/// Encabezado de pantalla móvil: atrás, título grande con subtítulo y acciones.
class MpHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  /// Centra el título entre el atrás y las acciones, en vez de alinearlo a la
  /// izquierda en tamaño grande.
  final bool centerTitle;

  const MpHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;

    final titleBlock = Column(
      crossAxisAlignment:
          centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: centerTitle
              ? MpTokens.title.copyWith(color: s.text)
              : MpTokens.h1.copyWith(color: s.text),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: MpTokens.space4),
          Text(
            subtitle!,
            textAlign: centerTitle ? TextAlign.center : TextAlign.start,
            style: MpTokens.caption.copyWith(color: s.textSecondary),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        MpTokens.space12,
        MpTokens.screenPadding,
        MpTokens.space16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null) ...[
            MpIconButton(
              icon: CupertinoIcons.chevron_left,
              onPressed: onBack,
            ),
            const SizedBox(width: MpTokens.space12),
          ],
          Expanded(child: titleBlock),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: MpTokens.space12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: MpTokens.space8),
                  actions[i],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESCRITORIO
//
// 12 de los 87 mockups no son móviles: son pantallas anchas con barra lateral
// oscura fija a la izquierda y contenido claro a la derecha
// (`creditos y planes.png`, `analytics de vacantes.png`, `candidatos
// conidenciales.png`, `busqueda global de talento.png`, …).
// Esa barra es SIEMPRE oscura, incluso cuando el contenido es claro.
// ─────────────────────────────────────────────────────────────────────────────

/// Punto de corte a partir del cual se usa el shell de escritorio.
const double kMpWideBreakpoint = 900;

bool mpIsWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kMpWideBreakpoint;

class MpSidebarItem {
  final IconData icon;
  final String label;
  final int badge;

  const MpSidebarItem({
    required this.icon,
    required this.label,
    this.badge = 0,
  });
}

/// Barra lateral oscura del shell de escritorio.
class MpSidebar extends StatelessWidget {
  final List<MpSidebarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Marca superior (normalmente [MpWordmark] en su variante para oscuro).
  final Widget? header;

  /// Tarjeta promocional / de usuario al pie.
  final Widget? footer;

  final double width;

  const MpSidebar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.header,
    this.footer,
    this.width = 236,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: MpTokens.darkBg,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: header!,
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: items.length,
                itemBuilder: (context, i) => _row(items[i], i == currentIndex,
                    () => onTap(i)),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(MpSidebarItem item, bool active, VoidCallback onTap) {
    final color = active ? const Color(0xFFFFFFFF) : MpTokens.darkTextSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active ? MpTokens.primary : const Color(0x00000000),
          borderRadius: BorderRadius.circular(MpTokens.radiusMD),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: color),
            const SizedBox(width: MpTokens.space12),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MpTokens.bodyStrong.copyWith(color: color, fontSize: 14),
              ),
            ),
            if (item.badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: active ? const Color(0x33FFFFFF) : MpTokens.primary,
                  borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                ),
                child: Text(
                  '${item.badge}',
                  style: MpTokens.micro.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontSize: 10.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shell de escritorio: barra lateral oscura + área de contenido clara.
///
/// Debajo de [kMpWideBreakpoint] devuelve solo el contenido, para que la misma
/// pantalla sirva en móvil con su [MpBottomNav].
class MpWebShell extends StatelessWidget {
  final Widget sidebar;
  final Widget child;

  const MpWebShell({super.key, required this.sidebar, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!mpIsWide(context)) return child;

    return MpSurface(
      style: MpSurfaceStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: MpTokens.lightBg,
        child: Row(
          children: [
            sidebar,
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
