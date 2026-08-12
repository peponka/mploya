import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/ai_match_service.dart';
import '../../widgets/ds/mploya_ds.dart';

/// Modalidad de trabajo. Se guarda como tag porque `jobs` no tiene columna
/// propia y es de ahí de donde la lista de vacantes la deduce hoy.
const _modalidades = ['Remoto', 'Híbrido', 'Presencial'];

/// Tipo de contrato → `jobs.employment_type` (texto libre).
const _contratos = ['Tiempo completo', 'Medio tiempo', 'Contrato', 'Prácticas'];

/// Nivel → `jobs.experience_level` (texto libre).
const _niveles = ['Junior', 'Semi Senior', 'Senior', 'Lead'];

/// Crear / Publicar vacante (Empresa móvil).
///
/// RECONSTRUCCIÓN DIRECTA del flujo de los cinco PNG:
///   · `crear vacante con ia.png` (13) y `publicar vacante3.png` (14) fijan el
///     asistente de CUATRO pasos — Información · Descripción · Requisitos ·
///     Publicar — que es el que se implementa.
///   · `crear vacante.png` (22) aporta el detalle del paso 1: contador en el
///     título, tarjetas de tipo de empleo, píldoras de nivel, chips de
///     habilidades y el panel de Asistente IA.
///   · `publicar vacante.png` (9) aporta el bloque de video, el rango salarial y
///     el interruptor de visibilidad.
///   · `publicar vacante 2.png` (23) aporta la vista previa del paso final y las
///     opciones de publicación.
///
/// LO QUE NO SE DIBUJA, y por qué:
///   · Video de la vacante: `jobs` no tiene columna de video. Un botón "Grabar
///     video" que no guarda nada es un botón muerto.
///   · Créditos y duración de la publicación: no existen en el modelo.
///   · Canales externos (WhatsApp, LinkedIn, Instagram): no hay integración.
///     Se muestran, como en el mockup, pero marcados "Próximamente" y sin
///     interruptor, para que no parezca que se van a publicar.
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 12/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
class EmpresaPublicarVacanteScreen extends StatefulWidget {
  /// Fuerza un paso inicial (sólo para los golden tests).
  final int pasoInicial;

  const EmpresaPublicarVacanteScreen({super.key, this.pasoInicial = 0});

  @override
  State<EmpresaPublicarVacanteScreen> createState() =>
      _EmpresaPublicarVacanteScreenState();
}

class _EmpresaPublicarVacanteScreenState
    extends State<EmpresaPublicarVacanteScreen> {
  final _titulo = TextEditingController();
  final _ubicacion = TextEditingController();
  final _salario = TextEditingController();
  final _descripcion = TextEditingController();
  final _horario = TextEditingController();
  final _extras = TextEditingController();
  final _nuevaHabilidad = TextEditingController();
  final _notasIa = TextEditingController();

  String? _modalidad;
  String? _contrato;
  String? _nivel;
  final _habilidades = <String>[];
  bool _confidencial = false;

  late int _paso = widget.pasoInicial;
  bool _generandoIa = false;
  bool _publicando = false;
  String? _errorIa;
  String? _errorPublicar;

  static const _pasos = [
    MpStep('Información', icon: CupertinoIcons.briefcase),
    MpStep('Descripción', icon: CupertinoIcons.doc_text),
    MpStep('Requisitos', icon: CupertinoIcons.checkmark_seal),
    MpStep('Publicar', icon: CupertinoIcons.paperplane),
  ];

  @override
  void dispose() {
    _titulo.dispose();
    _ubicacion.dispose();
    _salario.dispose();
    _descripcion.dispose();
    _horario.dispose();
    _extras.dispose();
    _nuevaHabilidad.dispose();
    _notasIa.dispose();
    super.dispose();
  }

  bool get _tituloListo => _titulo.text.trim().isNotEmpty;

  bool get _puedeAvanzar => _paso == 0 ? _tituloListo : true;

  void _avanzar() {
    if (!_puedeAvanzar) return;
    if (_paso < _pasos.length - 1) {
      FocusScope.of(context).unfocus();
      setState(() => _paso++);
    }
  }

  void _retroceder() {
    if (_paso == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _paso--);
  }

  void _agregarHabilidad([String? valor]) {
    final texto = (valor ?? _nuevaHabilidad.text).replaceAll('#', '').trim();
    if (texto.isEmpty) return;
    if (_habilidades.any((h) => h.toLowerCase() == texto.toLowerCase())) {
      _nuevaHabilidad.clear();
      return;
    }
    setState(() {
      _habilidades.add(texto);
      _nuevaHabilidad.clear();
    });
  }

  // ── IA ──────────────────────────────────────────────────────────────────────

  /// Redacción real: Edge Function `generate-job-posting` (Gemini). Si falla, se
  /// dice que falló — no se rellena con texto de muestra.
  Future<void> _generarConIa() async {
    if (!_tituloListo || _generandoIa) return;
    setState(() {
      _generandoIa = true;
      _errorIa = null;
    });

    final res = await AIMatchService.instance.generateJobPosting(
      _titulo.text.trim(),
      notes: _notasIa.text.trim().isEmpty ? null : _notasIa.text.trim(),
    );

    if (!mounted) return;
    if (res == null) {
      setState(() {
        _generandoIa = false;
        _errorIa = 'No pudimos generar la descripción. Probá de nuevo en un '
            'momento o escribila vos.';
      });
      return;
    }

    final desc = (res['description'] ?? '').toString().trim();
    final reqs = (res['requirements'] as List?)
            ?.map((e) => '• $e')
            .join('\n') ??
        '';
    final salario = (res['salary_range'] ?? '').toString().trim();
    final tags = (res['tags'] as List?) ?? const [];

    setState(() {
      _generandoIa = false;
      if (desc.isNotEmpty || reqs.isNotEmpty) {
        _descripcion.text = [
          if (desc.isNotEmpty) desc,
          if (reqs.isNotEmpty) 'Requisitos:\n$reqs',
        ].join('\n\n');
      }
      if (salario.isNotEmpty && _salario.text.trim().isEmpty) {
        _salario.text = salario;
      }
      for (final t in tags) {
        final valor = t.toString().replaceAll('#', '').trim();
        if (valor.isEmpty) continue;
        if (_habilidades.any((h) => h.toLowerCase() == valor.toLowerCase())) {
          continue;
        }
        _habilidades.add(valor);
      }
    });
  }

  // ── Publicar ────────────────────────────────────────────────────────────────

  List<String> get _tags => [
        ..._habilidades,
        if (_modalidad != null) _modalidad!,
      ];

  Future<void> _publicar() async {
    if (!_tituloListo || _publicando) return;
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;

    setState(() {
      _publicando = true;
      _errorPublicar = null;
    });

    try {
      double? lat, lng;
      try {
        if (await Geolocator.isLocationServiceEnabled()) {
          final permiso = await Geolocator.checkPermission();
          if (permiso == LocationPermission.whileInUse ||
              permiso == LocationPermission.always) {
            final pos = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.medium),
            );
            lat = pos.latitude;
            lng = pos.longitude;
          }
        }
      } catch (_) {
        // Sin GPS la vacante se publica igual, sólo que sin punto en el mapa.
      }

      String? nn(String s) => s.trim().isEmpty ? null : s.trim();

      final jobId = await client.rpc('create_job_with_postgis', params: {
        'p_title': _titulo.text.trim(),
        'p_salary': _salario.text.trim(),
        'p_tags': _tags,
        'p_is_stealth': _confidencial,
        'p_lat': lat,
        'p_lng': lng,
        'p_description': nn(_descripcion.text),
        'p_employment_type': _contrato,
        'p_schedule': nn(_horario.text),
        'p_experience_level': _nivel,
        'p_extras': nn(_extras.text),
      });

      // `create_job_with_postgis` no recibe ni la ubicación escrita ni la
      // modalidad, así que se completan después. Best-effort: si falla, la
      // vacante ya existe.
      //
      // `is_remote` se escribe SÓLO si el usuario eligió modalidad. Sin
      // elección no se toca: la columna queda en su valor por defecto y la
      // vacante simplemente no declara modalidad, que es la verdad.
      final ubicacion = nn(_ubicacion.text);
      final cambios = <String, dynamic>{
        if (ubicacion != null) 'location': ubicacion,
        if (_modalidad != null) 'is_remote': _modalidad == 'Remoto',
      };
      if (jobId is String && cambios.isNotEmpty) {
        try {
          await client.from('jobs').update(cambios).eq('id', jobId);
        } catch (_) {}
      }

      // Vectorizar para el matching (best-effort, igual que en el alta previa).
      if (jobId is String) {
        AIMatchService.instance.generateJobEmbedding(jobId);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _publicando = false;
        _errorPublicar = 'No pudimos publicar la vacante. Revisá tu conexión '
            'y volvé a intentar.';
      });
    }
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
                  title: 'Publicar vacante',
                  subtitle: 'Publicá una posición y recibí candidatos.',
                  onBack: _retroceder,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MpTokens.space8,
                  MpTokens.space16,
                  MpTokens.space8,
                  MpTokens.space8,
                ),
                child: MpStepper(
                  steps: _pasos,
                  currentIndex: _paso,
                  // Sólo se puede volver a un paso ya visitado: saltar adelante
                  // sin título dejaría el asistente en un estado imposible.
                  onStepTap: (i) {
                    if (i <= _paso || _tituloListo) {
                      FocusScope.of(context).unfocus();
                      setState(() => _paso = i);
                    }
                  },
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        MpTokens.screenPadding,
                        MpTokens.space12,
                        MpTokens.screenPadding,
                        MpTokens.space24 +
                            MediaQuery.of(context).viewInsets.bottom,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(_pasoActual()),
                      ),
                    ),
                  ],
                ),
              ),
              _barraAcciones(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _pasoActual() => switch (_paso) {
        0 => _pasoInformacion(),
        1 => _pasoDescripcion(),
        2 => _pasoRequisitos(),
        _ => _pasoPublicar(),
      };

  // ── Paso 1 · Información ───────────────────────────────────────────────────

  List<Widget> _pasoInformacion() {
    final s = context.mp;

    return [
      Text('Información básica', style: MpTokens.h2.copyWith(color: s.text)),
      const SizedBox(height: MpTokens.space16),
      const MpFieldLabel('Título del puesto'),
      MpTextField(
        controller: _titulo,
        placeholder: 'Ej: Product Manager Senior',
        counter: '${_titulo.text.characters.length}/80',
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: MpTokens.space16),
      const MpFieldLabel('Ubicación'),
      MpTextField(
        controller: _ubicacion,
        placeholder: 'Ej: Buenos Aires, Argentina',
        icon: CupertinoIcons.placemark,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: MpTokens.space16),
      const MpFieldLabel('Modalidad'),
      _pildoras(_modalidades, _modalidad, (v) => setState(() => _modalidad = v)),
      const SizedBox(height: MpTokens.space20),
      const MpFieldLabel('Tipo de contrato'),
      _tarjetasContrato(),
      const SizedBox(height: MpTokens.space20),
      const MpFieldLabel('Nivel de experiencia'),
      _pildoras(_niveles, _nivel, (v) => setState(() => _nivel = v)),
      const SizedBox(height: MpTokens.space20),
      const MpFieldLabel('Salario', helper: 'Opcional'),
      MpTextField(
        controller: _salario,
        placeholder: 'Ej: USD 3.000 – 4.500 / mes',
        icon: CupertinoIcons.money_dollar_circle,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: MpTokens.space16),
      const MpFieldLabel('Horario', helper: 'Opcional'),
      MpTextField(
        controller: _horario,
        placeholder: 'Ej: Lun a Vie, 9 a 18',
        icon: CupertinoIcons.time,
      ),
    ];
  }

  Widget _pildoras(
    List<String> opciones,
    String? valor,
    ValueChanged<String> onPick,
  ) {
    final s = context.mp;

    return Wrap(
      spacing: MpTokens.space8,
      runSpacing: MpTokens.space8,
      children: [
        for (final o in opciones)
          GestureDetector(
            onTap: () => onPick(o),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: MpTokens.space16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: o == valor ? s.tint(s.accent, alpha: 0.10) : s.card,
                borderRadius: BorderRadius.circular(MpTokens.radiusMD),
                border: Border.all(
                  color: o == valor ? s.accent : s.borderStrong,
                  width: o == valor ? 1.5 : 1,
                ),
              ),
              child: Text(
                o,
                style: MpTokens.label.copyWith(
                  color: o == valor ? s.accent : s.textSecondary,
                  fontWeight: o == valor ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// El mockup pone las cuatro opciones en una sola fila, pero ahí la maqueta
  /// es más ancha: a 393pt reales "Tiempo completo" se parte en tres líneas.
  /// Se conserva la tarjeta de opción del sistema y se acomoda en 2×2, que es
  /// lo que deja el texto legible en todos los tamaños de la tanda.
  Widget _tarjetasContrato() {
    const iconos = [
      CupertinoIcons.briefcase,
      CupertinoIcons.clock,
      CupertinoIcons.doc_plaintext,
      CupertinoIcons.book,
    ];

    Widget fila(int desde) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = desde; i < desde + 2; i++) ...[
            if (i > desde) const SizedBox(width: MpTokens.space8),
            Expanded(
              child: MpOptionCard(
                icon: iconos[i],
                label: _contratos[i],
                selected: _contrato == _contratos[i],
                onTap: () => setState(() => _contrato = _contratos[i]),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        IntrinsicHeight(child: fila(0)),
        const SizedBox(height: MpTokens.space8),
        IntrinsicHeight(child: fila(2)),
      ],
    );
  }

  // ── Paso 2 · Descripción ───────────────────────────────────────────────────

  List<Widget> _pasoDescripcion() {
    final s = context.mp;

    return [
      Text(
        'Descripción de la vacante',
        style: MpTokens.h2.copyWith(color: s.text),
      ),
      const SizedBox(height: MpTokens.space4),
      Text(
        'Es lo que va a leer el candidato, y también lo que usa el match para '
        'encontrar perfiles parecidos.',
        style: MpTokens.body.copyWith(color: s.textSecondary, fontSize: 14),
      ),
      const SizedBox(height: MpTokens.space16),
      _asistenteIa(),
      const SizedBox(height: MpTokens.space20),
      const MpFieldLabel('Descripción del puesto'),
      MpTextField(
        controller: _descripcion,
        placeholder: 'Qué va a hacer la persona, con qué equipo, qué se espera…',
        maxLines: 8,
        counter: '${_descripcion.text.characters.length}/2000',
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: MpTokens.space16),
      const MpFieldLabel(
        'Beneficios y extras',
        helper: 'Opcional. Prepaga, home office, capacitación…',
      ),
      MpTextField(
        controller: _extras,
        placeholder: 'Ej: Prepaga familiar, 15 días libres extra',
        maxLines: 3,
      ),
    ];
  }

  Widget _asistenteIa() {
    final s = context.mp;

    return MpAiCard(
      title: 'Asistente IA',
      tag: 'BETA',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tituloListo
                ? 'Contanos qué necesitás y la IA redacta la descripción a '
                    'partir del título "${_titulo.text.trim()}". Después la '
                    'podés editar.'
                : 'Volvé al paso 1 y cargá el título del puesto: la IA lo '
                    'necesita para redactar.',
            style: MpTokens.body.copyWith(color: s.textSecondary, fontSize: 13.5),
          ),
          const SizedBox(height: MpTokens.space12),
          MpTextField(
            controller: _notasIa,
            placeholder: 'Ej: para liderar el desarrollo de nuestra app mobile',
            maxLines: 2,
            enabled: _tituloListo,
          ),
          if (_errorIa != null) ...[
            const SizedBox(height: MpTokens.space8),
            Text(
              _errorIa!,
              style: MpTokens.caption.copyWith(color: MpTokens.danger),
            ),
          ],
          const SizedBox(height: MpTokens.space12),
          MpButton(
            label: _generandoIa ? 'Generando…' : 'Generar descripción con IA',
            icon: CupertinoIcons.sparkles,
            variant: MpButtonVariant.outline,
            expand: true,
            loading: _generandoIa,
            onPressed: _tituloListo ? _generarConIa : null,
          ),
        ],
      ),
    );
  }

  // ── Paso 3 · Requisitos ────────────────────────────────────────────────────

  List<Widget> _pasoRequisitos() {
    final s = context.mp;

    return [
      Text('Requisitos', style: MpTokens.h2.copyWith(color: s.text)),
      const SizedBox(height: MpTokens.space4),
      Text(
        'Las habilidades que cargues son con las que el match compara los '
        'perfiles. Sin habilidades, el match usa sólo el texto.',
        style: MpTokens.body.copyWith(color: s.textSecondary, fontSize: 14),
      ),
      const SizedBox(height: MpTokens.space20),
      const MpFieldLabel('Habilidades principales'),
      MpTextField(
        controller: _nuevaHabilidad,
        placeholder: 'Escribí una habilidad y agregala',
        icon: CupertinoIcons.tag,
        trailingIcon: CupertinoIcons.add_circled_solid,
        onTrailingTap: _agregarHabilidad,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: MpTokens.space12),
      if (_habilidades.isEmpty)
        Text(
          'Todavía no agregaste habilidades.',
          style: MpTokens.caption.copyWith(color: s.textTertiary),
        )
      else
        Wrap(
          spacing: MpTokens.space8,
          runSpacing: MpTokens.space8,
          children: [
            for (final h in _habilidades)
              MpTagChip(
                label: h,
                onRemove: () => setState(() => _habilidades.remove(h)),
              ),
          ],
        ),
      const SizedBox(height: MpTokens.space24),
      MpCard(
        child: Row(
          children: [
            const MpIconTile(
              icon: CupertinoIcons.lock_fill,
              color: MpTokens.catIndigo,
              size: 42,
            ),
            const SizedBox(width: MpTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Vacante confidencial',
                    style: MpTokens.title.copyWith(color: s.text, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No se muestra el nombre de tu empresa en el feed.',
                    style: MpTokens.caption.copyWith(color: s.textSecondary),
                  ),
                ],
              ),
            ),
            CupertinoSwitch(
              value: _confidencial,
              activeTrackColor: s.accent,
              onChanged: (v) => setState(() => _confidencial = v),
            ),
          ],
        ),
      ),
    ];
  }

  // ── Paso 4 · Publicar ──────────────────────────────────────────────────────

  List<Widget> _pasoPublicar() {
    final s = context.mp;

    return [
      Text(
        'Vista previa de tu vacante',
        style: MpTokens.h2.copyWith(color: s.text),
      ),
      const SizedBox(height: MpTokens.space4),
      Text(
        'Así la va a ver la comunidad de candidatos.',
        style: MpTokens.body.copyWith(color: s.textSecondary, fontSize: 14),
      ),
      const SizedBox(height: MpTokens.space16),
      _vistaPrevia(),
      const SizedBox(height: MpTokens.space16),
      _canales(),
      if (_errorPublicar != null) ...[
        const SizedBox(height: MpTokens.space16),
        MpBanner(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: 'No se pudo publicar',
          message: _errorPublicar!,
          color: MpTokens.danger,
        ),
      ],
    ];
  }

  Widget _vistaPrevia() {
    final s = context.mp;
    final titulo = _titulo.text.trim();
    final descripcion = _descripcion.text.trim();

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MpIconTile(
                icon: _confidencial
                    ? CupertinoIcons.lock_fill
                    : CupertinoIcons.briefcase_fill,
                color: _confidencial ? MpTokens.catIndigo : MpTokens.primary,
                size: 48,
              ),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo.isEmpty ? 'Título de la vacante' : titulo,
                      style: MpTokens.title.copyWith(
                        color: titulo.isEmpty ? s.textTertiary : s.text,
                      ),
                    ),
                    const SizedBox(height: MpTokens.space4),
                    Text(
                      [
                        if (_ubicacion.text.trim().isNotEmpty)
                          _ubicacion.text.trim(),
                        if (_modalidad != null) _modalidad!,
                        if (_contrato != null) _contrato!,
                        if (_nivel != null) _nivel!,
                      ].join('  ·  '),
                      style: MpTokens.caption.copyWith(color: s.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (descripcion.isNotEmpty) ...[
            const SizedBox(height: MpTokens.space12),
            Text(
              descripcion,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: MpTokens.body.copyWith(
                color: s.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
          if (_habilidades.isNotEmpty) ...[
            const SizedBox(height: MpTokens.space12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final h in _habilidades.take(6)) MpTagChip(label: h),
              ],
            ),
          ],
          if (_salario.text.trim().isNotEmpty) ...[
            const SizedBox(height: MpTokens.space12),
            Text(
              _salario.text.trim(),
              style: MpTokens.title.copyWith(
                color: MpTokens.successDeep,
                fontSize: 15,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _canales() {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dónde se publica',
            style: MpTokens.title.copyWith(color: s.text),
          ),
          const SizedBox(height: MpTokens.space12),
          Row(
            children: [
              const MpIconTile(
                icon: CupertinoIcons.checkmark_seal_fill,
                color: MpTokens.primary,
                size: 38,
              ),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mploya',
                      style: MpTokens.label.copyWith(color: s.text),
                    ),
                    Text(
                      _confidencial
                          ? 'Feed y buscador, sin el nombre de tu empresa.'
                          : 'Feed de candidatos, buscador y mapa.',
                      style: MpTokens.micro.copyWith(color: s.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MpTokens.space16),
          Container(height: 1, color: s.border),
          const SizedBox(height: MpTokens.space12),
          Text(
            'Publicación en canales externos',
            style: MpTokens.micro.copyWith(color: s.textTertiary),
          ),
          const SizedBox(height: MpTokens.space8),
          Wrap(
            spacing: MpTokens.space8,
            runSpacing: MpTokens.space8,
            children: [
              for (final canal in ['WhatsApp', 'LinkedIn', 'Instagram'])
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: s.fill,
                    borderRadius: BorderRadius.circular(MpTokens.radiusXS),
                  ),
                  child: Text(
                    '$canal · Próximamente',
                    style: MpTokens.micro.copyWith(
                      color: s.textTertiary,
                      fontSize: 10.5,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Barra de acciones ──────────────────────────────────────────────────────

  Widget _barraAcciones() {
    final s = context.mp;
    final ultimo = _paso == _pasos.length - 1;

    return Container(
      padding: EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        MpTokens.space12,
        MpTokens.screenPadding,
        MediaQuery.of(context).padding.bottom + MpTokens.space12,
      ),
      decoration: BoxDecoration(
        color: s.card,
        border: Border(top: BorderSide(color: s.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: MpButton(
              label: _paso == 0 ? 'Cancelar' : 'Volver',
              variant: MpButtonVariant.neutral,
              expand: true,
              onPressed: _retroceder,
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          Expanded(
            flex: 2,
            child: ultimo
                ? MpButton(
                    label: 'Publicar vacante',
                    icon: CupertinoIcons.paperplane_fill,
                    expand: true,
                    loading: _publicando,
                    onPressed: _tituloListo ? _publicar : null,
                  )
                : MpButton(
                    label: 'Continuar',
                    trailingArrow: true,
                    expand: true,
                    onPressed: _puedeAvanzar ? _avanzar : null,
                  ),
          ),
        ],
      ),
    );
  }
}
