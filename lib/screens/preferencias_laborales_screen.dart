import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/my_profile_service.dart';

import '../widgets/candidato/cand_ui.dart';
import '../widgets/ds/mploya_ds.dart';

/// PREFERENCIAS LABORALES (candidato) — Tanda 4.
///
/// Referencia visual: design-reference/FINAL_SCREENS_CODEX/.../
/// preferencias laborales candidatos.png — estructura, jerarquía y campos.
///
/// Pantalla NUEVA e independiente (no una 6ª pestaña de Editar Perfil — Tanda 1
/// sigue congelada). Se llega por push desde el action sheet de Mi Perfil,
/// mismo patrón que Mis Postulaciones (Tanda 2).
///
/// HONESTIDAD DE CAMPOS — auditado contra `users` real (`kUserColumns`,
/// `utils/user_columns.dart`) antes de escribir código:
///   · Modalidad, Idiomas → NO son columnas propias. El wizard de onboarding
///     (`candidate_profile_form_screen.dart`, congelado) las codifica como
///     líneas con prefijo dentro de `about` ("Idiomas: …", "Preferencias: …").
///     Esta pantalla reproduce EXACTAMENTE ese mismo contrato de texto para
///     poder guardarlas sin pisar el resto de `about` (el resumen libre, y
///     los bloques "Portfolio:"/"Certificaciones:"/"Experiencia clave:"/
///     "Educacion:" que el wizard también puede escribir ahí) — se preservan
///     tal cual, sin tocarlos.
///   · Ubicación (city) y Salario esperado (salary_expectation) → SÍ son
///     columnas propias reales, se escriben directo.
///   · GPS → mismo patrón real que `explore_screen.dart._goToMyLocation`
///     (permiso → intento con timeout de 10s → última posición conocida →
///     aviso si no hay fix). Siempre queda la carga manual de ciudad/país.
///   · Roles de interés, radio de búsqueda, industrias de interés,
///     disponibilidad → NO existen en `users`. NO se muestran (ni
///     deshabilitados ni con placeholder) — se omiten del todo. Ver el
///     informe de Tanda 4 para el detalle.
class PreferenciasLaboralesScreen extends StatefulWidget {
  const PreferenciasLaboralesScreen({super.key, this.previewData});

  /// Sólo para tests — si llega, la pantalla NO consulta Supabase.
  final PreferenciasPreviewData? previewData;

  @override
  State<PreferenciasLaboralesScreen> createState() => _PreferenciasLaboralesScreenState();
}

@immutable
class PreferenciasPreviewData {
  const PreferenciasPreviewData({
    this.about = '',
    this.city = '',
    this.salaryExpectation = '',
  });

  final String about;
  final String city;
  final String salaryExpectation;
}

// Mismo vocabulario que `_preferenceOptions` en
// `candidate_profile_form_screen.dart` (Tanda 1, congelada) — se repite acá
// a propósito para no importar un archivo privado de otra pantalla; ambas
// pantallas escriben/leen el mismo contrato de texto dentro de `about`.
const _opcionesModalidad = [
  'Remoto',
  'Hibrido',
  'Presencial',
  'Full Time',
  'Part Time',
  'Freelance',
  'Relocation OK',
  'Viajes',
];

class _PreferenciasLaboralesScreenState extends State<PreferenciasLaboralesScreen> {
  late final _supabase = Supabase.instance.client;

  bool _cargando = true;
  bool _guardando = false;
  bool _buscandoGps = false;

  final _ciudadController = TextEditingController();
  final _paisController = TextEditingController();
  final _idiomasController = TextEditingController();
  final _salarioController = TextEditingController();
  final Set<String> _modalidad = <String>{};

  // Paragraphs de `about` que esta pantalla NO entiende y debe preservar tal
  // cual (resumen libre, Portfolio:, Certificaciones:, Experiencia clave:,
  // Educacion:, o cualquier otra cosa que haya ahí).
  List<String> _otrosParrafos = const [];
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    final preview = widget.previewData;
    if (preview != null) {
      _aplicarDatos(about: preview.about, city: preview.city, salario: preview.salaryExpectation);
      _cargando = false;
      return;
    }
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) setState(() => _cargando = false);
        return;
      }
      final row = await loadMyProfile();
      if (!mounted) return;
      if (row != null) {
        _aplicarDatos(
          about: row['about']?.toString() ?? '',
          city: row['city']?.toString() ?? '',
          salario: row['salary_expectation']?.toString() ?? '',
        );
        _lat = (row['latitude'] as num?)?.toDouble();
        _lng = (row['longitude'] as num?)?.toDouble();
      }
      setState(() => _cargando = false);
    } catch (e) {
      debugPrint('Preferencias laborales · error cargando: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _aplicarDatos({required String about, required String city, required String salario}) {
    _salarioController.text = salario;
    if (city.contains(',')) {
      final partes = city.split(',');
      _ciudadController.text = partes[0].trim();
      _paisController.text = partes.sublist(1).join(',').trim();
    } else {
      _ciudadController.text = city;
    }
    _parsearAbout(about);
  }

  // Mismo contrato de prefijos que `_prefillFromAbout` en
  // `candidate_profile_form_screen.dart` — sólo reconoce Idiomas:/
  // Preferencias:, todo lo demás se guarda en `_otrosParrafos` sin tocar.
  void _parsearAbout(String about) {
    final parsed = parseAboutPreferencias(about);
    _idiomasController.text = parsed.idiomas;
    _modalidad.addAll(parsed.modalidad);
    _otrosParrafos = parsed.otrosParrafos;
  }

  String _reconstruirAbout() => rebuildAboutWithPreferencias(
        otrosParrafos: _otrosParrafos,
        idiomas: _idiomasController.text.trim(),
        modalidad: _modalidad,
      );

  Future<void> _usarMiUbicacion() async {
    setState(() => _buscandoGps = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _avisar('Activá el GPS del teléfono para usar esta función.');
        return;
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        _avisar('Necesitamos permiso de ubicación para esto.');
        return;
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (!mounted) return;
      if (pos == null) {
        _avisar('No pudimos obtener tu ubicación. Revisá que el GPS esté activo.');
        return;
      }
      setState(() {
        _lat = pos!.latitude;
        _lng = pos.longitude;
      });
      _avisar('Ubicación actual guardada. Podés seguir ajustando ciudad/país a mano.');
    } catch (e) {
      debugPrint('Preferencias laborales · GPS: $e');
      if (mounted) _avisar('No pudimos obtener tu ubicación ($e).');
    } finally {
      if (mounted) setState(() => _buscandoGps = false);
    }
  }

  void _avisar(String mensaje) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(mensaje),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
        ],
      ),
    );
  }

  Future<void> _guardar() async {
    if (widget.previewData != null) return; // Vista de test: no escribe.
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _guardando = true);
    try {
      final ciudad = _ciudadController.text.trim();
      final pais = _paisController.text.trim();
      await updateMyCandidatePreferences(
        about: _reconstruirAbout(),
        city: pais.isNotEmpty ? '$ciudad, $pais' : ciudad,
        salaryExpectation: _salarioController.text.trim().isNotEmpty
            ? _salarioController.text.trim()
            : null,
        latitude: _lat,
        longitude: _lng,
      );

      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (e) {
      debugPrint('Preferencias laborales · error guardando: $e');
      if (mounted) _avisar('No pudimos guardar tus preferencias. Probá de nuevo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  void dispose() {
    _ciudadController.dispose();
    _paisController.dispose();
    _idiomasController.dispose();
    _salarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: MpSurfaceStyle.light.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: MpSurfaceStyle.light.bg,
        border: null,
        middle: const Text('Preferencias laborales'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Icon(CupertinoIcons.chevron_back),
        ),
      ),
      child: MpSurface(
        style: MpSurfaceStyle.light,
        child: _cargando
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : Column(
                children: [
                  Expanded(child: _buildForm(context)),
                  _buildBarraGuardar(context),
                ],
              ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final s = context.mp;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MpTokens.space16,
        MpTokens.space12,
        MpTokens.space16,
        MpTokens.space16,
      ),
      children: [
        Text(
          'Cuéntanos qué tipo de trabajo estás buscando',
          style: MpTokens.body.copyWith(color: s.textTertiary),
        ),
        const SizedBox(height: MpTokens.space20),
        _seccion(
          context,
          icono: CupertinoIcons.briefcase_fill,
          titulo: 'Modalidad de trabajo',
          subtitulo: 'Elegí lo que mejor te represente hoy.',
          child: Wrap(
            spacing: MpTokens.space8,
            runSpacing: MpTokens.space8,
            children: [
              for (final opcion in _opcionesModalidad)
                CandChip(
                  opcion,
                  activo: _modalidad.contains(opcion),
                  onTap: () => setState(() {
                    if (_modalidad.contains(opcion)) {
                      _modalidad.remove(opcion);
                    } else {
                      _modalidad.add(opcion);
                    }
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: MpTokens.space16),
        _seccion(
          context,
          icono: CupertinoIcons.location_solid,
          titulo: 'Ubicación y distancia',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: MpTextField(controller: _ciudadController, placeholder: 'Ciudad')),
                  const SizedBox(width: MpTokens.space12),
                  Expanded(child: MpTextField(controller: _paisController, placeholder: 'País')),
                ],
              ),
              const SizedBox(height: MpTokens.space12),
              MpButton(
                label: _lat != null ? 'Ubicación actual guardada' : 'Usar mi ubicación',
                icon: _lat != null ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.location_fill,
                variant: MpButtonVariant.outline,
                color: _lat != null ? MpTokens.success : null,
                expand: true,
                loading: _buscandoGps,
                onPressed: _buscandoGps ? null : _usarMiUbicacion,
              ),
            ],
          ),
        ),
        const SizedBox(height: MpTokens.space16),
        _seccion(
          context,
          icono: CupertinoIcons.money_dollar_circle_fill,
          titulo: 'Expectativa salarial',
          subtitulo: 'Opcional. Mejora el matching con oportunidades reales.',
          child: MpTextField(controller: _salarioController, placeholder: 'Ej: USD 2.500 - 3.500 / mes'),
        ),
        const SizedBox(height: MpTokens.space16),
        _seccion(
          context,
          icono: CupertinoIcons.globe,
          titulo: 'Idiomas',
          subtitulo: 'Idioma y nivel, separados por coma.',
          child: MpTextField(
            controller: _idiomasController,
            maxLines: 2,
            placeholder: 'Español nativo, Inglés C1, Portugués intermedio',
          ),
        ),
        const SizedBox(height: MpTokens.space16),
        Container(
          padding: const EdgeInsets.all(MpTokens.space16),
          decoration: BoxDecoration(
            color: s.tint(MpTokens.primary, alpha: 0.06),
            borderRadius: BorderRadius.circular(MpTokens.radiusMD),
            border: Border.all(color: MpTokens.primary.withValues(alpha: 0.14)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.info_circle_fill, size: 18, color: s.accent),
              const SizedBox(width: MpTokens.space8),
              Expanded(
                child: Text(
                  'Radio de búsqueda, industrias de interés y disponibilidad todavía no se guardan '
                  'en tu perfil — los vamos a sumar cuando tengan dónde persistirse.',
                  style: MpTokens.caption.copyWith(color: s.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seccion(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    String? subtitulo,
    required Widget child,
  }) {
    final s = context.mp;
    return CandTarjeta(
      padding: const EdgeInsets.all(MpTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: s.tint(s.accent), shape: BoxShape.circle),
                child: Icon(icono, size: 15, color: s.accent),
              ),
              const SizedBox(width: MpTokens.space8),
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MpTokens.bodyStrong.copyWith(color: s.text, fontSize: 15.5),
                ),
              ),
            ],
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: MpTokens.space4),
            Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Text(subtitulo, style: MpTokens.caption.copyWith(color: s.textTertiary)),
            ),
          ],
          const SizedBox(height: MpTokens.space12),
          child,
        ],
      ),
    );
  }

  Widget _buildBarraGuardar(BuildContext context) {
    final s = context.mp;
    return Container(
      padding: const EdgeInsets.all(MpTokens.space16),
      decoration: BoxDecoration(
        color: s.card,
        border: Border(top: BorderSide(color: s.border)),
      ),
      child: SafeArea(
        top: false,
        child: MpButton(
          label: 'Guardar preferencias',
          expand: true,
          loading: _guardando,
          onPressed: _guardar,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Parseo/reconstrucción de `users.about` — funciones puras de nivel
// superior (no privadas) a propósito, para que el test unitario pueda
// verificar SIN Supabase que actualizar Idiomas/Preferencias nunca borra
// el resto de lo que ya vive en `about` (resumen libre, Portfolio:,
// Certificaciones:, Experiencia clave:, Educacion:, o cualquier otra cosa
// que el wizard congelado haya escrito ahí). Mismo contrato de prefijos
// que `_prefillFromAbout`/`_buildAbout` en `candidate_profile_form_screen.dart`.
// ─────────────────────────────────────────────────────────────────────────

@immutable
class AboutPreferenciasParseadas {
  const AboutPreferenciasParseadas({
    required this.idiomas,
    required this.modalidad,
    required this.otrosParrafos,
  });

  final String idiomas;
  final Set<String> modalidad;
  final List<String> otrosParrafos;
}

AboutPreferenciasParseadas parseAboutPreferencias(String about) {
  var idiomas = '';
  final modalidad = <String>{};
  final otros = <String>[];

  for (final parrafo in about.split('\n\n')) {
    final t = parrafo.trim();
    if (t.isEmpty) continue;
    if (t.startsWith('Idiomas:')) {
      idiomas = t.replaceFirst('Idiomas:', '').trim();
    } else if (t.startsWith('Preferencias:')) {
      final valor = t.replaceFirst('Preferencias:', '').trim();
      modalidad.addAll(valor.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    } else {
      otros.add(t);
    }
  }

  return AboutPreferenciasParseadas(idiomas: idiomas, modalidad: modalidad, otrosParrafos: otros);
}

String rebuildAboutWithPreferencias({
  required List<String> otrosParrafos,
  required String idiomas,
  required Set<String> modalidad,
}) {
  final lines = <String>[...otrosParrafos];
  if (idiomas.trim().isNotEmpty) {
    lines.add('Idiomas: ${idiomas.trim()}');
  }
  if (modalidad.isNotEmpty) {
    lines.add('Preferencias: ${modalidad.join(', ')}');
  }
  return lines.join('\n\n');
}
