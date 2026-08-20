import 'package:flutter/cupertino.dart';

import '../../services/headhunter_clients_service.dart';
import '../../widgets/ds/mploya_ds.dart';

/// Alta de cliente de Headhunter — wizard de 4 pasos.
///
/// RECONSTRUCCIÓN DIRECTA de los 4 PNG canónicos de
/// `design-reference/FINAL_SCREENS_CODEX/.../FINAL_SCREENS`:
///   · `head hunter agregar nuevo cliente.png` (06_Headhunter_Agregar_Cliente)
///     → paso 1, Información básica.
///   · `agregar nuevo cliente headhunter.png` (07_Headhunter_Contacto_
///     Principal_Cliente) → paso 2, Contacto principal.
///   · `08_Headhunter_Preferencias_Trabajo_Cliente.png` → paso 3.
///   · `09_Headhunter_Resumen_Cliente.png` → paso 4, revisión y guardado.
///
/// Mismo patrón de wizard que `empresa_publicar_vacante_screen.dart`
/// (`MpStepper`, `MpHeader` con `onBack`, barra inferior Anterior/Continuar).
///
/// Los cuatro campos que el mockup muestra como `<select>` con una sola
/// opción visible en la captura (nivel de decisión, cómo se conocieron,
/// frecuencia de búsquedas, frecuencia de contacto) usan acá una lista de
/// opciones razonable a partir de ese único ejemplo — la tabla
/// (`headhunter_clients`, migración 041) los guarda como texto libre, sin
/// CHECK, así que ampliar esta lista más adelante no pide otra migración.
///
/// SIN mockup canónico propio: también sirve para EDITAR (pasando
/// [existingClient]) — reutiliza el mismo wizard precargado, y el paso 4
/// suma un selector de "Estado del cliente" (activo/en pausa/finalizado,
/// migración 041) que el wizard de alta no tenía porque un cliente nuevo
/// siempre arranca activo.
class HeadhunterClientFormScreen extends StatefulWidget {
  const HeadhunterClientFormScreen({super.key, this.existingClient});

  /// Fila completa de `getHeadhunterClient`/`listHeadhunterClients` — si se
  /// pasa, la pantalla precarga todos los campos y guarda con
  /// `updateHeadhunterClient` en vez de crear un cliente nuevo.
  final Map<String, dynamic>? existingClient;

  bool get _isEdit => existingClient != null;

  @override
  State<HeadhunterClientFormScreen> createState() =>
      _HeadhunterClientFormScreenState();
}

const _kIndustrias = [
  'Tecnología', 'Software', 'Finanzas', 'Salud', 'Logística', 'Retail',
  'Educación', 'Manufactura', 'Otro',
];
const _kTamanios = [
  '1-50 empleados', '50-200 empleados', '200-500 empleados',
  '500-1000 empleados', '1000+ empleados',
];
const _kPaises = [
  'Paraguay', 'Argentina', 'Brasil', 'Colombia', 'Chile', 'Uruguay', 'Otro',
];
const _kNivelesDecision = [
  'Tomador de decisión', 'Influenciador', 'Recursos Humanos', 'Otro',
];
const _kComoConocimos = [
  'Recomendación de cliente actual', 'Contacto directo',
  'Evento / Networking', 'LinkedIn', 'Otro',
];
const _kFrecuenciaBusquedas = [
  'Alta (1 o más por mes)', 'Media (cada 2-3 meses)', 'Baja (ocasional)',
];
const _kFrecuenciaContacto = ['Semanal', 'Quincenal', 'Mensual', 'Según necesidad'];

class _HeadhunterClientFormScreenState
    extends State<HeadhunterClientFormScreen> {
  // Paso 1
  final _companyName = TextEditingController();
  final _website = TextEditingController();
  final _city = TextEditingController();
  final _description = TextEditingController();
  String? _industry;
  String? _companySize;
  String? _country;
  String _relationshipType = 'cliente_activo';

  // Paso 2
  final _contactFirstName = TextEditingController();
  final _contactLastName = TextEditingController();
  final _contactRole = TextEditingController();
  final _contactEmail = TextEditingController();
  final _contactPhone = TextEditingController();
  final _relationshipNotes = TextEditingController();
  String _contactChannel = 'email';
  String? _decisionLevel;
  String? _howWeMet;

  // Paso 3
  final _importantNotes = TextEditingController();
  String? _workMode;
  String? _searchFrequency;
  String? _responseTime;
  String _confidentialityLevel = 'alto';
  String? _updateChannel;
  String? _contactFrequency;

  String _status = 'active';

  int _paso = 0;
  bool _guardando = false;
  String? _error;

  static const _pasos = [
    MpStep('Información\nbásica', icon: CupertinoIcons.building_2_fill),
    MpStep('Contacto\nprincipal', icon: CupertinoIcons.person_fill),
    MpStep('Preferencias\nde trabajo', icon: CupertinoIcons.slider_horizontal_3),
    MpStep('Resumen', icon: CupertinoIcons.doc_text_fill),
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.existingClient;
    if (c == null) return;

    _companyName.text = (c['company_name'] as String?) ?? '';
    _website.text = (c['website'] as String?) ?? '';
    _city.text = (c['city'] as String?) ?? '';
    _description.text = (c['description'] as String?) ?? '';
    _industry = c['industry'] as String?;
    _companySize = c['company_size'] as String?;
    _country = c['country'] as String?;
    _relationshipType = (c['relationship_type'] as String?) ?? 'cliente_activo';

    _contactFirstName.text = (c['contact_first_name'] as String?) ?? '';
    _contactLastName.text = (c['contact_last_name'] as String?) ?? '';
    _contactRole.text = (c['contact_role'] as String?) ?? '';
    _contactEmail.text = (c['contact_email'] as String?) ?? '';
    _contactPhone.text = (c['contact_phone'] as String?) ?? '';
    _relationshipNotes.text = (c['relationship_notes'] as String?) ?? '';
    _contactChannel = (c['contact_channel'] as String?) ?? 'email';
    _decisionLevel = c['decision_level'] as String?;
    _howWeMet = c['how_we_met'] as String?;

    _importantNotes.text = (c['important_notes'] as String?) ?? '';
    _workMode = c['work_mode'] as String?;
    _searchFrequency = c['search_frequency'] as String?;
    _responseTime = c['response_time'] as String?;
    _confidentialityLevel = (c['confidentiality_level'] as String?) ?? 'alto';
    _updateChannel = c['update_channel'] as String?;
    _contactFrequency = c['contact_frequency'] as String?;

    _status = (c['status'] as String?) ?? 'active';
  }

  @override
  void dispose() {
    _companyName.dispose();
    _website.dispose();
    _city.dispose();
    _description.dispose();
    _contactFirstName.dispose();
    _contactLastName.dispose();
    _contactRole.dispose();
    _contactEmail.dispose();
    _contactPhone.dispose();
    _relationshipNotes.dispose();
    _importantNotes.dispose();
    super.dispose();
  }

  bool get _paso1Listo =>
      _companyName.text.trim().isNotEmpty &&
      _industry != null &&
      _country != null &&
      _city.text.trim().isNotEmpty;

  bool get _paso2Listo =>
      _contactFirstName.text.trim().isNotEmpty &&
      _contactLastName.text.trim().isNotEmpty &&
      _contactRole.text.trim().isNotEmpty &&
      _contactEmail.text.trim().isNotEmpty &&
      _contactPhone.text.trim().isNotEmpty;

  bool get _puedeAvanzar => switch (_paso) {
        0 => _paso1Listo,
        1 => _paso2Listo,
        _ => true,
      };

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

  String? _nn(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _guardar() async {
    if (!_paso1Listo || !_paso2Listo || _guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });

    final fields = {
      'company_name': _companyName.text.trim(),
      'industry': _industry,
      'company_size': _companySize,
      'website': _nn(_website.text),
      'country': _country,
      'city': _city.text.trim(),
      'description': _nn(_description.text),
      'relationship_type': _relationshipType,
      'contact_first_name': _contactFirstName.text.trim(),
      'contact_last_name': _contactLastName.text.trim(),
      'contact_role': _contactRole.text.trim(),
      'contact_email': _contactEmail.text.trim(),
      'contact_phone': _contactPhone.text.trim(),
      'contact_channel': _contactChannel,
      'decision_level': _decisionLevel,
      'how_we_met': _howWeMet,
      'relationship_notes': _nn(_relationshipNotes.text),
      'work_mode': _workMode,
      'search_frequency': _searchFrequency,
      'response_time': _responseTime,
      'confidentiality_level': _confidentialityLevel,
      'update_channel': _updateChannel,
      'contact_frequency': _contactFrequency,
      'important_notes': _nn(_importantNotes.text),
      if (widget._isEdit) 'status': _status,
    };

    try {
      if (widget._isEdit) {
        await updateHeadhunterClient(widget.existingClient!['id'].toString(), fields);
      } else {
        await createHeadhunterClient(fields);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'No pudimos guardar el cliente. Revisá tu conexión y volvé '
            'a intentar.';
      });
    }
  }

  Future<void> _elegir(
    String titulo,
    List<String> opciones,
    ValueChanged<String> onPick,
  ) async {
    FocusScope.of(context).unfocus();
    final resultado = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(titulo),
        actions: [
          for (final o in opciones)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, o),
              child: Text(o),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (resultado != null) onPick(resultado);
  }

  // ── Build ───────────────────────────────────────────────────────────────

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
                  title: widget._isEdit ? 'Editar cliente' : 'Agregar nuevo cliente',
                  subtitle: _subtitulo,
                  onBack: _retroceder,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MpTokens.space4,
                  MpTokens.space16,
                  MpTokens.space4,
                  MpTokens.space8,
                ),
                child: MpStepper(
                  steps: _pasos,
                  currentIndex: _paso,
                  onStepTap: (i) {
                    if (i <= _paso ||
                        (i == 1 && _paso1Listo) ||
                        (i >= 2 && _paso1Listo && _paso2Listo)) {
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

  String get _subtitulo => switch (_paso) {
        0 => widget._isEdit
            ? 'Actualizá los datos de la empresa.'
            : 'Registrá una empresa para la que vas a reclutar talento.',
        1 => 'Completá la información del contacto principal en la empresa.',
        2 => 'Definí las preferencias generales de trabajo y colaboración.',
        _ => widget._isEdit
            ? 'Revisá los cambios antes de guardar.'
            : 'Revisá la información antes de guardar el cliente.',
      };

  List<Widget> _pasoActual() => switch (_paso) {
        0 => _pasoInformacion(),
        1 => _pasoContacto(),
        2 => _pasoPreferencias(),
        _ => _pasoResumen(),
      };

  // ── Paso 1 · Información básica ────────────────────────────────────────

  List<Widget> _pasoInformacion() {
    final s = context.mp;

    return [
      MpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Información de la empresa',
                style: MpTokens.title.copyWith(color: s.text)),
            const SizedBox(height: MpTokens.space16),
            const MpFieldLabel('Nombre de la empresa'),
            MpTextField(
              controller: _companyName,
              placeholder: 'Ej: TechPro',
              icon: CupertinoIcons.building_2_fill,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: MpTokens.space16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MpFieldLabel('Industria'),
                      MpSelectField(
                        value: _industry ?? 'Seleccionar industria',
                        isPlaceholder: _industry == null,
                        onTap: () => _elegir(
                          'Industria',
                          _kIndustrias,
                          (v) => setState(() => _industry = v),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MpTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MpFieldLabel('Tamaño de la empresa'),
                      MpSelectField(
                        value: _companySize ?? 'Seleccionar tamaño',
                        isPlaceholder: _companySize == null,
                        onTap: () => _elegir(
                          'Tamaño de la empresa',
                          _kTamanios,
                          (v) => setState(() => _companySize = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MpTokens.space16),
            const MpFieldLabel('Sitio web', helper: 'Opcional'),
            MpTextField(
              controller: _website,
              placeholder: 'www.ejemplo.com',
              icon: CupertinoIcons.globe,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: MpTokens.space16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MpFieldLabel('País'),
                      MpSelectField(
                        value: _country ?? 'Seleccionar país',
                        isPlaceholder: _country == null,
                        onTap: () => _elegir(
                          'País',
                          _kPaises,
                          (v) => setState(() => _country = v),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MpTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MpFieldLabel('Ciudad'),
                      MpTextField(
                        controller: _city,
                        placeholder: 'Ej: Asunción',
                        icon: CupertinoIcons.location_solid,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MpTokens.space16),
            const MpFieldLabel('Descripción de la empresa', helper: 'Opcional'),
            MpTextField(
              controller: _description,
              placeholder: 'Contá brevemente a qué se dedica la empresa, su '
                  'cultura y lo que la hace especial.',
              maxLines: 3,
              counter: '${_description.text.characters.length}/300',
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      const SizedBox(height: MpTokens.space16),
      MpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tipo de relación', style: MpTokens.title.copyWith(color: s.text)),
            const SizedBox(height: MpTokens.space12),
            MpOptionCard(
              icon: CupertinoIcons.hand_thumbsup_fill,
              label: 'Cliente activo',
              subtitle: 'Ya tengo búsquedas abiertas o próximas a iniciar.',
              selected: _relationshipType == 'cliente_activo',
              onTap: () => setState(() => _relationshipType = 'cliente_activo'),
            ),
            const SizedBox(height: MpTokens.space8),
            MpOptionCard(
              icon: CupertinoIcons.time,
              label: 'Prospecto',
              subtitle: 'Aún no tiene búsquedas, pero hay interés en trabajar '
                  'juntos.',
              selected: _relationshipType == 'prospecto',
              onTap: () => setState(() => _relationshipType = 'prospecto'),
            ),
            const SizedBox(height: MpTokens.space8),
            MpOptionCard(
              icon: CupertinoIcons.person_2_fill,
              label: 'Red / Referido',
              subtitle: 'Contacto estratégico para futuras oportunidades.',
              selected: _relationshipType == 'red_referido',
              onTap: () => setState(() => _relationshipType = 'red_referido'),
            ),
          ],
        ),
      ),
      const SizedBox(height: MpTokens.space16),
      MpBanner(
        icon: CupertinoIcons.shield_fill,
        title: 'Confidencialidad garantizada',
        message: 'Toda la información de tus clientes está protegida y solo '
            'la podés compartir según tus acuerdos.',
      ),
      if (_error != null) ...[
        const SizedBox(height: MpTokens.space16),
        MpBanner(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: 'No se pudo guardar',
          message: _error!,
          color: MpTokens.danger,
        ),
      ],
    ];
  }

  // ── Paso 2 · Contacto principal ────────────────────────────────────────

  List<Widget> _pasoContacto() {
    final s = context.mp;

    return [
      MpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Información del contacto principal',
                style: MpTokens.title.copyWith(color: s.text)),
            const SizedBox(height: MpTokens.space16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MpFieldLabel('Nombre completo'),
                      MpTextField(
                        controller: _contactFirstName,
                        placeholder: 'Ej: María Fernanda',
                        icon: CupertinoIcons.person,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MpTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MpFieldLabel('Apellido'),
                      MpTextField(
                        controller: _contactLastName,
                        placeholder: 'Ej: Rodríguez',
                        icon: CupertinoIcons.person,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MpTokens.space16),
            const MpFieldLabel('Cargo / Puesto'),
            MpTextField(
              controller: _contactRole,
              placeholder: 'Ej: Gerente de Talento Humano',
              icon: CupertinoIcons.briefcase,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: MpTokens.space16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MpFieldLabel('Email laboral'),
                      MpTextField(
                        controller: _contactEmail,
                        placeholder: 'nombre@empresa.com',
                        icon: CupertinoIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MpTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MpFieldLabel('Teléfono / WhatsApp'),
                      MpTextField(
                        controller: _contactPhone,
                        placeholder: '+595 981 123 456',
                        icon: CupertinoIcons.phone,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MpTokens.space16),
            const MpFieldLabel('Canal de comunicación preferido'),
            _pildoras(
              const {'email': 'Email', 'whatsapp': 'WhatsApp', 'llamada': 'Llamada'},
              _contactChannel,
              (v) => setState(() => _contactChannel = v),
            ),
            const SizedBox(height: MpTokens.space16),
            const MpFieldLabel('Nivel de decisión'),
            MpSelectField(
              value: _decisionLevel ?? 'Seleccionar nivel',
              isPlaceholder: _decisionLevel == null,
              icon: CupertinoIcons.rosette,
              onTap: () => _elegir(
                'Nivel de decisión',
                _kNivelesDecision,
                (v) => setState(() => _decisionLevel = v),
              ),
            ),
            const SizedBox(height: MpTokens.space16),
            const MpFieldLabel('¿Cómo nos conocimos?', helper: 'Opcional'),
            MpSelectField(
              value: _howWeMet ?? 'Seleccionar',
              isPlaceholder: _howWeMet == null,
              icon: CupertinoIcons.person_2,
              onTap: () => _elegir(
                '¿Cómo nos conocimos?',
                _kComoConocimos,
                (v) => setState(() => _howWeMet = v),
              ),
            ),
            const SizedBox(height: MpTokens.space16),
            const MpFieldLabel('Notas sobre la relación', helper: 'Opcional'),
            MpTextField(
              controller: _relationshipNotes,
              placeholder: 'Ej: Trabajamos juntos en el reclutamiento del '
                  'equipo de desarrollo en 2024.',
              maxLines: 3,
              counter: '${_relationshipNotes.text.characters.length}/300',
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      const SizedBox(height: MpTokens.space16),
      MpBanner(
        icon: CupertinoIcons.lightbulb_fill,
        title: 'Tip Mploya',
        message: 'Un buen contacto principal acelera los procesos y mejora '
            'la calidad de las búsquedas.',
      ),
      if (_error != null) ...[
        const SizedBox(height: MpTokens.space16),
        MpBanner(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: 'No se pudo guardar',
          message: _error!,
          color: MpTokens.danger,
        ),
      ],
    ];
  }

  // ── Paso 3 · Preferencias de trabajo ───────────────────────────────────

  List<Widget> _pasoPreferencias() {
    final s = context.mp;

    const modalidades = {
      'colaboracion_continua': (
        'Colaboración continua',
        'Relación a largo plazo y búsquedas recurrentes.',
        CupertinoIcons.person_2_fill,
      ),
      'busquedas_puntuales': (
        'Búsquedas puntuales',
        'Colaboración por proyecto o búsqueda.',
        CupertinoIcons.calendar,
      ),
      'mandato_exclusivo': (
        'Por mandato exclusivo',
        'Mandatos confidenciales y exclusivos.',
        CupertinoIcons.hand_raised_fill,
      ),
      'tiempo_determinado': (
        'Por tiempo determinado',
        'Colaboración por un período específico.',
        CupertinoIcons.time,
      ),
    };

    return [
      MpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Preferencias de colaboración',
                style: MpTokens.title.copyWith(color: s.text)),
            const SizedBox(height: MpTokens.space16),
            const MpFieldLabel('Modalidad de trabajo preferida'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in modalidades.entries.take(2)) ...[
                  if (entry.key != modalidades.keys.first)
                    const SizedBox(width: MpTokens.space8),
                  Expanded(
                    child: MpOptionCard(
                      icon: entry.value.$3,
                      label: entry.value.$1,
                      subtitle: entry.value.$2,
                      selected: _workMode == entry.key,
                      onTap: () => setState(() => _workMode = entry.key),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: MpTokens.space8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in modalidades.entries.skip(2)) ...[
                  if (entry.key != modalidades.keys.elementAt(2))
                    const SizedBox(width: MpTokens.space8),
                  Expanded(
                    child: MpOptionCard(
                      icon: entry.value.$3,
                      label: entry.value.$1,
                      subtitle: entry.value.$2,
                      selected: _workMode == entry.key,
                      onTap: () => setState(() => _workMode = entry.key),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: MpTokens.space16),
            const MpFieldLabel('Frecuencia estimada de búsquedas'),
            MpSelectField(
              value: _searchFrequency ?? 'Seleccionar frecuencia',
              isPlaceholder: _searchFrequency == null,
              icon: CupertinoIcons.graph_square,
              onTap: () => _elegir(
                'Frecuencia estimada de búsquedas',
                _kFrecuenciaBusquedas,
                (v) => setState(() => _searchFrequency = v),
              ),
            ),
            const SizedBox(height: MpTokens.space16),
            const MpFieldLabel('Tiempo de respuesta esperado'),
            _pildoras(
              const {
                '24_48h': '24-48 hs',
                '2_3_dias': '2-3 días',
                '1_semana': '1 semana',
                'mas_1_semana': 'Más de 1 semana',
              },
              _responseTime,
              (v) => setState(() => _responseTime = v),
            ),
            const SizedBox(height: MpTokens.space16),
            const MpFieldLabel('Confidencialidad',
                helper: 'Nivel de confidencialidad requerido en las búsquedas'),
            _pildoras(
              const {'basico': 'Básico', 'alto': 'Alto', 'muy_alto': 'Muy alto'},
              _confidentialityLevel,
              (v) => setState(() => _confidentialityLevel = v),
            ),
          ],
        ),
      ),
      const SizedBox(height: MpTokens.space16),
      MpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Estilo y comunicación', style: MpTokens.title.copyWith(color: s.text)),
            const SizedBox(height: MpTokens.space16),
            const MpFieldLabel('¿Cómo preferís que lo mantengamos informado?'),
            _pildoras(
              const {
                'email': 'Email',
                'whatsapp': 'WhatsApp',
                'llamada': 'Llamada',
                'reuniones': 'Reuniones',
              },
              _updateChannel,
              (v) => setState(() => _updateChannel = v),
            ),
            const SizedBox(height: MpTokens.space16),
            const MpFieldLabel('¿Con qué frecuencia?'),
            MpSelectField(
              value: _contactFrequency ?? 'Seleccionar frecuencia',
              isPlaceholder: _contactFrequency == null,
              icon: CupertinoIcons.bell,
              onTap: () => _elegir(
                '¿Con qué frecuencia?',
                _kFrecuenciaContacto,
                (v) => setState(() => _contactFrequency = v),
              ),
            ),
            const SizedBox(height: MpTokens.space16),
            const MpFieldLabel('¿Hay algo importante que deberíamos saber?',
                helper: 'Opcional'),
            MpTextField(
              controller: _importantNotes,
              placeholder: 'Ej: Prefieren candidatos con inglés avanzado y '
                  'experiencia comprobable en empresas internacionales.',
              maxLines: 3,
              counter: '${_importantNotes.text.characters.length}/300',
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      const SizedBox(height: MpTokens.space16),
      MpBanner(
        icon: CupertinoIcons.lightbulb_fill,
        title: 'Tip Mploya',
        message: 'Cuanta más claridad tengamos sobre sus preferencias, '
            'mejores candidatos y resultados lograremos juntos.',
      ),
    ];
  }

  Widget _pildoras(
    Map<String, String> opciones,
    String? valor,
    ValueChanged<String> onPick,
  ) {
    final s = context.mp;

    return Wrap(
      spacing: MpTokens.space8,
      runSpacing: MpTokens.space8,
      children: [
        for (final entry in opciones.entries)
          GestureDetector(
            onTap: () => onPick(entry.key),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: MpTokens.space16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: entry.key == valor
                    ? s.tint(s.accent, alpha: 0.10)
                    : s.card,
                borderRadius: BorderRadius.circular(MpTokens.radiusMD),
                border: Border.all(
                  color: entry.key == valor ? s.accent : s.borderStrong,
                  width: entry.key == valor ? 1.5 : 1,
                ),
              ),
              child: Text(
                entry.value,
                style: MpTokens.label.copyWith(
                  color: entry.key == valor ? s.accent : s.textSecondary,
                  fontWeight: entry.key == valor ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Paso 4 · Resumen ────────────────────────────────────────────────────

  List<Widget> _pasoResumen() {
    return [
      if (widget._isEdit) ...[
        MpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MpFieldLabel('Estado del cliente'),
              Row(
                children: [
                  for (final entry in const {
                    'active': ('Activo', MpStatus.active),
                    'paused': ('En pausa', MpStatus.paused),
                    'finished': ('Finalizado', MpStatus.finished),
                  }.entries) ...[
                    if (entry.key != 'active') const SizedBox(width: MpTokens.space8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _status = entry.key),
                        behavior: HitTestBehavior.opaque,
                        child: _EstadoPill(
                          label: entry.value.$1,
                          mpStatus: entry.value.$2,
                          selected: _status == entry.key,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: MpTokens.space16),
      ],
      _resumenSeccion(
        icon: CupertinoIcons.building_2_fill,
        title: 'Información de la empresa',
        onEdit: () => setState(() => _paso = 0),
        rows: {
          'Nombre': _companyName.text.trim(),
          'País': _country ?? '—',
          'Industria': _industry ?? '—',
          'Ciudad': _city.text.trim(),
          if (_companySize != null) 'Tamaño de la empresa': _companySize!,
          if (_website.text.trim().isNotEmpty) 'Sitio web': _website.text.trim(),
          if (_description.text.trim().isNotEmpty)
            'Descripción': _description.text.trim(),
        },
      ),
      const SizedBox(height: MpTokens.space16),
      _resumenSeccion(
        icon: CupertinoIcons.person_fill,
        title: 'Contacto principal',
        onEdit: () => setState(() => _paso = 1),
        rows: {
          'Nombre': '${_contactFirstName.text.trim()} ${_contactLastName.text.trim()}',
          'Teléfono / WhatsApp': _contactPhone.text.trim(),
          'Cargo': _contactRole.text.trim(),
          'Canal preferido': _canalLabel(_contactChannel),
          'Email': _contactEmail.text.trim(),
          if (_decisionLevel != null) 'Nivel de decisión': _decisionLevel!,
        },
        note: _relationshipNotes.text.trim().isEmpty
            ? null
            : ('Notas sobre la relación', _relationshipNotes.text.trim()),
      ),
      const SizedBox(height: MpTokens.space16),
      _resumenSeccion(
        icon: CupertinoIcons.slider_horizontal_3,
        title: 'Preferencias de trabajo',
        onEdit: () => setState(() => _paso = 2),
        rows: {
          'Modalidad preferida': _modalidadLabel(_workMode),
          if (_searchFrequency != null) 'Frecuencia de búsquedas': _searchFrequency!,
          'Tiempo de respuesta esperado': _tiempoRespuestaLabel(_responseTime),
          'Confidencialidad requerida': _confidencialidadLabel(_confidentialityLevel),
          'Estilo de comunicación': _canalLabel(_updateChannel),
          if (_contactFrequency != null) 'Frecuencia de contacto': _contactFrequency!,
        },
        note: _importantNotes.text.trim().isEmpty
            ? null
            : ('Importante', _importantNotes.text.trim()),
      ),
      const SizedBox(height: MpTokens.space16),
      MpBanner(
        icon: CupertinoIcons.checkmark_circle_fill,
        title: 'Todo listo para agregar a ${_companyName.text.trim().isEmpty ? 'tu cliente' : _companyName.text.trim()}',
        message: 'Una vez guardado, podrás crear búsquedas y empezar a '
            'encontrar el mejor talento para tu cliente.',
        color: MpTokens.success,
      ),
      if (_error != null) ...[
        const SizedBox(height: MpTokens.space16),
        MpBanner(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: 'No se pudo guardar',
          message: _error!,
          color: MpTokens.danger,
        ),
      ],
    ];
  }

  String _canalLabel(String? key) => switch (key) {
        'email' => 'Email',
        'whatsapp' => 'WhatsApp',
        'llamada' => 'Llamada',
        'reuniones' => 'Reuniones',
        _ => '—',
      };

  String _modalidadLabel(String? key) => switch (key) {
        'colaboracion_continua' => 'Colaboración continua',
        'busquedas_puntuales' => 'Búsquedas puntuales',
        'mandato_exclusivo' => 'Por mandato exclusivo',
        'tiempo_determinado' => 'Por tiempo determinado',
        _ => '—',
      };

  String _tiempoRespuestaLabel(String? key) => switch (key) {
        '24_48h' => '24-48 hs',
        '2_3_dias' => '2-3 días',
        '1_semana' => '1 semana',
        'mas_1_semana' => 'Más de 1 semana',
        _ => '—',
      };

  String _confidencialidadLabel(String key) => switch (key) {
        'basico' => 'Básica',
        'muy_alto' => 'Muy alta',
        _ => 'Alta',
      };

  Widget _resumenSeccion({
    required IconData icon,
    required String title,
    required Map<String, String> rows,
    required VoidCallback onEdit,
    (String, String)? note,
  }) {
    final s = context.mp;
    final entries = rows.entries.toList();

    return MpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MpIconTile(icon: icon, color: MpTokens.catViolet, size: 34),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Text(title, style: MpTokens.title.copyWith(color: s.text)),
              ),
              GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Editar', style: MpTokens.label.copyWith(color: s.accent)),
                    const SizedBox(width: 4),
                    Icon(CupertinoIcons.pencil, size: 13, color: s.accent),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MpTokens.space16),
          for (int i = 0; i < entries.length; i += 2)
            Padding(
              padding: EdgeInsets.only(
                bottom: i + 2 < entries.length ? MpTokens.space16 : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _resumenCampo(entries[i].key, entries[i].value)),
                  const SizedBox(width: MpTokens.space12),
                  Expanded(
                    child: i + 1 < entries.length
                        ? _resumenCampo(entries[i + 1].key, entries[i + 1].value)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          if (note != null) ...[
            const SizedBox(height: MpTokens.space16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(MpTokens.space12),
              decoration: BoxDecoration(
                color: s.tint(s.accent, alpha: 0.06),
                borderRadius: BorderRadius.circular(MpTokens.radiusMD),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note.$1,
                      style: MpTokens.label.copyWith(color: s.text, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(note.$2, style: MpTokens.caption.copyWith(color: s.textSecondary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resumenCampo(String label, String value) {
    final s = context.mp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MpTokens.caption.copyWith(color: s.textTertiary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: MpTokens.bodyStrong.copyWith(color: s.text, fontSize: 14.5),
        ),
      ],
    );
  }

  // ── Barra de acciones ──────────────────────────────────────────────────

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
              label: _paso == 0 ? 'Cancelar' : 'Anterior',
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
                    label: widget._isEdit ? 'Guardar cambios' : 'Guardar cliente',
                    icon: CupertinoIcons.floppy_disk,
                    expand: true,
                    loading: _guardando,
                    onPressed: (_paso1Listo && _paso2Listo) ? _guardar : null,
                  )
                : MpButton(
                    label: 'Siguiente',
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

/// Píldora de estado seleccionable — mismos colores que [MpStatusBadge]
/// (`widgets/ds/mp_chip.dart`), pero tocable y con estado "elegido".
class _EstadoPill extends StatelessWidget {
  const _EstadoPill({required this.label, required this.mpStatus, required this.selected});

  final String label;
  final MpStatus mpStatus;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final color = mpStatus.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? s.tint(color, alpha: 0.14) : s.fill,
        borderRadius: BorderRadius.circular(MpTokens.radiusMD),
        border: Border.all(color: selected ? color : s.borderStrong, width: selected ? 1.5 : 1),
      ),
      child: Text(
        label,
        style: MpTokens.label.copyWith(
          color: selected ? color : s.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}
