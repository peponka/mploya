import 'package:flutter/cupertino.dart';

import '../../models/models.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../chat_inmail_screen.dart';
import '../scheduling_screen.dart';
import 'empresa_candidato_data.dart';
import 'empresa_candidato_perfil_screen.dart';
import 'empresa_match_ia_data.dart';

/// Match IA entre un candidato y una vacante de la Empresa.
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 12/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// RECONSTRUCCIÓN de `matchIAverdadera.png`, con `match IA 3.png` y `matchia.png`
/// de apoyo: banda oscura con los dos extremos y el anillo del match en el
/// medio, y debajo, sobre fondo claro, el desglose de la compatibilidad.
///
/// EL NÚMERO NO LO INVENTA ESTA PANTALLA. Sale de la RPC
/// `match_candidates_for_job` (migraciones 005/006), la misma que ya usa el
/// resto de Empresa. Si la vacante no tiene embedding o el candidato no entra
/// en el ranking, no hay match: se dice, y no se dibuja un número.
///
/// OMITIDO del mockup, y por qué. El PNG despliega cinco barras —Skills 95%,
/// Experiencia 90%, Cultura y valores 88%, Expectativas salariales 80%,
/// Ubicación 85%—, un texto de la IA ("detectó una gran alineación en
/// habilidades, valores y objetivos") y un veredicto de potencial conjunto.
/// **Nada de eso existe.** El único puntaje que la base puede producir es el
/// match global por embeddings; no hay modelo de cultura, ni de experiencia
/// comparada, ni de potencial. Dibujar cinco barras con números repartidos a
/// ojo sería inventar una evaluación, que es exactamente lo que este proyecto
/// dejó de hacer. En su lugar se muestran los tres cruces que SÍ son
/// verificables: skills, salario y distancia — y cada uno sólo si sus datos
/// existen de verdad.
///
/// POLISH VISUAL 4 (15/8/2026) — BUG DE PRIVACIDAD CORREGIDO: el encabezado
/// mostraba el nombre real, la foto real y la ciudad real del candidato sin
/// ningún chequeo de confidencialidad, a diferencia de Pipeline, Shortlist,
/// Mensajes y el Perfil de Candidato, que sí enmascaran. Ahora usa
/// `candidatoVisible`/`candidatoAvatarVisible`/`candidatoCiudadVisible`, con
/// el mismo criterio (`account_type` empieza con "confidenc"). El dato real
/// sigue viajando en `MatchIaData` para no romper `_mensaje()`, que ya se
/// comporta como el resto de Empresa al abrir el chat (deuda registrada, no
/// se toca en esta tanda).
class EmpresaMatchIaScreen extends StatefulWidget {
  final String jobId;
  final String candidatoId;

  /// Datos ya resueltos, para los golden tests.
  final MatchIaData? previewData;

  const EmpresaMatchIaScreen({
    super.key,
    required this.jobId,
    required this.candidatoId,
    this.previewData,
  });

  @override
  State<EmpresaMatchIaScreen> createState() => _EmpresaMatchIaScreenState();
}

class _EmpresaMatchIaScreenState extends State<EmpresaMatchIaScreen> {
  MatchIaData _data = MatchIaData.vacia;
  bool _loading = true;
  bool _guardado = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (widget.previewData != null) {
      _data = widget.previewData!;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (widget.previewData != null) return;
    if (!mounted) return;
    setState(() => _loading = true);
    final data = await loadMatchIa(
      jobId: widget.jobId,
      candidatoId: widget.candidatoId,
    );
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  Future<void> _alternarGuardado() async {
    if (_guardando || widget.previewData != null) return;
    setState(() => _guardando = true);
    final ok = await toggleCandidatoGuardado(widget.candidatoId, !_guardado);
    if (!mounted) return;
    setState(() {
      if (ok != null) _guardado = ok;
      _guardando = false;
    });
  }

  void _abrirPerfil() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) =>
            EmpresaCandidatoPerfilScreen(candidatoId: widget.candidatoId),
      ),
    );
  }

  void _mensaje() {
    // `ChatInmailScreen` espera el usuario destino. Se arma con los datos que
    // ya trajimos, sin volver a consultar.
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatInmailScreen(
          targetUser: NexUser(
            id: widget.candidatoId,
            name: _data.candidato,
            headline: _data.candidatoHeadline ?? '',
            avatarUrl: _data.candidatoAvatar,
          ),
        ),
      ),
    );
  }

  void _agendar() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const SchedulingScreen(isCompany: true),
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
        child: SafeArea(
          bottom: false,
          child: _loading
              ? const Center(child: CupertinoActivityIndicator(radius: 15))
              : _data.error
                  ? _errorState()
                  : CustomScrollView(
                      slivers: [
                        CupertinoSliverRefreshControl(onRefresh: _load),
                        SliverToBoxAdapter(child: _banda()),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            MpTokens.screenPadding,
                            MpTokens.space16,
                            MpTokens.screenPadding,
                            MpTokens.space32,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate(_cuerpo()),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.all(MpTokens.screenPadding),
      child: MpEmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'No pudimos calcular el match',
        message: 'Revisá tu conexión y volvé a intentar.',
        actionLabel: 'Reintentar',
        onAction: _load,
      ),
    );
  }

  // ── Banda oscura con los dos extremos ──
  Widget _banda() {
    return Container(
      width: double.infinity,
      color: MpTokens.darkBg,
      padding: const EdgeInsets.fromLTRB(
        MpTokens.space12,
        MpTokens.space8,
        MpTokens.space12,
        MpTokens.space24,
      ),
      child: Column(
        children: [
          Row(
            children: [
              MpIconButton(
                icon: CupertinoIcons.chevron_left,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const Expanded(
                child: Text(
                  'Match IA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MpTokens.darkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: MpTokens.space16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _extremo(
                  nombre: _data.empresa ?? 'Tu empresa',
                  detalle: _data.vacante,
                  ciudad: _data.empresaCiudad,
                  avatar: _data.empresaAvatar,
                ),
              ),
              _anillo(),
              Expanded(
                child: _extremo(
                  nombre: _data.candidatoVisible,
                  detalle: _data.candidatoHeadline,
                  ciudad: _data.candidatoCiudadVisible,
                  avatar: _data.candidatoAvatarVisible,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _extremo({
    required String nombre,
    String? detalle,
    String? ciudad,
    String? avatar,
  }) {
    return Column(
      children: [
        MpAvatar(
          name: nombre,
          size: 54,
          image: avatar == null ? null : NetworkImage(avatar),
        ),
        const SizedBox(height: MpTokens.space8),
        Text(
          nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MpTokens.darkText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
        ),
        if (detalle != null) ...[
          const SizedBox(height: 2),
          Text(
            detalle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MpTokens.darkTextSecondary,
              fontSize: 11.5,
              height: 1.25,
              decoration: TextDecoration.none,
            ),
          ),
        ],
        if (ciudad != null) ...[
          const SizedBox(height: 2),
          Text(
            ciudad,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MpTokens.darkTextTertiary,
              fontSize: 11,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ],
    );
  }

  /// Anillo con el match. Sin dato de la RPC no se dibuja ningún número.
  Widget _anillo() {
    final m = _data.match;

    if (m == null) {
      return SizedBox(
        width: 104,
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: MpTokens.darkBorder, width: 3),
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.sparkles,
                  color: MpTokens.darkTextTertiary,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: MpTokens.space8),
            const Text(
              'Sin match\ncalculado',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MpTokens.darkTextTertiary,
                fontSize: 10.5,
                height: 1.25,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 104,
      child: Column(
        children: [
          MpProgressRing(
            value: m / 100,
            size: 84,
            stroke: 7,
            color: MpTokens.primaryLight,
            center: Text(
              '$m%',
              style: const TextStyle(
                color: MpTokens.darkText,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: MpTokens.space8),
          Text(
            _data.etiquetaMatch ?? '',
            style: const TextStyle(
              color: MpTokens.primaryLight,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  // ── Cuerpo ──
  List<Widget> _cuerpo() {
    final s = context.mp;
    final bloques = <Widget>[];

    if (_data.match == null) {
      bloques
        ..add(
          MpBanner(
            icon: CupertinoIcons.sparkles,
            title: 'Todavía no hay match calculado',
            message: 'El match se calcula sobre la vacante. Si es nueva, puede '
                'tardar en estar listo.',
            color: MpTokens.premium,
          ),
        )
        ..add(const SizedBox(height: MpTokens.space16));
    }

    bloques.addAll(_bloqueSkills(s));

    if (_data.haySalario) {
      bloques
        ..add(const SizedBox(height: MpTokens.space16))
        ..addAll(_bloqueSalario(s));
    }

    if (_data.hayDistancia) {
      bloques
        ..add(const SizedBox(height: MpTokens.space16))
        ..addAll(_bloqueUbicacion(s));
    }

    bloques
      ..add(const SizedBox(height: MpTokens.space24))
      ..add(_acciones());

    return bloques;
  }

  List<Widget> _bloqueSkills(MpSurfaceStyle s) {
    final comunes = _data.skillsEnComun;
    final faltan = _data.skillsQueFaltan;

    if (comunes.isEmpty && faltan.isEmpty) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: const MpEmptyState(
            icon: CupertinoIcons.tag,
            title: 'Sin habilidades para cruzar',
            message: 'Ni la vacante ni el perfil tienen habilidades cargadas, '
                'así que no hay nada que comparar.',
          ),
        ),
      ];
    }

    return [
      MpSectionHeader(
        title: 'Habilidades',
        subtitle: comunes.isEmpty
            ? 'Ninguna de las que pide la vacante'
            : '${comunes.length} de ${comunes.length + faltan.length} '
                'que pide la vacante',
      ),
      const SizedBox(height: MpTokens.space12),
      MpCard(
        radius: MpTokens.radiusLG,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (comunes.isNotEmpty) ...[
              Text(
                'En común',
                style: MpTokens.micro.copyWith(color: s.textSecondary),
              ),
              const SizedBox(height: MpTokens.space8),
              Wrap(
                spacing: MpTokens.space8,
                runSpacing: MpTokens.space8,
                children: [
                  for (final t in comunes) MpTagChip(label: t),
                ],
              ),
            ],
            if (comunes.isNotEmpty && faltan.isNotEmpty)
              const SizedBox(height: MpTokens.space16),
            if (faltan.isNotEmpty) ...[
              Text(
                'No las declara',
                style: MpTokens.micro.copyWith(color: s.textTertiary),
              ),
              const SizedBox(height: MpTokens.space8),
              Wrap(
                spacing: MpTokens.space8,
                runSpacing: MpTokens.space8,
                children: [
                  for (final t in faltan) MpTagChip(label: t),
                ],
              ),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _bloqueSalario(MpSurfaceStyle s) {
    return [
      const MpSectionHeader(title: 'Salario'),
      const SizedBox(height: MpTokens.space12),
      MpCard(
        radius: MpTokens.radiusLG,
        child: Column(
          children: [
            _filaDato(
              s,
              icono: CupertinoIcons.money_dollar_circle,
              etiqueta: 'Pide el candidato',
              valor: _data.expectativaCandidato!,
            ),
            const SizedBox(height: MpTokens.space12),
            _filaDato(
              s,
              icono: CupertinoIcons.briefcase,
              etiqueta: 'Ofrece la vacante',
              valor: _data.rangoVacante!,
            ),
            const SizedBox(height: MpTokens.space8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Los dos valores son texto libre: se muestran como están, sin '
                'calcular compatibilidad.',
                style: MpTokens.micro.copyWith(color: s.textTertiary),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _bloqueUbicacion(MpSurfaceStyle s) {
    final km = _data.distanciaKm!;
    final texto = km < 1
        ? 'Menos de 1 km'
        : '${km.toStringAsFixed(km < 10 ? 1 : 0)} km de distancia';

    return [
      const MpSectionHeader(title: 'Ubicación'),
      const SizedBox(height: MpTokens.space12),
      MpCard(
        radius: MpTokens.radiusLG,
        child: _filaDato(
          s,
          icono: CupertinoIcons.placemark,
          etiqueta: 'Entre el candidato y tu empresa',
          valor: texto,
        ),
      ),
    ];
  }

  Widget _filaDato(
    MpSurfaceStyle s, {
    required IconData icono,
    required String etiqueta,
    required String valor,
  }) {
    return Row(
      children: [
        Icon(icono, size: 20, color: MpTokens.primary),
        const SizedBox(width: MpTokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                etiqueta,
                style: MpTokens.micro.copyWith(color: s.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: MpTokens.title.copyWith(color: s.text, fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _acciones() {
    return Column(
      children: [
        Row(
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
            Expanded(
              child: MpButton(
                label: _guardado ? 'Guardado' : 'Guardar',
                icon: _guardado
                    ? CupertinoIcons.bookmark_fill
                    : CupertinoIcons.bookmark,
                variant: MpButtonVariant.neutral,
                expand: true,
                loading: _guardando,
                onPressed: _alternarGuardado,
              ),
            ),
          ],
        ),
        const SizedBox(height: MpTokens.space8),
        MpButton(
          label: 'Agendar entrevista',
          icon: CupertinoIcons.calendar,
          expand: true,
          onPressed: _agendar,
        ),
        const SizedBox(height: MpTokens.space8),
        MpButton(
          label: 'Ver perfil completo',
          icon: CupertinoIcons.person_crop_circle,
          variant: MpButtonVariant.ghost,
          expand: true,
          onPressed: _abrirPerfil,
        ),
      ],
    );
  }
}
