import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';
import '../premium_paywall_screen.dart';
import '../settings_screen.dart';
import 'empresa_actividad_screen.dart';
import 'empresa_busqueda_screen.dart';
import 'empresa_configuracion_screen.dart';
import 'empresa_confidenciales_screen.dart';
import 'empresa_contrataciones_screen.dart';
import 'empresa_creditos_screen.dart';
import 'empresa_entrevistas_screen.dart';
import 'empresa_ofertas_screen.dart';
import 'empresa_rendimiento_screen.dart';
import 'empresa_video_pitch_screen.dart';
import 'empresa_guardados_screen.dart';
import 'empresa_perfil_screen.dart';
import 'empresa_pipeline_screen.dart';
import 'empresa_verificacion_screen.dart';
import 'empresa_filtros_screen.dart';
import 'empresa_publicar_vacante_screen.dart';
import 'empresa_talent_feed_screen.dart';
import 'empresa_vacantes_screen.dart';

/// Herramientas de Empresa.
///
/// RECONSTRUCCIÓN DIRECTA desde `mis herramientas.png` (08. Mis Herramientas),
/// que es literalmente esta pantalla: su barra inferior es la de Empresa
/// —Inicio · Mapa · (+) · Mensajes · Herramientas— con Herramientas activa.
///
/// Orden del PNG: título + campana · banner premium violeta · "Accesos rápidos"
/// (4 tarjetas con contador) · "Herramientas de IA" (filas con ícono en círculo
/// de color) · "Más herramientas" (filas).
///
/// REGLA APLICADA: sólo se listan módulos que EXISTEN hoy en el proyecto. Las
/// herramientas del mockup que todavía no tienen pantalla no se dibujan como
/// filas muertas — se omiten. Y los contadores del mockup (12 en proceso, 24
/// candidatos, 156 vistas) NO se copian: van los datos reales que se le pasen,
/// y si no hay, no se muestra subtítulo.
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 12/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// ADENDA 29/8/2026: el botón "Upgrade" del banner premium llevaba a
/// `SettingsScreen` (configuración general: tema, notificaciones, cerrar
/// sesión) en vez de a la pantalla de suscripción. Bug funcional concreto
/// — Pedro lo detectó probando la app ("te lleva a una pantalla del
/// teléfono"). Se corrigió para ir directo a `PremiumPaywallScreen`, que es
/// el mismo destino que usan los demás CTA de "Premium"/"Upgrade" del
/// proyecto (`ats_dashboard_screen.dart`, `b2b_paywall_screen.dart`,
/// `settings_screen.dart`).
///
class EmpresaHerramientasScreen extends StatelessWidget {
  /// Contadores reales. Null = no se muestra el subtítulo de esa tarjeta.
  final int? enProceso;
  final int? entrevistasAgendadas;
  final int? candidatosGuardados;
  final int unreadNotifications;

  const EmpresaHerramientasScreen({
    super.key,
    this.enProceso,
    this.entrevistasAgendadas,
    this.candidatosGuardados,
    this.unreadNotifications = 0,
  });

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                MpTokens.screenPadding,
                MpTokens.space12,
                MpTokens.screenPadding,
                MpTokens.space32,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _encabezado(context),
                  const SizedBox(height: MpTokens.space20),
                  _bannerPremium(context),
                  const SizedBox(height: MpTokens.space24),
                  _seccion(context, 'Accesos rápidos'),
                  const SizedBox(height: MpTokens.space12),
                  _accesosRapidos(context),
                  const SizedBox(height: MpTokens.space24),
                  _seccion(context, 'Herramientas de IA'),
                  const SizedBox(height: MpTokens.space12),
                  _herramientasIA(context),
                  const SizedBox(height: MpTokens.space24),
                  _seccion(context, 'Más herramientas'),
                  const SizedBox(height: MpTokens.space12),
                  _masHerramientas(context),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Encabezado ────────────────────────────────────────────────────────────

  Widget _encabezado(BuildContext context) {
    final s = context.mp;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mis Herramientas',
                style: MpTokens.h1.copyWith(color: s.text),
              ),
              const SizedBox(height: MpTokens.space4),
              Text(
                'Gestioná todo tu proceso de reclutamiento',
                style: MpTokens.body.copyWith(
                  color: s.textSecondary,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: MpTokens.space12),
        GestureDetector(
          onTap: () => _push(context, const EmpresaActividadScreen()),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(top: 2, right: 2),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(CupertinoIcons.bell, size: 27, color: s.text),
                if (unreadNotifications > 0)
                  Positioned(
                    top: -8,
                    right: -9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      constraints: const BoxConstraints(minWidth: 22),
                      decoration: BoxDecoration(
                        color: MpTokens.primary,
                        borderRadius:
                            BorderRadius.circular(MpTokens.radiusPill),
                        border: Border.all(color: s.bg, width: 2),
                      ),
                      child: Text(
                        '$unreadNotifications',
                        textAlign: TextAlign.center,
                        style: MpTokens.micro.copyWith(
                          color: const Color(0xFFFFFFFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _seccion(BuildContext context, String titulo) {
    return Text(
      titulo,
      style: MpTokens.h2.copyWith(color: context.mp.text, fontSize: 18),
    );
  }

  // ── Banner premium ────────────────────────────────────────────────────────

  Widget _bannerPremium(BuildContext context) {
    const white = Color(0xFFFFFFFF);

    return GestureDetector(
      onTap: () => _push(context, const PremiumPaywallScreen()),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(MpTokens.space16),
        decoration: BoxDecoration(
          gradient: MpTokens.heroGradient,
          borderRadius: BorderRadius.circular(MpTokens.radiusXL),
          boxShadow: MpTokens.glow(MpTokens.primary),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0x33FFFFFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.bolt_fill,
                size: 22,
                color: white,
              ),
            ),
            const SizedBox(width: MpTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Potenciá tu contratación',
                    style: MpTokens.title.copyWith(color: white, fontSize: 15.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Activá Mploya Premium y accedé a herramientas avanzadas con IA.',
                    style: MpTokens.caption.copyWith(
                      color: const Color(0xE6FFFFFF),
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: MpTokens.space8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(MpTokens.radiusMD),
              ),
              child: Text(
                'Upgrade',
                style: MpTokens.label.copyWith(
                  color: MpTokens.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Accesos rápidos ───────────────────────────────────────────────────────

  Widget _accesosRapidos(BuildContext context) {
    final items = <_Acceso>[
      _Acceso(
        icon: CupertinoIcons.person_2,
        color: MpTokens.primary,
        titulo: 'Pipeline',
        // Sin dato real no se inventa "12 en proceso".
        pie: enProceso == null ? null : '$enProceso en proceso',
        destino: const EmpresaPipelineScreen(),
      ),
      _Acceso(
        icon: CupertinoIcons.calendar,
        color: MpTokens.catOrange,
        titulo: 'Entrevistas',
        pie: entrevistasAgendadas == null
            ? null
            : '$entrevistasAgendadas agendadas',
        destino: const EmpresaEntrevistasScreen(),
      ),
      _Acceso(
        icon: CupertinoIcons.bookmark,
        color: MpTokens.catGreen,
        titulo: 'Guardados',
        pie: candidatosGuardados == null
            ? null
            : '$candidatosGuardados ${candidatosGuardados == 1 ? 'candidato' : 'candidatos'}',
        destino: const EmpresaGuardadosScreen(),
      ),
      _Acceso(
        icon: CupertinoIcons.chart_bar_alt_fill,
        color: MpTokens.catBlue,
        titulo: 'Métricas',
        pie: null,
        destino: const EmpresaRendimientoScreen(),
      ),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: MpTokens.space8),
            Expanded(child: _accesoCard(context, items[i])),
          ],
        ],
      ),
    );
  }

  Widget _accesoCard(BuildContext context, _Acceso acceso) {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.symmetric(
        horizontal: MpTokens.space4,
        vertical: MpTokens.space16,
      ),
      onTap: () => _push(context, acceso.destino),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(acceso.icon, size: 25, color: acceso.color),
          const SizedBox(height: MpTokens.space8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              acceso.titulo,
              style: MpTokens.label.copyWith(color: s.text, fontSize: 13),
            ),
          ),
          if (acceso.pie != null) ...[
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                acceso.pie!,
                style: MpTokens.micro.copyWith(
                  color: s.textTertiary,
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Listas de herramientas ────────────────────────────────────────────────

  Widget _herramientasIA(BuildContext context) {
    return MpRowGroup(
      dividerIndent: 62,
      rows: [
        _fila(
          context,
          icon: CupertinoIcons.sparkles,
          color: MpTokens.primary,
          titulo: 'Match IA',
          subtitulo: 'Encontrá candidatos ideales 10x más rápido.',
          destino: const EmpresaTalentFeedScreen(),
        ),
        _fila(
          context,
          icon: CupertinoIcons.doc_text,
          color: MpTokens.catBlue,
          titulo: 'Redacción con IA',
          subtitulo: 'Creá descripciones de puesto en segundos.',
          destino: const EmpresaPublicarVacanteScreen(),
        ),
        _fila(
          context,
          icon: CupertinoIcons.search,
          color: MpTokens.catPurple,
          titulo: 'Buscar talento',
          subtitulo: 'Buscá por habilidad o dejá que la IA recomiende.',
          destino: const EmpresaBusquedaScreen(),
        ),
        _fila(
          context,
          icon: CupertinoIcons.chart_bar_alt_fill,
          color: MpTokens.catOrange,
          // Antes decía "Análisis de candidatos · Evaluá habilidades y ajuste
          // con IA". Prometía un análisis que el destino no hace: abre el
          // Pipeline, que hoy sólo informa el estado del proceso. El destino no
          // cambia; el texto ahora lo describe.
          titulo: 'Seguimiento de candidatos',
          subtitulo: 'En qué etapa está cada proceso abierto.',
          destino: const EmpresaPipelineScreen(),
        ),
      ],
    );
  }

  Widget _masHerramientas(BuildContext context) {
    return MpRowGroup(
      dividerIndent: 62,
      rows: [
        _fila(
          context,
          icon: CupertinoIcons.speaker_2_fill,
          color: MpTokens.primary,
          titulo: 'Publicar vacante',
          subtitulo: 'Creá y publicá una nueva búsqueda.',
          destino: const EmpresaPublicarVacanteScreen(),
        ),
        _fila(
          context,
          icon: CupertinoIcons.briefcase,
          color: MpTokens.catGreen,
          titulo: 'Mis vacantes',
          subtitulo: 'Gestioná tus vacantes publicadas.',
          destino: const EmpresaVacantesScreen(),
        ),
        _fila(
          context,
          icon: CupertinoIcons.folder,
          color: MpTokens.catIndigo,
          titulo: 'Base de talento',
          subtitulo: 'Administrá tus candidatos guardados.',
          destino: const EmpresaGuardadosScreen(),
        ),
        _fila(
          context,
          icon: CupertinoIcons.slider_horizontal_3,
          color: MpTokens.catBlue,
          titulo: 'Filtros avanzados',
          subtitulo: 'Buscá talento por habilidad, ciudad y distancia.',
          destino: const EmpresaFiltrosScreen(),
        ),
        _fila(
          context,
          icon: CupertinoIcons.checkmark_seal,
          color: MpTokens.success,
          titulo: 'Verificación de empresa',
          subtitulo: 'Tu nivel de verificación y su historial.',
          destino: const EmpresaVerificacionScreen(),
        ),
        _fila(
          context,
          icon: CupertinoIcons.lock_fill,
          color: MpTokens.catPurple,
          titulo: 'Talento confidencial',
          subtitulo: 'Perfiles reservados y tus créditos de desbloqueo.',
          destino: const EmpresaConfidencialesScreen(),
        ),
        _fila(
          context,
          icon: CupertinoIcons.building_2_fill,
          color: MpTokens.catBlue,
          titulo: 'Perfil de empresa',
          subtitulo: 'Así te ven los candidatos.',
          destino: const EmpresaPerfilScreen(),
        ),
        _fila(
          context,
          icon: CupertinoIcons.creditcard,
          color: MpTokens.premium,
          titulo: 'Créditos',
          subtitulo: 'Tu saldo y los perfiles que desbloqueaste.',
          destino: const EmpresaCreditosScreen(),
        ),
        _fila(
          context,
          icon: CupertinoIcons.paperplane,
          color: MpTokens.catBlue,
          titulo: 'Ofertas',
          subtitulo: 'Candidatos con oferta, por vacante.',
          destino: const EmpresaOfertasScreen(),
        ),
        _fila(
          context,
          icon: CupertinoIcons.check_mark_circled_solid,
          color: MpTokens.catGreen,
          titulo: 'Contrataciones',
          subtitulo: 'Personas registradas como contratadas en tu proceso.',
          destino: const EmpresaContratacionesScreen(),
        ),
        _fila(
          context,
          icon: CupertinoIcons.chart_bar_square,
          color: MpTokens.primary,
          titulo: 'Rendimiento de vacantes',
          subtitulo: 'Cuáles atraen candidatos y cuáles no.',
          destino: const EmpresaRendimientoScreen(),
        ),
        _fila(
          context,
          icon: CupertinoIcons.videocam_fill,
          color: MpTokens.catOrange,
          titulo: 'Video de tu empresa',
          subtitulo: 'Contales quiénes son en 60 segundos.',
          destino: const EmpresaVideoPitchScreen(),
        ),
        _fila(
          context,
          icon: CupertinoIcons.slider_horizontal_3,
          color: MpTokens.catIndigo,
          titulo: 'Configuración de empresa',
          subtitulo: 'Notificaciones y preferencias de reclutamiento.',
          destino: const EmpresaConfiguracionScreen(),
        ),
        // No duplica "Configuración de empresa": aquélla son las preferencias
        // de reclutamiento; ésta es la cuenta en sí —contraseña, usuarios
        // bloqueados, tema y cerrar sesión—, que la pantalla nueva no cubre.
        // Se renombra para que no parezcan la misma opción.
        _fila(
          context,
          icon: CupertinoIcons.person_crop_circle,
          color: MpTokens.catPurple,
          titulo: 'Cuenta y seguridad',
          subtitulo: 'Contraseña, privacidad, tema y cerrar sesión.',
          destino: const SettingsScreen(),
        ),
      ],
    );
  }

  MpListRow _fila(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String titulo,
    required String subtitulo,
    required Widget destino,
  }) {
    return MpListRow(
      leading: MpIconTile(icon: icon, color: color, size: 38, circular: true),
      title: titulo,
      subtitle: subtitulo,
      onTap: () => _push(context, destino),
    );
  }
}

class _Acceso {
  final IconData icon;
  final Color color;
  final String titulo;
  final String? pie;
  final Widget destino;

  const _Acceso({
    required this.icon,
    required this.color,
    required this.titulo,
    required this.pie,
    required this.destino,
  });
}
