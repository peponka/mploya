import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mploya/models/models.dart';
import 'package:mploya/services/storage_service.dart';
import 'package:mploya/services/my_profile_service.dart';
import 'package:mploya/widgets/candidato/cand_ui.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';
import 'package:mploya/widgets/onboarding/assistant_fields.dart';
import 'package:mploya/widgets/onboarding/assistant_shell.dart';
import 'package:mploya/widgets/portfolio_section.dart';
import 'package:mploya/widgets/unsaved_changes_guard.dart';
import 'package:mploya/screens/onboarding_pitch_screen.dart';

enum _TalentStep {
  identity,
  experience,
  education,
  skills,
  languages,
  portfolio,
  certifications,
  preferences,
  review,
}

class CandidateProfileFormScreen extends StatefulWidget {
  final bool isEditing;
  const CandidateProfileFormScreen({super.key, this.isEditing = false});

  @override
  State<CandidateProfileFormScreen> createState() =>
      _CandidateProfileFormScreenState();
}

class _CandidateProfileFormScreenState
    extends State<CandidateProfileFormScreen> {
  final _nombreController = TextEditingController();
  final _headlineController = TextEditingController();
  final _paisController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _hashtagsController = TextEditingController();
  final _aboutController = TextEditingController();
  final _experienceController = TextEditingController();
  final _educationController = TextEditingController();
  final _languagesController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _certificationsController = TextEditingController();
  final _salaryController = TextEditingController();
  final _preferencesController = TextEditingController();

  bool _isLoading = false;
  int _stepIndex = 0;
  final Set<String> _selectedSkills = <String>{};
  final Set<String> _selectedPreferences = <String>{};

  // Solo para `widget.isEditing`: pestañas de "Editar perfil"
  // (design-reference/FINAL_SCREENS_CODEX/.../editar perfil candidato.png).
  // El onboarding (isEditing == false) no usa nada de esto.
  int _editTabIndex = 0;
  String? _avatarUrl;
  bool _avatarBusy = false;

  static const List<_TalentStep> _steps = [
    _TalentStep.identity,
    _TalentStep.experience,
    _TalentStep.education,
    _TalentStep.skills,
    _TalentStep.languages,
    _TalentStep.portfolio,
    _TalentStep.certifications,
    _TalentStep.preferences,
    _TalentStep.review,
  ];

  static const List<String> _skillOptions = [
    'Flutter',
    'Product',
    'UX/UI',
    'Growth',
    'Ventas B2B',
    'Data',
    'People',
    'Fintech',
    'Marketing',
    'Python',
    'Liderazgo',
    'Comunicacion',
  ];
  static const List<String> _preferenceOptions = [
    'Remoto',
    'Hibrido',
    'Presencial',
    'Full Time',
    'Part Time',
    'Freelance',
    'Relocation OK',
    'Viajes',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    setState(() => _isLoading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final row = await loadMyProfile();
      if (row != null && mounted) {
        _avatarUrl = row['avatar_url']?.toString();
        _nombreController.text = row['name']?.toString() ?? '';
        _headlineController.text = row['headline']?.toString() ?? '';
        _aboutController.text = row['about']?.toString() ?? '';
        _salaryController.text = row['salary_expectation']?.toString() ?? '';
        final tags = row['tags'];
        if (tags is List) {
          _hashtagsController.text = tags.map((t) => '#$t').join(', ');
          _selectedSkills.addAll(tags.map((t) => t.toString()));
        }
        final skills = row['skills'];
        if (skills is List) {
          _selectedSkills.addAll(skills.map((s) => s.toString()));
        }
        final city = row['city']?.toString() ?? '';
        if (city.contains(',')) {
          final parts = city.split(',');
          _ciudadController.text = parts[0].trim();
          _paisController.text = parts.sublist(1).join(',').trim();
        } else {
          _ciudadController.text = city;
        }
        final experience = row['experience'];
        if (experience is List && experience.isNotEmpty) {
          _experienceController.text = experience
              .map((item) {
                final map = item as Map<String, dynamic>;
                final role = map['role']?.toString() ?? '';
                final company = map['company']?.toString() ?? '';
                final duration = map['duration']?.toString() ?? '';
                return [
                  role,
                  company,
                  duration,
                ].where((part) => part.isNotEmpty).join(' · ');
              })
              .join('\n');
        }
        final education = row['education'];
        if (education is List && education.isNotEmpty) {
          _educationController.text = education
              .map((item) {
                final map = item as Map<String, dynamic>;
                final degree = map['degree']?.toString() ?? '';
                final school = map['school']?.toString() ?? '';
                final years = map['years']?.toString() ?? '';
                return [
                  degree,
                  school,
                  years,
                ].where((part) => part.isNotEmpty).join(' · ');
              })
              .join('\n');
        }
        _prefillFromAbout(_aboutController.text);
      }
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Mismo patrón que `ProfileScreen._pickAndUploadAvatar`: ImagePicker →
  // StorageService.uploadAvatar → persistir en `users.avatar_url`. Se guarda
  // al toque, independiente del botón "Guardar cambios" del resto del form.
  Future<void> _pickAndUploadAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _avatarBusy = true);
    final url = await StorageService.instance.uploadAvatar(uid, picked);
    if (!mounted) return;

    if (url == null) {
      setState(() => _avatarBusy = false);
      _showAlert(
        'No se pudo actualizar',
        StorageService.instance.lastError ?? 'Intenta nuevamente en unos segundos.',
      );
      return;
    }

    await setMyProfileAvatar(url);
    if (!mounted) return;
    setState(() {
      _avatarUrl = url;
      _avatarBusy = false;
    });
  }

  Future<void> _removeAvatar() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _avatarBusy = true);
    await setMyProfileAvatar(null);
    if (!mounted) return;
    setState(() {
      _avatarUrl = null;
      _avatarBusy = false;
    });
  }

  void _prefillFromAbout(String about) {
    if (about.isEmpty) return;
    for (final line in about.split('\n').map((line) => line.trim())) {
      if (line.startsWith('Idiomas:')) {
        _languagesController.text = line.replaceFirst('Idiomas:', '').trim();
      } else if (line.startsWith('Portfolio:')) {
        _portfolioController.text = line.replaceFirst('Portfolio:', '').trim();
      } else if (line.startsWith('Certificaciones:')) {
        _certificationsController.text = line
            .replaceFirst('Certificaciones:', '')
            .trim();
      } else if (line.startsWith('Preferencias:')) {
        final value = line.replaceFirst('Preferencias:', '').trim();
        _preferencesController.text = value;
        _selectedPreferences.addAll(
          value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
        );
      }
    }
  }

  static const Map<String, List<double>> _knownCities = {
    'madrid': [40.4168, -3.7038],
    'barcelona': [41.3851, 2.1734],
    'sevilla': [37.3891, -5.9845],
    'valencia': [39.4699, -0.3763],
    'london': [51.5074, -0.1278],
    'londres': [51.5074, -0.1278],
    'paris': [48.8566, 2.3522],
    'berlin': [52.5200, 13.4050],
    'amsterdam': [52.3676, 4.9041],
    'rome': [41.9028, 12.4964],
    'roma': [41.9028, 12.4964],
    'milan': [45.4642, 9.1900],
    'lisbon': [38.7223, -9.1393],
    'lisboa': [38.7223, -9.1393],
    'new york': [40.7128, -74.0060],
    'los angeles': [34.0522, -118.2437],
    'chicago': [41.8781, -87.6298],
    'miami': [25.7617, -80.1918],
    'toronto': [43.6532, -79.3832],
    'cdmx': [19.4326, -99.1332],
    'mexico': [19.4326, -99.1332],
    'guadalajara': [20.6597, -103.3496],
    'monterrey': [25.6866, -100.3161],
    'buenos aires': [-34.6037, -58.3816],
    'bogota': [4.7110, -74.0721],
    'lima': [-12.0464, -77.0428],
    'santiago': [-33.4489, -70.6693],
    'sao paulo': [-23.5505, -46.6333],
    'medellin': [6.2442, -75.5812],
    'tokyo': [35.6762, 139.6503],
    'dubai': [25.2048, 55.2708],
    'singapore': [1.3521, 103.8198],
    'seoul': [37.5665, 126.9780],
    'sydney': [-33.8688, 151.2093],
    'san francisco': [37.7749, -122.4194],
    'austin': [30.2672, -97.7431],
    'denver': [39.7392, -104.9903],
    'seattle': [47.6062, -122.3321],
    'quito': [-0.1807, -78.4678],
    'caracas': [10.4806, -66.9036],
    'montevideo': [-34.9011, -56.1645],
    'la paz': [-16.4897, -68.1193],
    'asuncion': [-25.2637, -57.5759],
    'panama': [8.9824, -79.5199],
    'san jose': [9.9281, -84.0907],
    'havana': [23.1136, -82.3666],
    'santo domingo': [18.4861, -69.9312],
  };

  List<double>? _resolveCity(String city) {
    final q = city.toLowerCase().trim();
    for (final entry in _knownCities.entries) {
      if (q.contains(entry.key) || entry.key.contains(q)) return entry.value;
    }
    return null;
  }

  List<String> _parseCommaValues(String value) => value
      .split(',')
      .map((e) => e.trim().replaceAll('#', ''))
      .where((e) => e.isNotEmpty)
      .toList();

  List<Experience> _buildExperience() {
    final lines = _experienceController.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return [
        Experience(
          role: _headlineController.text.trim().isEmpty
              ? 'Talento en crecimiento'
              : _headlineController.text.trim(),
          company: 'Experiencia destacada',
          duration: 'Actualmente',
          description: _aboutController.text.trim().isEmpty
              ? 'Perfil creado desde el assistant de talento.'
              : _aboutController.text.trim(),
          isCurrent: true,
        ),
      ];
    }
    return lines.map((line) {
      final parts = line.split('·').map((e) => e.trim()).toList();
      return Experience(
        role: parts.isNotEmpty && parts[0].isNotEmpty
            ? parts[0]
            : _headlineController.text.trim(),
        company: parts.length > 1 && parts[1].isNotEmpty
            ? parts[1]
            : 'Proyecto / Empresa',
        duration: parts.length > 2 && parts[2].isNotEmpty
            ? parts[2]
            : 'Experiencia reciente',
        description: line,
        isCurrent: line.toLowerCase().contains('actual'),
      );
    }).toList();
  }

  List<Education> _buildEducation() {
    final lines = _educationController.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return lines.map((line) {
      final parts = line.split('·').map((e) => e.trim()).toList();
      return Education(
        degree: parts.isNotEmpty && parts[0].isNotEmpty
            ? parts[0]
            : 'Formacion',
        school: parts.length > 1 && parts[1].isNotEmpty
            ? parts[1]
            : 'Institucion',
        years: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : 'En curso',
        field: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
      );
    }).toList();
  }

  String _buildAbout() {
    final lines = <String>[];
    if (_aboutController.text.trim().isNotEmpty) {
      lines.add(_aboutController.text.trim());
    }
    if (_languagesController.text.trim().isNotEmpty) {
      lines.add('Idiomas: ${_languagesController.text.trim()}');
    }
    if (_portfolioController.text.trim().isNotEmpty) {
      lines.add('Portfolio: ${_portfolioController.text.trim()}');
    }
    if (_certificationsController.text.trim().isNotEmpty) {
      lines.add('Certificaciones: ${_certificationsController.text.trim()}');
    }
    final pref = _mergedPreferences();
    if (pref.isNotEmpty) {
      lines.add('Preferencias: ${pref.join(', ')}');
    }
    if (_experienceController.text.trim().isNotEmpty) {
      lines.add('Experiencia clave:\n${_experienceController.text.trim()}');
    }
    if (_educationController.text.trim().isNotEmpty) {
      lines.add('Educacion:\n${_educationController.text.trim()}');
    }
    return lines.join('\n\n');
  }

  List<String> _mergedSkills() => {
    ..._selectedSkills,
    ..._parseCommaValues(_hashtagsController.text),
  }.toList();
  List<String> _mergedPreferences() => {
    ..._selectedPreferences,
    ..._preferencesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty),
  }.toList();

  Future<void> _guardarPerfilYContinuar() async {
    final nombre = _nombreController.text.trim();
    final headline = _headlineController.text.trim();
    final pais = _paisController.text.trim();
    final ciudad = _ciudadController.text.trim();
    if (nombre.isEmpty || headline.isEmpty || pais.isEmpty || ciudad.isEmpty) {
      _showAlert(
        'Faltan datos',
        'Por favor, completa tu nombre, tu titular profesional, pais y ciudad.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        debugPrint('uid es null - no se guardo el perfil');
        return;
      }
      final mergedSkills = _mergedSkills();
      final coords = _resolveCity(ciudad);
      final about = _buildAbout();
      final experience = _buildExperience();
      final education = _buildEducation();
      await updateMyCandidateProfile(
        name: nombre,
        headline: headline,
        city: '$ciudad, $pais',
        about: about.isNotEmpty ? about : null,
        tags: mergedSkills.isNotEmpty ? mergedSkills : null,
        skills: mergedSkills.isNotEmpty ? mergedSkills : null,
        experience: experience
            .map(
              (e) => <String, Object?>{
                'role': e.role,
                'company': e.company,
                'duration': e.duration,
                'location': e.location,
                'description': e.description,
                'is_current': e.isCurrent,
              },
            )
            .toList(),
        education: education
            .map(
              (e) => <String, Object?>{
                'school': e.school,
                'degree': e.degree,
                'field': e.field,
                'years': e.years,
              },
            )
            .toList(),
        salaryExpectation: _salaryController.text.trim().isNotEmpty
            ? _salaryController.text.trim()
            : null,
        latitude: coords?[0],
        longitude: coords?[1],
        completeOnboarding: !widget.isEditing,
      );

      if (!mounted) return;
      if (widget.isEditing) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (_) => const OnboardingPitchScreen(isCompany: false),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error guardando perfil de candidato: $e');
      if (mounted) _showAlert('Error', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAlert(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  bool _validateCurrentStep() {
    switch (_steps[_stepIndex]) {
      case _TalentStep.identity:
        if (_nombreController.text.trim().isEmpty ||
            _headlineController.text.trim().isEmpty ||
            _paisController.text.trim().isEmpty ||
            _ciudadController.text.trim().isEmpty) {
          _showAlert(
            'Completa tu perfil base',
            'Necesitamos tu nombre, titular profesional, pais y ciudad para continuar.',
          );
          return false;
        }
        return true;
      case _TalentStep.skills:
        if (_mergedSkills().isEmpty) {
          _showAlert(
            'Agrega al menos una habilidad',
            'Tu perfil necesita al menos un skill o hashtag para mejorar el matching.',
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_steps[_stepIndex] == _TalentStep.review) {
      _guardarPerfilYContinuar();
      return;
    }
    setState(() => _stepIndex++);
  }

  void _previousStep() {
    if (_stepIndex == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _stepIndex--);
  }

  void _skipCurrentStep() {
    if (_steps[_stepIndex] == _TalentStep.review) return;
    setState(() => _stepIndex++);
  }

  void _toggleSkill(String value) {
    setState(() {
      if (_selectedSkills.contains(value)) {
        _selectedSkills.remove(value);
      } else {
        _selectedSkills.add(value);
      }
    });
  }

  void _togglePreference(String value) {
    setState(() {
      if (_selectedPreferences.contains(value)) {
        _selectedPreferences.remove(value);
      } else {
        _selectedPreferences.add(value);
      }
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _headlineController.dispose();
    _paisController.dispose();
    _ciudadController.dispose();
    _hashtagsController.dispose();
    _aboutController.dispose();
    _experienceController.dispose();
    _educationController.dispose();
    _languagesController.dispose();
    _portfolioController.dispose();
    _certificationsController.dispose();
    _salaryController.dispose();
    _preferencesController.dispose();
    super.dispose();
  }

  String get _eyebrow {
    switch (_steps[_stepIndex]) {
      case _TalentStep.identity:
        return 'Crear perfil';
      case _TalentStep.experience:
        return 'Experiencia laboral';
      case _TalentStep.education:
        return 'Educacion';
      case _TalentStep.skills:
        return 'Habilidades';
      case _TalentStep.languages:
        return 'Idiomas';
      case _TalentStep.portfolio:
        return 'Portfolio';
      case _TalentStep.certifications:
        return 'Certificaciones';
      case _TalentStep.preferences:
        return 'Preferencias laborales';
      case _TalentStep.review:
        return 'Tu perfil esta casi listo';
    }
  }

  String get _title {
    switch (_steps[_stepIndex]) {
      case _TalentStep.identity:
        return 'Vamos a presentar tu talento como si ya fueras memorable.';
      case _TalentStep.experience:
        return 'Contame tu experiencia reciente.';
      case _TalentStep.education:
        return 'Mostremos la base que respalda tu carrera.';
      case _TalentStep.skills:
        return 'En que queres destacar dentro de Mploya?';
      case _TalentStep.languages:
        return 'Tus idiomas tambien son una ventaja competitiva.';
      case _TalentStep.portfolio:
        return 'Dale contexto visual a tu trabajo.';
      case _TalentStep.certifications:
        return 'Todo respaldo suma confianza.';
      case _TalentStep.preferences:
        return 'Alineemos tu perfil con el tipo de oportunidad ideal.';
      case _TalentStep.review:
        return 'Revisa tu assistant antes de pasar al video pitch.';
    }
  }

  String get _subtitle {
    switch (_steps[_stepIndex]) {
      case _TalentStep.identity:
        return 'Este primer bloque define como te van a descubrir empresas y recruiters en el feed.';
      case _TalentStep.experience:
        return 'Podes escribir una linea por experiencia. Ejemplo: Product Manager · Uala · 2023-Actual.';
      case _TalentStep.education:
        return 'Una linea por formacion funciona perfecto. Ejemplo: Lic. en Marketing · UCA · 2018-2022.';
      case _TalentStep.skills:
        return 'Elegi tus fortalezas principales y suma hashtags propios para que la IA te encuentre mejor.';
      case _TalentStep.languages:
        return 'Indica idiomas y nivel si queres. Esto ayuda mucho en busquedas globales.';
      case _TalentStep.portfolio:
        return 'Podes compartir un link, una coleccion de trabajos o una breve descripcion de tus proyectos.';
      case _TalentStep.certifications:
        return 'Cursos, badges y certificaciones aumentan credibilidad aunque todavia no esten verificados.';
      case _TalentStep.preferences:
        return 'Defini modalidad, tipo de trabajo y rango salarial para mejorar el matching.';
      case _TalentStep.review:
        return 'En el siguiente paso te pediremos tu video presentacion, asi que aca dejamos todo listo.';
    }
  }

  Widget _buildIdentityStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AssistantSectionCard(
        child: Row(
          children: [
            Icon(
              CupertinoIcons.person_crop_circle_fill,
              color: Color(0xFFF97316),
              size: 26,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tu perfil va a vivir en una experiencia visual y rapida. Priorizamos claridad, energia y posicionamiento.',
                style: TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const AssistantFieldLabel(
        title: 'Nombre o apodo profesional',
        hint: 'Como queres que aparezca tu perfil dentro de la plataforma.',
      ),
      const SizedBox(height: 10),
      AssistantTextField(
        controller: _nombreController,
        placeholder: 'Ej: Camila Ruiz',
      ),
      const SizedBox(height: 18),
      const AssistantFieldLabel(
        title: 'Titular profesional',
        hint: 'Tu mejor resumen en una sola linea.',
      ),
      const SizedBox(height: 10),
      AssistantTextField(
        controller: _headlineController,
        placeholder: 'Ej: Product Designer enfocada en fintech y growth',
      ),
      const SizedBox(height: 18),
      const AssistantFieldLabel(
        title: 'Pais y ciudad',
        hint: 'Usamos esto para discovery, mapa y matching local.',
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: AssistantTextField(
              controller: _paisController,
              placeholder: 'Paraguay',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AssistantTextField(
              controller: _ciudadController,
              placeholder: 'Asuncion',
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      const AssistantFieldLabel(
        title: 'Resumen breve',
        hint: 'Tu tono, tu foco y el tipo de impacto que soles generar.',
      ),
      const SizedBox(height: 10),
      AssistantTextField(
        controller: _aboutController,
        placeholder:
            'Ej: Diseno experiencias claras para productos digitales con foco en conversion, research y velocidad de ejecucion.',
        maxLines: 4,
      ),
    ],
  );

  Widget _buildExperienceStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AssistantSectionCard(
        child: Text(
          'Podes escribir una experiencia por linea. Si queres, usa este formato: Rol · Empresa · Periodo.',
          style: TextStyle(
            color: Color(0xFF4B5563),
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
      const SizedBox(height: 18),
      const AssistantFieldLabel(
        title: 'Experiencia laboral',
        hint: 'Prioriza las 2 o 3 experiencias que mejor te posicionan.',
      ),
      const SizedBox(height: 10),
      AssistantTextField(
        controller: _experienceController,
        placeholder:
            'Ej:\nSenior Product Designer · Uala · 2022-Actual\nUX Designer · Globant · 2020-2022',
        maxLines: 7,
      ),
    ],
  );

  Widget _buildEducationStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AssistantFieldLabel(
        title: 'Educacion',
        hint: 'Una linea por formacion es suficiente en esta primera version.',
      ),
      const SizedBox(height: 10),
      AssistantTextField(
        controller: _educationController,
        placeholder:
            'Ej:\nLic. en Marketing · UCA · 2018-2022\nCurso UX Research · Coderhouse · 2024',
        maxLines: 6,
      ),
    ],
  );

  Widget _buildSkillsStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AssistantFieldLabel(
        title: 'Elegi tus skills mas fuertes',
        hint: 'Despues podes sumar tus propios hashtags mas abajo.',
      ),
      const SizedBox(height: 12),
      AssistantChoiceChips(
        options: _skillOptions,
        selected: _selectedSkills,
        onToggle: _toggleSkill,
      ),
      const SizedBox(height: 20),
      const AssistantFieldLabel(
        title: 'Hashtags personalizados',
        hint: 'Separados por coma. Ej: #flutter, #growth, #peopleops',
      ),
      const SizedBox(height: 10),
      AssistantTextField(
        controller: _hashtagsController,
        placeholder: '#producto, #liderazgo, #uxresearch',
        maxLines: 3,
      ),
    ],
  );
  Widget _buildLanguagesStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AssistantFieldLabel(
        title: 'Idiomas',
        hint:
            'Podes escribir idioma y nivel. Ej: Ingles C1, Portugues intermedio.',
      ),
      const SizedBox(height: 10),
      AssistantTextField(
        controller: _languagesController,
        placeholder: 'Espanol nativo, Ingles C1, Portugues intermedio',
        maxLines: 4,
      ),
    ],
  );

  Widget _buildPortfolioStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AssistantFieldLabel(
        title: 'Portfolio o proyectos',
        hint:
            'Comparte un link o describi el tipo de trabajo que te representa mejor.',
      ),
      const SizedBox(height: 10),
      AssistantTextField(
        controller: _portfolioController,
        placeholder:
            'https://miportfolio.com o "Diseno productos B2B, dashboards y sistemas de diseno para fintechs."',
        maxLines: 4,
      ),
    ],
  );

  Widget _buildCertificationsStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AssistantFieldLabel(
        title: 'Certificaciones',
        hint:
            'Cursos, badges, licencias o formaciones que valga la pena mencionar.',
      ),
      const SizedBox(height: 10),
      AssistantTextField(
        controller: _certificationsController,
        placeholder:
            'Ej: Scrum Fundamentals, Google Analytics, AWS Cloud Practitioner',
        maxLines: 5,
      ),
    ],
  );

  Widget _buildPreferencesStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AssistantFieldLabel(
        title: 'Preferencias laborales',
        hint: 'Elegi lo que mas te representa hoy.',
      ),
      const SizedBox(height: 12),
      AssistantChoiceChips(
        options: _preferenceOptions,
        selected: _selectedPreferences,
        onToggle: _togglePreference,
      ),
      const SizedBox(height: 20),
      const AssistantFieldLabel(
        title: 'Detalle adicional',
        hint: 'Podes especificar jornada, industria, viajes o disponibilidad.',
      ),
      const SizedBox(height: 10),
      AssistantTextField(
        controller: _preferencesController,
        placeholder:
            'Ej: Disponible para roles regionales en producto o growth.',
        maxLines: 4,
      ),
      const SizedBox(height: 18),
      const AssistantFieldLabel(
        title: 'Expectativa salarial',
        hint:
            'Opcional. Si lo completas, mejora el matching con oportunidades reales.',
      ),
      const SizedBox(height: 10),
      AssistantTextField(
        controller: _salaryController,
        placeholder: 'Ej: USD 2.500 - 3.500 / mes',
      ),
    ],
  );

  Widget _buildReviewStep() {
    final mergedSkills = _mergedSkills();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AssistantReviewCard(
          title: 'Perfil base',
          lines: [
            _nombreController.text.trim().isEmpty
                ? 'Sin nombre'
                : _nombreController.text.trim(),
            _headlineController.text.trim().isEmpty
                ? 'Sin titular'
                : _headlineController.text.trim(),
            '${_ciudadController.text.trim()}, ${_paisController.text.trim()}',
          ],
          onEdit: () => setState(() => _stepIndex = 0),
        ),
        const SizedBox(height: 14),
        AssistantReviewCard(
          title: 'Experiencia y educacion',
          lines: [
            if (_experienceController.text.trim().isNotEmpty)
              _experienceController.text.trim(),
            if (_educationController.text.trim().isNotEmpty)
              _educationController.text.trim(),
            if (_experienceController.text.trim().isEmpty &&
                _educationController.text.trim().isEmpty)
              'Todavia no agregaste experiencia ni educacion.',
          ],
          onEdit: () => setState(() => _stepIndex = 1),
        ),
        const SizedBox(height: 14),
        AssistantReviewCard(
          title: 'Skills y preferencias',
          lines: [
            mergedSkills.isEmpty
                ? 'Sin skills'
                : 'Skills: ${mergedSkills.join(', ')}',
            _mergedPreferences().isEmpty
                ? 'Sin preferencias explicitas'
                : 'Preferencias: ${_mergedPreferences().join(', ')}',
            if (_salaryController.text.trim().isNotEmpty)
              'Expectativa: ${_salaryController.text.trim()}',
          ],
          onEdit: () => setState(() => _stepIndex = 3),
        ),
        const SizedBox(height: 14),
        AssistantReviewCard(
          title: 'Refuerzos del perfil',
          lines: [
            if (_languagesController.text.trim().isNotEmpty)
              'Idiomas: ${_languagesController.text.trim()}',
            if (_portfolioController.text.trim().isNotEmpty)
              'Portfolio: ${_portfolioController.text.trim()}',
            if (_certificationsController.text.trim().isNotEmpty)
              'Certificaciones: ${_certificationsController.text.trim()}',
            if (_languagesController.text.trim().isEmpty &&
                _portfolioController.text.trim().isEmpty &&
                _certificationsController.text.trim().isEmpty)
              'Podes completar esto mas adelante desde tu perfil.',
          ],
          onEdit: () => setState(() => _stepIndex = 4),
        ),
        const SizedBox(height: 18),
        const AssistantSectionCard(
          child: Text(
            'Al guardar, pasas directo al paso de video presentacion. Conservamos la logica actual de subida y vinculacion del pitch a tu perfil.',
            style: TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_steps[_stepIndex]) {
      case _TalentStep.identity:
        return _buildIdentityStep();
      case _TalentStep.experience:
        return _buildExperienceStep();
      case _TalentStep.education:
        return _buildEducationStep();
      case _TalentStep.skills:
        return _buildSkillsStep();
      case _TalentStep.languages:
        return _buildLanguagesStep();
      case _TalentStep.portfolio:
        return _buildPortfolioStep();
      case _TalentStep.certifications:
        return _buildCertificationsStep();
      case _TalentStep.preferences:
        return _buildPreferencesStep();
      case _TalentStep.review:
        return _buildReviewStep();
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // "Editar perfil" (widget.isEditing == true) — pestañas basadas en
  // design-reference/FINAL_SCREENS_CODEX/.../editar perfil candidato.png.
  // El onboarding (isEditing == false, wizard de arriba) no toca nada de esto.
  // ───────────────────────────────────────────────────────────────────────

  static const List<String> _editTabLabels = [
    'Información',
    'Experiencia',
    'Habilidades',
    'Video pitch',
    'Portafolio',
  ];

  static const List<IconData> _editTabIcons = [
    CupertinoIcons.person_crop_circle,
    CupertinoIcons.briefcase_fill,
    CupertinoIcons.star_fill,
    CupertinoIcons.videocam_fill,
    CupertinoIcons.photo_on_rectangle,
  ];

  Widget _buildEditTabsLayout(BuildContext context) {
    final s = context.mp;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              MpTokens.space16,
              MpTokens.space20,
              MpTokens.space16,
              MpTokens.space16,
            ),
            children: [
              _buildAvatarHeader(context),
              const SizedBox(height: MpTokens.space20),
              _buildEditTabBar(context),
              const SizedBox(height: MpTokens.space24),
              _buildEditTabContent(context),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(MpTokens.space16),
          decoration: BoxDecoration(
            color: s.card,
            border: Border(top: BorderSide(color: s.border)),
          ),
          child: SafeArea(
            top: false,
            child: MpButton(
              label: 'Guardar cambios',
              expand: true,
              loading: _isLoading,
              onPressed: _guardarPerfilYContinuar,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarHeader(BuildContext context) {
    final s = context.mp;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CandAvatar(
          nombre: _nombreController.text.trim().isEmpty
              ? 'Talento'
              : _nombreController.text.trim(),
          imagenUrl: _avatarUrl,
          tamano: 72,
        ),
        const SizedBox(width: MpTokens.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Foto de perfil',
                style: MpTokens.label.copyWith(
                  color: s.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: MpTokens.space4),
              Text(
                'Tu foto es lo primero que verán.',
                style: MpTokens.caption.copyWith(color: s.textTertiary),
              ),
              const SizedBox(height: MpTokens.space8),
              Wrap(
                spacing: MpTokens.space8,
                runSpacing: MpTokens.space8,
                children: [
                  MpButton(
                    label: 'Cambiar foto',
                    size: MpButtonSize.small,
                    variant: MpButtonVariant.outline,
                    loading: _avatarBusy,
                    onPressed: _avatarBusy ? null : _pickAndUploadAvatar,
                  ),
                  if (_avatarUrl != null && _avatarUrl!.trim().isNotEmpty)
                    MpButton(
                      label: 'Eliminar',
                      size: MpButtonSize.small,
                      variant: MpButtonVariant.ghost,
                      color: MpTokens.danger,
                      onPressed: _avatarBusy ? null : _removeAvatar,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Las 5 pestañas en fila, ícono arriba + etiqueta abajo — como
  // `editar perfil candidato.png`. `MpSegmentedFilter` (solo texto, en una
  // fila) no entra sin scroll con 5 etiquetas en 390px; este layout compacto
  // sí entra completo, así que las 5 quedan visibles y accesibles al abrir
  // la pantalla, sin recortar texto ni encogerlo por debajo de `MpTokens.micro`
  // (el tamaño que el propio sistema de diseño reserva para etiquetas de nav).
  Widget _buildEditTabBar(BuildContext context) {
    final s = context.mp;
    return Container(
      padding: const EdgeInsets.all(MpTokens.space4),
      decoration: BoxDecoration(
        color: s.fill,
        borderRadius: BorderRadius.circular(MpTokens.radiusLG),
        border: Border.all(color: s.border),
      ),
      child: Row(
        children: [
          for (int i = 0; i < _editTabLabels.length; i++)
            Expanded(
              child: _EditTabSegment(
                icon: _editTabIcons[i],
                label: _editTabLabels[i],
                active: i == _editTabIndex,
                onTap: () => setState(() => _editTabIndex = i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditTabContent(BuildContext context) {
    switch (_editTabIndex) {
      case 0:
        return _buildEditInfoTab();
      case 1:
        return _buildEditExperienceTab();
      case 2:
        return _buildEditSkillsTab();
      case 3:
        return _buildEditVideoTab(context);
      case 4:
        return _buildEditPortfolioTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEditInfoTab() {
    // Subconjunto de `_preferenceOptions` que representa modalidad — el resto
    // (Full Time, Freelance, Viajes, etc.) sigue viviendo en Preferencias, que
    // no forma parte de esta tanda.
    const modalidades = ['Remoto', 'Presencial', 'Hibrido'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MpFieldLabel('Nombre completo'),
        MpTextField(controller: _nombreController, placeholder: 'Ej: Camila Ruiz'),
        const SizedBox(height: MpTokens.space16),
        const MpFieldLabel('Título profesional'),
        MpTextField(
          controller: _headlineController,
          placeholder: 'Ej: Product Designer enfocada en fintech',
        ),
        const SizedBox(height: MpTokens.space16),
        const MpFieldLabel('Ubicación'),
        Row(
          children: [
            Expanded(
              child: MpTextField(controller: _ciudadController, placeholder: 'Ciudad'),
            ),
            const SizedBox(width: MpTokens.space12),
            Expanded(
              child: MpTextField(controller: _paisController, placeholder: 'País'),
            ),
          ],
        ),
        const SizedBox(height: MpTokens.space16),
        const MpFieldLabel('Modalidad preferida'),
        Wrap(
          spacing: MpTokens.space8,
          runSpacing: MpTokens.space8,
          children: [
            for (final m in modalidades)
              CandChip(
                m,
                activo: _selectedPreferences.contains(m),
                onTap: () => _togglePreference(m),
              ),
          ],
        ),
        const SizedBox(height: MpTokens.space16),
        const MpFieldLabel('Sobre mí'),
        MpTextField(
          controller: _aboutController,
          maxLines: 4,
          placeholder: 'Tu tono, tu foco y el tipo de impacto que generás.',
        ),
        const SizedBox(height: MpTokens.space16),
        const MpFieldLabel(
          'Expectativa salarial',
          helper: 'Opcional. Mejora el matching con oportunidades reales.',
        ),
        MpTextField(controller: _salaryController, placeholder: 'Ej: USD 2.500 - 3.500 / mes'),
      ],
    );
  }

  Widget _buildEditExperienceTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MpFieldLabel(
          'Experiencia laboral',
          helper: 'Una línea por experiencia. Ej: Rol · Empresa · Período.',
        ),
        MpTextField(
          controller: _experienceController,
          maxLines: 6,
          placeholder:
              'Ej:\nSenior Product Designer · Uala · 2022-Actual\nUX Designer · Globant · 2020-2022',
        ),
        const SizedBox(height: MpTokens.space20),
        const MpFieldLabel('Educación', helper: 'Una línea por formación.'),
        MpTextField(
          controller: _educationController,
          maxLines: 5,
          placeholder: 'Ej:\nLic. en Marketing · UCA · 2018-2022',
        ),
      ],
    );
  }

  Widget _buildEditSkillsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MpFieldLabel('Habilidades principales'),
        Wrap(
          spacing: MpTokens.space8,
          runSpacing: MpTokens.space8,
          children: [
            for (final skill in _skillOptions)
              CandChip(
                skill,
                activo: _selectedSkills.contains(skill),
                onTap: () => _toggleSkill(skill),
              ),
          ],
        ),
        const SizedBox(height: MpTokens.space20),
        const MpFieldLabel('Hashtags personalizados', helper: 'Separados por coma.'),
        MpTextField(
          controller: _hashtagsController,
          maxLines: 3,
          placeholder: '#producto, #liderazgo, #uxresearch',
        ),
        const SizedBox(height: MpTokens.space20),
        const MpFieldLabel('Idiomas'),
        MpTextField(
          controller: _languagesController,
          maxLines: 3,
          placeholder: 'Español nativo, Inglés C1, Portugués intermedio',
        ),
      ],
    );
  }

  Widget _buildEditVideoTab(BuildContext context) {
    final s = context.mp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MpFieldLabel(
          'Video pitch',
          helper:
              'Se graba desde el flujo real de cámara — no es un campo de texto, así que no hay nada que "escribir" acá.',
        ),
        Container(
          padding: const EdgeInsets.all(MpTokens.space16),
          decoration: BoxDecoration(
            color: s.fill,
            borderRadius: BorderRadius.circular(MpTokens.radiusMD),
            border: Border.all(color: s.border),
          ),
          child: Row(
            children: [
              Icon(CupertinoIcons.videocam_fill, color: s.accent, size: 28),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Text(
                  'Grabá o actualizá tu video de presentación (máx. 60 segundos).',
                  style: MpTokens.body.copyWith(color: s.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MpTokens.space16),
        MpButton(
          label: 'Ir a grabar video pitch',
          icon: CupertinoIcons.videocam_fill,
          expand: true,
          onPressed: () => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => const OnboardingPitchScreen(isCompany: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditPortfolioTab() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MpFieldLabel('Portafolio', helper: 'Hasta 3 proyectos con video, imagen o link.'),
        // Widget real ya existente (`portfolio_service.dart`) que hasta esta
        // tanda no estaba montado en ninguna pantalla productiva.
        PortfolioSection(userId: uid, isOwnProfile: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      hasUnsavedChanges: () =>
          _nombreController.text.trim().isNotEmpty ||
          _headlineController.text.trim().isNotEmpty ||
          _aboutController.text.trim().isNotEmpty ||
          _selectedSkills.isNotEmpty,
      child: CupertinoPageScaffold(
        backgroundColor: widget.isEditing
            ? MpSurfaceStyle.light.bg
            : const Color(0xFFFFFBF7),
        navigationBar: widget.isEditing
            ? CupertinoNavigationBar(
                backgroundColor: MpSurfaceStyle.light.bg,
                border: null,
                middle: const Text('Editar perfil'),
                leading: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Icon(CupertinoIcons.chevron_back),
                ),
              )
            : null,
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : widget.isEditing
            ? MpSurface(
                style: MpSurfaceStyle.light,
                child: _buildEditTabsLayout(context),
              )
            : AssistantShell(
                eyebrow: _eyebrow,
                title: _title,
                subtitle: _subtitle,
                currentStep: _stepIndex + 1,
                totalSteps: _steps.length,
                onClose: widget.isEditing
                    ? () => Navigator.of(context).maybePop()
                    : null,
                footer: AssistantFooterBar(
                  onBack: _previousStep,
                  onNext: _nextStep,
                  nextLabel: _steps[_stepIndex] == _TalentStep.review
                      ? (widget.isEditing
                            ? 'Guardar cambios'
                            : 'Guardar y seguir al video')
                      : 'Continuar',
                  secondaryLabel:
                      _steps[_stepIndex] == _TalentStep.identity ||
                          _steps[_stepIndex] == _TalentStep.skills ||
                          _steps[_stepIndex] == _TalentStep.review
                      ? null
                      : 'Saltar',
                  onSecondary: _skipCurrentStep,
                  isBusy: _isLoading,
                ),
                child: _buildStepContent(),
              ),
      ),
    );
  }
}

/// Un segmento de la barra de "Editar perfil": ícono arriba, etiqueta abajo.
/// Privado del archivo — no es parte de `widgets/ds/*`, es específico de esta
/// pantalla.
class _EditTabSegment extends StatelessWidget {
  const _EditTabSegment({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          vertical: MpTokens.space8,
          horizontal: MpTokens.space4,
        ),
        decoration: BoxDecoration(
          color: active ? s.card : const Color(0x00000000),
          borderRadius: BorderRadius.circular(MpTokens.radiusMD),
          boxShadow: active ? s.cardShadow : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 19,
              color: active ? s.accent : s.textTertiary,
            ),
            const SizedBox(height: MpTokens.space4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: MpTokens.micro.copyWith(
                color: active ? s.accent : s.textSecondary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
