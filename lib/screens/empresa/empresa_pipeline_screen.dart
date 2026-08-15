import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../chat_inmail_screen.dart';
import 'empresa_candidato_perfil_screen.dart';
import 'empresa_mensajes_screen.dart';
import 'empresa_talent_feed_screen.dart';

/// Etapas del pipeline de Empresa.
///
/// Son EXACTAMENTE las que soporta `connections.ats_status`
/// (new | interviewing | hired | rejected). El mockup de referencia tiene siete,
/// pero dos —"Presentados al cliente" y "Entrevista con cliente"— pertenecen al
/// flujo de headhunter, donde hay un tercero. En Empresa la vacante es propia:
/// esas etapas no existen y no se inventan.
enum EtapaPipeline { nuevos, entrevista, contratados, descartados }

extension EtapaInfo on EtapaPipeline {
  String get etiqueta => switch (this) {
        EtapaPipeline.nuevos => 'Nuevos',
        EtapaPipeline.entrevista => 'En entrevista',
        EtapaPipeline.contratados => 'Contratados',
        EtapaPipeline.descartados => 'Descartados',
      };

  /// Valor real de `connections.ats_status`.
  String get atsStatus => switch (this) {
        EtapaPipeline.nuevos => 'new',
        EtapaPipeline.entrevista => 'interviewing',
        EtapaPipeline.contratados => 'hired',
        EtapaPipeline.descartados => 'rejected',
      };

  Color get color => switch (this) {
        EtapaPipeline.nuevos => MpTokens.primary,
        EtapaPipeline.entrevista => MpTokens.catOrange,
        EtapaPipeline.contratados => MpTokens.catGreen,
        EtapaPipeline.descartados => MpTokens.danger,
      };

  IconData get icono => switch (this) {
        EtapaPipeline.nuevos => CupertinoIcons.person_badge_plus,
        EtapaPipeline.entrevista => CupertinoIcons.calendar,
        EtapaPipeline.contratados => CupertinoIcons.checkmark_seal,
        EtapaPipeline.descartados => CupertinoIcons.xmark_circle,
      };
}

@immutable
class CandidatoPipeline {
  final String connectionId;
  final NexUser usuario;
  final EtapaPipeline etapa;

  const CandidatoPipeline({
    required this.connectionId,
    required this.usuario,
    required this.etapa,
  });
}

@immutable
class PipelineData {
  final List<CandidatoPipeline> candidatos;
  final bool error;

  /// Filas que la RPC devolvió con un `ats_status` que esta app no soporta.
  ///
  /// Existe para poder decir la verdad en pantalla: hay gente conectada, pero
  /// su estado no pertenece al vocabulario del pipeline, así que no se la puede
  /// ubicar en ninguna etapa. Verificado el 12/8/2026: la base tiene
  /// `pendiente`, y el código sólo entiende new/interviewing/hired/rejected.
  final int sinSoporte;

  const PipelineData({
    required this.candidatos,
    this.error = false,
    this.sinSoporte = 0,
  });

  static const empty = PipelineData(candidatos: []);

  /// No hay ni una fila ubicable en una etapa real.
  bool get sinPipelineSoportado => candidatos.isEmpty;

  List<CandidatoPipeline> de(EtapaPipeline etapa) =>
      candidatos.where((c) => c.etapa == etapa).toList();

  int get total => candidatos.length;
}

/// Carga el pipeline real vía la RPC `get_my_pipeline`, la misma que usa el
/// Kanban existente. No hay datos de relleno.
Future<PipelineData> loadEmpresaPipeline() async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return PipelineData.empty;

  try {
    final filas = await client.rpc('get_my_pipeline') as List<dynamic>;
    final candidatos = <CandidatoPipeline>[];
    var sinSoporte = 0;

    for (final raw in filas) {
      final fila = raw as Map;
      // NO se adivina la etapa. Antes había un `orElse: () => nuevos`, que
      // convertía CUALQUIER estado desconocido en "Nuevos" — verificado contra
      // la base, las filas reales tienen `ats_status = 'pendiente'`, así que
      // todas habrían aparecido como nuevas sin serlo.
      final estado = fila['ats_status']?.toString() ?? '';
      EtapaPipeline? etapa;
      for (final e in EtapaPipeline.values) {
        if (e.atsStatus == estado) {
          etapa = e;
          break;
        }
      }
      if (etapa == null) {
        sinSoporte++;
        continue;
      }

      candidatos.add(
        CandidatoPipeline(
          connectionId: fila['connection_id']?.toString() ?? '',
          etapa: etapa,
          usuario: NexUser.fromJson({
            'id': fila['user_id'],
            'name': fila['user_name'],
            'headline': fila['user_headline'],
            'avatar_url': fila['user_avatar_url'],
            'account_type': fila['is_confidential'] == true
                ? 'confidencial'
                : fila['user_account_type'],
            'video_url': fila['user_video_url'],
            'tags': <String>[],
          }),
        ),
      );
    }

    return PipelineData(candidatos: candidatos, sinSoporte: sinSoporte);
  } catch (e) {
    debugPrint('pipeline · get_my_pipeline: $e');
    return const PipelineData(candidatos: [], error: true);
  }
}

/// Pipeline de candidatos de Empresa.
///
/// DERIVACIÓN CONTROLADA de `_Headhunter_Pipeline_Busqueda.png`: se conserva su
/// estructura —columnas por etapa con contador, tarjetas de candidato, fila de
/// métricas y acciones rápidas— y se adapta al rol Empresa, quitando las etapas
/// de cliente externo y usando los cuatro estados que la base soporta.
///
/// No se muestra porcentaje de Match: el Match es candidato ↔ vacante y el
/// pipeline no está acotado a una vacante.
/// DESCONGELADA el 12/8/2026 para contención. Se comprobó contra la base que
/// el vocabulario de estados que esta pantalla asume —new/interviewing/hired/
/// rejected— NO lo escribe ninguna ruta productiva: el único código que lo
/// hacía (`ats_kanban_screen`) es inalcanzable, y las filas reales tienen
/// `ats_status = pendiente`. La pantalla ya no afirma que hay un pipeline por
/// etapas cuando no lo hay.
///
/// POLISH VISUAL 2 (15/8/2026): se agregó "Acciones rápidas" (Buscar
/// candidatos / Mensajes) entre las columnas y las métricas — el mockup tiene
/// un bloque equivalente ("Agregar candidato / Enviar mensaje / Crear
/// shortlist / Ver shortlist"), pero acá sólo se llevan las DOS acciones que
/// no requieren elegir antes un candidato o una vacante (Shortlist pide una
/// vacante; "enviar mensaje" desde acá no tiene destinatario). También llena
/// el hueco visual que dejaba una columna de 316pt con 2-3 tarjetas cortas.
///
class EmpresaPipelineScreen extends StatefulWidget {
  final PipelineData? previewData;

  const EmpresaPipelineScreen({super.key, this.previewData});

  @override
  State<EmpresaPipelineScreen> createState() => _EmpresaPipelineScreenState();
}

class _EmpresaPipelineScreenState extends State<EmpresaPipelineScreen> {
  PipelineData _data = PipelineData.empty;
  bool _loading = true;

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
    final data = await loadEmpresaPipeline();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

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
                  SliverToBoxAdapter(child: _encabezado()),
                  if (_data.total == 0)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _vacio(),
                    )
                  else ...[
                    SliverToBoxAdapter(child: _columnas()),
                    SliverToBoxAdapter(child: _accionesRapidas()),
                    SliverToBoxAdapter(child: _metricas()),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: MpTokens.space32),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _encabezado() {
    final s = context.mp;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        MpTokens.space12,
        MpTokens.screenPadding,
        MpTokens.space16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El Pipeline vive en dos lugares: como pestaña del IndexedStack —donde
          // volver no significa nada— y empujado desde Herramientas o desde el
          // detalle de una vacante. El botón sólo existe en el segundo caso.
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
                Text('Pipeline', style: MpTokens.h1.copyWith(color: s.text)),
                const SizedBox(height: MpTokens.space4),
                Text(
                  _data.total == 0
                      ? 'Seguí a tus candidatos por etapa'
                      : '${_data.total} ${_data.total == 1 ? 'candidato' : 'candidatos'} en proceso',
                  style: MpTokens.body.copyWith(
                    color: s.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          MpIconButton(icon: CupertinoIcons.refresh, onPressed: _load),
        ],
      ),
    );
  }

  Widget _vacio() {
    if (_data.error) {
      return MpEmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'No pudimos cargar el pipeline',
        message: 'Revisá tu conexión y volvé a intentar.',
        actionLabel: 'Reintentar',
        onAction: _load,
      );
    }

    // HAY GENTE, PERO NO HAY ETAPAS. La RPC devolvió filas con un estado que
    // esta app no sabe interpretar. Antes se las metía a todas en "Nuevos";
    // ahora se dice lo que pasa en vez de fabricar una etapa.
    if (_data.sinSoporte > 0) {
      return MpEmptyState(
        icon: CupertinoIcons.exclamationmark_circle,
        title: 'El seguimiento por etapas todavía no está disponible',
        message: 'Tenés ${_data.sinSoporte} '
            '${_data.sinSoporte == 1 ? "candidato conectado" : "candidatos conectados"}, '
            'pero su estado no corresponde a ninguna etapa que la app pueda '
            'seguir. Mientras tanto, gestionalos desde Candidatos.',
      );
    }

    return const MpEmptyState(
      icon: CupertinoIcons.person_2,
      title: 'Todavía no hay candidatos en proceso',
      message: 'Cuando marques candidatos como interesantes desde el feed, van '
          'a aparecer acá por etapa.',
    );
  }

  // ── Columnas por etapa ────────────────────────────────────────────────────

  Widget _columnas() {
    return SizedBox(
      height: 316,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: MpTokens.screenPadding,
        ),
        itemCount: EtapaPipeline.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: MpTokens.space12),
        itemBuilder: (context, i) => _columna(EtapaPipeline.values[i]),
      ),
    );
  }

  Widget _columna(EtapaPipeline etapa) {
    final s = context.mp;
    final candidatos = _data.de(etapa);
    const visibles = 2;

    return SizedBox(
      width: 208,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MpTokens.space12,
              vertical: MpTokens.space8,
            ),
            decoration: BoxDecoration(
              color: etapa.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(MpTokens.radiusMD),
            ),
            child: Row(
              children: [
                Icon(etapa.icono, size: 15, color: etapa.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    etapa.etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MpTokens.label.copyWith(color: etapa.color),
                  ),
                ),
                Text(
                  '${candidatos.length}',
                  style: MpTokens.label.copyWith(
                    color: etapa.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MpTokens.space8),
          if (candidatos.isEmpty)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: s.fill,
                  borderRadius: BorderRadius.circular(MpTokens.radiusLG),
                ),
                child: Center(
                  child: Text(
                    'Sin candidatos',
                    style: MpTokens.micro.copyWith(color: s.textTertiary),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in candidatos.take(visibles)) ...[
                    _tarjeta(c),
                    const SizedBox(height: MpTokens.space8),
                  ],
                  if (candidatos.length > visibles)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.fill,
                        borderRadius:
                            BorderRadius.circular(MpTokens.radiusMD),
                      ),
                      child: Text(
                        '+${candidatos.length - visibles} más',
                        style: MpTokens.micro.copyWith(
                          color: s.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tarjeta(CandidatoPipeline c) {
    final s = context.mp;
    final confidencial =
        c.usuario.accountType.toLowerCase().startsWith('confidenc');

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.all(MpTokens.space12),
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) =>
              EmpresaCandidatoPerfilScreen(candidatoId: c.usuario.id),
        ),
      ),
      child: Row(
        children: [
          MpAvatar(
            name: c.usuario.name,
            size: 34,
            image: (c.usuario.avatarUrl?.isNotEmpty ?? false) && !confidencial
                ? NetworkImage(c.usuario.avatarUrl!)
                : null,
          ),
          const SizedBox(width: MpTokens.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  confidencial ? 'Candidato confidencial' : c.usuario.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MpTokens.label.copyWith(color: s.text, fontSize: 13),
                ),
                if (c.usuario.headline.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    c.usuario.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MpTokens.micro.copyWith(
                      color: s.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => ChatInmailScreen(targetUser: c.usuario),
              ),
            ),
            behavior: HitTestBehavior.opaque,
            child: Icon(
              CupertinoIcons.chat_bubble,
              size: 16,
              color: s.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Acciones rápidas ──────────────────────────────────────────────────────

  Widget _accionesRapidas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        MpTokens.space20,
        MpTokens.screenPadding,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: MpButton(
              label: 'Buscar candidatos',
              icon: CupertinoIcons.search,
              variant: MpButtonVariant.outline,
              expand: true,
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const EmpresaTalentFeedScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          Expanded(
            child: MpButton(
              label: 'Mensajes',
              icon: CupertinoIcons.chat_bubble_2,
              variant: MpButtonVariant.outline,
              expand: true,
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const EmpresaMensajesScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Métricas ──────────────────────────────────────────────────────────────

  Widget _metricas() {
    final s = context.mp;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        MpTokens.space24,
        MpTokens.screenPadding,
        0,
      ),
      child: MpCard(
        radius: MpTokens.radiusXL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Métricas del pipeline',
              style: MpTokens.title.copyWith(color: s.text),
            ),
            const SizedBox(height: MpTokens.space16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < EtapaPipeline.values.length; i++) ...[
                    if (i > 0) const SizedBox(width: MpTokens.space8),
                    Expanded(child: _metrica(EtapaPipeline.values[i])),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metrica(EtapaPipeline etapa) {
    final s = context.mp;
    final cantidad = _data.de(etapa).length;
    final pct = _data.total == 0
        ? '0%'
        : '${(cantidad / _data.total * 100).round()}%';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MpIconTile(
          icon: etapa.icono,
          color: etapa.color,
          size: 32,
          circular: true,
        ),
        const SizedBox(height: MpTokens.space8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$cantidad',
            style: MpTokens.stat.copyWith(color: s.text, fontSize: 20),
          ),
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            etapa.etiqueta,
            style: MpTokens.micro.copyWith(color: s.textSecondary, fontSize: 10.5),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            pct,
            style: MpTokens.micro.copyWith(
              color: s.textTertiary,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}
