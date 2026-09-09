import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/application_stage_service.dart';
import '../../widgets/ds/mploya_ds.dart';

/// Historial de una candidatura: cada cambio de etapa, con quién y por qué.
///
/// Pantalla nueva del 30/8/2026 (etapa E1 del plan). No hay PNG de referencia
/// —entre los 88 no existe una pantalla de historial—, así que se arma con
/// piezas ya aprobadas del sistema: encabezado de pantalla empujada, lista
/// vertical y estado vacío explicado.
///
/// LOS DATOS SON DE SÓLO LECTURA. El historial lo escribe el trigger del
/// servidor (migración 050); acá nunca se inserta ni se corrige nada.
///
/// EL VACÍO NO ES UN ERROR. Las postulaciones anteriores a la migración 050
/// no tienen historial y no se les inventa uno: no sabemos quién las movió ni
/// cuándo. La pantalla lo dice con todas las letras en vez de mostrar una
/// lista vacía sin explicación.
class EmpresaCandidaturaHistorialScreen extends StatefulWidget {
  const EmpresaCandidaturaHistorialScreen({
    super.key,
    required this.applicationId,
    required this.nombreCandidato,
    this.vacante,
    this.previewData,
  });

  final String applicationId;
  final String nombreCandidato;
  final String? vacante;

  /// Datos ya resueltos, para los golden tests.
  final List<ApplicationStageEvent>? previewData;

  @override
  State<EmpresaCandidaturaHistorialScreen> createState() =>
      _EmpresaCandidaturaHistorialScreenState();
}

class _EmpresaCandidaturaHistorialScreenState
    extends State<EmpresaCandidaturaHistorialScreen> {
  List<ApplicationStageEvent> _eventos = const [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    final preview = widget.previewData;
    if (preview != null) {
      _eventos = preview;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final eventos = await loadStageHistory(widget.applicationId);
      if (!mounted) return;
      setState(() {
        _eventos = eventos;
        _loading = false;
      });
    } catch (e) {
      debugPrint('historial · loadStageHistory: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  String? get _miUid => Supabase.instance.client.auth.currentUser?.id;

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: Builder(
        builder: (context) {
          final s = context.mp;
          return CupertinoPageScaffold(
            backgroundColor: s.bg,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _encabezado(s),
                  Expanded(
                    child: _loading
                        ? const Center(child: CupertinoActivityIndicator(radius: 15))
                        : _cuerpo(s),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _encabezado(MpSurfaceStyle s) {
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
          MpIconButton(
            icon: CupertinoIcons.chevron_left,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Historial', style: MpTokens.h1.copyWith(color: s.text)),
                const SizedBox(height: MpTokens.space4),
                Text(
                  widget.vacante == null
                      ? widget.nombreCandidato
                      : '${widget.nombreCandidato} · ${widget.vacante}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MpTokens.body.copyWith(
                    color: s.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cuerpo(MpSurfaceStyle s) {
    if (_error) {
      return MpEmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'No pudimos cargar el historial',
        message: 'Revisá tu conexión y volvé a intentar.',
        actionLabel: 'Reintentar',
        onAction: _load,
      );
    }

    if (_eventos.isEmpty) {
      return const MpEmptyState(
        icon: CupertinoIcons.clock,
        title: 'Todavía no hay movimientos registrados',
        message: 'El historial empieza a guardarse a partir del primer cambio '
            'de etapa. Las postulaciones que ya venían de antes no tienen '
            'registro previo, y no se les inventa uno.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        0,
        MpTokens.screenPadding,
        MpTokens.space32,
      ),
      itemCount: _eventos.length,
      separatorBuilder: (_, __) => const SizedBox(height: MpTokens.space8),
      itemBuilder: (context, i) => _evento(_eventos[i], s),
    );
  }

  Widget _evento(ApplicationStageEvent e, MpSurfaceStyle s) {
    final destino = e.toStatus;
    final color = destino == kApplicationRejected
        ? MpTokens.danger
        : (destino == 'hired' ? MpTokens.catGreen : MpTokens.primary);

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.all(MpTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: MpTokens.space8),
              Expanded(
                child: Text(
                  e.fromStatus == null
                      ? applicationStageVerb(destino)
                      : '${applicationStageLabel(e.fromStatus!)} → '
                          '${applicationStageLabel(destino)}',
                  style: MpTokens.label.copyWith(color: s.text, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: MpTokens.space8),
          Text(
            '${_fecha(e.changedAt)} · ${e.actorLabel(_miUid)}',
            style: MpTokens.micro.copyWith(color: s.textSecondary),
          ),
          if (e.reason != null) ...[
            const SizedBox(height: MpTokens.space12),
            const MpFieldLabel('Motivo'),
            const SizedBox(height: MpTokens.space4),
            Text(
              e.reason!,
              style: MpTokens.body.copyWith(color: s.text, fontSize: 14),
            ),
          ],
          if (e.notes != null) ...[
            const SizedBox(height: MpTokens.space12),
            const MpFieldLabel('Notas internas'),
            const SizedBox(height: MpTokens.space4),
            Text(
              e.notes!,
              style: MpTokens.body.copyWith(
                color: s.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Fecha corta y legible. No se usa `intl` porque el resto del proyecto
  /// tampoco lo usa para esto.
  String _fecha(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} · $hh:$mi';
  }
}
