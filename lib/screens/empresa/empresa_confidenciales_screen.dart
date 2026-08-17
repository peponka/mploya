import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';
import 'empresa_candidato_perfil_screen.dart';
import 'empresa_confidenciales_data.dart';

/// Candidatos confidenciales y desbloqueo por créditos.
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 11/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ║ Su golden es protección de regresión: si falla, averiguar por qué     ║
/// ║ antes de regenerarlo.                                                 ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// DERIVACIÓN CONTROLADA de tres PNG de escritorio —`candidatos
/// conidenciales.png` (31), `perfil confidencial.png` (32) y `desbloquear un
/// candidato.png` (35)— llevados a la columna única de móvil. Se conservan: la
/// tarjeta de saldo con el plan, los filtros por estado, las fichas con la foto
/// velada y el candado, el precio en créditos sobre el botón "Desbloquear", y el
/// bloque "¿Cómo funciona?" de cuatro pasos.
///
/// ESTO NO ES UNA MAQUETA: el circuito existe entero en la base y hasta ahora no
/// tenía pantalla.
///   · `get_stealth_catalog()` devuelve un handle opaco sin UUID ni PII hasta
///     que este actor haya desbloqueado el perfil.
///   · `unlock_stealth_profile(p_candidate_handle)` descuenta el crédito y registra
///     en `profile_unlocks`, todo en una transacción con `FOR UPDATE`.
///   · `company_wallets` guarda el saldo y el plan.
///
/// OMITIDO, y por qué. El mockup tarifa por seniority (5 créditos Junior, 20
/// Senior, 50 C-Level): la RPC real cobra **1 crédito fijo** y no hay campo de
/// seniority en el catálogo, así que la tabla de precios sería falsa. Tampoco
/// están "Comprar créditos" (no hay checkout), el mapa de confidenciales, ni las
/// estadísticas de ROI por desbloqueo.
class EmpresaConfidencialesScreen extends StatefulWidget {
  /// Datos ya resueltos, para los golden tests.
  final ConfidencialesData? previewData;

  const EmpresaConfidencialesScreen({super.key, this.previewData});

  @override
  State<EmpresaConfidencialesScreen> createState() =>
      _EmpresaConfidencialesScreenState();
}

class _EmpresaConfidencialesScreenState
    extends State<EmpresaConfidencialesScreen> {
  ConfidencialesData _data = ConfidencialesData.empty;
  bool _loading = true;
  String? _desbloqueando;
  int _filtro = 0;

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
    final data = await loadConfidenciales();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  List<CandidatoConfidencial> get _visibles => switch (_filtro) {
        1 => _data.candidatos.where((c) => !c.desbloqueado).toList(),
        2 => _data.candidatos.where((c) => c.desbloqueado).toList(),
        _ => _data.candidatos,
      };

  Future<void> _desbloquear(CandidatoConfidencial c) async {
    if (_desbloqueando != null) return;
    setState(() => _desbloqueando = c.id);

    final res = await desbloquearCandidato(c.id);
    if (!mounted) return;
    setState(() => _desbloqueando = null);

    switch (res.resultado) {
      case ResultadoDesbloqueo.exito:
      case ResultadoDesbloqueo.yaDesbloqueado:
        await _load();
      case ResultadoDesbloqueo.sinCreditos:
        await _alerta(
          'No te alcanzan los créditos',
          'Tenés ${res.saldo ?? 0} créditos y hace falta 1 para desbloquear '
              'este perfil.',
        );
      case ResultadoDesbloqueo.noPermitido:
        await _alerta(
          'No se puede desbloquear',
          'Este perfil no se puede desbloquear desde tu cuenta.',
        );
      case ResultadoDesbloqueo.error:
        await _alerta(
          'No pudimos desbloquear',
          'No se descontó ningún crédito. Probá de nuevo en un momento.',
        );
    }
  }

  Future<void> _alerta(String titulo, String mensaje) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

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
    return [
      _encabezado(),
      const SizedBox(height: MpTokens.space20),
      _billetera(),
      if (_data.total == 0)
        _vacio()
      else ...[
        // El saldo es una sección propia: separarlo de los filtros evita que se
        // lea como el encabezado de la lista.
        const SizedBox(height: MpTokens.space24),
        MpSegmentedFilter(
          options: [
            MpFilterOption('Todos', count: _data.total),
            MpFilterOption('Bloqueados', count: _data.bloqueados),
            MpFilterOption('Desbloqueados', count: _data.desbloqueados),
          ],
          selectedIndex: _filtro,
          onChanged: (i) => setState(() => _filtro = i),
          scrollable: true,
        ),
        const SizedBox(height: MpTokens.space16),
        ..._listado(),
      ],
      const SizedBox(height: MpTokens.space32),
      _comoFunciona(),
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
                'Confidenciales',
                style: MpTokens.h1.copyWith(color: s.text),
              ),
              const SizedBox(height: MpTokens.space4),
              Text(
                'Profesionales que eligieron mantener su identidad reservada.',
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
            : CupertinoIcons.lock,
        title: _data.error
            ? 'No pudimos cargar el catálogo'
            : 'Todavía no hay candidatos confidenciales',
        message: _data.error
            ? 'Revisá tu conexión y volvé a intentar.'
            : 'Cuando haya profesionales con perfil reservado, aparecen acá y '
                'podés desbloquear los que te interesen.',
        actionLabel: _data.error ? 'Reintentar' : null,
        onAction: _data.error ? _load : null,
      ),
    );
  }

  // ── Billetera ──────────────────────────────────────────────────────────────

  Widget _billetera() {
    final s = context.mp;
    final b = _data.billetera;

    if (b.noDisponible) {
      return MpBanner(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'No pudimos leer tu saldo',
        message: 'Podés ver el catálogo, pero no sabemos cuántos créditos '
            'tenés disponibles.',
        color: MpTokens.premium,
        actionLabel: 'Reintentar',
        onAction: _load,
      );
    }

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Row(
        children: [
          const MpIconTile(
            icon: CupertinoIcons.creditcard,
            color: MpTokens.primary,
            size: 48,
          ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tus créditos',
                  style: MpTokens.caption.copyWith(color: s.textSecondary),
                ),
                Text(
                  '${b.creditos}',
                  style: MpTokens.stat.copyWith(color: s.text, fontSize: 28),
                ),
                Text(
                  b.creditos == 0
                      ? 'Sin créditos disponibles'
                      : 'Cada desbloqueo usa 1 crédito',
                  style: MpTokens.micro.copyWith(color: s.textTertiary),
                ),
              ],
            ),
          ),
          if (b.plan != null)
            MpTypeChip(
              label: b.plan!,
              color: MpTokens.premium,
              icon: CupertinoIcons.star_fill,
            ),
        ],
      ),
    );
  }

  // ── Listado ────────────────────────────────────────────────────────────────

  List<Widget> _listado() {
    final visibles = _visibles;

    if (visibles.isEmpty) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: const MpEmptyState(
            icon: CupertinoIcons.lock,
            title: 'Sin candidatos en este filtro',
            message: 'Probá con otro estado.',
          ),
        ),
      ];
    }

    return [
      for (final c in visibles) ...[
        _tarjeta(c),
        const SizedBox(height: MpTokens.space12),
      ],
    ];
  }

  Widget _tarjeta(CandidatoConfidencial c) {
    final s = context.mp;
    final ocupado = _desbloqueando == c.id;
    final candidateId = c.candidateId;

    return MpCard(
      radius: MpTokens.radiusXL,
      onTap: c.desbloqueado && candidateId != null
          ? () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) =>
                      EmpresaCandidatoPerfilScreen(candidatoId: candidateId),
                ),
              )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _retrato(c),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.headline?.isNotEmpty == true
                          ? c.headline!
                          : 'Perfil confidencial',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MpTokens.title.copyWith(color: s.text),
                    ),
                    const SizedBox(height: MpTokens.space4),
                    MpTypeChip(
                      label: c.desbloqueado ? c.nombre : 'Identidad reservada',
                      color: c.desbloqueado
                          ? MpTokens.success
                          : MpTokens.catIndigo,
                      icon: c.desbloqueado
                          ? CupertinoIcons.checkmark_seal
                          : CupertinoIcons.lock_fill,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (c.about != null) ...[
            const SizedBox(height: MpTokens.space12),
            Text(
              c.about!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: MpTokens.body.copyWith(
                color: s.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
          if (c.tags.isNotEmpty) ...[
            const SizedBox(height: MpTokens.space12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in c.tags.take(5)) MpTagChip(label: t),
              ],
            ),
          ],
          const SizedBox(height: MpTokens.space16),
          if (c.desbloqueado && candidateId != null)
            MpButton(
              label: 'Ver perfil completo',
              icon: CupertinoIcons.person,
              variant: MpButtonVariant.outline,
              expand: true,
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) =>
                      EmpresaCandidatoPerfilScreen(candidatoId: candidateId),
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '1 crédito',
                        style: MpTokens.label.copyWith(color: s.text),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Revela nombre y contacto',
                        maxLines: 2,
                        style: MpTokens.micro.copyWith(
                          color: s.textTertiary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MpTokens.space12),
                MpButton(
                  label: 'Desbloquear',
                  icon: CupertinoIcons.lock_open,
                  loading: ocupado,
                  onPressed: () => _desbloquear(c),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Retrato velado: sin foto (la RPC no la devuelve mientras esté bloqueado),
  /// así que se dibuja el candado sobre un bloque tintado.
  Widget _retrato(CandidatoConfidencial c) {
    final s = context.mp;

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: s.tint(
          c.desbloqueado ? MpTokens.success : MpTokens.catIndigo,
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(MpTokens.radiusLG),
      ),
      child: Icon(
        c.desbloqueado ? CupertinoIcons.person_fill : CupertinoIcons.lock_fill,
        size: 26,
        color: c.desbloqueado ? MpTokens.success : MpTokens.catIndigo,
      ),
    );
  }

  // ── Cómo funciona ──────────────────────────────────────────────────────────

  Widget _comoFunciona() {
    final s = context.mp;

    const pasos = [
      (CupertinoIcons.search, 'Descubrí', 'Explorá perfiles reservados.'),
      (CupertinoIcons.lock_open, 'Desbloqueá', 'Usás 1 crédito por perfil.'),
      (CupertinoIcons.eye, 'Accedé', 'Ves su información completa.'),
      (CupertinoIcons.chat_bubble, 'Conectá', 'Le escribís directamente.'),
    ];

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Cómo funciona?', style: MpTokens.title.copyWith(color: s.text)),
          const SizedBox(height: MpTokens.space16),
          for (var i = 0; i < pasos.length; i++) ...[
            if (i > 0) const SizedBox(height: MpTokens.space16),
            Row(
              children: [
                MpIconTile(
                  icon: pasos[i].$1,
                  color: MpTokens.primary,
                  size: 38,
                  circular: true,
                ),
                const SizedBox(width: MpTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${i + 1}. ${pasos[i].$2}',
                        style: MpTokens.label.copyWith(color: s.text),
                      ),
                      Text(
                        pasos[i].$3,
                        style: MpTokens.micro.copyWith(
                          color: s.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
