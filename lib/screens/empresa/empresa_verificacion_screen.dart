import 'package:flutter/cupertino.dart';

import '../../services/company_verification_service.dart';
import '../../widgets/ds/mploya_ds.dart';
import 'empresa_verificacion_data.dart';

/// Verificación de la Empresa.
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 12/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// ESTRUCTURA tomada de `veriifcacion de perfil.png`, con una aclaración
/// importante: ese PNG es de **escritorio y del rol candidato** (identidad,
/// experiencia, educación, referencias, portfolio, insignias, vista previa
/// pública). Nada de eso existe para Empresa. Lo que se reutiliza es la FORMA
/// —estado arriba, progreso por niveles, historial abajo— llevada a móvil y al
/// modelo real de esta app.
///
/// DATOS REALES: la tabla `company_verifications` y sus tres niveles —`basic`,
/// `verified`, `trusted`— con sus estados `pending` / `approved` / `rejected`.
/// Se muestran las filas que existen, con su fecha y su `review_note`.
///
/// OMITIDO, y por qué:
///
/// · **Subida de documentos.** `requestVerification()` espera `document_urls`,
///   pero no hay un bucket para documentos: los únicos son `videos`, `avatars`
///   y `thumbnails`. Subir un PDF a `videos` sería un hack, así que el nivel
///   `verified` se muestra pero no se puede solicitar desde acá todavía.
///
/// · **Progreso hacia `trusted`.** El servicio lo otorga contando
///   `job_applications.status = 'hired'`, pero esa columna sólo admite
///   `pending · viewed · accepted · rejected`: **'hired' no puede existir**, así
///   que el contador siempre daría 0. Dibujar "0 de 5 contrataciones" sería
///   prometer una meta inalcanzable. Se muestra el nivel como informativo.
///
/// · Las insignias por documento, la vista previa pública y los beneficios con
///   números ("3.2x más visibilidad") del PNG: son del candidato, o métricas
///   que nadie mide.
class EmpresaVerificacionScreen extends StatefulWidget {
  /// Datos ya resueltos, para los golden tests.
  final VerificacionData? previewData;

  const EmpresaVerificacionScreen({super.key, this.previewData});

  @override
  State<EmpresaVerificacionScreen> createState() =>
      _EmpresaVerificacionScreenState();
}

class _EmpresaVerificacionScreenState extends State<EmpresaVerificacionScreen> {
  VerificacionData _data = VerificacionData.vacia;
  bool _loading = true;
  bool _verificando = false;

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
    final d = await loadVerificacion();
    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  Future<void> _verificarEmail() async {
    if (_verificando || widget.previewData != null) return;
    setState(() => _verificando = true);
    final r = await verificarEmailCorporativo();
    if (!mounted) return;
    setState(() => _verificando = false);

    final (titulo, mensaje) = switch (r) {
      ResultadoAutoVerificacion.verificada => (
          'Email verificado',
          'Tu dominio corporativo quedó verificado.',
        ),
      ResultadoAutoVerificacion.dominioPublico => (
          'No pudimos verificarlo',
          'Tu cuenta usa un dominio de correo público '
              '(${_data.dominioEmail ?? "gmail, hotmail y similares"}). '
              'La verificación automática necesita el dominio propio de la '
              'empresa.',
        ),
      ResultadoAutoVerificacion.noDisponible => (
          'Verificación pendiente',
          'La solicitud de verificación estará disponible próximamente.',
        ),
      ResultadoAutoVerificacion.error => (
          'No pudimos verificarlo',
          'Probá de nuevo en un momento.',
        ),
    };

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

    if (r == ResultadoAutoVerificacion.verificada) await _load();
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MpTokens.screenPadding,
                  MpTokens.space8,
                  MpTokens.screenPadding,
                  0,
                ),
                child: MpHeader(
                  title: 'Verificación',
                  subtitle: 'Genera confianza con los candidatos.',
                  onBack: () => Navigator.of(context).maybePop(),
                  actions: [
                    MpIconButton(
                      icon: CupertinoIcons.refresh,
                      onPressed: _load,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CupertinoActivityIndicator(radius: 15))
                    : CustomScrollView(
                        slivers: [
                          CupertinoSliverRefreshControl(onRefresh: _load),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              MpTokens.screenPadding,
                              MpTokens.space16,
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
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _cuerpo() {
    if (_data.error) {
      return [
        MpEmptyState(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: 'No pudimos leer tu verificación',
          message: 'Revisá tu conexión y volvé a intentar.',
          actionLabel: 'Reintentar',
          onAction: _load,
        ),
      ];
    }

    return [
      _estadoActual(),
      const SizedBox(height: MpTokens.space24),
      const MpSectionHeader(
        title: 'Niveles',
        subtitle: 'Cada uno se otorga por su propio criterio.',
      ),
      const SizedBox(height: MpTokens.space12),
      _niveles(),
      const SizedBox(height: MpTokens.space24),
      ..._historial(),
    ];
  }

  // ── Estado actual ──
  Widget _estadoActual() {
    final nivel = _data.nivel;
    final verificada = nivel != VerificationLevel.none;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MpTokens.space20),
      decoration: BoxDecoration(
        gradient: verificada ? MpTokens.heroGradient : null,
        color: verificada ? null : MpTokens.lightFill,
        borderRadius: BorderRadius.circular(MpTokens.radiusXL),
        border: verificada
            ? null
            : Border.all(color: MpTokens.lightBorderStrong),
      ),
      child: Column(
        children: [
          Icon(
            verificada
                ? CupertinoIcons.checkmark_seal_fill
                : CupertinoIcons.checkmark_seal,
            size: 44,
            color: verificada
                ? const Color(0xFFFFFFFF)
                : MpTokens.lightTextTertiary,
          ),
          const SizedBox(height: MpTokens.space12),
          Text(
            verificada
                ? CompanyVerificationService.levelLabel(nivel)
                : 'Sin verificar',
            textAlign: TextAlign.center,
            style: MpTokens.h2.copyWith(
              color: verificada
                  ? const Color(0xFFFFFFFF)
                  : MpTokens.lightText,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: MpTokens.space4),
          Text(
            verificada
                ? 'Los candidatos ven este estado en tu perfil.'
                : 'Todavía no completaste ningún nivel de verificación.',
            textAlign: TextAlign.center,
            style: MpTokens.caption.copyWith(
              color: verificada
                  ? const Color(0xCCFFFFFF)
                  : MpTokens.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Los tres niveles reales ──
  Widget _niveles() {
    return Column(
      children: [
        _fichaNivel(
          nivel: VerificationLevel.basic,
          icono: CupertinoIcons.mail,
          titulo: 'Email corporativo',
          criterio: 'Tu cuenta usa el dominio propio de la empresa, no un '
              'correo público.',
          accion: _data.tieneAprobado(VerificationLevel.basic)
              ? null
              : MpButton(
                  label: 'Verificar mi email',
                  icon: CupertinoIcons.checkmark_shield,
                  size: MpButtonSize.small,
                  loading: _verificando,
                  onPressed: _verificarEmail,
                ),
        ),
        const SizedBox(height: MpTokens.space8),
        _fichaNivel(
          nivel: VerificationLevel.verified,
          icono: CupertinoIcons.doc_text,
          titulo: 'Documentación legal',
          criterio: 'Un moderador revisa la documentación de la empresa.',
          nota: 'Todavía no se puede enviar desde la app: falta el espacio de '
              'almacenamiento para documentos.',
        ),
        const SizedBox(height: MpTokens.space8),
        _fichaNivel(
          nivel: VerificationLevel.trusted,
          icono: CupertinoIcons.rosette,
          titulo: 'Empresa de confianza',
          criterio: 'Se otorga por historial de contrataciones en la '
              'plataforma.',
          nota: 'Informativo: el criterio automático todavía no puede '
              'evaluarse, así que hoy sólo se asigna manualmente.',
        ),
      ],
    );
  }

  Widget _fichaNivel({
    required VerificationLevel nivel,
    required IconData icono,
    required String titulo,
    required String criterio,
    String? nota,
    Widget? accion,
  }) {
    final s = context.mp;
    final aprobado = _data.tieneAprobado(nivel);
    final pendiente = _data.pendienteDe(nivel);
    final rechazo = _data.rechazoDe(nivel);

    final badge = aprobado
        ? const MpStatusBadge(label: 'Obtenido', status: MpStatus.active)
        : pendiente != null
            ? const MpStatusBadge(label: 'En revisión', status: MpStatus.paused)
            : rechazo != null
                ? const MpStatusBadge(
                    label: 'Rechazado', status: MpStatus.danger)
                : null;

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.all(MpTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: aprobado
                      ? MpTokens.success.withValues(alpha: 0.12)
                      : MpTokens.lightFill,
                  borderRadius: BorderRadius.circular(MpTokens.radiusSM),
                ),
                child: Icon(
                  icono,
                  size: 19,
                  color: aprobado ? MpTokens.success : s.textTertiary,
                ),
              ),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      style:
                          MpTokens.title.copyWith(color: s.text, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      criterio,
                      style: MpTokens.micro.copyWith(color: s.textSecondary),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: MpTokens.space8),
                badge,
              ],
            ],
          ),
          if (nota != null) ...[
            const SizedBox(height: MpTokens.space8),
            Text(
              nota,
              style: MpTokens.micro.copyWith(color: s.textTertiary),
            ),
          ],
          if (accion != null) ...[
            const SizedBox(height: MpTokens.space12),
            Align(alignment: Alignment.centerLeft, child: accion),
          ],
        ],
      ),
    );
  }

  // ── Historial real ──
  List<Widget> _historial() {
    final s = context.mp;

    if (_data.historial.isEmpty) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: const MpEmptyState(
            icon: CupertinoIcons.time,
            title: 'Sin movimientos',
            message: 'Cuando se registre una verificación vas a ver acá su '
                'fecha y el comentario de quien la revisó.',
          ),
        ),
      ];
    }

    return [
      const MpSectionHeader(title: 'Historial'),
      const SizedBox(height: MpTokens.space12),
      MpRowGroup(
        rows: [
          for (final v in _data.historial)
            MpListRow(
              leading: Icon(
                v.aprobada
                    ? CupertinoIcons.checkmark_circle_fill
                    : v.rechazada
                        ? CupertinoIcons.xmark_circle_fill
                        : CupertinoIcons.clock_fill,
                size: 22,
                color: v.aprobada
                    ? MpTokens.success
                    : v.rechazada
                        ? MpTokens.danger
                        : MpTokens.premium,
              ),
              title: CompanyVerificationService.levelLabel(v.nivel),
              subtitle: v.notaDeRevision,
              titleMaxLines: 2,
              trailingText: _fecha(v.cuando),
              showChevron: false,
            ),
        ],
      ),
      const SizedBox(height: MpTokens.space8),
      Text(
        'Cada fila es un registro real de la revisión.',
        style: MpTokens.micro.copyWith(color: s.textTertiary),
      ),
    ];
  }

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  String _fecha(DateTime? d) {
    if (d == null) return '';
    return '${d.day} ${_meses[d.month - 1]}';
  }
}
