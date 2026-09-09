import 'package:flutter/cupertino.dart';

import '../../services/job_offer_service.dart';
import '../../widgets/ds/mploya_ds.dart';

/// Crear o revisar una oferta laboral (migración 051, bloque E2).
///
/// UN SOLO FORMULARIO PARA LAS DOS COSAS. Crear una oferta nueva son dos
/// llamadas seguidas (`create_job_offer` + `send_job_offer`); revisar una ya
/// enviada es una sola (`revise_job_offer`, que ya la deja en 'sent'). La
/// pantalla no distingue eso para la empresa: sólo cambia qué guarda al tocar
/// el botón final.
///
/// LOS CUATRO CAMPOS OBLIGATORIOS PARA ENVIAR — monto, moneda, fecha de
/// inicio y vencimiento — los exige `send_job_offer` del lado del servidor.
/// Acá se piden desde el principio para no dejar completar un formulario que
/// después el servidor va a rechazar.
class EmpresaCrearOfertaScreen extends StatefulWidget {
  const EmpresaCrearOfertaScreen({
    super.key,
    required this.applicationId,
    required this.candidatoNombre,
    required this.vacante,
    this.ofertaExistente,
  });

  final String applicationId;
  final String candidatoNombre;
  final String vacante;

  /// Si viene con valor, la pantalla arranca precargada con sus datos y el
  /// botón final llama a `revise_job_offer` en vez de crear una nueva.
  final JobOffer? ofertaExistente;

  @override
  State<EmpresaCrearOfertaScreen> createState() =>
      _EmpresaCrearOfertaScreenState();
}

class _EmpresaCrearOfertaScreenState extends State<EmpresaCrearOfertaScreen> {
  final _monto = TextEditingController();
  final _mensaje = TextEditingController();
  final _beneficioNuevo = TextEditingController();

  int _monedaIdx = 0; // ARS, USD
  int _periodoIdx = 0; // mensual, anual, hora
  int? _modalidadIdx; // presencial, hibrido, remoto — sin elegir por defecto

  DateTime? _inicio;
  DateTime? _vencimiento;
  final List<String> _beneficios = [];

  bool _enviando = false;
  String? _error;

  static const _monedas = ['ARS', 'USD'];
  static const _periodos = ['mensual', 'anual', 'hora'];
  static const _modalidades = ['presencial', 'hibrido', 'remoto'];

  @override
  void initState() {
    super.initState();
    final o = widget.ofertaExistente;
    if (o != null) {
      _monto.text =
          o.salaryAmount == null ? '' : o.salaryAmount!.toStringAsFixed(0);
      _monedaIdx = _monedas.indexOf(o.salaryCurrency ?? 'ARS').clamp(0, 1);
      _periodoIdx = _periodos.indexOf(o.salaryPeriod).clamp(0, 2);
      _modalidadIdx =
          o.modalidad == null ? null : _modalidades.indexOf(o.modalidad!);
      _inicio = o.startDate;
      _vencimiento = o.expiresAt;
      _beneficios.addAll(o.benefits);
      _mensaje.text = o.message ?? '';
    } else {
      // Vencimiento por defecto: 5 días, el mismo plazo usado en la prueba
      // del circuito completo desde el SQL Editor.
      _vencimiento = DateTime.now().add(const Duration(days: 5));
    }
  }

  @override
  void dispose() {
    _monto.dispose();
    _mensaje.dispose();
    _beneficioNuevo.dispose();
    super.dispose();
  }

  double? get _montoNumerico {
    final texto = _monto.text.trim().replaceAll('.', '').replaceAll(',', '.');
    if (texto.isEmpty) return null;
    return double.tryParse(texto);
  }

  bool get _puedeEnviar =>
      !_enviando &&
      _montoNumerico != null &&
      _montoNumerico! > 0 &&
      _inicio != null &&
      _vencimiento != null &&
      _vencimiento!.isAfter(DateTime.now());

  Future<void> _elegirFecha({required bool esInicio}) async {
    final actual = esInicio ? _inicio : _vencimiento;
    final elegido = await _mostrarSelectorFecha(
      context,
      inicial: actual ?? DateTime.now().add(Duration(days: esInicio ? 14 : 5)),
      minima: esInicio ? null : DateTime.now(),
    );
    if (elegido == null) return;
    setState(() {
      if (esInicio) {
        _inicio = elegido;
      } else {
        _vencimiento = elegido;
      }
    });
  }

  void _agregarBeneficio() {
    final texto = _beneficioNuevo.text.trim();
    if (texto.isEmpty || _beneficios.length >= 20) return;
    setState(() {
      _beneficios.add(texto);
      _beneficioNuevo.clear();
    });
  }

  Future<void> _enviar() async {
    if (!_puedeEnviar) return;
    setState(() {
      _enviando = true;
      _error = null;
    });

    final modalidad =
        _modalidadIdx == null ? null : _modalidades[_modalidadIdx!];
    final mensaje = _mensaje.text.trim();

    try {
      final existente = widget.ofertaExistente;
      if (existente != null) {
        await reviseJobOffer(
          offerId: existente.id,
          salaryAmount: _montoNumerico,
          salaryCurrency: _monedas[_monedaIdx],
          salaryPeriod: _periodos[_periodoIdx],
          modalidad: modalidad,
          benefits: _beneficios,
          startDate: _inicio,
          expiresAt: _vencimiento,
          message: mensaje.isEmpty ? null : mensaje,
        );
      } else {
        final offerId = await createJobOffer(
          applicationId: widget.applicationId,
          salaryAmount: _montoNumerico,
          salaryCurrency: _monedas[_monedaIdx],
          salaryPeriod: _periodos[_periodoIdx],
          modalidad: modalidad,
          benefits: _beneficios,
          startDate: _inicio,
          expiresAt: _vencimiento,
          message: mensaje.isEmpty ? null : mensaje,
        );
        await sendJobOffer(offerId);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on JobOfferException catch (e) {
      setState(() => _error = e.mensaje);
    } catch (e) {
      setState(() => _error = 'No pudimos enviar la oferta. Probá de nuevo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esRevision = widget.ofertaExistente != null;

    return MpSurface(
      style: MpSurfaceStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: MpTokens.lightBg,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: MpTokens.lightBg,
          border: null,
          middle: Text(esRevision ? 'Revisar oferta' : 'Nueva oferta'),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              MpTokens.screenPadding,
              MpTokens.space16,
              MpTokens.screenPadding,
              MpTokens.space32,
            ),
            children: [
              Text(
                widget.candidatoNombre,
                style: MpTokens.h2.copyWith(color: context.mp.text),
              ),
              Text(
                widget.vacante,
                style:
                    MpTokens.body.copyWith(color: context.mp.textSecondary),
              ),
              const SizedBox(height: MpTokens.space24),

              const MpFieldLabel('Monto'),
              MpTextField(
                controller: _monto,
                placeholder: 'Ej: 850000',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: MpTokens.space12),

              const MpFieldLabel('Moneda'),
              MpSegmentedFilter(
                options: const [MpFilterOption('ARS'), MpFilterOption('USD')],
                selectedIndex: _monedaIdx,
                onChanged: (i) => setState(() => _monedaIdx = i),
              ),
              const SizedBox(height: MpTokens.space12),

              const MpFieldLabel('Periodicidad'),
              MpSegmentedFilter(
                options: const [
                  MpFilterOption('Mensual'),
                  MpFilterOption('Anual'),
                  MpFilterOption('Por hora'),
                ],
                selectedIndex: _periodoIdx,
                onChanged: (i) => setState(() => _periodoIdx = i),
              ),
              const SizedBox(height: MpTokens.space16),

              const MpFieldLabel('Modalidad', helper: 'Opcional'),
              MpSegmentedFilter(
                options: const [
                  MpFilterOption('Presencial'),
                  MpFilterOption('Híbrido'),
                  MpFilterOption('Remoto'),
                ],
                selectedIndex: _modalidadIdx ?? -1,
                onChanged: (i) => setState(() => _modalidadIdx = i),
              ),
              const SizedBox(height: MpTokens.space16),

              MpFieldLabel(
                'Fecha de inicio',
                helper: _inicio == null ? null : _fechaLarga(_inicio!),
              ),
              MpButton(
                label:
                    _inicio == null ? 'Elegir fecha' : _fechaLarga(_inicio!),
                variant: MpButtonVariant.neutral,
                expand: true,
                icon: CupertinoIcons.calendar,
                onPressed: () => _elegirFecha(esInicio: true),
              ),
              const SizedBox(height: MpTokens.space12),

              const MpFieldLabel('Vencimiento'),
              MpButton(
                label: _vencimiento == null
                    ? 'Elegir fecha'
                    : _fechaLarga(_vencimiento!),
                variant: MpButtonVariant.neutral,
                expand: true,
                icon: CupertinoIcons.calendar_badge_plus,
                onPressed: () => _elegirFecha(esInicio: false),
              ),
              if (_vencimiento != null &&
                  !_vencimiento!.isAfter(DateTime.now())) ...[
                const SizedBox(height: MpTokens.space4),
                Text(
                  'Tiene que ser una fecha posterior a hoy.',
                  style: MpTokens.micro.copyWith(color: MpTokens.danger),
                ),
              ],
              const SizedBox(height: MpTokens.space16),

              const MpFieldLabel('Beneficios', helper: 'Opcional, hasta 20'),
              if (_beneficios.isNotEmpty)
                Wrap(
                  spacing: MpTokens.space8,
                  runSpacing: MpTokens.space8,
                  children: [
                    for (final b in _beneficios)
                      MpTagChip(
                        label: b,
                        onRemove: () => setState(() => _beneficios.remove(b)),
                      ),
                  ],
                ),
              if (_beneficios.isNotEmpty)
                const SizedBox(height: MpTokens.space8),
              Row(
                children: [
                  Expanded(
                    child: MpTextField(
                      controller: _beneficioNuevo,
                      placeholder: 'Ej: Obra social',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: MpTokens.space8),
                  MpButton(
                    label: 'Agregar',
                    variant: MpButtonVariant.outline,
                    onPressed: _beneficioNuevo.text.trim().isEmpty
                        ? null
                        : _agregarBeneficio,
                  ),
                ],
              ),
              const SizedBox(height: MpTokens.space16),

              const MpFieldLabel('Mensaje para el candidato',
                  helper: 'Opcional'),
              MpTextField(
                controller: _mensaje,
                placeholder: 'Un mensaje corto que acompañe la oferta',
                maxLines: 3,
              ),

              if (_error != null) ...[
                const SizedBox(height: MpTokens.space16),
                MpBanner(
                  icon: CupertinoIcons.exclamationmark_triangle,
                  title: 'No pudimos enviarla',
                  message: _error!,
                  color: MpTokens.danger,
                ),
              ],

              const SizedBox(height: MpTokens.space24),
              MpButton(
                label: esRevision ? 'Guardar cambios' : 'Enviar oferta',
                expand: true,
                loading: _enviando,
                onPressed: _puedeEnviar ? _enviar : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fechaLarga(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

Future<DateTime?> _mostrarSelectorFecha(
  BuildContext context, {
  required DateTime inicial,
  DateTime? minima,
}) {
  DateTime elegido = inicial;
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (_) => MpSurface(
      style: MpSurfaceStyle.light,
      child: Builder(
        builder: (context) {
          final s = context.mp;
          return Container(
            height: 320,
            decoration: BoxDecoration(
              color: s.bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(MpTokens.radiusXL),
              ),
            ),
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(elegido),
                      child: const Text('Listo'),
                    ),
                  ],
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: inicial,
                    minimumDate: minima,
                    onDateTimeChanged: (d) => elegido = d,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
