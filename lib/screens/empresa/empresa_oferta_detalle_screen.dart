import 'package:flutter/cupertino.dart';

import '../../services/job_offer_service.dart';
import '../../widgets/ds/mploya_ds.dart';
import 'empresa_crear_oferta_screen.dart';

/// Detalle de una oferta desde el lado de la empresa (migración 051, E2).
///
/// Muestra lo que sí es real ahora — salario, moneda, modalidad, beneficios,
/// fechas, mensaje — y el historial de versiones completo. Mientras la
/// oferta está abierta permite revisarla (nueva versión) o retirarla.
class EmpresaOfertaDetalleScreen extends StatefulWidget {
  const EmpresaOfertaDetalleScreen({
    super.key,
    required this.applicationId,
    required this.candidatoNombre,
    required this.vacante,
  });

  final String applicationId;
  final String candidatoNombre;
  final String vacante;

  @override
  State<EmpresaOfertaDetalleScreen> createState() =>
      _EmpresaOfertaDetalleScreenState();
}

class _EmpresaOfertaDetalleScreenState
    extends State<EmpresaOfertaDetalleScreen> {
  JobOffer? _oferta;
  List<JobOfferVersion> _versiones = const [];
  bool _cargando = true;
  bool _accionando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final oferta = await loadOfferForApplication(widget.applicationId);
      final versiones = oferta == null
          ? <JobOfferVersion>[]
          : await loadOfferVersions(oferta.id);
      if (!mounted) return;
      setState(() {
        _oferta = oferta;
        _versiones = versiones;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar la oferta.';
        _cargando = false;
      });
    }
  }

  Future<void> _revisar() async {
    final oferta = _oferta;
    if (oferta == null) return;
    final resultado = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => EmpresaCrearOfertaScreen(
          applicationId: widget.applicationId,
          candidatoNombre: widget.candidatoNombre,
          vacante: widget.vacante,
          ofertaExistente: oferta,
        ),
      ),
    );
    if (resultado == true) _cargar();
  }

  Future<void> _retirar() async {
    final oferta = _oferta;
    if (oferta == null) return;

    final confirmar = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('¿Retirar esta oferta?'),
        content: const Text(
          'El candidato ya no va a poder responderla. Esta acción no se '
          'puede deshacer.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _accionando = true);
    try {
      await withdrawJobOffer(oferta.id);
      await _cargar();
    } on JobOfferException catch (e) {
      if (!mounted) return;
      _avisar(e.mensaje);
    } catch (_) {
      if (!mounted) return;
      _avisar('No pudimos retirar la oferta. Probá de nuevo.');
    } finally {
      if (mounted) setState(() => _accionando = false);
    }
  }

  void _avisar(String mensaje) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(mensaje),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: MpTokens.lightBg,
        child: SafeArea(
          child: _cargando
              ? const Center(child: CupertinoActivityIndicator(radius: 15))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    MpTokens.screenPadding,
                    MpTokens.space8,
                    MpTokens.screenPadding,
                    MpTokens.space32,
                  ),
                  children: _cuerpo(),
                ),
        ),
      ),
    );
  }

  List<Widget> _cuerpo() {
    final s = context.mp;
    final oferta = _oferta;

    return [
      Row(
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
                Text(widget.candidatoNombre,
                    style: MpTokens.h2.copyWith(color: s.text)),
                Text(widget.vacante,
                    style:
                        MpTokens.body.copyWith(color: s.textSecondary)),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: MpTokens.space20),
      if (_error != null)
        MpEmptyState(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: 'No pudimos cargar la oferta',
          message: _error!,
          actionLabel: 'Reintentar',
          onAction: _cargar,
        )
      else if (oferta == null)
        const MpEmptyState(
          icon: CupertinoIcons.doc_text,
          title: 'Esta postulación todavía no tiene oferta',
          message: 'Se creó y se retiró, o todavía no se hizo ninguna.',
        )
      else ...[
        _tarjetaOferta(oferta),
        const SizedBox(height: MpTokens.space20),
        if (oferta.abierta) ...[
          MpButton(
            label: 'Revisar oferta',
            expand: true,
            variant: MpButtonVariant.outline,
            loading: _accionando,
            onPressed: _accionando ? null : _revisar,
          ),
          const SizedBox(height: MpTokens.space8),
          MpButton(
            label: 'Retirar oferta',
            expand: true,
            variant: MpButtonVariant.ghost,
            color: MpTokens.danger,
            onPressed: _accionando ? null : _retirar,
          ),
          const SizedBox(height: MpTokens.space20),
        ],
        if (_versiones.isNotEmpty) ...[
          Text('Historial', style: MpTokens.h2.copyWith(color: s.text, fontSize: 17)),
          const SizedBox(height: MpTokens.space12),
          for (final v in _versiones.reversed) ...[
            _filaVersion(v),
            const SizedBox(height: MpTokens.space8),
          ],
        ],
      ],
    ];
  }

  Widget _tarjetaOferta(JobOffer o) {
    final s = context.mp;
    final status = switch (o.status) {
      'accepted' => MpStatus.active,
      'declined' => MpStatus.danger,
      'withdrawn' || 'expired' => MpStatus.finished,
      'changes_requested' => MpStatus.paused,
      _ => MpStatus.info,
    };

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.all(MpTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                o.salarioFormateado,
                style: MpTokens.stat.copyWith(color: s.text, fontSize: 22),
              ),
              const Spacer(),
              MpStatusBadge(label: offerStatusLabel(o.status), status: status),
            ],
          ),
          if (o.modalidad != null) ...[
            const SizedBox(height: MpTokens.space4),
            Text(o.modalidadLabel,
                style: MpTokens.body.copyWith(color: s.textSecondary)),
          ],
          const SizedBox(height: MpTokens.space16),
          _dato('Fecha de inicio', o.startDate == null
              ? '—'
              : '${o.startDate!.day}/${o.startDate!.month}/${o.startDate!.year}'),
          _dato('Vencimiento', o.expiresAt == null
              ? '—'
              : '${o.expiresAt!.day}/${o.expiresAt!.month}/${o.expiresAt!.year}'),
          if (o.decidedAt != null)
            _dato('Respondida el',
                '${o.decidedAt!.day}/${o.decidedAt!.month}/${o.decidedAt!.year}'),
          if (o.declineReason != null) _dato('Motivo', o.declineReason!),
          if (o.benefits.isNotEmpty) ...[
            const SizedBox(height: MpTokens.space12),
            Wrap(
              spacing: MpTokens.space8,
              runSpacing: MpTokens.space8,
              children: [for (final b in o.benefits) MpTagChip(label: b)],
            ),
          ],
          if (o.message != null && o.message!.isNotEmpty) ...[
            const SizedBox(height: MpTokens.space12),
            Text(o.message!,
                style: MpTokens.body.copyWith(color: s.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _dato(String etiqueta, String valor) {
    final s = context.mp;
    return Padding(
      padding: const EdgeInsets.only(top: MpTokens.space4),
      child: Row(
        children: [
          Text(etiqueta,
              style: MpTokens.micro.copyWith(color: s.textTertiary)),
          const SizedBox(width: MpTokens.space8),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: MpTokens.body.copyWith(color: s.text, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaVersion(JobOfferVersion v) {
    final s = context.mp;
    return MpCard(
      radius: MpTokens.radiusMD,
      padding: const EdgeInsets.all(MpTokens.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offerChangeKindLabel(v.changeKind),
                    style: MpTokens.title.copyWith(color: s.text, fontSize: 14)),
                if (v.message != null) ...[
                  const SizedBox(height: MpTokens.space2),
                  Text(v.message!,
                      style: MpTokens.micro.copyWith(color: s.textSecondary)),
                ],
              ],
            ),
          ),
          Text(
            '${v.createdAt.day}/${v.createdAt.month} '
            '${v.createdAt.hour.toString().padLeft(2, '0')}:'
            '${v.createdAt.minute.toString().padLeft(2, '0')}',
            style: MpTokens.micro.copyWith(color: s.textTertiary),
          ),
        ],
      ),
    );
  }
}
