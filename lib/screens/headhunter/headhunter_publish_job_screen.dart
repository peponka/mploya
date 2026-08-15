import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/ai_match_service.dart';

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
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Publicar vacante'),
        backgroundColor: CupertinoColors.white,
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _publishing ? null : _publish,
          child: _publishing
              ? const CupertinoActivityIndicator(radius: 8)
              : const Text('Publicar'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            const Text(
              'Creá una vacante',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'La vacante quedará asociada a tu cuenta Headhunter.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B778C)),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              _messageCard(),
            ],
            const SizedBox(height: 18),
            _card([
              _field('Título del puesto *', _title, 'Ej. Flutter Developer'),
              const SizedBox(height: 14),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(vertical: 11),
                onPressed: _generating ? null : _generate,
                child: _generating
                    ? const CupertinoActivityIndicator(
                        radius: 8,
                        color: CupertinoColors.white,
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.sparkles, size: 16),
                          SizedBox(width: 7),
                          Text('Completar con IA'),
                        ],
                      ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Usa la función existente y deja todo editable antes de guardar.',
                style: TextStyle(fontSize: 12, color: Color(0xFF7C879A)),
              ),
            ]),
            const SizedBox(height: 14),
            _card([
              _field(
                'Descripción',
                _description,
                'Responsabilidades y requisitos reales del puesto',
                maxLines: 5,
              ),
              const SizedBox(height: 14),
              _field('Rango salarial', _salary, 'Opcional'),
              const SizedBox(height: 14),
              _field('Horario', _schedule, 'Opcional'),
              const SizedBox(height: 14),
              _field('Skills', _tags, 'Separadas por coma'),
              const SizedBox(height: 14),
              _field('Extras', _extras, 'Opcional', maxLines: 2),
            ]),
            const SizedBox(height: 14),
            _card([
              _picker(
                'Jornada',
                const ['Completa', 'Parcial', 'Por horas'],
                _employmentType,
                (value) => setState(() => _employmentType = value),
              ),
              const SizedBox(height: 16),
              _picker(
                'Experiencia',
                const ['Sin experiencia', 'Se valora', 'Imprescindible'],
                _experienceLevel,
                (value) => setState(() => _experienceLevel = value),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vacante confidencial',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF172033),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Oculta la identidad del publicador mediante is_stealth.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7C879A),
                          ),
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
            ]),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              onPressed: _publishing ? null : _publish,
              child: _publishing
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : const Text('Publicar vacante'),
            ),
            const SizedBox(height: 10),
            const Text(
              'No se crean clientes, mandatos, promociones ni canales externos.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF7C879A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: (_success ? const Color(0xFF24A66A) : const Color(0xFFD35B44))
          .withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      _message!,
      style: TextStyle(
        color: _success ? const Color(0xFF187A4D) : const Color(0xFFA63A2A),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _card(List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: CupertinoColors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFE3E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller,
    String placeholder, {
    int maxLines = 1,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF445069),
        ),
      ),
      const SizedBox(height: 7),
      CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        maxLines: maxLines,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      ),
    ],
  );

  Widget _picker(
    String label,
    List<String> values,
    String? selected,
    ValueChanged<String> onSelected,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF445069),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in values)
            GestureDetector(
              onTap: () => onSelected(value),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected == value
                      ? const Color(0xFF4C2CF3)
                      : const Color(0xFFF4F5F8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: selected == value
                        ? CupertinoColors.white
                        : const Color(0xFF445069),
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
