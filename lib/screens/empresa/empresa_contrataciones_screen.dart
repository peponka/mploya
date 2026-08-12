import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';
import '../chat_inmail_screen.dart';
import '../../models/models.dart';
import 'empresa_candidato_perfil_screen.dart';
import 'empresa_proceso_data.dart';

/// Contrataciones de la Empresa.
///
/// DERIVACIÓN CONTROLADA de `Headhunter_Colocaciones_Analytics.png`, que es la
/// pantalla de colocaciones del rol headhunter: se conserva su estructura
/// —resumen arriba, listado de colocaciones abajo— y se quita todo lo que
/// pertenece a un tercero (cliente, honorarios, comisión), porque en Empresa la
/// contratación es propia.
///
/// QUÉ SIGNIFICA "CONTRATADO" ACÁ. Hay dos fuentes reales y no siempre
/// coinciden, así que se leen las dos y se fusionan:
///   · `job_applications.status = 'hired'` — trae la vacante.
///   · `connections.ats_status = 'hired'` (RPC `get_my_pipeline`) — es la que
///     mueve el Pipeline, pero NO dice para qué vacante.
/// Cuando una persona viene sólo del pipeline, la vacante no se infiere: se
/// dice que no está registrada.
///
/// OMITIDO: fecha de ingreso, onboarding, documentos, salario final, manager y
/// período de prueba. Ninguno existe. Tampoco hay fecha de contratación: lo que
/// se muestra es la fecha de la postulación, rotulada como tal.
class EmpresaContratacionesScreen extends StatefulWidget {
  /// Datos ya resueltos, para los golden tests.
  final ProcesoData? previewData;

  const EmpresaContratacionesScreen({super.key, this.previewData});

  @override
  State<EmpresaContratacionesScreen> createState() =>
      _EmpresaContratacionesScreenState();
}

class _EmpresaContratacionesScreenState
    extends State<EmpresaContratacionesScreen> {
  ProcesoData _data = ProcesoData.empty;
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
    final data = await loadContrataciones();
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

    final sinVacante =
        _data.personas.where((p) => p.vacante == null).length;

    return [
      _encabezado(),
      const SizedBox(height: MpTokens.space20),
      _resumen(),
      const SizedBox(height: MpTokens.space24),
      for (final p in _data.personas) ...[
        _tarjeta(p),
        const SizedBox(height: MpTokens.space8),
      ],
      if (sinVacante > 0) ...[
        const SizedBox(height: MpTokens.space16),
        _avisoSinVacante(sinVacante),
      ],
      const SizedBox(height: MpTokens.space16),
      _queNoSeGuarda(),
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
              Text(
                'Contrataciones',
                style: MpTokens.h1.copyWith(color: s.text),
              ),
              const SizedBox(height: MpTokens.space4),
              Text(
                'Las personas que ya sumaste a tu equipo.',
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
            : CupertinoIcons.checkmark_seal,
        title: _data.error
            ? 'No pudimos cargar las contrataciones'
            : 'Todavía no hay contrataciones',
        message: _data.error
            ? 'Revisá tu conexión y volvé a intentar.'
            : 'Cuando marques a un candidato como contratado en el pipeline, '
                'va a aparecer acá.',
        actionLabel: _data.error ? 'Reintentar' : null,
        onAction: _data.error ? _load : null,
      ),
    );
  }

  Widget _resumen() {
    final s = context.mp;
    final conVacante =
        _data.personas.where((p) => p.vacante != null).length;

    final items = <({String valor, String etiqueta})>[
      (valor: '${_data.total}', etiqueta: 'Contratados'),
      (valor: '$conVacante', etiqueta: 'Con vacante'),
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

  Widget _tarjeta(PersonaEnProceso p) {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.all(MpTokens.space12),
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) =>
              EmpresaCandidatoPerfilScreen(candidatoId: p.candidatoId),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MpAvatar(
                name: p.nombre,
                size: 46,
                image: p.avatarUrl == null ? null : NetworkImage(p.avatarUrl!),
              ),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          MpTokens.title.copyWith(color: s.text, fontSize: 15),
                    ),
                    if (p.headline != null)
                      Text(
                        p.headline!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MpTokens.micro.copyWith(
                          color: s.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: MpTokens.space8),
              const MpStatusBadge(
                label: 'Contratado',
                status: MpStatus.active,
              ),
            ],
          ),
          const SizedBox(height: MpTokens.space12),
          Row(
            children: [
              Icon(
                CupertinoIcons.briefcase,
                size: 14,
                color: s.textTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  // Sin vacante registrada NO se adivina: viene del pipeline,
                  // que no guarda a qué vacante corresponde.
                  p.vacante ?? 'Vacante no registrada',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MpTokens.micro.copyWith(
                    color: p.vacante == null ? s.textTertiary : s.textSecondary,
                  ),
                ),
              ),
              if (p.antiguedad != null)
                Text(
                  'Postulado ${p.antiguedad!.toLowerCase()}',
                  style: MpTokens.micro.copyWith(
                    color: s.textTertiary,
                    fontSize: 10.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: MpTokens.space12),
          MpButton(
            label: 'Escribirle',
            icon: CupertinoIcons.chat_bubble,
            size: MpButtonSize.small,
            variant: MpButtonVariant.neutral,
            expand: true,
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => ChatInmailScreen(
                  targetUser: NexUser.fromJson({
                    'id': p.candidatoId,
                    'name': p.nombre,
                    'headline': p.headline ?? '',
                    'avatar_url': p.avatarUrl,
                    'tags': p.tags,
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avisoSinVacante(int cuantos) {
    return MpBanner(
      icon: CupertinoIcons.info,
      title: 'Sin vacante asociada',
      message: '$cuantos ${cuantos == 1 ? 'contratación viene' : 'contrataciones vienen'} '
          'del pipeline, que no guarda a qué vacante corresponde. Para que '
          'quede registrada, la contratación tiene que salir de una postulación.',
      color: MpTokens.premium,
    );
  }

  Widget _queNoSeGuarda() {
    final s = context.mp;

    return MpBanner(
      icon: CupertinoIcons.info,
      title: 'Qué no queda registrado',
      message: 'No se guarda la fecha de contratación ni la de ingreso, el '
          'salario final, el manager ni el período de prueba.',
      color: s.textTertiary,
    );
  }
}
