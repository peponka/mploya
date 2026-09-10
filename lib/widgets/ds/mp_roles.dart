import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'mp_nav.dart';
import 'mp_surface.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// PATRONES POR ROL
///
/// Leído de los 87 PNG: los tres roles comparten tokens y componentes, y se
/// diferencian en tres cosas concretas. Nada más. Codificarlas acá evita que
/// cada pantalla vuelva a inventarlas.
///
///   1. SUPERFICIE POR DEFECTO
///      Candidato  → mezcla: oscura en consumo de video (feed, historias,
///                   notificaciones, llamada), clara en gestión (perfil,
///                   postulaciones, formularios).
///      Empresa    → clara siempre.
///      Headhunter → clara siempre.
///
///   2. BARRA INFERIOR (siempre 4 pestañas + acción central)
///      Candidato  Inicio · Explorar · (+) · Mensajes · Perfil
///      Empresa    Inicio · Candidatos · (+) · Mensajes · Empresa
///      Headhunter Dashboard · Clientes · (+) · Búsquedas · Talent Pool
///
///   3. COLOR DE CATEGORÍA del rol, usado en la selección de rol y en avatares
///      o etiquetas que distinguen de quién es una tarjeta.
///
/// El color de ACCIÓN es violeta en los tres. El naranja es solo de la
/// superficie de entrada.
/// ─────────────────────────────────────────────────────────────────────────────

enum MpRole { candidato, confidencial, empresa, headhunter }

extension MpRolePattern on MpRole {
  /// Etiqueta tal como aparece en la pantalla de bienvenida.
  String get title => switch (this) {
    MpRole.candidato => 'Soy Candidato',
    MpRole.confidencial => 'Candidato Confidencial',
    MpRole.empresa => 'Soy Empresa',
    MpRole.headhunter => 'Soy Headhunter',
  };

  String get tagline => switch (this) {
    MpRole.candidato => 'Busco oportunidades',
    MpRole.confidencial => 'Exploro en privado',
    MpRole.empresa => 'Publico vacantes',
    MpRole.headhunter => 'Busco talento',
  };

  IconData get icon => switch (this) {
    MpRole.candidato => CupertinoIcons.person_fill,
    MpRole.confidencial => CupertinoIcons.eye_slash_fill,
    MpRole.empresa => CupertinoIcons.building_2_fill,
    MpRole.headhunter => CupertinoIcons.briefcase_fill,
  };

  /// Color del círculo de la tarjeta de rol. Medidos en
  /// `01_Bienvenida_SeleccionRol.png`.
  Color get color => switch (this) {
    MpRole.candidato => MpTokens.catOrange,
    MpRole.confidencial => MpTokens.catIndigo,
    MpRole.empresa => MpTokens.catGreen,
    MpRole.headhunter => MpTokens.catPurple,
  };

  /// Superficie de las pantallas de gestión de este rol.
  MpSurfaceKind get surface => MpSurfaceKind.light;

  /// Las 4 pestañas de la barra inferior. La acción central va aparte.
  List<MpNavItem> navItems({int unreadMessages = 0}) => switch (this) {
    MpRole.candidato || MpRole.confidencial => [
      const MpNavItem(icon: CupertinoIcons.house_fill, label: 'Inicio'),
      const MpNavItem(icon: CupertinoIcons.briefcase_fill, label: 'Vacantes'),
      MpNavItem(
        icon: CupertinoIcons.chat_bubble_2_fill,
        label: 'Mensajes',
        badge: unreadMessages,
      ),
      const MpNavItem(
        icon: CupertinoIcons.square_grid_2x2,
        label: 'Herramientas',
      ),
    ],
    // Medido en `dashboard empresa.png` y `video pantalla completa
    // candidato.png`: la barra de Empresa es Inicio · Mapa · (+) ·
    // Mensajes · Herramientas.
    MpRole.empresa => [
      const MpNavItem(icon: CupertinoIcons.house, label: 'Inicio'),
      const MpNavItem(
        // Pin de mapa, no la flecha de navegación.
        icon: CupertinoIcons.placemark,
        label: 'Mapa',
      ),
      MpNavItem(
        icon: CupertinoIcons.chat_bubble_2,
        label: 'Mensajes',
        badge: unreadMessages,
      ),
      // Antes "Herramientas" — la auditoría de navegabilidad (10/9/2026)
      // mostró que Vacantes, el objeto central del flujo de Empresa, vivía
      // sólo escondido dentro del menú "+". Herramientas sigue accesible
      // desde ahí ("Ir a Herramientas").
      const MpNavItem(icon: CupertinoIcons.briefcase, label: 'Vacantes'),
    ],
    MpRole.headhunter => [
      const MpNavItem(icon: CupertinoIcons.house_fill, label: 'Dashboard'),
      const MpNavItem(icon: CupertinoIcons.building_2_fill, label: 'Clientes'),
      const MpNavItem(icon: CupertinoIcons.scope, label: 'Búsquedas'),
      const MpNavItem(
        icon: CupertinoIcons.square_grid_2x2,
        label: 'Herramientas',
      ),
    ],
  };

  /// Etiqueta bajo el botón central. Antes iba sin texto en Empresa y
  /// Headhunter (medido en `dashboard empresa.png`), pero ese botón en la
  /// práctica abre el menú principal de esos roles, no solo "crear" — así
  /// que lleva etiqueta para no leerse como un simple botón de publicar.
  String? get centerLabel => switch (this) {
    MpRole.candidato || MpRole.confidencial => 'Publicar',
    MpRole.empresa => 'Accesos',
    MpRole.headhunter => 'Accesos',
  };
}
