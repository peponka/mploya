import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/ai_match_service.dart';
import '../../widgets/ds/mploya_ds.dart';

/// Publicar vacante de Headhunter.
///
/// Migrada al sistema de diseño (18/8/2026), 7ª pantalla — mismo patrón de
/// `headhunter_dashboard_screen.dart`.
///
/// NO es un wizard de varios pasos (a diferencia de lo que sugiere el
/// nombre del mockup "publicar vacante 2/3"): es un único `ListView` con
/// 3 tarjetas (IA / campos / preferencias), igual que
/// `empresa_publicar_vacante_screen.dart` en estructura. Ese sibling SÍ
/// es un wizard de 4 pasos con `MpStepper` — no se copió esa estructura
/// acá porque cambiaría el flujo real (esto sería un cambio funcional,
/// fuera de alcance de un rediseño visual). Patrón:
///
///   · Aviso de éxito/error → [MpBanner] (reemplaza el `Container` tinte
///     a mano). `title` es genérico ("Listo"/"Revisá esto"); el texto
///     real que verifican los tests va en `message`, sin cambios.
///   · Campos               → [MpFieldLabel] + [MpTextField].
///   · Jornada/Experiencia  → SIN cambio de widget: siguen siendo pills en
///     `Wrap` a mano (tokenizadas). No hay equivalente en `ds/` para
///     "elegí una opción entre N" fuera de listas con contador
///     ([MpSegmentedFilter], que no encaja: esto no es un filtro).
///   · CTA inferior          → [MpButton] (`variant: primary, expand: true,
///     loading: _publishing`) — el parámetro `loading` ya resuelve el
///     spinner que antes se armaba a mano.
///
/// El botón "Publicar" de la barra de navegación queda como
/// `CupertinoButton` simple, sin cambios: no tenía ningún color
/// hardcodeado que migrar, y es el patrón nativo correcto para una acción
/// de `trailing` en una `CupertinoNavigationBar`.
typedef HeadhunterPublishOverride =
    Future<String?> Function(Map<String, dynamic> values);

class HeadhunterPublishJobScreen extends StatefulWidget {
  const HeadhunterPublishJobScreen({
    super.key,
    this.publishOverride,
    this.initialValues = const {},
  });

  final HeadhunterPublishOverride? publishOverride;
  final Map<String, dynamic> initialValues;

  @override
  State<HeadhunterPublishJobScreen> createState() =>
      _HeadhunterPublishJobScreenState();
}

class _HeadhunterPublishJobScreenState
    extends State<HeadhunterPublishJobScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _salary;
  late final TextEditingController _schedule;
  late final TextEditingController _extras;
  late final TextEditingController _tags;
  String? _employmentType;
  String? _experienceLevel;
  bool _confidential = false;
  bool _publishing = false;
  bool _generating = false;
  String? _message;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    final values = widget.initialValues;
    _title = TextEditingController(text: values['title']?.toString() ?? '');
    _description = TextEditingController(
      text: values['description']?.toString() ?? '',
    );
    _salary = TextEditingController(
      text: values['salary_range']?.toString() ?? '',
    );
    _schedule = TextEditingController(
      text: values['schedule']?.toString() ?? '',
    );
    _extras = TextEditingController(text: values['extras']?.toString() ?? '');
    _tags = TextEditingController(
      text: (values['required_tags'] as List? ?? const []).join(', '),
    );
    _employmentType = values['employment_type']?.toString();
    _experienceLevel = values['experience_level']?.toString();
    _confidential = values['is_stealth'] == true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _salary.dispose();
    _schedule.dispose();
    _extras.dispose();
    _tags.dispose();
    super.dispose();
  }

  List<String> get _tagList => _tags.text
      .split(',')
      .map((tag) => tag.trim().replaceAll('#', ''))
      .where((tag) => tag.isNotEmpty)
      .toList();

  Map<String, dynamic> get _values => {
    'p_title': _title.text.trim(),
    'p_salary': _salary.text.trim(),
    'p_tags': _tagList,
    'p_is_stealth': _confidential,
    'p_lat': null,
    'p_lng': null,
    'p_description': _nullable(_description.text),
    'p_employment_type': _employmentType,
    'p_schedule': _nullable(_schedule.text),
    'p_experience_level': _experienceLevel,
    'p_extras': _nullable(_extras.text),
  };

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _generate() async {
    final title = _title.text.trim();
    if (title.isEmpty || _generating) {
      setState(() {
        _success = false;
        _message = 'Ingresá primero el título del puesto.';
      });
      return;
    }
    setState(() {
      _generating = true;
      _message = null;
    });
    final result = await AIMatchService.instance.generateJobPosting(title);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _generating = false;
        _success = false;
        _message =
            'No se pudo generar el contenido. Podés completar el formulario manualmente.';
      });
      return;
    }
    final requirements = (result['requirements'] as List? ?? const [])
        .map((item) => '• $item')
        .join('\n');
    setState(() {
      final description = result['description']?.toString().trim() ?? '';
      _description.text = [
        if (description.isNotEmpty) description,
        if (requirements.isNotEmpty) 'Requisitos:\n$requirements',
      ].join('\n\n');
      final salary = result['salary_range']?.toString().trim() ?? '';
      if (salary.isNotEmpty) _salary.text = salary;
      final tags = (result['tags'] as List? ?? const [])
          .map((tag) => tag.toString().replaceAll('#', ''))
          .join(', ');
      if (tags.isNotEmpty) _tags.text = tags;
      _generating = false;
      _success = true;
      _message = 'Contenido generado. Revisalo antes de publicar.';
    });
  }

  Future<void> _publish() async {
    if (_publishing) return;
    if (_title.text.trim().isEmpty) {
      setState(() {
        _success = false;
        _message = 'El título del puesto es obligatorio.';
      });
      return;
    }
    setState(() {
      _publishing = true;
      _message = null;
    });
    try {
      String? jobId;
      if (widget.publishOverride != null) {
        jobId = await widget.publishOverride!(_values);
      } else {
        final client = Supabase.instance.client;
        if (client.auth.currentUser == null) {
          throw StateError('La sesión no está disponible.');
        }
        final result = await client.rpc(
          'create_job_with_postgis',
          params: _values,
        );
        jobId = result?.toString();
      }
      if (jobId == null || jobId.isEmpty) {
        throw StateError('La vacante no devolvió un identificador.');
      }
      if (widget.publishOverride == null) {
        AIMatchService.instance.generateJobEmbedding(jobId);
      }
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _publishing = false;
          _success = true;
          _message = 'Vacante publicada correctamente.';
        });
      }
    } catch (error) {
      debugPrint('Headhunter publish job: $error');
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _success = false;
        _message =
            'No se pudo publicar la vacante. Tus datos siguen en el formulario.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: Builder(
        builder: (context) {
          final s = context.mp;
          return CupertinoPageScaffold(
            backgroundColor: s.bg,
            navigationBar: CupertinoNavigationBar(
              middle: const Text('Publicar vacante'),
              backgroundColor: s.card,
              border: null,
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _publishing ? null : _publish,
                child: _publishing
                    ? const CupertinoActivityIndicator(radius: 8)
                    : const Text('Publicar'),
              ),
            ),
            child: SafeArea(child: _content(context)),
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context) {
    final s = context.mp;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        MpTokens.space20,
        MpTokens.screenPadding,
        MpTokens.space40,
      ),
      children: [
        Text('Creá una vacante', style: MpTokens.h1.copyWith(color: s.text, fontSize: 26)),
        const SizedBox(height: MpTokens.space4),
        Text(
          'La vacante quedará asociada a tu cuenta Headhunter.',
          style: MpTokens.body.copyWith(color: s.textSecondary),
        ),
        if (_message != null) ...[
          const SizedBox(height: MpTokens.space16),
          MpBanner(
            icon: _success ? CupertinoIcons.checkmark_circle : CupertinoIcons.exclamationmark_circle,
            title: _success ? 'Listo' : 'Revisá esto',
            message: _message!,
            color: _success ? MpTokens.success : MpTokens.danger,
          ),
        ],
        const SizedBox(height: MpTokens.space16),
        MpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MpFieldLabel('Título del puesto *'),
              MpTextField(controller: _title, placeholder: 'Ej. Flutter Developer'),
              const SizedBox(height: MpTokens.space12),
              MpButton(
                label: 'Completar con IA',
                icon: CupertinoIcons.sparkles,
                variant: MpButtonVariant.primary,
                expand: true,
                loading: _generating,
                onPressed: _generating ? null : _generate,
              ),
              const SizedBox(height: MpTokens.space8),
              Text(
                'Usa la función existente y deja todo editable antes de guardar.',
                style: MpTokens.micro.copyWith(color: s.textTertiary),
              ),
            ],
          ),
        ),
        const SizedBox(height: MpTokens.space12),
        MpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MpFieldLabel('Descripción'),
              MpTextField(
                controller: _description,
                placeholder: 'Responsabilidades y requisitos reales del puesto',
                maxLines: 5,
              ),
              const SizedBox(height: MpTokens.space12),
              const MpFieldLabel('Rango salarial'),
              MpTextField(controller: _salary, placeholder: 'Opcional'),
              const SizedBox(height: MpTokens.space12),
              const MpFieldLabel('Horario'),
              MpTextField(controller: _schedule, placeholder: 'Opcional'),
              const SizedBox(height: MpTokens.space12),
              const MpFieldLabel('Skills'),
              MpTextField(controller: _tags, placeholder: 'Separadas por coma'),
              const SizedBox(height: MpTokens.space12),
              const MpFieldLabel('Extras'),
              MpTextField(controller: _extras, placeholder: 'Opcional', maxLines: 2),
            ],
          ),
        ),
        const SizedBox(height: MpTokens.space12),
        MpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _picker(
                s,
                'Jornada',
                const ['Completa', 'Parcial', 'Por horas'],
                _employmentType,
                (value) => setState(() => _employmentType = value),
              ),
              const SizedBox(height: MpTokens.space16),
              _picker(
                s,
                'Experiencia',
                const ['Sin experiencia', 'Se valora', 'Imprescindible'],
                _experienceLevel,
                (value) => setState(() => _experienceLevel = value),
              ),
              const SizedBox(height: MpTokens.space16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vacante confidencial',
                          style: TextStyle(color: s.text, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: MpTokens.space2),
                        Text(
                          'Oculta la identidad del publicador mediante is_stealth.',
                          style: MpTokens.micro.copyWith(color: s.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  CupertinoSwitch(
                    value: _confidential,
                    onChanged: (value) => setState(() => _confidential = value),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: MpTokens.space20),
        MpButton(
          label: 'Publicar vacante',
          variant: MpButtonVariant.primary,
          expand: true,
          size: MpButtonSize.large,
          loading: _publishing,
          onPressed: _publishing ? null : _publish,
        ),
        const SizedBox(height: MpTokens.space8),
        Text(
          'No se crean clientes, mandatos, promociones ni canales externos.',
          textAlign: TextAlign.center,
          style: MpTokens.micro.copyWith(color: s.textTertiary),
        ),
      ],
    );
  }

  Widget _picker(
    MpSurfaceStyle s,
    String label,
    List<String> values,
    String? selected,
    ValueChanged<String> onSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: s.text, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: MpTokens.space8),
        Wrap(
          spacing: MpTokens.space8,
          runSpacing: MpTokens.space8,
          children: [
            for (final value in values)
              GestureDetector(
                onTap: () => onSelected(value),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected == value ? MpTokens.primary : s.fill,
                    borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: selected == value ? const Color(0xFFFFFFFF) : s.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
