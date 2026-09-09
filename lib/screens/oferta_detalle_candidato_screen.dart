import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/job_offer_service.dart';
import '../services/safe_profile_query_service.dart';
import '../widgets/candidato/cand_ui.dart';
import '../widgets/candidato/responder_oferta_sheet.dart';
import '../widgets/ds/mploya_ds.dart';
import 'chat_inmail_screen.dart';

/// Detalle de una oferta recibida, con Aceptar / Rechazar / Pedir cambios
/// reales (migración 051, bloque E2).
///
/// Reemplaza el "Escribirle a la empresa" como única acción posible de
/// `ofertas_recibidas_screen.dart` (adaptación honesta de cuando no existía
/// tabla de ofertas): ahora hay una oferta real detrás, así que hay una
/// respuesta real que dar.
///
/// SE MARCA COMO VISTA AL ABRIR. Efecto secundario silencioso, igual que del
/// lado de la empresa: si falla, no rompe la pantalla.
class OfertaDetalleCandidatoScreen extends StatefulWidget {
  const OfertaDetalleCandidatoScreen({super.key, required this.offerId});

  final String offerId;

  @override
  State<OfertaDetalleCandidatoScreen> createState() =>
      _OfertaDetalleCandidatoScreenState();
}

class _OfertaDetalleCandidatoScreenState
    extends State<OfertaDetalleCandidatoScreen> {
  late final _supabase = Supabase.instance.client;

  JobOffer? _oferta;
  String _jobTitle = 'Vacante';
  String? _companyId;
  String _companyName = 'Empresa';
  String? _companyAvatarUrl;

  bool _cargando = true;
  bool _respondiendo = false;
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
      final row = await _supabase
          .from('job_offers')
          .select('*, jobs(title, company_id)')
          .eq('id', widget.offerId)
          .single();

      final hydrated =
          await hydrateNestedJobCompanies([row], client: _supabase);
      final fila = hydrated.first;
      final job = fila['jobs'] as Map<String, dynamic>?;
      final empresa = job?['users'] as Map<String, dynamic>?;

      final oferta = JobOffer.fromRow(fila);

      if (oferta.status == 'sent') {
        // Silencioso: ver doc del método.
        await markJobOfferViewed(oferta.id);
      }

      if (!mounted) return;
      setState(() {
        _oferta = oferta;
        _jobTitle = job?['title']?.toString() ?? 'Vacante';
        _companyId = empresa?['id']?.toString() ?? oferta.companyId;
        _companyName = empresa?['name']?.toString() ?? 'Empresa';
        _companyAvatarUrl = empresa?['avatar_url']?.toString();
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar esta oferta.';
        _cargando = false;
      });
    }
  }

  Future<void> _responder() async {
    final oferta = _oferta;
    if (oferta == null) return;

    final respuesta = await mostrarRespuestaOferta(context, vacante: _jobTitle);
    if (respuesta == null) return;

    setState(() => _respondiendo = true);
    try {
      await respondToJobOffer(
        offerId: oferta.id,
        decision: respuesta.decision,
        message: respuesta.message,
      );
      if (!mounted) return;
      await showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(_tituloConfirmacion(respuesta.decision)),
          content: Text(_mensajeConfirmacion(respuesta.decision)),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Listo'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on JobOfferException catch (e) {
      if (!mounted) return;
      _avisar(e.mensaje);
    } catch (_) {
      if (!mounted) return;
      _avisar('No pudimos enviar tu respuesta. Probá de nuevo.');
    } finally {
      if (mounted) setState(() => _respondiendo = false);
    }
  }

  String _tituloConfirmacion(String decision) => switch (decision) {
        'accepted' => '¡Felicitaciones!',
        'declined' => 'Oferta rechazada',
        _ => 'Cambios enviados',
      };

  String _mensajeConfirmacion(String decision) => switch (decision) {
        'accepted' =>
          'Aceptaste la oferta. La empresa ya te ve como contratado.',
        'declined' => 'Le avisamos a la empresa que rechazaste la oferta.',
        _ => 'Le enviamos tu pedido de cambios a la empresa.',
      };

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

  void _escribirleALaEmpresa() {
    final id = _companyId;
    if (id == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatInmailScreen(
          targetUser: NexUser(
            id: id,
            name: _companyName,
            headline: '',
            avatarUrl: _companyAvatarUrl,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: MpSurfaceStyle.light.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: MpSurfaceStyle.light.bg,
        border: null,
        middle: const Text('Oferta'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Icon(CupertinoIcons.chevron_back),
        ),
      ),
      child: MpSurface(
        style: MpSurfaceStyle.light,
        child: _cargando
            ? const CandCargandoLista()
            : _error != null
                ? CandError(
                    titulo: 'No pudimos cargar la oferta',
                    detalle: _error!,
                    onReintentar: _cargar,
                  )
                : _cuerpo(),
      ),
    );
  }

  Widget _cuerpo() {
    final oferta = _oferta;
    if (oferta == null) {
      return const CandVacio(
        icono: CupertinoIcons.doc_text,
        titulo: 'Esta oferta ya no está disponible.',
        detalle: 'Puede que la empresa la haya retirado.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        CandTarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CandAvatar(
                      nombre: _companyName,
                      imagenUrl: _companyAvatarUrl,
                      tamano: 48),
                  const SizedBox(width: MpTokens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_jobTitle, style: MpTokens.title.copyWith(fontSize: 16)),
                        const SizedBox(height: MpTokens.space2),
                        Text(_companyName,
                            style: MpTokens.body
                                .copyWith(color: MpTokens.lightTextSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MpTokens.space16),
              Text(
                oferta.salarioFormateado,
                style: MpTokens.stat.copyWith(fontSize: 24),
              ),
              if (oferta.modalidad != null) ...[
                const SizedBox(height: MpTokens.space4),
                Text(oferta.modalidadLabel,
                    style: MpTokens.body
                        .copyWith(color: MpTokens.lightTextSecondary)),
              ],
              const SizedBox(height: MpTokens.space12),
              if (oferta.startDate != null)
                _dato('Fecha de inicio',
                    '${oferta.startDate!.day}/${oferta.startDate!.month}/${oferta.startDate!.year}'),
              if (oferta.expiresAt != null)
                _dato('Vence el',
                    '${oferta.expiresAt!.day}/${oferta.expiresAt!.month}/${oferta.expiresAt!.year}'),
              if (oferta.benefits.isNotEmpty) ...[
                const SizedBox(height: MpTokens.space12),
                Wrap(
                  spacing: MpTokens.space8,
                  runSpacing: MpTokens.space8,
                  children: [
                    for (final b in oferta.benefits) CandChip(b, compacto: true),
                  ],
                ),
              ],
              if (oferta.message != null && oferta.message!.isNotEmpty) ...[
                const SizedBox(height: MpTokens.space12),
                Text(oferta.message!,
                    style: MpTokens.body
                        .copyWith(color: MpTokens.lightTextSecondary)),
              ],
            ],
          ),
        ),
        const SizedBox(height: MpTokens.space16),

        if (oferta.abierta) ...[
          MpButton(
            label: 'Responder oferta',
            expand: true,
            loading: _respondiendo,
            onPressed: _respondiendo ? null : _responder,
          ),
        ] else
          MpBanner(
            icon: oferta.status == 'accepted'
                ? CupertinoIcons.checkmark_seal
                : CupertinoIcons.info,
            title: 'Estado: ${offerStatusLabel(oferta.status)}',
            message: oferta.status == 'accepted'
                ? 'Ya aceptaste esta oferta.'
                : oferta.status == 'declined'
                    ? 'Rechazaste esta oferta.'
                    : 'Esta oferta ya no está abierta.',
            color: oferta.status == 'accepted'
                ? MpTokens.success
                : MpTokens.lightTextTertiary,
          ),

        const SizedBox(height: MpTokens.space12),
        MpButton(
          label: 'Escribirle a la empresa',
          icon: CupertinoIcons.chat_bubble_2_fill,
          variant: MpButtonVariant.outline,
          expand: true,
          onPressed: _companyId == null ? null : _escribirleALaEmpresa,
        ),
      ],
    );
  }

  Widget _dato(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(top: MpTokens.space4),
      child: Row(
        children: [
          Text(etiqueta,
              style: MpTokens.micro.copyWith(color: MpTokens.lightTextTertiary)),
          const SizedBox(width: MpTokens.space8),
          Text(valor, style: MpTokens.body.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}
