import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../widgets/candidato/cand_ui.dart';
import '../widgets/ds/mploya_ds.dart';
import 'chat_inmail_screen.dart';

/// OFERTAS RECIBIDAS (candidato) — Tanda 5, pantalla nueva.
///
/// Referencia visual: design-reference/FINAL_SCREENS_CODEX/.../
/// oferta recibida candidato.png.
///
/// El mockup muestra una oferta con carta de oferta, beneficios detallados,
/// bonos, revisión salarial, countdown de "5 días para responder" y botones
/// Aceptar/Rechazar/Negociar. NADA de eso existe en `job_applications` (6
/// columnas reales: id, job_id, candidate_id, status, created_at,
/// is_favorite — confirmado en Tanda 2). No hay RPC que permita al candidato
/// cambiar el status ni backend para carta/beneficios/countdown.
///
/// Adaptación honesta: una "oferta" es, con los datos reales, una
/// postulación con `status = 'accepted'`. Esta pantalla lista esas
/// postulaciones con lo que sí es real (puesto, empresa, ubicación,
/// modalidad, fecha) y reemplaza Aceptar/Rechazar/Negociar (que necesitarían
/// escribir un estado que no se puede escribir desde acá) por una acción
/// real: escribirle a la empresa por el chat que ya existe.
@immutable
class OfertasPreviewData {
  const OfertasPreviewData({required this.filas});
  final List<Map<String, dynamic>> filas;
}

class OfertasRecibidasScreen extends StatefulWidget {
  const OfertasRecibidasScreen({super.key, this.previewData});

  final OfertasPreviewData? previewData;

  @override
  State<OfertasRecibidasScreen> createState() => _OfertasRecibidasScreenState();
}

class _Oferta {
  const _Oferta({
    required this.id,
    required this.creada,
    required this.jobTitle,
    required this.location,
    required this.isRemote,
    required this.salaryRange,
    required this.companyId,
    required this.companyName,
    required this.companyAvatarUrl,
  });

  final String id;
  final DateTime? creada;
  final String jobTitle;
  final String? location;
  final bool isRemote;
  final String? salaryRange;
  final String? companyId;
  final String companyName;
  final String? companyAvatarUrl;
}

class _OfertasRecibidasScreenState extends State<OfertasRecibidasScreen> {
  late final _supabase = Supabase.instance.client;

  bool _cargando = true;
  String? _error;
  List<_Oferta> _ofertas = const [];

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

  static _Oferta _filaAOferta(Map<String, dynamic> row) {
    final job = row['jobs'] as Map<String, dynamic>?;
    final empresa = job?['users'] as Map<String, dynamic>?;
    return _Oferta(
      id: row['id'].toString(),
      creada: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      jobTitle: job?['title']?.toString() ?? 'Vacante',
      location: job?['location']?.toString(),
      isRemote: job?['is_remote'] == true,
      salaryRange: job?['salary_range']?.toString(),
      companyId: empresa?['id']?.toString(),
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
          .from('job_applications')
          .select(
            'id, created_at, '
            'jobs(title, location, is_remote, salary_range, '
            'users!jobs_company_id_fkey(id, name, avatar_url, headline))',
          )
          .eq('candidate_id', uid)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);

      final lista = (rows as List)
          .map((raw) => _filaAOferta(raw as Map<String, dynamic>))
          .toList();

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

  void _escribirleALaEmpresa(_Oferta o) {
    if (o.companyId == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatInmailScreen(
          targetUser: NexUser(
            id: o.companyId!,
            name: o.companyName,
            headline: '',
            avatarUrl: o.companyAvatarUrl,
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
        detalle: 'Cuando una empresa acepte tu postulación real, la vas a ver acá.',
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

  Widget _buildTarjeta(_Oferta o) {
    return CandTarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.star_fill, size: 16, color: MpTokens.success),
              const SizedBox(width: MpTokens.space8),
              Text(
                'Oferta activa',
                style: MpTokens.micro.copyWith(color: MpTokens.success, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (o.creada != null)
                Text(
                  'Recibida ${_fechaCorta(o.creada!)}',
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
              if (o.salaryRange != null && o.salaryRange!.trim().isNotEmpty)
                CandChip(o.salaryRange!, compacto: true, color: MpTokens.success),
            ],
          ),
          const SizedBox(height: MpTokens.space12),
          MpButton(
            label: 'Escribirle a la empresa',
            icon: CupertinoIcons.chat_bubble_2_fill,
            expand: true,
            onPressed: o.companyId == null ? null : () => _escribirleALaEmpresa(o),
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
