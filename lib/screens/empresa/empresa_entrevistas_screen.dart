import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/ds/mploya_ds.dart';
import '../scheduling_screen.dart';
import 'empresa_candidato_perfil_screen.dart';
import 'empresa_crear_entrevista_screen.dart';
import 'empresa_entrevistas_data.dart';
import 'empresa_informe_entrevista_screen.dart';
import 'empresa_sala_entrevista_screen.dart';

/// Entrevistas y agenda de la Empresa.
///
/// DERIVACIÓN CONTROLADA de `agenda inteligente.png` (21), que es la pantalla
/// móvil del rol: se conservan su fila de métricas, la tira de días de la
/// semana con puntos, la línea de tiempo del día elegido, la tarjeta de
/// "Próxima entrevista" con su acción de unirse y la barra inferior de Empresa.
/// De `entrevistas nuevas.png` (39, escritorio) se toma el vocabulario de
/// estados y la idea de separar las entrevistas por tipo.
///
/// DATOS. Nada de relleno: si no hay entrevistas, hay estado vacío. Lo que el
/// mockup muestra y acá NO existe —sincronización con Google/Outlook, "huecos
/// libres" detectados por IA, sugerencias automáticas, puntajes en vivo— no se
/// dibuja, porque no hay nada detrás.
class EmpresaEntrevistasScreen extends StatefulWidget {
  /// Datos ya resueltos, para los golden tests.
  final EntrevistasData? previewData;

  /// Día seleccionado inicialmente. Sólo lo fijan los tests, para que el golden
  /// no dependa de la fecha en que corre.
  final DateTime? diaInicial;

  const EmpresaEntrevistasScreen({
    super.key,
    this.previewData,
    this.diaInicial,
  });

  @override
  State<EmpresaEntrevistasScreen> createState() =>
      _EmpresaEntrevistasScreenState();
}

class _EmpresaEntrevistasScreenState extends State<EmpresaEntrevistasScreen> {
  EntrevistasData _data = EntrevistasData.empty;
  bool _loading = true;
  late DateTime _dia;

  static const _diasCortos = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
  static const _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  @override
  void initState() {
    super.initState();
    final base = widget.diaInicial ?? DateTime.now();
    _dia = DateTime(base.year, base.month, base.day);

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
    final data = await loadEmpresaEntrevistas();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  List<DateTime> get _semana {
    final inicio = _dia.subtract(Duration(days: _dia.weekday - 1));
    return [for (var i = 0; i < 7; i++) inicio.add(Duration(days: i))];
  }

  Future<void> _unirse(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _hora(DateTime? cuando) {
    if (cuando == null) return '';
    final h = cuando.hour.toString().padLeft(2, '0');
    final m = cuando.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _estadoLegible(String estado) => switch (estado.toLowerCase()) {
        'confirmed' => 'Confirmada',
        'pending' => 'Pendiente',
        'cancelled' => 'Cancelada',
        'completed' => 'Completada',
        'in_progress' => 'En curso',
        _ => estado,
      };

  MpStatus _estadoChip(String estado) => switch (estado.toLowerCase()) {
        'confirmed' => MpStatus.active,
        'completed' => MpStatus.finished,
        'cancelled' => MpStatus.danger,
        'in_progress' => MpStatus.info,
        _ => MpStatus.neutral,
      };

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 15))
            : CustomScrollView(
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _load),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      MpTokens.screenPadding,
                      MpTokens.space12,
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
    );
  }

  List<Widget> _cuerpo() {
    if (_data.todoRoto) return [_errorTotal()];

    return [
      _encabezado(),
      const SizedBox(height: MpTokens.space20),
      _metricas(),
      const SizedBox(height: MpTokens.space16),
      if (_data.agendaNoDisponible)
        MpBanner(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: 'No pudimos leer la agenda',
          message: 'Las entrevistas con fecha no están disponibles ahora.',
          color: MpTokens.danger,
          actionLabel: 'Reintentar',
          onAction: _load,
        )
      else ...[
        _tiraSemana(),
        const SizedBox(height: MpTokens.space16),
        ..._lineaDelDia(),
        if (_data.siguiente != null) ...[
          const SizedBox(height: MpTokens.space20),
          _proxima(_data.siguiente!),
        ],
      ],
      if (_data.conIa.isNotEmpty) ...[
        const SizedBox(height: MpTokens.space24),
        ..._entrevistasIa(),
      ],
      const SizedBox(height: MpTokens.space24),
      _gestionarDisponibilidad(),
    ];
  }

  Widget _errorTotal() {
    return Padding(
      padding: const EdgeInsets.only(top: MpTokens.space32),
      child: MpEmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'No pudimos cargar las entrevistas',
        message: 'Ni la agenda ni las entrevistas con IA respondieron. '
            'Revisá tu conexión y volvé a intentar.',
        actionLabel: 'Reintentar',
        onAction: _load,
      ),
    );
  }

  Widget _encabezado() {
    final s = context.mp;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Se llega empujada desde Herramientas, así que hace falta salida. Va
        // condicional por si mañana se cuelga de una pestaña, como el Pipeline.
        if (Navigator.of(context).canPop()) ...[
          MpIconButton(
            icon: CupertinoIcons.chevron_left,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: MpTokens.space12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Entrevistas', style: MpTokens.h1.copyWith(color: s.text)),
              // El acceso al alta va en el encabezado: sin él, el circuito de
              // entrevista con IA no se puede originar desde Empresa.
              const SizedBox(height: MpTokens.space4),
              Text(
                'Tu agenda de entrevistas, en un solo lugar.',
                style: MpTokens.body.copyWith(
                  color: s.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: MpTokens.space8),
        MpIconButton(
          icon: CupertinoIcons.add,
          onPressed: () => Navigator.of(context)
              .push(
                CupertinoPageRoute(
                  builder: (_) => const EmpresaCrearEntrevistaScreen(),
                ),
              )
              .then((_) => _load()),
        ),
        const SizedBox(width: MpTokens.space8),
        MpIconButton(icon: CupertinoIcons.refresh, onPressed: _load),
      ],
    );
  }

  // ── Métricas ───────────────────────────────────────────────────────────────

  Widget _metricas() {
    final agendaOk = !_data.agendaNoDisponible;

    final tiles = <Widget>[
      MpStatTile(
        icon: CupertinoIcons.calendar_today,
        color: MpTokens.primary,
        value: agendaOk ? '${_data.hoy}' : '—',
        label: 'Hoy',
        compact: true,
      ),
      MpStatTile(
        icon: CupertinoIcons.calendar,
        color: MpTokens.catBlue,
        value: agendaOk ? '${_data.estaSemana}' : '—',
        label: 'Esta semana',
        compact: true,
      ),
      MpStatTile(
        icon: CupertinoIcons.clock,
        color: MpTokens.catOrange,
        value: agendaOk ? '${_data.proximas}' : '—',
        label: 'Próximas',
        compact: true,
      ),
      if (!_data.iaNoDisponible)
        MpStatTile(
          icon: CupertinoIcons.sparkles,
          color: MpTokens.catPurple,
          value: '${_data.conIa.length}',
          label: 'Con IA',
          compact: true,
        ),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: MpTokens.space8),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }

  // ── Tira de la semana ──────────────────────────────────────────────────────

  Widget _tiraSemana() {
    final s = context.mp;
    final hoy = DateTime.now();

    return MpCard(
      radius: MpTokens.radiusXL,
      padding: const EdgeInsets.symmetric(
        horizontal: MpTokens.space8,
        vertical: MpTokens.space12,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MpTokens.space8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_meses[_dia.month - 1]} ${_dia.year}',
                    style: MpTokens.label.copyWith(color: s.text),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(
                    () => _dia = _dia.subtract(const Duration(days: 7)),
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: Icon(
                    CupertinoIcons.chevron_left,
                    size: 16,
                    color: s.textSecondary,
                  ),
                ),
                const SizedBox(width: MpTokens.space16),
                GestureDetector(
                  onTap: () =>
                      setState(() => _dia = _dia.add(const Duration(days: 7))),
                  behavior: HitTestBehavior.opaque,
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: s.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MpTokens.space12),
          Row(
            children: [
              for (final dia in _semana)
                Expanded(child: _celdaDia(dia, hoy)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _celdaDia(DateTime dia, DateTime hoy) {
    final s = context.mp;
    final activo = dia.year == _dia.year &&
        dia.month == _dia.month &&
        dia.day == _dia.day;
    final esHoy =
        dia.year == hoy.year && dia.month == hoy.month && dia.day == hoy.day;
    final cantidad = _data.del(dia).length;

    return GestureDetector(
      onTap: () => setState(() => _dia = dia),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _diasCortos[dia.weekday - 1],
              style: MpTokens.micro.copyWith(
                color: activo ? s.accent : s.textTertiary,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(height: MpTokens.space4),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: activo ? s.accent : const Color(0x00000000),
              shape: BoxShape.circle,
              border: !activo && esHoy
                  ? Border.all(color: s.accent.withValues(alpha: 0.5))
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '${dia.day}',
              style: MpTokens.label.copyWith(
                color: activo ? const Color(0xFFFFFFFF) : s.text,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: cantidad > 0 ? MpTokens.catOrange : const Color(0x00000000),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  // ── Línea del día ──────────────────────────────────────────────────────────

  List<Widget> _lineaDelDia() {
    final s = context.mp;
    final delDia = _data.del(_dia);

    if (delDia.isEmpty) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: MpEmptyState(
            icon: CupertinoIcons.calendar,
            title: _data.agenda.isEmpty
                ? 'Todavía no tenés entrevistas agendadas'
                : 'Sin entrevistas este día',
            message: _data.agenda.isEmpty
                ? 'Cuando agendes una entrevista con un candidato, aparece acá '
                    'con su fecha, su hora y el acceso a la videollamada.'
                : 'Elegí otro día de la semana para ver su agenda.',
          ),
        ),
      ];
    }

    return [
      MpSectionHeader(
        title: 'Agenda del día',
        subtitle: '${delDia.length} '
            '${delDia.length == 1 ? 'entrevista' : 'entrevistas'} · '
            '${_dia.day} de ${_meses[_dia.month - 1]}',
      ),
      const SizedBox(height: MpTokens.space12),
      for (final e in delDia) ...[
        _filaAgenda(e),
        const SizedBox(height: MpTokens.space8),
      ],
      Text(
        'Sólo se listan entrevistas realmente agendadas.',
        style: MpTokens.micro.copyWith(color: s.textTertiary),
      ),
    ];
  }

  Widget _filaAgenda(EntrevistaEmpresa e) {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.all(MpTokens.space12),
      // La fila lleva a la sala de la entrevista, que es la acción del día. El
      // perfil del candidato sigue a un toque, desde dentro de la sala.
      onTap: () => _abrirSala(e),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _hora(e.cuando),
                  style: MpTokens.label.copyWith(color: s.text, fontSize: 13),
                ),
                if (e.duracionMinutos != null)
                  Text(
                    '${e.duracionMinutos} min',
                    style: MpTokens.micro.copyWith(
                      color: s.textTertiary,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 2,
            height: 44,
            margin: const EdgeInsets.only(right: MpTokens.space12),
            decoration: BoxDecoration(
              color: e.cancelada ? s.border : MpTokens.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          MpAvatar(
            name: e.candidato,
            size: 38,
            image: e.candidatoAvatar == null
                ? null
                : NetworkImage(e.candidatoAvatar!),
          ),
          const SizedBox(width: MpTokens.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e.candidato,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MpTokens.label.copyWith(color: s.text, fontSize: 14),
                ),
                if (e.candidatoHeadline != null)
                  Text(
                    e.candidatoHeadline!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MpTokens.micro.copyWith(color: s.textSecondary),
                  ),
                const SizedBox(height: MpTokens.space8),
                MpStatusBadge(
                  label: _estadoLegible(e.estado),
                  status: _estadoChip(e.estado),
                ),
              ],
            ),
          ),
          // "Ingresar" a la derecha de la fila, como en `entrevistas
          // nuevas.png`. Sólo si hay link real de videollamada.
          if (e.meetingUrl != null) ...[
            const SizedBox(width: MpTokens.space8),
            SizedBox(
              width: 92,
              child: MpButton(
                label: 'Unirse',
                icon: CupertinoIcons.videocam,
                size: MpButtonSize.small,
                expand: true,
                onPressed: () => _unirse(e.meetingUrl!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _abrirSala(EntrevistaEmpresa e) {
    Navigator.of(context)
        .push(
          CupertinoPageRoute(
            builder: (_) => EmpresaSalaEntrevistaScreen(entrevista: e),
          ),
        )
        // La sala puede haber creado el link: al volver se refresca.
        .then((_) => _load());
  }

  void _abrirInforme(EntrevistaEmpresa e) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => EmpresaInformeEntrevistaScreen(interviewId: e.id),
      ),
    );
  }

  void _abrirPerfil(EntrevistaEmpresa e) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) =>
            EmpresaCandidatoPerfilScreen(candidatoId: e.candidatoId!),
      ),
    );
  }

  // ── Próxima entrevista ─────────────────────────────────────────────────────

  Widget _proxima(EntrevistaEmpresa e) {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Próxima entrevista',
            style: MpTokens.title.copyWith(color: s.text),
          ),
          const SizedBox(height: MpTokens.space12),
          Row(
            children: [
              MpAvatar(
                name: e.candidato,
                size: 44,
                image: e.candidatoAvatar == null
                    ? null
                    : NetworkImage(e.candidatoAvatar!),
              ),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e.candidato,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MpTokens.label.copyWith(color: s.text),
                    ),
                    Text(
                      '${e.cuando!.day} de ${_meses[e.cuando!.month - 1]}'
                      ' · ${_hora(e.cuando)}',
                      style: MpTokens.micro.copyWith(color: s.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MpTokens.space12),
          if (e.meetingUrl != null)
            MpButton(
              label: 'Unirse a la entrevista',
              icon: CupertinoIcons.videocam_fill,
              expand: true,
              onPressed: () => _unirse(e.meetingUrl!),
            )
          else
            Text(
              'Esta entrevista todavía no tiene link de videollamada.',
              style: MpTokens.micro.copyWith(color: s.textTertiary),
            ),
        ],
      ),
    );
  }

  // ── Entrevistas con IA ─────────────────────────────────────────────────────

  List<Widget> _entrevistasIa() {
    final s = context.mp;

    return [
      const MpSectionHeader(
        title: 'Entrevistas con IA',
        subtitle: 'Asíncronas: el candidato responde cuando puede.',
      ),
      const SizedBox(height: MpTokens.space12),
      MpRowGroup(
        dividerIndent: 62,
        rows: [
          for (final e in _data.conIa)
            // La fila lleva al INFORME sólo si existe de verdad en
            // `interview_reports`. Sin informe cae al perfil del candidato:
            // ningún camino ofrece abrir algo que todavía no se generó.
            MpListRow(
              leading: MpAvatar(
                name: e.candidato,
                size: 42,
                image: e.candidatoAvatar == null
                    ? null
                    : NetworkImage(e.candidatoAvatar!),
              ),
              title: e.candidato,
              subtitle: _data.conInforme.contains(e.id)
                  ? 'Informe de IA listo'
                  : e.vacante,
              trailing: _data.conInforme.contains(e.id)
                  ? const MpTypeChip(
                      label: 'Ver informe',
                      color: MpTokens.primary,
                      icon: CupertinoIcons.sparkles,
                    )
                  : MpStatusBadge(
                      label: _estadoLegible(e.estado),
                      status: _estadoChip(e.estado),
                    ),
              showChevron: _data.conInforme.contains(e.id),
              onTap: _data.conInforme.contains(e.id)
                  ? () => _abrirInforme(e)
                  : (e.candidatoId == null ? null : () => _abrirPerfil(e)),
            ),
        ],
      ),
      const SizedBox(height: MpTokens.space8),
      Text(
        'El informe de cada entrevista se genera cuando el candidato la '
        'completa.',
        style: MpTokens.micro.copyWith(color: s.textTertiary),
      ),
    ];
  }

  // ── Disponibilidad ─────────────────────────────────────────────────────────

  /// Los horarios disponibles (`interview_slots`) ya tienen pantalla propia y
  /// funciona: se enlaza en vez de duplicarla.
  Widget _gestionarDisponibilidad() {
    return MpBanner(
      icon: CupertinoIcons.clock_fill,
      title: 'Tus horarios disponibles',
      message: 'Definí en qué franjas podés entrevistar y los candidatos '
          'reservan sobre esa disponibilidad.',
      actionLabel: 'Gestionar horarios',
      onAction: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => const SchedulingScreen(isCompany: true),
        ),
      ),
    );
  }
}
