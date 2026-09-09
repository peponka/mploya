import 'package:flutter/cupertino.dart';

import '../../services/job_offer_service.dart';
import '../../widgets/ds/mploya_ds.dart';
import 'empresa_oferta_detalle_screen.dart';
import 'empresa_proceso_data.dart';

/// Ofertas: candidatos con una oferta laboral real hecha (migración 051).
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ ADENDA 30/8/2026 — migración 051, bloque E2. Reemplaza la versión      ║
/// ║ CONGELADA del 12/8/2026 (comentario original más abajo, conservado    ║
/// ║ por honestidad histórica).                                             ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// Antes de esta migración no existía tabla de ofertas: esta pantalla listaba
/// postulaciones con `status = 'accepted'` y decía explícitamente que no
/// podía mostrar salario, vencimiento, beneficios ni historial porque nada de
/// eso se guardaba. Ahora `job_offers` es una tabla real y esta pantalla la
/// lee directamente vía `loadOfertasEmpresa()` — salario, moneda, modalidad,
/// vencimiento y estado real de cada oferta.
///
/// ---
/// COMENTARIO ORIGINAL (CONGELADA 12/8/2026), conservado por honestidad
/// histórica — ya no describe el comportamiento actual de esta pantalla:
///
/// DERIVACIÓN CONTROLADA. Entre los 87 PNG no hay una pantalla de "gestión de
/// ofertas" de Empresa: `ofertadigital.png` y `oferta recibida candidato.png`
/// están escritas desde el lado del CANDIDATO (reciben la oferta, la aceptan).
/// Se conserva de ellas la idea de ficha por oferta con la vacante y el
/// estado, y la estructura de listado de las pantallas de Empresa ya
/// aprobadas.
class EmpresaOfertasScreen extends StatefulWidget {
  /// Datos ya resueltos, para los golden tests.
  final OfertasEmpresaData? previewData;

  const EmpresaOfertasScreen({super.key, this.previewData});

  @override
  State<EmpresaOfertasScreen> createState() => _EmpresaOfertasScreenState();
}

class _EmpresaOfertasScreenState extends State<EmpresaOfertasScreen> {
  OfertasEmpresaData _data = OfertasEmpresaData.empty;
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
    final data = await loadOfertasEmpresa();
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
      child: CupertinoPageScaffold(
        backgroundColor: MpTokens.lightBg,
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
                        MpTokens.space8,
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

  List<Widget> _cuerpo() {
    if (_data.total == 0) return [_encabezado(), _vacio()];

    final grupos = _data.porVacante;

    return [
      _encabezado(),
      const SizedBox(height: MpTokens.space20),
      _resumen(),
      const SizedBox(height: MpTokens.space24),
      for (final entrada in grupos.entries) ...[
        Text(
          entrada.key,
          style: MpTokens.h2.copyWith(color: context.mp.text, fontSize: 17),
        ),
        const SizedBox(height: MpTokens.space4),
        Text(
          '${entrada.value.length} '
          '${entrada.value.length == 1 ? 'oferta' : 'ofertas'}',
          style: MpTokens.micro.copyWith(color: context.mp.textTertiary),
        ),
        const SizedBox(height: MpTokens.space12),
        for (final o in entrada.value) ...[
          _tarjeta(o),
          const SizedBox(height: MpTokens.space8),
        ],
        const SizedBox(height: MpTokens.space16),
      ],
    ];
  }

  Widget _encabezado() {
    final s = context.mp;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              Text('Ofertas', style: MpTokens.h1.copyWith(color: s.text)),
              const SizedBox(height: MpTokens.space4),
              Text(
                'Ofertas hechas, por vacante.',
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
    );
  }

  Widget _vacio() {
    return Padding(
      padding: const EdgeInsets.only(top: MpTokens.space32),
      child: MpEmptyState(
        icon: _data.error
            ? CupertinoIcons.exclamationmark_triangle
            : CupertinoIcons.paperplane,
        title: _data.error
            ? 'No pudimos cargar las ofertas'
            : 'Todavía no hay ofertas',
        message: _data.error
            ? 'Revisá tu conexión y volvé a intentar.'
            : 'Las ofertas que le hagas a un candidato desde Pipeline '
                'aparecen acá.',
        actionLabel: _data.error ? 'Reintentar' : null,
        onAction: _data.error ? _load : null,
      ),
    );
  }

  Widget _resumen() {
    final s = context.mp;
    final vacantes = _data.porVacante.length;
    final abiertas = _data.ofertas.where((o) => o.oferta.abierta).length;

    final items = <({String valor, String etiqueta})>[
      (valor: '${_data.total}', etiqueta: 'Ofertas'),
      (valor: '$abiertas', etiqueta: abiertas == 1 ? 'Abierta' : 'Abiertas'),
      (valor: '$vacantes', etiqueta: vacantes == 1 ? 'Vacante' : 'Vacantes'),
    ];

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.symmetric(
        horizontal: MpTokens.space8,
        vertical: MpTokens.space16,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Container(width: 1, color: s.border),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        items[i].valor,
                        style: MpTokens.stat.copyWith(
                          color: s.text,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].etiqueta,
                      style: MpTokens.micro.copyWith(
                        color: s.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(OfertaEmpresa o) {
    final s = context.mp;
    final status = switch (o.oferta.status) {
      'accepted' => MpStatus.active,
      'declined' => MpStatus.danger,
      'withdrawn' || 'expired' => MpStatus.finished,
      'changes_requested' => MpStatus.paused,
      _ => MpStatus.info,
    };

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.all(MpTokens.space12),
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => EmpresaOfertaDetalleScreen(
            applicationId: o.oferta.applicationId,
            candidatoNombre: o.nombreVisible,
            vacante: o.vacante,
          ),
        ),
      ),
      child: Row(
        children: [
          MpAvatar(
            name: o.nombreVisible,
            size: 46,
            image: o.avatarUrl == null || o.confidencial
                ? null
                : NetworkImage(o.avatarUrl!),
          ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  o.nombreVisible,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MpTokens.title.copyWith(color: s.text, fontSize: 15),
                ),
                Text(
                  o.oferta.salarioFormateado,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MpTokens.micro.copyWith(color: s.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          MpStatusBadge(label: offerStatusLabel(o.oferta.status), status: status),
        ],
      ),
    );
  }
}
