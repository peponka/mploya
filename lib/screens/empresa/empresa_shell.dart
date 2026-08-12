import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';

/// Shell de Empresa: barra inferior en móvil, barra lateral oscura en ancho.
///
/// Móvil, medido en `dashboard empresa.png` y `video pantalla completa
/// candidato.png`:
///     Inicio · Mapa · (+) · Mensajes · Herramientas
///
/// Ancho, medido en `analytics de vacantes.png` y `busqueda global de
/// talento.png`: barra lateral oscura fija con la marca arriba, los destinos en
/// el medio y el usuario abajo.
///
/// Los índices son los del `IndexedStack` de `main_navigation.dart`; el shell
/// sólo traduce entre las ranuras del diseño y esos índices, así que no cambia
/// la navegación real de la app.
class EmpresaShell extends StatelessWidget {
  /// Índice global activo.
  final int currentIndex;

  /// Navega a un índice global.
  final ValueChanged<int> onTap;

  /// Acción del botón central (+).
  final VoidCallback onPrimaryAction;

  final Widget body;
  final int unreadMessages;
  final String companyName;

  const EmpresaShell({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onPrimaryAction,
    required this.body,
    this.unreadMessages = 0,
    this.companyName = '',
  });

  /// Ranuras de la barra inferior → índice global.
  static const _bottomSlots = <int>[7, 2, 5, 8];

  /// Destinos de la barra lateral → índice global.
  ///
  /// Deliberadamente corta: es la MISMA experiencia que en móvil más los dos
  /// destinos que el dashboard enlaza, no un menú de administración. Perfil de
  /// empresa vive en el pie y Notificaciones en la campana del encabezado.
  static const _sidebarSlots = <int>[7, 0, 6, 1, 2, 5, 8];

  static const _sidebarItems = <MpSidebarItem>[
    MpSidebarItem(icon: CupertinoIcons.house, label: 'Inicio'),
    MpSidebarItem(icon: CupertinoIcons.play_rectangle, label: 'Feed talento'),
    MpSidebarItem(icon: CupertinoIcons.briefcase, label: 'Vacantes'),
    MpSidebarItem(icon: CupertinoIcons.person_2, label: 'Pipeline'),
    MpSidebarItem(icon: CupertinoIcons.placemark, label: 'Mapa'),
    MpSidebarItem(icon: CupertinoIcons.chat_bubble_2, label: 'Mensajes'),
    MpSidebarItem(icon: CupertinoIcons.square_grid_2x2, label: 'Herramientas'),
  ];

  @override
  Widget build(BuildContext context) {
    return mpIsWide(context) ? _wide(context) : _narrow(context);
  }

  // ── Móvil ─────────────────────────────────────────────────────────────────

  Widget _narrow(BuildContext context) {
    final selected = _bottomSlots.indexOf(currentIndex);

    return MpSurface(
      style: MpSurfaceStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: MpTokens.lightBg,
        child: Column(
          children: [
            Expanded(child: body),
            MpBottomNav(
              items: MpRole.empresa.navItems(unreadMessages: unreadMessages),
              // -1 cuando la pantalla activa no es una de las cuatro ranuras
              // (p. ej. el feed de talento): no se marca ninguna en falso.
              currentIndex: selected,
              onTap: (slot) => onTap(_bottomSlots[slot]),
              onCenterTap: onPrimaryAction,
              centerLabel: MpRole.empresa.centerLabel,
            ),
          ],
        ),
      ),
    );
  }

  // ── Ancho ─────────────────────────────────────────────────────────────────

  Widget _wide(BuildContext context) {
    final selected = _sidebarSlots.indexOf(currentIndex);

    return MpSurface(
      style: MpSurfaceStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: MpTokens.lightBg,
        child: Row(
          children: [
            MpSidebar(
              items: [
                for (var i = 0; i < _sidebarItems.length; i++)
                  i == 5
                      ? MpSidebarItem(
                          icon: _sidebarItems[i].icon,
                          label: _sidebarItems[i].label,
                          badge: unreadMessages,
                        )
                      : _sidebarItems[i],
              ],
              currentIndex: selected,
              onTap: (slot) => onTap(_sidebarSlots[slot]),
              header: const _SidebarHeader(),
              footer: _SidebarFooter(
                companyName: companyName,
                onPrimaryAction: onPrimaryAction,
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(MpTokens.radiusXXL),
                ),
                child: ColoredBox(color: MpTokens.lightBg, child: body),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader();

  @override
  Widget build(BuildContext context) {
    return const MpWordmark(
      style: MpWordmarkStyle.product,
      fontSize: 24,
      onDark: true,
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  final String companyName;
  final VoidCallback onPrimaryAction;

  const _SidebarFooter({
    required this.companyName,
    required this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MpButton(
          label: 'Publicar vacante',
          icon: CupertinoIcons.add,
          expand: true,
          onPressed: onPrimaryAction,
        ),
        const SizedBox(height: MpTokens.space16),
        Row(
          children: [
            MpCompanyLogo(
              name: companyName.isEmpty ? 'Empresa' : companyName,
              color: MpTokens.primary,
              size: 34,
            ),
            const SizedBox(width: MpTokens.space8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    companyName.isEmpty ? 'Tu empresa' : companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MpTokens.label.copyWith(color: MpTokens.darkText),
                  ),
                  Text(
                    'Empresa',
                    style: MpTokens.micro.copyWith(
                      color: MpTokens.darkTextSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
