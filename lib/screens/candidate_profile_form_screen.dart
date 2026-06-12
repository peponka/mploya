import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import 'onboarding_pitch_screen.dart';
import '../widgets/unsaved_changes_guard.dart';

class CandidateProfileFormScreen extends StatefulWidget {
  const CandidateProfileFormScreen({super.key});

  @override
  State<CandidateProfileFormScreen> createState() => _CandidateProfileFormScreenState();
}

class _CandidateProfileFormScreenState extends State<CandidateProfileFormScreen> {
  final _nombreController = TextEditingController();
  final _headlineController = TextEditingController();
  final _hashtagsController = TextEditingController();
  final _paisController = TextEditingController();
  final _ciudadController = TextEditingController();

  bool _isLoading = false;

  // Diccionario de ciudades conocidas → coordenadas para el mapa
  static const Map<String, List<double>> _knownCities = {
    'madrid': [40.4168, -3.7038], 'barcelona': [41.3851, 2.1734],
    'sevilla': [37.3891, -5.9845], 'valencia': [39.4699, -0.3763],
    'london': [51.5074, -0.1278], 'londres': [51.5074, -0.1278],
    'paris': [48.8566, 2.3522], 'berlin': [52.5200, 13.4050],
    'amsterdam': [52.3676, 4.9041], 'rome': [41.9028, 12.4964],
    'roma': [41.9028, 12.4964], 'milan': [45.4642, 9.1900],
    'lisbon': [38.7223, -9.1393], 'lisboa': [38.7223, -9.1393],
    'new york': [40.7128, -74.0060], 'los angeles': [34.0522, -118.2437],
    'chicago': [41.8781, -87.6298], 'miami': [25.7617, -80.1918],
    'toronto': [43.6532, -79.3832], 'cdmx': [19.4326, -99.1332],
    'mexico': [19.4326, -99.1332], 'guadalajara': [20.6597, -103.3496],
    'monterrey': [25.6866, -100.3161], 'buenos aires': [-34.6037, -58.3816],
    'bogota': [4.7110, -74.0721], 'lima': [-12.0464, -77.0428],
    'santiago': [-33.4489, -70.6693], 'sao paulo': [-23.5505, -46.6333],
    'medellin': [6.2442, -75.5812], 'tokyo': [35.6762, 139.6503],
    'dubai': [25.2048, 55.2708], 'singapore': [1.3521, 103.8198],
    'seoul': [37.5665, 126.9780], 'sydney': [-33.8688, 151.2093],
    'san francisco': [37.7749, -122.4194], 'austin': [30.2672, -97.7431],
    'denver': [39.7392, -104.9903], 'seattle': [47.6062, -122.3321],
    'quito': [-0.1807, -78.4678], 'caracas': [10.4806, -66.9036],
    'montevideo': [-34.9011, -56.1645], 'la paz': [-16.4897, -68.1193],
    'asuncion': [-25.2637, -57.5759], 'panama': [8.9824, -79.5199],
    'san jose': [9.9281, -84.0907], 'havana': [23.1136, -82.3666],
    'santo domingo': [18.4861, -69.9312],
  };

  List<double>? _resolveCity(String city) {
    final q = city.toLowerCase().trim();
    for (final entry in _knownCities.entries) {
      if (q.contains(entry.key) || entry.key.contains(q)) {
        return entry.value;
      }
    }
    return null;
  }

  Future<void> _guardarPerfilYContinuar() async {
    final nombre = _nombreController.text.trim();
    final headline = _headlineController.text.trim();
    final tagsStr = _hashtagsController.text.trim();
    final pais = _paisController.text.trim();
    final ciudad = _ciudadController.text.trim();

    if (nombre.isEmpty || headline.isEmpty || pais.isEmpty || ciudad.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Faltan Datos'),
          content: const Text('Por favor, ingresa tu nombre, país, ciudad y un breve resumen (headline).'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Completar'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        // Parse hashtags
        List<String> rawTags = tagsStr.split(',');
        List<String> cleanTags = rawTags
            .map((t) => t.trim().replaceAll('#', ''))
            .where((t) => t.isNotEmpty)
            .toList();

        // Resolver coordenadas de la ciudad para el mapa Explore
        final coords = _resolveCity(ciudad);

        await Supabase.instance.client.from('users').update({
          'account_type': 'candidato',
          'name': nombre,
          'headline': headline,
          'city': '$ciudad, $pais',
          'tags': cleanTags.isNotEmpty ? cleanTags : null,
          'onboarding_step': 2,
          if (coords != null) 'latitude': coords[0],
          if (coords != null) 'longitude': coords[1],
        }).eq('id', uid);

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const OnboardingPitchScreen(isCompany: false)),
        );
      } else {
        debugPrint('⚠️ uid es null — no se guardó el perfil');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error guardando perfil de candidato: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _headlineController.dispose();
    _hashtagsController.dispose();
    _paisController.dispose();
    _ciudadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      hasUnsavedChanges: () => _nombreController.text.trim().isNotEmpty || _headlineController.text.trim().isNotEmpty,
      child: CupertinoPageScaffold(
        backgroundColor: MployaTheme.lightBg,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: MployaTheme.lightNavBar,
        border: null,
        middle: Text(
          'Perfil de Talento',
          style: TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w700),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle and icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: MployaTheme.brandAccent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.person_crop_circle_fill,
                          size: 40,
                          color: MployaTheme.brandAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    const Text('Tu Nombre o Apodo', style: TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: _nombreController,
                      placeholder: 'Ej: Juan Pérez',
                      placeholderStyle: const TextStyle(color: MployaTheme.lightTertiary),
                      style: const TextStyle(color: MployaTheme.lightText),
                      decoration: BoxDecoration(
                        color: MployaTheme.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MployaTheme.lightDivider),
                      ),
                      padding: const EdgeInsets.all(16),
                    ),
                    const SizedBox(height: 24),

                    const Text('Cargo y Empresa actual', style: TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: _headlineController,
                      placeholder: 'Ej: Director de Marketing en MercadoLibre',
                      placeholderStyle: const TextStyle(color: MployaTheme.lightTertiary),
                      style: const TextStyle(color: MployaTheme.lightText),
                      decoration: BoxDecoration(
                        color: MployaTheme.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MployaTheme.lightDivider),
                      ),
                      padding: const EdgeInsets.all(16),
                    ),
                    const SizedBox(height: 24),

                    const Text('País', style: TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: _paisController,
                      placeholder: 'Ej: México',
                      placeholderStyle: const TextStyle(color: MployaTheme.lightTertiary),
                      style: const TextStyle(color: MployaTheme.lightText),
                      decoration: BoxDecoration(
                        color: MployaTheme.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MployaTheme.lightDivider),
                      ),
                      padding: const EdgeInsets.all(16),
                    ),
                    const SizedBox(height: 24),

                    const Text('Ciudad', style: TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: _ciudadController,
                      placeholder: 'Ej: CDMX',
                      placeholderStyle: const TextStyle(color: MployaTheme.lightTertiary),
                      style: const TextStyle(color: MployaTheme.lightText),
                      decoration: BoxDecoration(
                        color: MployaTheme.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MployaTheme.lightDivider),
                      ),
                      padding: const EdgeInsets.all(16),
                    ),
                    const SizedBox(height: 24),

                    const Text('Cualidades (Hashtags separados por coma)', style: TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: _hashtagsController,
                      placeholder: 'Ej: #flutter, #backend, líder, python',
                      maxLines: 2,
                      placeholderStyle: const TextStyle(color: MployaTheme.lightTertiary),
                      style: const TextStyle(color: MployaTheme.lightText),
                      decoration: BoxDecoration(
                        color: MployaTheme.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MployaTheme.lightDivider),
                      ),
                      padding: const EdgeInsets.all(16),
                    ),
                    const SizedBox(height: 48),

                    SizedBox(
                      height: 52,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        color: MployaTheme.brandAccent,
                        borderRadius: BorderRadius.circular(14),
                        onPressed: _guardarPerfilYContinuar,
                        child: const Text(
                          'Siguiente paso: Video CV →',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: CupertinoColors.white,
                            fontFamily: '.SF Pro Text',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
      ),
    );
  }
}
