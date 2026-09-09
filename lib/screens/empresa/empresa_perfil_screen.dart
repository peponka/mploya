import 'package:flutter/cupertino.dart';
import 'package:video_player/video_player.dart';

import '../../services/share_service.dart';
import '../../widgets/ds/mploya_ds.dart';
import 'company_cultura_screen.dart';
import 'empresa_cultura_editor_screen.dart';
import 'empresa_editar_perfil_screen.dart';
import 'empresa_perfil_data.dart';
import 'empresa_publicar_vacante_screen.dart';
import 'empresa_vacante_detalle_screen.dart';
import 'empresa_vacantes_data.dart';

/// Perfil público de la propia Empresa.
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 11/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ║ Su golden es protección de regresión: si falla, averiguar por qué     ║
/// ║ antes de regenerarlo.                                                 ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// DERIVACIÓN CONTROLADA de `perfil empresa premium.png` (Pantalla 39). Ojo con
/// el PNG: está escrito desde el lado del CANDIDATO —dice "Conoce a la empresa
/// antes de postularte" y su acción principal es "Guardar"—, así que la
/// estructura se conserva y el eje se invierte: acá la empresa se ve a sí misma
/// tal como la ven los candidatos, y sus acciones son editar y compartir.
///
/// Del PNG se conservan: el héroe a sangre con la marca, la fila de identidad
/// con logo y verificado, la banda de cuatro métricas, "Sobre la empresa", los
/// sectores y el carrusel de vacantes activas.
///
/// OMITIDO, y por qué. `users` no guarda: cantidad de empleados, año de
/// fundación, porcentaje de crecimiento anual, galería de cultura, lista de
/// beneficios ni oficinas con dirección. Todo eso son bloques enteros del
/// mockup que quedarían con texto de muestra. Las métricas se reemplazan por
/// las que sí existen y le importan a la empresa: vacantes, activas,
/// postulaciones y valoración como empleador (`employer_rating_*`), esta última
/// sólo si alguien la calificó.
///
/// Cantidad de empleados, año de fundación, crecimiento, galería de cultura
/// y valores DEJARON de estar omitidos el 29/8/2026: ver ADENDA más abajo y
/// `046_company_culture.sql`. Beneficios y oficinas con dirección siguen sin
/// tener dónde guardarse.
///
/// POLISH VISUAL 15/8/2026 — héroe con VIDEO cuando `empresa.videoUrl` existe
/// (la empresa grabó su pitch en la pantalla congelada
/// `EmpresaVideoPitchScreen`, pero hasta ahora ningún otro lugar de la app lo
/// mostraba). Sin video, se conserva el héroe de banner/degradado de
/// siempre — no se inventa un video.
///
/// Se evaluó pasar TODA la superficie a oscuro para acercarse más al PNG (que
/// es de fondo negro), pero se descartó: `MpSurface` documenta "perfil" como
/// superficie CLARA a propósito (junto con empresa/headhunter/formularios), y
/// forzar oscuro rompía el contraste de los títulos de sección (pensados
/// contra fondo claro). El héroe, en cambio, siempre fue un bloque oscuro
/// sobre cuerpo claro — el video sigue esa misma convención ya aprobada.
///
/// ADENDA 29/8/2026 — se agregó la tarjeta "Cultura de la empresa" (antes
/// OMITIDA, ver más arriba) porque Pedro pidió construirla en serio y ya
/// existe dónde guardarla (`046_company_culture.sql` + `CompanyCultureService`).
/// Es aditiva: no toca el héroe ni las métricas, sólo agrega una tarjeta más
/// en `_cuerpo()`, mismo patrón que `_ubicacion()`.
class EmpresaPerfilScreen extends StatefulWidget {
  /// Datos ya resueltos, para los golden tests.
  final PerfilEmpresa? previewData;

  const EmpresaPerfilScreen({super.key, this.previewData});

  @override
  State<EmpresaPerfilScreen> createState() => _EmpresaPerfilScreenState();
}

class _EmpresaPerfilScreenState extends State<EmpresaPerfilScreen> {
  PerfilEmpresa? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.previewData != null) {
      _data = widget.previewData;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (widget.previewData != null) return;
    if (!mounted) return;
    setState(() => _loading = true);
    final data = await loadPerfilEmpresa();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  /// Sólo cambia el DESTINO, no el diseño de esta pantalla (congelada): el
  /// formulario legacy concatenaba seis campos dentro de `about` y al reabrirlo
  /// no se podían separar. La edición nueva escribe columna por columna.
  Future<void> _editar() async {
    final empresa = _data?.empresa;
    if (empresa == null) return;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => EmpresaEditarPerfilScreen(empresa: empresa),
      ),
    );
    await _load();
  }

  Future<void> _compartir() async {
    final data = _data;
    if (data == null) return;
    await ShareService.instance.shareProfile(
      name: data.empresa.name,
      headline: data.empresa.headline,
      userId: data.empresa.id,
      accountType: 'empresa',
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: MpTokens.lightBg,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 15))
            : _data == null
            ? SafeArea(
                child: MpEmptyState(
                  icon: CupertinoIcons.building_2_fill,
                  title: 'No pudimos cargar tu perfil',
                  message: 'Revisá tu conexión y volvé a intentar.',
                  actionLabel: 'Reintentar',
                  onAction: _load,
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        CupertinoSliverRefreshControl(onRefresh: _load),
                        SliverToBoxAdapter(child: _hero()),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            MpTokens.screenPadding,
                            MpTokens.space16,
                            MpTokens.screenPadding,
                            MpTokens.space24,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate(_cuerpo()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _barraAcciones(),
                ],
              ),
      ),
    );
  }

  // ── Héroe ──────────────────────────────────────────────────────────────────

  Widget _hero() {
    final e = _data!.empresa;
    final imagen = (e.bannerUrl?.isNotEmpty ?? false) ? e.bannerUrl : null;
    final video = (e.videoUrl?.isNotEmpty ?? false) ? e.videoUrl : null;

    return Stack(
      children: [
        if (video != null)
          _CompanyVideoPoster(videoUrl: video)
        else
          Container(
            height: 208,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: imagen == null ? MpTokens.heroGradient : null,
              image: imagen == null
                  ? null
                  : DecorationImage(
                      image: NetworkImage(imagen),
                      fit: BoxFit.cover,
                    ),
            ),
          ),
        if (imagen != null && video == null)
          Container(
            height: 208,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000810), Color(0xCC000810)],
              ),
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MpTokens.screenPadding,
                vertical: MpTokens.space8,
              ),
              child: Row(
                children: [
                  if (Navigator.of(context).canPop())
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Color(0x66000810),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.chevron_left,
                          size: 19,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _load,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0x66000810),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.refresh,
                        size: 18,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: MpTokens.screenPadding,
          right: MpTokens.screenPadding,
          bottom: MpTokens.space16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // El logo va sobre una placa blanca, como en el PNG 39. Antes se
              // le pasaba blanco como color de relleno y el monograma —que el
              // componente dibuja siempre en blanco— quedaba invisible.
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: MpTokens.lightCard,
                  borderRadius: BorderRadius.circular(MpTokens.radiusLG),
                ),
                child: MpCompanyLogo(
                  name: _data!.empresa.name,
                  color: MpTokens.primary,
                  size: 48,
                  image: (_data!.empresa.avatarUrl?.isNotEmpty ?? false)
                      ? NetworkImage(_data!.empresa.avatarUrl!)
                      : null,
                ),
              ),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _data!.empresa.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MpTokens.h1.copyWith(
                              color: const Color(0xFFFFFFFF),
                              fontSize: 23,
                            ),
                          ),
                        ),
                        if (_data!.empresa.isVerified) ...[
                          const SizedBox(width: 6),
                          const MpVerifiedBadge(size: 16),
                        ],
                      ],
                    ),
                    if (_data!.empresa.headline.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _data!.empresa.headline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: MpTokens.caption.copyWith(
                              color: const Color(0xE6FFFFFF),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x33FFFFFF),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0x33FFFFFF),
                              ),
                            ),
                            child: Text(
                              'Empresa · Perfil público',
                              style: MpTokens.micro.copyWith(
                                color: const Color(0xFFFFFFFF),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Empresa · Perfil público',
                        style: MpTokens.caption.copyWith(
                          color: const Color(0xE6FFFFFF),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Cuerpo ─────────────────────────────────────────────────────────────────

  List<Widget> _cuerpo() {
    final data = _data!;

    return [
      Text(
        'Así te ven los candidatos',
        style: MpTokens.micro.copyWith(color: context.mp.textTertiary),
      ),
      const SizedBox(height: MpTokens.space12),
      // El aviso de perfil incompleto va ARRIBA de las métricas: es lo que hay
      // que resolver, y debajo de ellas se perdía.
      if (data.perfilIncompleto) ...[
        _bannerIncompleto(),
        const SizedBox(height: MpTokens.space16),
      ],
      _metricas(),
      if (data.empresa.about?.isNotEmpty ?? false) ...[
        const SizedBox(height: MpTokens.space24),
        _sobreLaEmpresa(),
      ],
      if (data.empresa.location?.isNotEmpty ?? false) ...[
        const SizedBox(height: MpTokens.space24),
        _ubicacion(),
      ],
      if (data.sectores.isNotEmpty) ...[
        const SizedBox(height: MpTokens.space24),
        _sectores(),
      ],
      const SizedBox(height: MpTokens.space24),
      _culturaCard(),
      const SizedBox(height: MpTokens.space24),
      ..._vacantes(),
    ];
  }

  Widget _culturaCard() {
    final s = context.mp;
    final empresa = _data!.empresa;

    return MpCard(
      child: Row(
        children: [
          const MpIconTile(
            icon: CupertinoIcons.building_2_fill,
            color: MpTokens.catPurple,
            size: 42,
          ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cultura de la empresa',
                  style: MpTokens.title.copyWith(color: s.text, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Video institucional, valores y el equipo.',
                  style: MpTokens.caption.copyWith(color: s.textSecondary),
                ),
              ],
            ),
          ),
          MpButton(
            label: 'Ver',
            size: MpButtonSize.small,
            variant: MpButtonVariant.outline,
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => CompanyCulturaScreen(
                  companyUserId: empresa.id,
                  companyName: empresa.name,
                ),
              ),
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          MpButton(
            label: 'Cargar',
            size: MpButtonSize.small,
            onPressed: () async {
              await Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => EmpresaCulturaEditorScreen(empresa: empresa),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Banda de métricas con divisores, la misma que usan la Shortlist y
  /// Guardados. Cuatro `MpStatTile` sueltos dejaban ~85pt por columna y
  /// "Postulaciones" se partía en "Postulacio/nes"; acá cada columna tiene el
  /// ancho completo entre divisores.
  Widget _metricas() {
    final s = context.mp;
    final data = _data!;

    final items = <({IconData icon, Color color, String valor, String etiqueta})>[
      (
        icon: CupertinoIcons.briefcase,
        color: MpTokens.primary,
        valor: '${data.vacantes.length}',
        etiqueta: 'Vacantes',
      ),
      (
        icon: CupertinoIcons.play_circle,
        color: MpTokens.catGreen,
        valor: '${data.vacantesActivas}',
        etiqueta: 'Activas',
      ),
      (
        icon: CupertinoIcons.person_2,
        color: MpTokens.catBlue,
        valor: data.postulacionesNoDisponibles ? '—' : '${data.postulaciones}',
        etiqueta: 'Postulaciones',
      ),
      // Sólo si alguien calificó de verdad: un 0.0 con estrella parecería una
      // mala reputación, y lo que pasa es que no hay reseñas.
      if (data.empresa.ratingCount > 0)
        (
          icon: CupertinoIcons.star_fill,
          color: MpTokens.premium,
          valor: data.empresa.ratingStars.toStringAsFixed(1),
          etiqueta: 'Valoración',
        ),
    ];

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.symmetric(
        horizontal: MpTokens.space8,
        vertical: MpTokens.space16,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Container(width: 1, color: s.border),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(items[i].icon, size: 17, color: items[i].color),
                    const SizedBox(height: MpTokens.space8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        items[i].valor,
                        style: MpTokens.stat.copyWith(
                          color: s.text,
                          fontSize: 21,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        items[i].etiqueta,
                        style: MpTokens.micro.copyWith(
                          color: s.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bannerIncompleto() {
    return MpBanner(
      icon: CupertinoIcons.pencil_outline,
      title: 'Tu perfil está incompleto',
      message:
          'Los candidatos ven esta ficha antes de postularse. Sumá una '
          'descripción y un titular para que sepan quién sos.',
      actionLabel: 'Completar perfil',
      onAction: _editar,
    );
  }

  Widget _sobreLaEmpresa() {
    final s = context.mp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sobre ${_data!.empresa.name}',
          style: MpTokens.h2.copyWith(color: s.text),
        ),
        const SizedBox(height: MpTokens.space12),
        // En tarjeta, igual que el "Sobre el candidato" del perfil de candidato:
        // las dos fichas del producto tienen que leerse iguales.
        MpCard(
          child: Text(
            _data!.empresa.about!,
            style: MpTokens.body.copyWith(color: s.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _ubicacion() {
    final s = context.mp;

    return MpCard(
      child: Row(
        children: [
          const MpIconTile(
            icon: CupertinoIcons.placemark_fill,
            color: MpTokens.catOrange,
            size: 42,
          ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ubicación',
                  style: MpTokens.caption.copyWith(color: s.textSecondary),
                ),
                Text(
                  _data!.empresa.location!,
                  style: MpTokens.label.copyWith(color: s.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectores() {
    final s = context.mp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('En qué buscamos', style: MpTokens.h2.copyWith(color: s.text)),
        const SizedBox(height: MpTokens.space4),
        Text(
          'Las habilidades que más pedís en tus vacantes.',
          style: MpTokens.micro.copyWith(color: s.textTertiary),
        ),
        const SizedBox(height: MpTokens.space12),
        Wrap(
          spacing: MpTokens.space8,
          runSpacing: MpTokens.space8,
          children: [for (final t in _data!.sectores) MpTagChip(label: t)],
        ),
      ],
    );
  }

  List<Widget> _vacantes() {
    final s = context.mp;
    final vacantes = _data!.vacantes;

    if (vacantes.isEmpty) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: MpEmptyState(
            icon: CupertinoIcons.briefcase,
            title: 'Todavía no publicaste vacantes',
            message:
                'Los candidatos que entren a tu perfil no van a encontrar '
                'a qué postularse.',
            actionLabel: 'Publicar vacante',
            onAction: () async {
              await Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const EmpresaPublicarVacanteScreen(),
                ),
              );
              await _load();
            },
          ),
        ),
      ];
    }

    return [
      Text('Vacantes activas', style: MpTokens.h2.copyWith(color: s.text)),
      const SizedBox(height: MpTokens.space12),
      for (final v in vacantes.take(6)) ...[
        _filaVacante(v),
        const SizedBox(height: MpTokens.space8),
      ],
    ];
  }

  Widget _filaVacante(Vacante v) {
    return MpListRow(
      leading: MpIconTile(
        icon: v.confidencial
            ? CupertinoIcons.lock_fill
            : CupertinoIcons.briefcase_fill,
        color: v.confidencial ? MpTokens.catIndigo : MpTokens.primary,
        size: 42,
      ),
      title: v.titulo,
      subtitle: [
        if (v.modalidad != null) v.modalidad!,
        if (v.ubicacion != null) v.ubicacion!,
        '${v.candidatos} ${v.candidatos == 1 ? 'candidato' : 'candidatos'}',
      ].join('  ·  '),
      badge: v.estado == VacanteEstado.pausada
          ? const MpStatusBadge(label: 'Pausada', status: MpStatus.paused)
          : null,
      onTap: () async {
        await Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => EmpresaVacanteDetalleScreen(vacante: v),
          ),
        );
        await _load();
      },
    );
  }

  // ── Barra de acciones ──────────────────────────────────────────────────────

  Widget _barraAcciones() {
    final s = context.mp;

    return Container(
      padding: EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        MpTokens.space12,
        MpTokens.screenPadding,
        MediaQuery.of(context).padding.bottom + MpTokens.space12,
      ),
      decoration: BoxDecoration(
        color: s.card,
        border: Border(top: BorderSide(color: s.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: MpButton(
              label: 'Compartir',
              icon: CupertinoIcons.share,
              variant: MpButtonVariant.neutral,
              expand: true,
              onPressed: _compartir,
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          // Mitad y mitad: con 2/3 para "Editar perfil", "Compartir" quedaba
          // truncado en "Comp…" a 393pt.
          Expanded(
            child: MpButton(
              label: 'Editar perfil',
              icon: CupertinoIcons.pencil,
              expand: true,
              onPressed: _editar,
            ),
          ),
        ],
      ),
    );
  }
}

/// Póster tocable del video de la empresa: degradado + botón de play. No
/// decodifica el video acá (evita el costo de un `VideoPlayerController` sólo
/// para mostrar un cuadro); reproduce a pantalla completa al tocar.
class _CompanyVideoPoster extends StatelessWidget {
  final String videoUrl;

  const _CompanyVideoPoster({required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => _CompanyVideoPlayerPage(videoUrl: videoUrl),
        ),
      ),
      child: Container(
        height: 208,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B1436), Color(0xFF2E1F63), Color(0xFF0E0A1E)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x40FFFFFF)),
                ),
                child: const Icon(
                  CupertinoIcons.play_fill,
                  size: 26,
                  color: Color(0xFFFFFFFF),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Video de la empresa',
                style: MpTokens.label.copyWith(
                  color: const Color(0xE6FFFFFF),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reproductor a pantalla completa del video de la empresa. Sin datos de
/// muestra: si falla la carga, muestra el error real, no un video de relleno.
class _CompanyVideoPlayerPage extends StatefulWidget {
  final String videoUrl;

  const _CompanyVideoPlayerPage({required this.videoUrl});

  @override
  State<_CompanyVideoPlayerPage> createState() =>
      _CompanyVideoPlayerPageState();
}

class _CompanyVideoPlayerPageState extends State<_CompanyVideoPlayerPage> {
  VideoPlayerController? _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    _controller = controller;
    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});
          controller.play();
        })
        .catchError((_) {
          if (mounted) setState(() => _hasError = true);
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return CupertinoPageScaffold(
      backgroundColor: MpTokens.darkBg,
      child: Stack(
        children: [
          Center(
            child: _hasError
                ? Text(
                    'No pudimos cargar el video.',
                    style: MpTokens.body.copyWith(
                      color: const Color(0xFFFFFFFF),
                    ),
                  )
                : !ready
                ? const CupertinoActivityIndicator(
                    radius: 15,
                    color: Color(0xFFFFFFFF),
                  )
                : GestureDetector(
                    onTap: () => setState(() {
                      controller.value.isPlaying
                          ? controller.pause()
                          : controller.play();
                    }),
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + MpTokens.space8,
            left: MpTokens.screenPadding,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0x66000810),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.xmark,
                  size: 18,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
