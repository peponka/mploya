import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/job_offer_service.dart';
import '../services/safe_profile_query_service.dart';
import '../widgets/candidato/cand_ui.dart';
import '../widgets/ds/mploya_ds.dart';
import 'oferta_detalle_candidato_screen.dart';

/// OFERTAS RECIBIDAS (candidato).
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ ADENDA 30/8/2026 — migración 051, bloque E2 del plan de ofertas y     ║
/// ║ pipeline.                                                              ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// Hasta esta migración no existía tabla de ofertas: esta pantalla listaba
/// postulaciones con `status = 'accepted'` y la única acción posible era
/// escribirle a la empresa por chat, porque no había nada más real que
/// mostrar ni backend para aceptar o rechazar (ver el comentario original
/// más abajo, que se conserva por honestidad histórica).
///
/// Ahora `job_offers` es una tabla real con salario, moneda, modalidad,
/// beneficios, vencimiento y mensaje, y el candidato puede responder de
/// verdad — aceptar, rechazar o pedir cambios — desde
/// `OfertaDetalleCandidatoScreen`. Esta pantalla pasó a ser el listado: toda
/// oferta recibida, abierta o ya respondida, ordenada de la más nueva a la
/// más vieja.
///
/// ---
/// COMENTARIO ORIGINAL (Tanda 5, pantalla nueva), conservado por honestidad
/// histórica — ya no describe el comportamiento actual de esta pantalla:
///
/// Referencia visual: design-reference/FINAL_SCREENS_CODEX/.../
/// oferta recibida candidato.png.
///
/// El mockup muestra una oferta con carta de oferta, beneficios detallados,
/// bonos, revisión salarial, countdown de "5 días para responder" y botones
/// Aceptar/Rechazar/Negociar. Antes de la 051 nada de eso existía en
/// `job_applications` (6 columnas reales). Ahora sí: `job_offers` guarda
/// exactamente eso, salvo el countdown (el vencimiento se muestra como
/// fecha, no como cuenta regresiva).
@immutable
class OfertasPreviewData {
  const OfertasPreviewData({required this.filas});
  final List<Map<String, dynamic>> filas;
}

class OfertasRecibidasScreen extends StatefulWidget {
  const OfertasRecibidasScreen({super.key, this.previewData});

  final OfertasPreviewData? previewData;

  @override
  State<OfertasRecibidasScreen> createState() =>
      _OfertasRecibidasScreenState();
}

class _OfertaConContexto {
  const _OfertaConContexto({
    required this.oferta,
    required this.jobTitle,
    required this.companyName,
    this.companyAvatarUrl,
    this.location,
    this.isRemote = false,
  });

  final JobOffer oferta;
  final String jobTitle;
  final String companyName;
  final String? companyAvatarUrl;
  final String? location;
  final bool isRemote;
}

class _OfertasRecibidasScreenState extends State<OfertasRecibidasScreen> {
  late final _supabase = Supabase.instance.client;

  bool _cargando = true;
  String? _error;
  List<_OfertaConContexto> _ofertas = const [];

  @override
  void initState() {
    super.initState();
    if (widget.previewData != null) {
      _ofertas = widget.previewData!.filas.map(_filaAOferta).toList();
      _cargando = false;
      return;
    }
    _cargar();
  }

  static _OfertaConContexto _filaAOferta(Map<String, dynamic> row) {
    final job = row['jobs'] as Map<String, dynamic>?;
    final empresa = job?['users'] as Map<String, dynamic>?;
    return _OfertaConContexto(
      oferta: JobOffer.fromRow(row),
      jobTitle: job?['title']?.toString() ?? 'Vacante',
      location: job?['location']?.toString(),
      isRemote: job?['is_remote'] == true,
      companyName: empresa?['name']?.toString() ?? 'Empresa',
      companyAvatarUrl: empresa?['avatar_url']?.toString(),
    );
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) {
        setState(() {
          _ofertas = const [];
          _cargando = false;
        });
        return;
      }
      final rows = await _supabase
          .from('job_offers')
          .select('*, jobs(title, location, is_remote, company_id)')
          .eq('candidate_id', uid)
          .order('created_at', ascending: false);

      final hydrated = await hydrateNestedJobCompanies(rows, client: _supabase);
      final lista = hydrated.map(_filaAOferta).toList();

      if (!mounted) return;
      setState(() {
        _ofertas = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _abrir(_OfertaConContexto o) async {
    final actualizo = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => OfertaDetalleCandidatoScreen(offerId: o.oferta.id),
      ),
    );
    if (actualizo == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: MpSurfaceStyle.light.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: MpSurfaceStyle.light.bg,
        border: null,
        middle: const Text('Ofertas recibidas'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Icon(CupertinoIcons.chevron_back),
        ),
      ),
      child: MpSurface(style: MpSurfaceStyle.light, child: _buildCuerpo(context)),
    );
  }

  Widget _buildCuerpo(BuildContext context) {
    if (_cargando) return const CandCargandoLista();
    if (_error != null) {
      return CandError(
        titulo: 'No pudimos cargar tus ofertas',
        detalle: _error!,
        onReintentar: _cargar,
      );
    }
    if (_ofertas.isEmpty) {
      return const CandVacio(
        icono: CupertinoIcons.star,
        titulo: 'Todavía no tenés ofertas.',
        detalle: 'Cuando una empresa te haga una oferta, la vas a ver acá.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        for (final o in _ofertas) ...[
          _buildTarjeta(o),
          const SizedBox(height: MpTokens.space12),
        ],
      ],
    );
  }

  Widget _buildTarjeta(_OfertaConContexto o) {
    final abierta = o.oferta.abierta;
    final color = abierta
        ? MpTokens.success
        : o.oferta.status == 'accepted'
            ? MpTokens.success
            : MpTokens.lightTextTertiary;

    return CandTarjeta(
      onTap: () => _abrir(o),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                abierta ? CupertinoIcons.star_fill : CupertinoIcons.checkmark_seal,
                size: 16,
                color: color,
              ),
              const SizedBox(width: MpTokens.space8),
              Text(
                abierta ? 'Oferta activa' : offerStatusLabel(o.oferta.status),
                style: MpTokens.micro
                    .copyWith(color: color, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                _fechaCorta(o.oferta.createdAt),
                style: MpTokens.micro.copyWith(color: MpTokens.lightTextTertiary),
              ),
            ],
          ),
          const SizedBox(height: MpTokens.space12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CandAvatar(nombre: o.companyName, imagenUrl: o.companyAvatarUrl, tamano: 48),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.jobTitle, style: MpTokens.title.copyWith(fontSize: 16)),
                    const SizedBox(height: MpTokens.space2),
                    Text(
                      o.companyName,
                      style: MpTokens.body.copyWith(color: MpTokens.lightTextSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MpTokens.space12),
          Wrap(
            spacing: MpTokens.space8,
            runSpacing: MpTokens.space4,
            children: [
              if (o.isRemote) const CandChip('Remoto', compacto: true),
              if (o.location != null &&
                  o.location!.trim().isNotEmpty &&
                  o.location!.trim().toLowerCase() != 'remoto')
                CandChip(o.location!, compacto: true),
              CandChip(o.oferta.salarioFormateado, compacto: true, color: MpTokens.success),
            ],
          ),
        ],
      ),
    );
  }

  String _fechaCorta(DateTime fecha) {
    final dias = DateTime.now().difference(fecha).inDays;
    if (dias <= 0) return 'hoy';
    if (dias == 1) return 'ayer';
    if (dias < 30) return 'hace $dias días';
    return 'el ${fecha.day}/${fecha.month}/${fecha.year.toString().substring(2)}';
  }
}
