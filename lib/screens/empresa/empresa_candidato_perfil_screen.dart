import 'package:flutter/cupertino.dart';
import 'package:video_player/video_player.dart';

import '../../models/models.dart';
import '../../services/share_service.dart';
import '../../services/social_service.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../chat_inmail_screen.dart';
import 'empresa_candidato_data.dart';

/// Perfil de un candidato, visto por la Empresa.
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 11/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ║ Su golden es protección de regresión: si falla, averiguar por qué     ║
/// ║ antes de regenerarlo.                                                 ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// RECONSTRUCCIÓN DIRECTA de `perfil de candidato.png` (Pantalla 7): héroe a
/// sangre con el candidato, chip de disponibilidad, nombre + verificado, rol en
/// violeta, ubicación, anillo de Match a la derecha; barra de cinco acciones
/// montada sobre el héroe; y el cuerpo claro con Sobre mí · Información clave ·
/// Skills · Experiencia · Educación, más la barra fija de Mensaje / Hacer match.
///
/// POR QUÉ EXISTE: hasta ahora la Shortlist, el Detalle de Vacante y el Pipeline
/// abrían `ProfileScreen`, que es la pantalla legacy del rol candidato. Se veía
/// de otro sistema visual y ofrecía acciones que no son las de una empresa.
///
/// DATOS. Del PNG se omiten los campos que `users` no tiene: años de
/// experiencia como número, modalidad preferida, idiomas y "1.2 km de vos"
/// (la distancia requiere la ubicación de la empresa y la del candidato, y la
/// segunda es opcional). Cada bloque desaparece si no hay dato: no hay
/// "Información clave" con casillas vacías.
///
/// POLISH VISUAL 3 (15/8/2026): el héroe reproduce el VIDEO PITCH real
/// (`usuario.videoUrl`, la misma columna que llena `OnboardingPitchScreen`)
/// cuando existe, con el botón de play del PNG. Antes el héroe sólo mostraba
/// la foto — el video del candidato existía en la base pero ningún camino de
/// Empresa lo reproducía. Sin video (o candidato confidencial, que tampoco
/// muestra su cara), se conserva la foto/avatar de siempre.
class EmpresaCandidatoPerfilScreen extends StatefulWidget {
  final String candidatoId;

  /// Match ya calculado para una vacante concreta (viene de la Shortlist).
  final int? match;
  final String? vacanteTitulo;

  /// Datos ya resueltos, para los golden tests.
  final CandidatoPerfil? previewData;

  const EmpresaCandidatoPerfilScreen({
    super.key,
    required this.candidatoId,
    this.match,
    this.vacanteTitulo,
    this.previewData,
  });

  @override
  State<EmpresaCandidatoPerfilScreen> createState() =>
      _EmpresaCandidatoPerfilScreenState();
}

class _EmpresaCandidatoPerfilScreenState
    extends State<EmpresaCandidatoPerfilScreen> {
  CandidatoPerfil? _data;
  bool _loading = true;
  bool _guardando = false;
  bool _conectando = false;
  String? _aviso;
  bool _sobreMiExpandido = false;
  bool _calificando = false;

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
    final data = await loadCandidatoPerfil(
      widget.candidatoId,
      matchPrecalculado: widget.match,
      vacanteTitulo: widget.vacanteTitulo,
    );
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  Future<void> _toggleGuardado() async {
    final data = _data;
    if (data == null || _guardando) return;

    setState(() {
      _guardando = true;
      _aviso = null;
    });

    final resultado =
        await toggleCandidatoGuardado(data.usuario.id, !data.guardado);
    if (!mounted) return;

    setState(() {
      _guardando = false;
      if (resultado == null) {
        _aviso = 'No pudimos guardar el cambio.';
      } else {
        _data = CandidatoPerfil(
          usuario: data.usuario,
          guardado: resultado,
          match: data.match,
          vacanteTitulo: data.vacanteTitulo,
        );
      }
    });
  }

  /// "Hacer match" del mockup = crear la conexión real. Es la misma vía por la
  /// que un candidato entra al Pipeline con etapa `new`.
  Future<void> _conectar() async {
    final data = _data;
    if (data == null || _conectando) return;

    setState(() {
      _conectando = true;
      _aviso = null;
    });

    final res = await SocialService.instance.sendConnectionRequest(
      data.usuario.id,
    );
    if (!mounted) return;

    setState(() {
      _conectando = false;
      _aviso = res['error'] != null
          ? 'No pudimos conectar con este candidato.'
          : 'Listo: el candidato entró a tu pipeline.';
    });
  }

  /// Calificar a este candidato (1 a 5 estrellas). Usa el mismo RPC
  /// `rate_user` que ya alimenta `ratingStars`/`ratingCount` en el modelo —
  /// hasta ahora nada de la UI lo llamaba, asi que la calificacion promedio
  /// quedaba siempre en 0.0 aunque el backend funcionara. Recarga el perfil
  /// al terminar para reflejar el nuevo promedio.
  Future<void> _calificar(double stars) async {
    final data = _data;
    if (data == null || _calificando) return;

    setState(() {
      _calificando = true;
      _aviso = null;
    });

    final res = await SocialService.instance.rateUser(data.usuario.id, stars);
    if (!mounted) return;

    setState(() {
      _calificando = false;
      _aviso = res['error'] != null
          ? 'No pudimos guardar la calificacion.'
          : 'Gracias: calificacion guardada.';
    });

    if (res['error'] == null) {
      await _load();
    }
  }

  Future<void> _mostrarMenuCalificar() async {
    final data = _data;
    if (data == null) return;

    final stars = await showCupertinoModalPopup<double>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Calificar candidato'),
        message: Text(
          '\u00bfComo fue tu experiencia con ${data.usuario.name}?',
        ),
        actions: [
          for (var i = 5; i >= 1; i--)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(i.toDouble()),
              child: Text(i == 1 ? '1 estrella' : '$i estrellas'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );

    if (stars != null) {
      await _calificar(stars);
    }
  }

  Future<void> _compartir() async {
    final data = _data;
    if (data == null || data.confidencial) return;
    await ShareService.instance.shareProfile(
      name: data.usuario.name,
      headline: data.usuario.headline,
      userId: data.usuario.id,
      accountType: data.usuario.accountType,
    );
  }

  void _mensaje() {
    final data = _data;
    if (data == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatInmailScreen(targetUser: data.usuario),
      ),
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
                ? _noEncontrado()
                : Column(
                    children: [
                      Expanded(
                        child: CustomScrollView(
                          slivers: [
                            CupertinoSliverRefreshControl(onRefresh: _load),
                            SliverToBoxAdapter(child: _hero()),
                            SliverPadding(
                              // Sin aire arriba: la barra de acciones tiene que
                              // quedar pegada al borde del héroe, como en el PNG.
                              padding: const EdgeInsets.fromLTRB(
                                MpTokens.screenPadding,
                                MpTokens.space12,
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

  Widget _noEncontrado() {
    return SafeArea(
      child: MpEmptyState(
        icon: CupertinoIcons.person_crop_circle_badge_xmark,
        title: 'No pudimos abrir el perfil',
        message: 'El candidato puede haber cerrado su cuenta, o hubo un '
            'problema de conexión.',
        actionLabel: 'Reintentar',
        onAction: _load,
      ),
    );
  }

  // ── Héroe ──────────────────────────────────────────────────────────────────

  Widget _hero() {
    final data = _data!;
    final u = data.usuario;
    final imagen = data.confidencial
        ? null
        : (u.bannerUrl?.isNotEmpty ?? false)
            ? u.bannerUrl
            : (u.avatarUrl?.isNotEmpty ?? false)
                ? u.avatarUrl
                : null;
    final video = (!data.confidencial && (u.videoUrl?.isNotEmpty ?? false))
        ? u.videoUrl
        : null;

    return Stack(
      children: [
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            color: MpTokens.darkCard,
            image: imagen == null
                ? null
                : DecorationImage(
                    image: NetworkImage(imagen),
                    fit: BoxFit.cover,
                  ),
          ),
          child: imagen != null
              ? null
              : Center(
                  child: MpAvatar(name: data.nombreVisible, size: 96),
                ),
        ),
        // Velo para que el texto sea legible sobre cualquier foto.
        Container(
          height: 300,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99000810), Color(0x00000810), Color(0xE6000810)],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        if (video != null)
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            height: 210,
            child: Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => _CandidatoVideoPlayerPage(videoUrl: video),
                  ),
                ),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0x40000810),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x66FFFFFF), width: 2),
                  ),
                  child: const Icon(
                    CupertinoIcons.play_fill,
                    size: 26,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
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
                  _botonHero(
                    CupertinoIcons.chevron_left,
                    () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  if (u.isOpenToWork)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC000810),
                        borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: MpTokens.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Disponible',
                            style: MpTokens.micro.copyWith(
                              color: MpTokens.darkText,
                            ),
                          ),
                        ],
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            data.nombreVisible,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: MpTokens.h1.copyWith(
                              color: MpTokens.darkText,
                              fontSize: 24,
                            ),
                          ),
                        ),
                        if (u.isVerified) ...[
                          const SizedBox(width: 6),
                          const MpVerifiedBadge(size: 17),
                        ],
                      ],
                    ),
                    if (u.headline.isNotEmpty) ...[
                      const SizedBox(height: MpTokens.space4),
                      Text(
                        u.headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MpTokens.bodyStrong.copyWith(
                          color: MpTokens.primaryLight,
                        ),
                      ),
                    ],
                    if ((u.location?.isNotEmpty ?? false) &&
                        !data.confidencial) ...[
                      const SizedBox(height: MpTokens.space4),
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.placemark,
                            size: 13,
                            color: MpTokens.darkTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              u.location!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MpTokens.caption.copyWith(
                                color: MpTokens.darkTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (data.match != null) ...[
                const SizedBox(width: MpTokens.space12),
                MpProgressRing(
                  value: data.match! / 100,
                  size: 72,
                  stroke: 6,
                  color: MpTokens.primaryLight,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${data.match}%',
                        style: MpTokens.label.copyWith(
                          color: MpTokens.darkText,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Match',
                        style: MpTokens.micro.copyWith(
                          color: MpTokens.darkTextSecondary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _botonHero(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Color(0xCC000810),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: MpTokens.darkText),
      ),
    );
  }

  // ── Cuerpo ─────────────────────────────────────────────────────────────────

  List<Widget> _cuerpo() {
    final data = _data!;
    final u = data.usuario;

    return [
      _barraRapida(),
      if (_aviso != null) ...[
        const SizedBox(height: MpTokens.space12),
        _bannerAviso(),
      ],
      if (data.vacanteTitulo != null) ...[
        const SizedBox(height: MpTokens.space16),
        _contextoVacante(),
      ],
      if (u.about?.isNotEmpty ?? false) ...[
        const SizedBox(height: MpTokens.space24),
        _sobreMi(),
      ],
      if (_infoClave().isNotEmpty) ...[
        const SizedBox(height: MpTokens.space24),
        _informacionClave(),
      ],
      if (u.tags.isNotEmpty || u.skills.isNotEmpty) ...[
        const SizedBox(height: MpTokens.space24),
        _skills(),
      ],
      if (u.experience.isNotEmpty) ...[
        const SizedBox(height: MpTokens.space24),
        _experiencia(),
      ],
      if (u.education.isNotEmpty) ...[
        const SizedBox(height: MpTokens.space24),
        _educacion(),
      ],
      if (_vacio()) ...[
        const SizedBox(height: MpTokens.space24),
        _perfilVacio(),
      ],
    ];
  }

  bool _vacio() {
    final u = _data!.usuario;
    return (u.about?.isEmpty ?? true) &&
        u.tags.isEmpty &&
        u.skills.isEmpty &&
        u.experience.isEmpty &&
        u.education.isEmpty &&
        _infoClave().isEmpty;
  }

  Widget _perfilVacio() {
    final s = context.mp;

    return MpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perfil sin completar',
            style: MpTokens.title.copyWith(color: s.text),
          ),
          const SizedBox(height: MpTokens.space4),
          Text(
            'Este candidato todavía no cargó su descripción, habilidades ni '
            'experiencia. Podés escribirle igual.',
            style: MpTokens.body.copyWith(color: s.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// La fila de acciones que en el PNG monta sobre el héroe. Lleva la sombra
  /// elevada del sistema —no la de tarjeta— para que se lea flotando sobre el
  /// borde del héroe oscuro, que es lo que hace el mockup.
  Widget _barraRapida() {
    final s = context.mp;
    final data = _data!;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: MpTokens.space12),
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(MpTokens.radiusXL),
        border: Border.all(color: s.border),
        boxShadow: MpTokens.raisedShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: _accion(
              icon: data.guardado
                  ? CupertinoIcons.bookmark_fill
                  : CupertinoIcons.bookmark,
              label: data.guardado ? 'Guardado' : 'Guardar',
              activo: data.guardado,
              onTap: _toggleGuardado,
            ),
          ),
          Expanded(
            child: _accion(
              icon: CupertinoIcons.chat_bubble,
              label: 'Mensaje',
              onTap: _mensaje,
            ),
          ),
          Expanded(
            child: _accion(
              icon: CupertinoIcons.bolt_fill,
              label: 'Hacer match',
              activo: true,
              onTap: _conectar,
            ),
          ),
          // Compartir sólo si hay identidad que compartir.
          if (!data.confidencial)
            Expanded(
              child: _accion(
                icon: CupertinoIcons.share,
                label: 'Compartir',
                onTap: _compartir,
              ),
            ),
          // "Más" del PNG 7: estaba en el mockup pero nunca se había
          // implementado. Por ahora abre directo el flujo de calificación
          // (único ítem), pensado para sumar más acciones acá después.
          Expanded(
            child: _accion(
              icon: CupertinoIcons.ellipsis,
              label: 'Más',
              onTap: _mostrarMenuCalificar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _accion({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool activo = false,
  }) {
    final s = context.mp;
    final color = activo ? s.accent : s.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(height: MpTokens.space4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: MpTokens.micro.copyWith(color: color, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerAviso() {
    final esError = _aviso!.startsWith('No pudimos');

    return MpBanner(
      icon: esError
          ? CupertinoIcons.exclamationmark_triangle
          : CupertinoIcons.checkmark_circle,
      title: esError ? 'No se pudo aplicar' : 'Hecho',
      message: _aviso!,
      color: esError ? MpTokens.danger : MpTokens.success,
      onDismiss: () => setState(() => _aviso = null),
    );
  }

  /// Bloque de match. Sólo existe cuando el perfil se abrió DESDE una vacante;
  /// desde Pipeline, Guardados o Búsqueda no hay vacante contra la cual medir y
  /// esta sección no se dibuja.
  Widget _contextoVacante() {
    final s = context.mp;
    final data = _data!;

    return MpAiCard(
      title: 'Match con tu vacante',
      tag: 'MATCH IA',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.vacanteTitulo!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MpTokens.title.copyWith(color: s.text, fontSize: 15),
                ),
                const SizedBox(height: MpTokens.space4),
                Text(
                  data.match == null
                      ? 'Aparece en la shortlist de esta vacante.'
                      : 'Según la afinidad de su perfil y las habilidades que '
                          'pediste.',
                  style: MpTokens.caption.copyWith(color: s.textSecondary),
                ),
              ],
            ),
          ),
          // El anillo NO se repite acá: ya está en el héroe, que es donde el
          // PNG lo pone. Dos veces el mismo número en la misma pantalla es
          // ruido, no jerarquía.
        ],
      ),
    );
  }

  Widget _sobreMi() {
    final s = context.mp;
    final about = _data!.usuario.about!;
    final largo = about.length > 220;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sobre el candidato', style: MpTokens.h2.copyWith(color: s.text)),
        const SizedBox(height: MpTokens.space12),
        // Dentro de una tarjeta, no como texto suelto sobre el fondo: es lo que
        // separa un perfil de un volcado de campos.
        MpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                about,
                maxLines: (_sobreMiExpandido || !largo) ? null : 4,
                overflow: (_sobreMiExpandido || !largo)
                    ? TextOverflow.clip
                    : TextOverflow.ellipsis,
                style: MpTokens.body.copyWith(color: s.textSecondary),
              ),
              if (largo) ...[
                const SizedBox(height: MpTokens.space8),
                MpButton(
                  label: _sobreMiExpandido ? 'Ver menos' : 'Ver más',
                  variant: MpButtonVariant.ghost,
                  size: MpButtonSize.small,
                  onPressed: () =>
                      setState(() => _sobreMiExpandido = !_sobreMiExpandido),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Sólo los campos que `users` tiene de verdad.
  List<({IconData icon, String etiqueta, String valor})> _infoClave() {
    final u = _data!.usuario;
    final confidencial = _data!.confidencial;

    return [
      if ((u.location?.isNotEmpty ?? false) && !confidencial)
        (
          icon: CupertinoIcons.placemark,
          etiqueta: 'Ubicación',
          valor: u.location!,
        ),
      if (u.salaryExpectation?.isNotEmpty ?? false)
        (
          icon: CupertinoIcons.money_dollar_circle,
          etiqueta: 'Salario esperado',
          valor: u.salaryExpectation!,
        ),
      // Sólo cuando el candidato DECLARÓ que busca. `open_to_work` en false
      // puede ser el valor por defecto de la columna, no una declaración suya:
      // escribir "No disponible" a partir de eso sería afirmar de más.
      if (u.isOpenToWork)
        (
          icon: CupertinoIcons.clock,
          etiqueta: 'Disponibilidad',
          valor: 'Buscando trabajo',
        ),
      if (u.ratingCount > 0)
        (
          icon: CupertinoIcons.star,
          etiqueta: 'Valoración',
          valor: '${u.ratingStars.toStringAsFixed(1)} (${u.ratingCount})',
        ),
    ];
  }

  /// Grilla de dos columnas: ícono, etiqueta chica y valor destacado apilados.
  /// Es la forma del bloque "Información clave" del PNG 7 — antes era una lista
  /// de filas etiqueta→valor, que se leía como una tabla de configuración.
  Widget _informacionClave() {
    final s = context.mp;
    final items = _infoClave();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Información clave', style: MpTokens.h2.copyWith(color: s.text)),
        const SizedBox(height: MpTokens.space12),
        MpCard(
          child: Column(
            children: [
              for (var fila = 0; fila < (items.length + 1) ~/ 2; fila++) ...[
                if (fila > 0) ...[
                  const SizedBox(height: MpTokens.space16),
                  Container(height: 1, color: s.border),
                  const SizedBox(height: MpTokens.space16),
                ],
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _celdaInfo(items[fila * 2])),
                      if (fila * 2 + 1 < items.length) ...[
                        Container(width: 1, color: s.border),
                        Expanded(child: _celdaInfo(items[fila * 2 + 1])),
                      ] else
                        const Spacer(),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _celdaInfo(({IconData icon, String etiqueta, String valor}) item) {
    final s = context.mp;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MpTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 15, color: s.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MpTokens.micro.copyWith(
                    color: s.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MpTokens.space4),
          Text(
            item.valor,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: MpTokens.label.copyWith(color: s.text, fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  Widget _skills() {
    final s = context.mp;
    final u = _data!.usuario;
    final lista = u.tags.isNotEmpty ? u.tags : u.skills;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Skills principales', style: MpTokens.h2.copyWith(color: s.text)),
        const SizedBox(height: MpTokens.space12),
        Wrap(
          spacing: MpTokens.space8,
          runSpacing: MpTokens.space8,
          children: [
            for (final t in lista)
              MpTagChip(label: t.replaceAll('#', '').trim()),
          ],
        ),
      ],
    );
  }

  Widget _experiencia() {
    final s = context.mp;
    final items = _data!.usuario.experience;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Experiencia', style: MpTokens.h2.copyWith(color: s.text)),
        const SizedBox(height: MpTokens.space12),
        MpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) ...[
                  const SizedBox(height: MpTokens.space16),
                  Container(height: 1, color: s.border),
                  const SizedBox(height: MpTokens.space16),
                ],
                _filaExperiencia(items[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _filaExperiencia(Experience e) {
    final s = context.mp;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MpAvatar(name: e.company, size: 36),
        const SizedBox(width: MpTokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.role,
                style: MpTokens.title.copyWith(color: s.text, fontSize: 15),
              ),
              Text(
                [
                  if (e.company.isNotEmpty) e.company,
                  if (e.duration.isNotEmpty) e.duration,
                ].join('  ·  '),
                style: MpTokens.caption.copyWith(color: s.textSecondary),
              ),
              if (e.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: MpTokens.space4),
                Text(
                  e.description!,
                  style: MpTokens.caption.copyWith(color: s.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _educacion() {
    final s = context.mp;
    final items = _data!.usuario.education;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Educación', style: MpTokens.h2.copyWith(color: s.text)),
        const SizedBox(height: MpTokens.space12),
        MpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) ...[
                  const SizedBox(height: MpTokens.space16),
                  Container(height: 1, color: s.border),
                  const SizedBox(height: MpTokens.space16),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MpIconTile(
                      icon: CupertinoIcons.book,
                      color: MpTokens.catIndigo,
                      size: 36,
                    ),
                    const SizedBox(width: MpTokens.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].degree,
                            style: MpTokens.title.copyWith(
                              color: s.text,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            [
                              if (items[i].school.isNotEmpty) items[i].school,
                              if (items[i].years.isNotEmpty) items[i].years,
                            ].join('  ·  '),
                            style: MpTokens.caption.copyWith(
                              color: s.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Barra fija ─────────────────────────────────────────────────────────────

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
              label: 'Mensaje',
              icon: CupertinoIcons.chat_bubble,
              variant: MpButtonVariant.neutral,
              expand: true,
              onPressed: _mensaje,
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          // Mitad y mitad: con 2/3 para "Hacer match", "Mensaje" quedaba
          // truncado en "Mens…" a 393pt.
          Expanded(
            child: MpButton(
              label: 'Hacer match',
              icon: CupertinoIcons.bolt_fill,
              expand: true,
              loading: _conectando,
              onPressed: _conectar,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reproductor a pantalla completa del video pitch del candidato. Sin datos
/// de muestra: si falla la carga, muestra el error real.
class _CandidatoVideoPlayerPage extends StatefulWidget {
  final String videoUrl;

  const _CandidatoVideoPlayerPage({required this.videoUrl});

  @override
  State<_CandidatoVideoPlayerPage> createState() =>
      _CandidatoVideoPlayerPageState();
}

class _CandidatoVideoPlayerPageState extends State<_CandidatoVideoPlayerPage> {
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
