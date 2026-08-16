import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/my_profile_service.dart';

class HeadhunterEditableProfile {
  const HeadhunterEditableProfile({
    required this.name,
    required this.headline,
    this.about,
    this.location,
    this.company,
    this.tags = const [],
    this.avatarUrl,
  });

  final String name;
  final String headline;
  final String? about;
  final String? location;
  final String? company;
  final List<String> tags;
  final String? avatarUrl;

  factory HeadhunterEditableProfile.fromMap(Map<String, dynamic> row) =>
      HeadhunterEditableProfile(
        name: row['name']?.toString() ?? '',
        headline: row['headline']?.toString() ?? '',
        about: row['about']?.toString(),
        location: row['location']?.toString(),
        company: row['company']?.toString(),
        tags: [
          for (final tag in row['tags'] as List? ?? const []) tag.toString(),
        ],
        avatarUrl: row['avatar_url']?.toString(),
      );
}

typedef HeadhunterProfileSaver =
    Future<void> Function(Map<String, dynamic> values);

class HeadhunterEditProfileScreen extends StatefulWidget {
  const HeadhunterEditProfileScreen({
    super.key,
    this.previewData,
    this.saveOverride,
  });

  final HeadhunterEditableProfile? previewData;
  final HeadhunterProfileSaver? saveOverride;

  @override
  State<HeadhunterEditProfileScreen> createState() =>
      _HeadhunterEditProfileScreenState();
}

class _HeadhunterEditProfileScreenState
    extends State<HeadhunterEditProfileScreen> {
  final _name = TextEditingController();
  final _headline = TextEditingController();
  final _about = TextEditingController();
  final _location = TextEditingController();
  final _company = TextEditingController();
  final _tags = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _error = false;
  bool _success = false;
  String? _message;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    if (widget.previewData != null) {
      _assign(widget.previewData!);
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _headline.dispose();
    _about.dispose();
    _location.dispose();
    _company.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _assign(HeadhunterEditableProfile profile) {
    _name.text = profile.name;
    _headline.text = profile.headline;
    _about.text = profile.about ?? '';
    _location.text = profile.location ?? '';
    _company.text = profile.company ?? '';
    _tags.text = profile.tags.join(', ');
    _avatarUrl = profile.avatarUrl;
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw StateError('Sin sesión');
      final row = await loadMyProfile(client: client);
      if (row == null || row['account_type']?.toString() != 'headhunter') {
        throw StateError('Perfil Headhunter no disponible');
      }
      if (!mounted) return;
      setState(() {
        _assign(HeadhunterEditableProfile.fromMap(row));
        _loading = false;
      });
    } catch (error) {
      debugPrint('Headhunter profile load: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Map<String, dynamic> get _values => {
    'name': _name.text.trim(),
    'headline': _headline.text.trim(),
    'about': _nullable(_about.text),
    'location': _nullable(_location.text),
    'company': _nullable(_company.text),
    'tags': _tags.text
        .split(',')
        .map((tag) => tag.trim().replaceAll('#', ''))
        .where((tag) => tag.isNotEmpty)
        .toList(),
  };

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty || _headline.text.trim().isEmpty) {
      setState(() {
        _success = false;
        _message = 'Nombre y especialidad son obligatorios.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      if (widget.saveOverride != null) {
        await widget.saveOverride!(_values);
      } else {
        final client = Supabase.instance.client;
        final uid = client.auth.currentUser?.id;
        if (uid == null) throw StateError('Sin sesión');
        await updateMyHeadhunterProfile(
          name: _values['name']?.toString() ?? '',
          headline: _values['headline']?.toString() ?? '',
          city: '',
          tags: [
            for (final tag in _values['tags'] as List? ?? const [])
              tag.toString(),
          ],
          about: _values['about']?.toString(),
          location: _values['location']?.toString(),
          company: _values['company']?.toString(),
          updateDetails: true,
          completeOnboarding: false,
          client: client,
        );
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _success = true;
        _message = 'Perfil actualizado correctamente.';
      });
    } catch (error) {
      debugPrint('Headhunter profile save: $error');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _success = false;
        _message = 'No se pudo guardar. Los cambios siguen en el formulario.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Editar perfil'),
        backgroundColor: CupertinoColors.white,
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saving || _loading ? null : _save,
          child: _saving
              ? const CupertinoActivityIndicator(radius: 8)
              : const Text('Guardar'),
        ),
      ),
      child: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CupertinoActivityIndicator());
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 42,
              color: Color(0xFF8D98AA),
            ),
            const SizedBox(height: 14),
            const Text(
              'No pudimos cargar tu perfil',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            CupertinoButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Center(child: _avatar()),
        const SizedBox(height: 10),
        const Text(
          'La foto se cambia desde tu Perfil público.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF7C879A)),
        ),
        if (_message != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  (_success ? const Color(0xFF24A66A) : const Color(0xFFD35B44))
                      .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _message!,
              style: TextStyle(
                color: _success
                    ? const Color(0xFF187A4D)
                    : const Color(0xFFA63A2A),
                fontSize: 13,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        _card([
          _field('Nombre *', _name, 'Tu nombre profesional'),
          const SizedBox(height: 14),
          _field('Especialidad *', _headline, 'Ej. Recruiter Tech'),
          const SizedBox(height: 14),
          _field('Sobre vos', _about, 'Tu enfoque profesional', maxLines: 4),
        ]),
        const SizedBox(height: 14),
        _card([
          _field('Ubicación', _location, 'Ciudad o región'),
          const SizedBox(height: 14),
          _field('Consultora o empresa', _company, 'Opcional'),
          const SizedBox(height: 14),
          _field('Especialidades', _tags, 'Separadas por coma'),
        ]),
        const SizedBox(height: 20),
        CupertinoButton.filled(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
              : const Text('Guardar cambios'),
        ),
        const SizedBox(height: 10),
        const Text(
          'No se solicitan clientes, colocaciones, rating ni años de experiencia porque esos campos no existen.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF7C879A), height: 1.4),
        ),
      ],
    );
  }

  Widget _avatar() {
    final url = _avatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: 78,
          height: 78,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _avatarFallback(),
        ),
      );
    }
    return _avatarFallback();
  }

  Widget _avatarFallback() => Container(
    width: 78,
    height: 78,
    decoration: const BoxDecoration(
      color: Color(0xFFEDEAFF),
      shape: BoxShape.circle,
    ),
    child: const Icon(
      CupertinoIcons.person_fill,
      size: 34,
      color: Color(0xFF4C2CF3),
    ),
  );

  Widget _card(List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: CupertinoColors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFE3E8F0)),
    ),
    child: Column(children: children),
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
}
