import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../services/application_stage_service.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../../services/job_offer_service.dart';
import '../../widgets/empresa/cambio_etapa_sheet.dart';
import '../chat_inmail_screen.dart';
import 'empresa_candidato_perfil_screen.dart';
import 'empresa_candidatura_historial_screen.dart';
import 'empresa_crear_oferta_screen.dart';
import 'empresa_oferta_detalle_screen.dart';
import 'empresa_mensajes_screen.dart';
import 'empresa_talent_feed_screen.dart';

/// Etapas del pipeline de Empresa.
///
/// ADENDA 30/8/2026 · ETAPA E1 DEL PLAN. Estas etapas eran las cuatro de
/// `connections.ats_status` (new | interviewing | hired | rejected). Se
/// cambian por las SEIS de `job_applications.status`, que es la vía canónica
/// de la migración 029: la anterior no la escribía ninguna ruta productiva
/// —el propio encabezado de esta pantalla lo dejó documentado el 12/8— así
/// que el Pipeline era una lista de lectura sobre una columna muerta y no
/// podía mover a nadie de etapa.
///
/// Son EXACTAMENTE los seis estados que admite el CHECK de la tabla. No se
/// agrupan dos en una columna ni se inventa ninguna: "Con oferta" y
/// "Contratado" son estados distintos en la base, y esa distinción es
/// justamente lo que hacía falta para cerrar el proceso.
enum EtapaPipeline {
  nuevos,
  vistos,
  entrevista,
  oferta,
  contratados,
  descartados,
}

extension EtapaInfo on EtapaPipeline {
  /// Valor real de `job_applications.status`.
  String get status => switch (this) {
        EtapaPipeline.nuevos => 'pending',
        EtapaPipeline.vistos => 'viewed',
        EtapaPipeline.entrevista => 'interviewing',
        EtapaPipeline.oferta => 'accepted',
        EtapaPipeline.contratados => 'hired',
        EtapaPipeline.descartados => 'rejected',
      };

  /// La etiqueta sale del servicio para que Pipeline, historial y
  /// Contrataciones llamen igual a la misma etapa.
  String get etiqueta => applicationStageLabel(status);

  Color get color => switch (this) {
        EtapaPipeline.nuevos => MpTokens.primary,
        EtapaPipeline.vistos => MpTokens.catBlue,
        EtapaPipeline.entrevista => MpTokens.catOrange,
        EtapaPipeline.oferta => MpTokens.catPurple,
        EtapaPipeline.contratados => MpTokens.catGreen,
        EtapaPipeline.descartados => MpTokens.danger,
      };

  IconData get icono => switch (this) {
        EtapaPipeline.nuevos => CupertinoIcons.person_badge_plus,
        EtapaPipeline.vistos => CupertinoIcons.eye,
        EtapaPipeline.entrevista => CupertinoIcons.calendar,
        EtapaPipeline.oferta => CupertinoIcons.doc_text,
        EtapaPipeline.contratados => CupertinoIcons.checkmark_seal,
        EtapaPipeline.descartados => CupertinoIcons.xmark_circle,
      };
}

/// La etapa que corresponde a un `status` crudo, o null si no lo conocemos.
EtapaPipeline? etapaDeStatus(String status) {
  for (final e in EtapaPipeline.values) {
    if (e.status == status) return e;
  }
  return null;
}

@immutable
class CandidatoPipeline {
  /// `job_applications.id`. Es lo que necesita `update_application_status`
  /// para mover a esta persona de etapa.
  final String applicationId;

  final NexUser usuario;
  final EtapaPipeline etapa;

  /// Título de la vacante a la que se postuló. Una misma persona puede estar
  /// en el pipeline dos veces si se postuló a dos vacantes: son dos
  /// postulaciones distintas y se muestran por separado.
  final String? vacante;

  const CandidatoPipeline({
    required this.applicationId,
    required this.usuario,
    required this.etapa,
    this.vacante,
  });
}

@immutable
class PipelineData {
  final List<CandidatoPipeline> candidatos;
  final bool error;

  /// Postulaciones cuyo `status` no pertenece al vocabulario de la app.
  ///
  /// Con la vía canónica esto debería ser siempre cero —el CHECK de la tabla
  /// no admite otro valor—, pero la guarda se conserva: si alguna vez se
  /// agrega un estado en la base antes que en la app, la pantalla lo dice en
  /// vez de meter esas filas en la primera columna como si fueran nuevas.
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

/// Carga el pipeline real desde `job_applications` — la vía canónica de la
/// migración 029.
///
/// TRES CONSULTAS, Y CADA UNA POR UN MOTIVO:
///
///   1. `jobs` — las vacantes propias. Da los ids con los que acotar las
///      postulaciones y, de paso, el título de cada vacante.
///   2. `job_applications` — el ESTADO y, sobre todo, el `id` de cada
///      postulación, que es lo único que permite moverla de etapa.
///   3. `get_company_candidates` — el perfil del candidato ya resuelto, con
///      la confidencialidad aplicada. Se usa esta RPC y no un SELECT sobre
///      `users` para no rehacer a mano las reglas de perfiles confidenciales.
///
/// POR QUÉ NO SE SACA TODO DE LA RPC. El contrato de columnas de
/// `get_company_candidates` no vive en ninguna migración: se escribió a mano
/// contra la base (ver la nota de la 038), así que no se asume que devuelva
/// el id de la postulación. Se une por (candidato, vacante), que es la clave
/// real de una postulación.
///
/// Si el perfil de alguien no aparece en la RPC, la fila se muestra igual con
/// el nombre en blanco: perder una postulación del tablero por no tener el
/// nombre sería peor que mostrarla incompleta.
Future<PipelineData> loadEmpresaPipeline() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return PipelineData.empty;

  try {
    // ── 1. Vacantes propias ──
    final vacantes = await client
        .from('jobs')
        .select('id, title')
        .eq('company_id', uid);

    final titulos = <String, String>{};
    for (final raw in vacantes as List<dynamic>) {
      final v = raw as Map;
      final id = v['id']?.toString();
      if (id == null || id.isEmpty) continue;
      titulos[id] = v['title']?.toString() ?? 'Vacante';
    }
    if (titulos.isEmpty) return PipelineData.empty;

    // ── 2. Postulaciones a esas vacantes ──
    final postulaciones = await client
        .from('job_applications')
        .select('id, status, job_id, candidate_id, created_at')
        .inFilter('job_id', titulos.keys.toList())
        .order('created_at', ascending: false);

    // ── 3. Perfiles, indexados por (candidato, vacante) ──
    final perfiles = <String, Map>{};
    try {
      final filas = await client.rpc('get_company_candidates') as List<dynamic>;
      for (final raw in filas) {
        final f = raw as Map;
        final clave =
            '${f['candidate_id']}|${f['job_id']}';
        perfiles[clave] = f;
      }
    } catch (e) {
      // El perfil es adorno; el proceso no. Si la RPC falla, el tablero
      // igual se dibuja con los estados reales.
      debugPrint('pipeline · get_company_candidates: $e');
    }

    final candidatos = <CandidatoPipeline>[];
    var sinSoporte = 0;

    for (final raw in postulaciones as List<dynamic>) {
      final fila = raw as Map;
      final estado = fila['status']?.toString() ?? '';

      // NO se adivina la etapa: un estado desconocido se cuenta aparte y se
      // dice en pantalla, en vez de caer en la primera columna.
      final etapa = etapaDeStatus(estado);
      if (etapa == null) {
        sinSoporte++;
        continue;
      }

      final candidatoId = fila['candidate_id']?.toString() ?? '';
      final jobId = fila['job_id']?.toString() ?? '';
      final perfil = perfiles['$candidatoId|$jobId'];

      final confidencial = perfil?['is_confidential'] == true;
      final tags = perfil?['candidate_tags'];

      candidatos.add(
        CandidatoPipeline(
          applicationId: fila['id']?.toString() ?? '',
          etapa: etapa,
          vacante: titulos[jobId],
          usuario: NexUser.fromJson({
            'id': candidatoId,
            'name': perfil?['candidate_name']?.toString() ?? 'Candidato',
            'headline': perfil?['candidate_headline'],
            'avatar_url': perfil?['candidate_avatar_url'],
            'account_type': confidencial ? 'confidencial' : 'candidato',
            'tags': tags is List ? List<String>.from(tags.map((t) => '$t')) : <String>[],
          }),
        ),
      );
    }

    return PipelineData(candidatos: candidatos, sinSoporte: sinSoporte);
  } catch (e) {
    debugPrint('pipeline · job_applications: $e');
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
/// ADENDA 30/8/2026 · ETAPA E1 DEL PLAN — se cierra aquella contención. La
/// pantalla deja de leer `connections.ats_status` (la columna muerta) y pasa
/// a `job_applications`, la vía canónica de la migración 029, que sí tiene
/// una ruta de escritura productiva: la RPC `update_application_status`. Con
/// eso el tablero recupera lo que nunca pudo hacer —mover a alguien de
/// etapa— y cada movimiento queda registrado con actor y motivo en el
/// historial de la migración 050.
///
/// Tres consecuencias visibles, todas deliberadas:
///   · Las columnas pasan de cuatro a seis, porque ése es el vocabulario
///     real de la base ("Con oferta" y "Contratado" son estados distintos).
///   · La unidad del tablero pasa a ser la POSTULACIÓN, no la conexión: una
///     persona que se postuló a dos vacantes aparece dos veces, que es lo
///     correcto porque cada proceso avanza por su cuenta.
///   · Tocar una tarjeta abre un menú en vez de ir directo al perfil.
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

  /// FIX (Pedro, 30/8/2026): con seis columnas en una pantalla de teléfono
  /// entran menos de dos a la vez, así que después de mover a alguien la
  /// tarjeta desaparecía de la vista y había que ir buscándola a mano
  /// columna por columna. Ahora el tablero se desplaza solo hasta la etapa
  /// donde quedó, y las métricas de abajo —que sí muestran las seis juntas—
  /// funcionan como índice: tocar una lleva a su columna.
  final ScrollController _columnasCtrl = ScrollController();

  /// Ancho de una columna (208) más la separación (space12).
  static const double _anchoColumna = 208 + MpTokens.space12;

  @override
  void dispose() {
    _columnasCtrl.dispose();
    super.dispose();
  }

  Future<void> _irAEtapa(EtapaPipeline etapa) async {
    if (!_columnasCtrl.hasClients) return;
    final destino = (EtapaPipeline.values.indexOf(etapa) * _anchoColumna)
        .clamp(0.0, _columnasCtrl.position.maxScrollExtent)
        .toDouble();
    await _columnasCtrl.animateTo(
      destino,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

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
        title: 'Hay postulaciones que la app no sabe ubicar',
        message: 'Tenés ${_data.sinSoporte} '
            '${_data.sinSoporte == 1 ? "postulación" : "postulaciones"} '
            'con un estado que esta versión no reconoce. Actualizá la app; '
            'mientras tanto podés gestionarlas desde Candidatos.',
      );
    }

    return const MpEmptyState(
      icon: CupertinoIcons.person_2,
      title: 'Todavía no hay postulaciones',
      message: 'Cuando alguien se postule a una de tus vacantes va a aparecer '
          'acá, y desde este tablero lo movés de etapa.',
    );
  }

  // ── Acciones sobre una postulación ────────────────────────────────────────

  /// Menú de la tarjeta. Antes la tarjeta abría el perfil directo; ahora
  /// desde acá también se mueve de etapa, que es lo que este tablero no podía
  /// hacer (ver la adenda del 30/8 arriba).
  Future<void> _acciones(CandidatoPipeline c) async {
    final confidencial =
        c.usuario.accountType.toLowerCase().startsWith('confidenc');
    final nombre = confidencial ? 'Candidato confidencial' : c.usuario.name;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(nombre),
        message: Text(
          c.vacante == null
              ? 'Está en ${c.etapa.etiqueta}'
              : '${c.vacante} · ${c.etapa.etiqueta}',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _moverEtapa(c, nombre);
            },
            child: const Text('Mover de etapa'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => EmpresaCandidaturaHistorialScreen(
                    applicationId: c.applicationId,
                    nombreCandidato: nombre,
                    vacante: c.vacante,
                  ),
                ),
              );
            },
            child: const Text('Ver historial'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) =>
                      EmpresaCandidatoPerfilScreen(candidatoId: c.usuario.id),
                ),
              );
            },
            child: const Text('Ver perfil'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _oferta(c, nombre);
            },
            child: const Text('Oferta'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  /// Abre la oferta de esta postulación si ya existe, o el formulario para
  /// crear una si no. La empresa no tiene que saber cuál es: acá se
  /// consulta y se decide (migración 051, bloque E2).
  Future<void> _oferta(CandidatoPipeline c, String nombre) async {
    setState(() => _loading = true);
    JobOffer? existente;
    try {
      existente = await loadOfferForApplication(c.applicationId);
    } catch (_) {
      existente = null;
    }
    if (!mounted) return;
    setState(() => _loading = false);

    final vacante = c.vacante ?? 'Vacante';
    if (existente == null) {
      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => EmpresaCrearOfertaScreen(
            applicationId: c.applicationId,
            candidatoNombre: nombre,
            vacante: vacante,
          ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => EmpresaOfertaDetalleScreen(
            applicationId: c.applicationId,
            candidatoNombre: nombre,
            vacante: vacante,
          ),
        ),
      );
    }
    if (!mounted) return;
    _load();
  }

  /// El estado nuevo lo decide el servidor: acá no se toca `_data` a mano.
  /// Si la RPC acepta el cambio se recarga el tablero completo, así el
  /// contador de cada columna y la etapa quedan siempre como los ve la base.
  Future<void> _moverEtapa(CandidatoPipeline c, String nombre) async {
    final eleccion = await mostrarCambioEtapa(
      context,
      nombreCandidato: nombre,
      estadoActual: c.etapa.status,
    );
    if (eleccion == null || !mounted) return;

    setState(() => _loading = true);
    try {
      await setApplicationStage(
        applicationId: c.applicationId,
        status: eleccion.status,
        reason: eleccion.reason,
        notes: eleccion.notes,
      );
    } on StageChangeException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await _avisar('No se pudo mover', e.mensaje);
      return;
    }
    if (!mounted) return;
    await _load();
    if (!mounted) return;

    // El tablero ya se recargó: llevar la vista a donde quedó la persona.
    // Se espera al frame siguiente porque el ListView de columnas recién se
    // vuelve a construir cuando termina la recarga, y antes de eso el
    // controller todavía no tiene clientes.
    final destino = etapaDeStatus(eleccion.status);
    if (destino != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _irAEtapa(destino);
      });
    }
  }

  Future<void> _avisar(String titulo, String mensaje) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(titulo),
        content: Padding(
          padding: const EdgeInsets.only(top: MpTokens.space8),
          child: Text(mensaje),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ── Columnas por etapa ────────────────────────────────────────────────────

  Widget _columnas() {
    return SizedBox(
      height: 316,
      child: ListView.separated(
        controller: _columnasCtrl,
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
      onTap: () => _acciones(c),
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

    return GestureDetector(
      onTap: () => _irAEtapa(etapa),
      behavior: HitTestBehavior.opaque,
      child: Column(
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
      ),
    );
  }
}
