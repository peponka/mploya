import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';
import 'empresa_candidato_perfil_screen.dart';
import 'empresa_confidenciales_screen.dart';
import 'empresa_creditos_data.dart';

/// Créditos y consumo de la Empresa.
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 11/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// DERIVACIÓN CONTROLADA de `creditos y planes.png` (Pantalla 37), con
/// `analitics y desbloqueados.png` (36) para el bloque de consumo. Ambos son de
/// escritorio; acá la jerarquía baja a una columna: saldo grande, consumo,
/// historial de desbloqueos y cómo funciona.
///
/// DATOS REALES: `company_wallets` (saldo y plan), `profile_unlocks` (cada
/// desbloqueo con `unlocked_at`) y `claim_welcome_credits` (5 créditos una
/// sola vez, cuando todavía no existe billetera). Los créditos gastados no se
/// estiman: cada desbloqueo cuesta 1 crédito según `unlock_stealth_profile`,
/// así que gastados = desbloqueos.
///
/// OMITIDO, y por qué. El PNG de Planes muestra cuatro planes con precio
/// ($49 / $149 / $299 / Personalizado), botón "Comprar créditos", "Elegir plan",
/// renovación, ahorro anual y una tabla de costo por seniority. **No existe
/// checkout, ni tabla de precios, ni planes en la base**: `subscription_tier` es
/// un texto y nada más. Dibujar precios sería inventar una oferta comercial. Y
/// el costo por seniority contradice a la RPC, que cobra 1 crédito fijo.
/// También falta el historial de transacciones: no hay tabla de movimientos, así
/// que sólo se puede listar lo que sí quedó registrado, que son los desbloqueos.
class EmpresaCreditosScreen extends StatefulWidget {
  /// Datos ya resueltos, para los golden tests.
  final CreditosData? previewData;

  const EmpresaCreditosScreen({super.key, this.previewData});

  @override
  State<EmpresaCreditosScreen> createState() => _EmpresaCreditosScreenState();
}

class _EmpresaCreditosScreenState extends State<EmpresaCreditosScreen> {
  CreditosData _data = CreditosData.empty;
  bool _loading = true;
  bool _reclamandoBienvenida = false;

  static const _meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

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
    final data = await loadCreditos();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  String _fecha(DateTime? f) {
    if (f == null) return '';
    return '${f.day} ${_meses[f.month - 1]}';
  }

  Future<void> _reclamarBienvenida() async {
    if (_reclamandoBienvenida || widget.previewData != null) return;
    setState(() => _reclamandoBienvenida = true);
    final resultado = await reclamarCreditosBienvenida();
    if (!mounted) return;
    setState(() => _reclamandoBienvenida = false);

    if (resultado == ResultadoCreditosBienvenida.error) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('No pudimos activar los créditos'),
          content: const Text('Probá de nuevo en unos minutos.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    await _load();
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
      _saldo(),
      const SizedBox(height: MpTokens.space16),
      _consumo(),
      const SizedBox(height: MpTokens.space24),
      ..._historial(),
      const SizedBox(height: MpTokens.space24),
      _comoSeConsigue(),
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
              Text('Créditos', style: MpTokens.h1.copyWith(color: s.text)),
              const SizedBox(height: MpTokens.space4),
              Text(
                'Tu saldo y en qué lo usaste.',
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

  Widget _saldo() {
    if (_data.billeteraNoDisponible) {
      return MpBanner(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'No pudimos leer tu saldo',
        message: 'Revisá tu conexión y volvé a intentar.',
        color: MpTokens.danger,
        actionLabel: 'Reintentar',
        onAction: _load,
      );
    }

    return Container(
      padding: const EdgeInsets.all(MpTokens.space20),
      decoration: BoxDecoration(
        gradient: MpTokens.heroGradient,
        borderRadius: BorderRadius.circular(MpTokens.radiusXXL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Créditos disponibles',
                  style: MpTokens.caption.copyWith(
                    color: MpTokens.darkTextSecondary,
                  ),
                ),
              ),
              if (_data.plan != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.star_fill,
                        size: 12,
                        color: MpTokens.premiumBright,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _data.plan!,
                        style: MpTokens.micro.copyWith(
                          color: MpTokens.darkText,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: MpTokens.space8),
          Text(
            '${_data.creditos}',
            style: MpTokens.display.copyWith(
              color: MpTokens.darkText,
              fontSize: 46,
            ),
          ),
          const SizedBox(height: MpTokens.space4),
          Text(
            _data.creditos == 0
                ? 'Sin créditos: no vas a poder desbloquear perfiles.'
                : 'Cada perfil confidencial cuesta 1 crédito.',
            style: MpTokens.caption.copyWith(
              color: MpTokens.darkTextSecondary,
            ),
          ),
          const SizedBox(height: MpTokens.space16),
          if (_data.puedeReclamarBienvenida) ...[
            MpButton(
              label: 'Activar 5 créditos de bienvenida',
              icon: CupertinoIcons.gift,
              variant: MpButtonVariant.neutral,
              expand: true,
              loading: _reclamandoBienvenida,
              onPressed: _reclamarBienvenida,
            ),
            const SizedBox(height: MpTokens.space8),
          ],
          MpButton(
            label: 'Ver talento confidencial',
            icon: CupertinoIcons.lock_open,
            variant: MpButtonVariant.neutral,
            expand: true,
            onPressed: () => Navigator.of(context)
                .push(
                  CupertinoPageRoute(
                    builder: (_) => const EmpresaConfidencialesScreen(),
                  ),
                )
                .then((_) => _load()),
          ),
        ],
      ),
    );
  }

  Widget _consumo() {
    final s = context.mp;

    if (_data.historialNoDisponible) {
      return MpBanner(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'No pudimos leer tu consumo',
        message: 'El saldo de arriba sí es correcto.',
        color: MpTokens.premium,
      );
    }

    final items = <({String valor, String etiqueta})>[
      (valor: '${_data.totalDesbloqueos}', etiqueta: 'Desbloqueos'),
      (valor: '${_data.desbloqueosDelMes}', etiqueta: 'Este mes'),
      (valor: '${_data.creditosGastados}', etiqueta: 'Créditos usados'),
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        items[i].etiqueta,
                        style: MpTokens.micro.copyWith(
                          color: s.textSecondary,
                          fontSize: 10.5,
                        ),
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

  List<Widget> _historial() {
    final s = context.mp;

    if (_data.historialNoDisponible) return const [];

    if (_data.desbloqueos.isEmpty) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: const MpEmptyState(
            icon: CupertinoIcons.lock_open,
            title: 'Todavía no desbloqueaste a nadie',
            message: 'Cuando desbloquees un perfil confidencial vas a ver acá '
                'a quién y cuándo.',
          ),
        ),
      ];
    }

    return [
      MpSectionHeader(
        title: 'Perfiles desbloqueados',
        subtitle: '${_data.totalDesbloqueos} en total.',
      ),
      const SizedBox(height: MpTokens.space12),
      MpRowGroup(
        dividerIndent: 62,
        rows: [
          for (final d in _data.desbloqueos)
            MpListRow(
              leading: MpAvatar(
                name: d.nombre ?? 'Candidato',
                size: 42,
                image:
                    d.avatarUrl == null ? null : NetworkImage(d.avatarUrl!),
              ),
              title: d.nombre ?? 'Candidato',
              subtitle: d.headline,
              trailingText: _fecha(d.cuando),
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => EmpresaCandidatoPerfilScreen(
                    candidatoId: d.candidatoId,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: MpTokens.space8),
      Text(
        'Cada uno costó 1 crédito.',
        style: MpTokens.micro.copyWith(color: s.textTertiary),
      ),
    ];
  }

  /// El mockup vende planes con precio. No hay checkout ni tabla de planes, así
  /// que en vez de simular una oferta se explica de dónde salen los créditos hoy.
  Widget _comoSeConsigue() {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cómo funcionan los créditos',
            style: MpTokens.title.copyWith(color: s.text),
          ),
          const SizedBox(height: MpTokens.space12),
          Text(
            'Un crédito desbloquea un perfil confidencial: te muestra su nombre '
            'y su información completa, y podés escribirle. El desbloqueo es '
            'para siempre — no se vuelve a cobrar por el mismo perfil.',
            style: MpTokens.body.copyWith(
              color: s.textSecondary,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: MpTokens.space16),
          Container(height: 1, color: s.border),
          const SizedBox(height: MpTokens.space16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.info, size: 16, color: s.textTertiary),
              const SizedBox(width: MpTokens.space8),
              Expanded(
                child: Text(
                  _data.puedeReclamarBienvenida
                      ? 'Podés activar una vez los 5 créditos de bienvenida. '
                          'La compra de créditos y los planes todavía no están '
                          'disponibles en la app.'
                      : 'La compra de créditos y los planes todavía no están '
                          'disponibles en la app. Por ahora el saldo se '
                          'administra desde tu cuenta.',
                  style: MpTokens.micro.copyWith(color: s.textTertiary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
