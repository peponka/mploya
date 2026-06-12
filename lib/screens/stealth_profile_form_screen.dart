import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/spring_interaction.dart';
import '../screens/onboarding_pitch_screen.dart';

class StealthProfileFormScreen extends StatefulWidget {
  const StealthProfileFormScreen({super.key});

  @override
  State<StealthProfileFormScreen> createState() => _StealthProfileFormScreenState();
}

class _StealthProfileFormScreenState extends State<StealthProfileFormScreen> {
  final _seudonimoController = TextEditingController();
  final _titularController = TextEditingController();
  final _empresaController = TextEditingController();
  final _hashtagsController = TextEditingController();
  // ── Nuevos campos ──
  final _experienciaController = TextEditingController();
  final _salarioController = TextEditingController();
  final _disponibilidadController = TextEditingController();
  final _logrosController = TextEditingController();
  final _ubicacionController = TextEditingController();
  final _modalidadController = TextEditingController();
  final _idiomasController = TextEditingController();

  bool _isLoading = false;

  // Modalidad seleccionada
  int _modalidadIndex = 0;
  final _modalidades = ['Remoto', 'Híbrido', 'Presencial', 'Relocation OK'];

  Future<void> _saveTrailer() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final seudonimo = _seudonimoController.text.trim();
        final titular = _titularController.text.trim();
        final empresa = _empresaController.text.trim();
        final experiencia = _experienciaController.text.trim();
        final salario = _salarioController.text.trim();
        final logros = _logrosController.text.trim();
        final ubicacion = _ubicacionController.text.trim();
        final idiomas = _idiomasController.text.trim();
        
        final rawTags = _hashtagsController.text;
        final tagsList = rawTags
            .split(',')
            .map((e) => e.trim().replaceAll('#', '').toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList();

        // Construir el "about" confidencial con toda la info extra
        final aboutParts = <String>[];
        if (experiencia.isNotEmpty) aboutParts.add('📊 $experiencia años de experiencia');
        if (salario.isNotEmpty) aboutParts.add('💰 Expectativa salarial: $salario');
        aboutParts.add('🏠 Modalidad: ${_modalidades[_modalidadIndex]}');
        if (ubicacion.isNotEmpty) aboutParts.add('📍 Zona: $ubicacion');
        if (idiomas.isNotEmpty) aboutParts.add('🌐 Idiomas: $idiomas');
        if (logros.isNotEmpty) aboutParts.add('\n🏆 Logros destacados:\n$logros');

        await Supabase.instance.client.from('users').update({
          'account_type': 'confidencial',
          'name': seudonimo.isEmpty ? 'Talento Oculto' : seudonimo,
          'company': empresa,
          'headline': titular.isEmpty ? 'Directivo Stealth' : titular,
          'tags': tagsList.isNotEmpty ? tagsList : null,
          'about': aboutParts.join('\n'),
          'onboarding_step': 2,
        }).eq('id', user.id);

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const OnboardingPitchScreen(isCompany: false)),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _seudonimoController.dispose();
    _titularController.dispose();
    _empresaController.dispose();
    _hashtagsController.dispose();
    _experienciaController.dispose();
    _salarioController.dispose();
    _disponibilidadController.dispose();
    _logrosController.dispose();
    _ubicacionController.dispose();
    _modalidadController.dispose();
    _idiomasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: MployaTheme.lightBg,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: MployaTheme.lightNavBar,
        border: null,
        middle: Text(
          'Tráiler Confidencial',
          style: TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w700),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Banner Stealth ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      MployaTheme.brandAccent.withValues(alpha: 0.15),
                      const Color(0xFF5F3DC4).withValues(alpha: 0.1),
                    ],
                  ),
                  border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(CupertinoIcons.lock_shield_fill, color: MployaTheme.brandAccent, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Modo Stealth Activado', style: TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w700, fontSize: 16)),
                          SizedBox(height: 4),
                          Text('Tu identidad permanece en bóveda. Cuanto más completes, mejores serán tus matches IA.', style: TextStyle(color: MployaTheme.lightSecondary, fontSize: 13, height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Sección 1: Identidad ──
              _sectionHeader('🎭', 'Identidad Blind'),
              const SizedBox(height: 12),
              _buildField(
                controller: _seudonimoController,
                label: 'Seudónimo o Nombre Real',
                placeholder: 'Ej: Martín (o un alias creativo)',
                icon: CupertinoIcons.person_fill,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _titularController,
                label: 'Titular Blind (tu puesto objetivo)',
                placeholder: 'Ej: VP Engineering, CTO Fintech',
                icon: CupertinoIcons.briefcase_fill,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _empresaController,
                label: 'Empresa Referencia (Opcional)',
                placeholder: 'Ej: Ex-MercadoLibre / Actual Globant',
                icon: CupertinoIcons.building_2_fill,
              ),

              const SizedBox(height: 28),
              // ── Sección 2: Experiencia ──
              _sectionHeader('📊', 'Trayectoria'),
              const SizedBox(height: 12),
              _buildField(
                controller: _experienciaController,
                label: 'Años de Experiencia',
                placeholder: 'Ej: 12',
                icon: CupertinoIcons.chart_bar_fill,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _logrosController,
                label: 'Logros Clave (tus hitos más importantes)',
                placeholder: 'Ej: Escalé equipo de 5 a 80 devs, Exit de USD 20M',
                icon: CupertinoIcons.star_fill,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _idiomasController,
                label: 'Idiomas',
                placeholder: 'Ej: Español nativo, Inglés avanzado, Portugués',
                icon: CupertinoIcons.globe,
              ),

              const SizedBox(height: 28),
              // ── Sección 3: Condiciones ──
              _sectionHeader('💼', 'Preferencias Laborales'),
              const SizedBox(height: 12),
              _buildField(
                controller: _salarioController,
                label: 'Expectativa Salarial (USD/año)',
                placeholder: 'Ej: 80K-120K USD',
                icon: CupertinoIcons.money_dollar_circle_fill,
              ),
              const SizedBox(height: 16),
              // Modalidad con selector visual
              const Text('Modalidad Preferida', style: TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _modalidadIndex,
                  backgroundColor: MployaTheme.lightCard,
                  thumbColor: MployaTheme.brandAccent,
                  children: {
                    0: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text('🏠 Remoto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _modalidadIndex == 0 ? Colors.white : MployaTheme.lightText)),
                    ),
                    1: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text('🔄 Híbrido', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _modalidadIndex == 1 ? Colors.white : MployaTheme.lightText)),
                    ),
                    2: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text('🏢 Oficina', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _modalidadIndex == 2 ? Colors.white : MployaTheme.lightText)),
                    ),
                    3: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text('✈️ Reloc', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _modalidadIndex == 3 ? Colors.white : MployaTheme.lightText)),
                    ),
                  },
                  onValueChanged: (val) => setState(() => _modalidadIndex = val ?? 0),
                ),
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _ubicacionController,
                label: 'Zona / Ciudad (para matches locales)',
                placeholder: 'Ej: Buenos Aires, Miami, Remote LatAm',
                icon: CupertinoIcons.location_fill,
              ),

              const SizedBox(height: 28),
              // ── Sección 4: Skills ──
              _sectionHeader('🏷️', 'Keywords para IA'),
              const SizedBox(height: 12),
              _buildField(
                controller: _hashtagsController,
                label: 'Skills y Keywords (separadas por coma)',
                placeholder: 'Ej: leadership, fintech, agile, python, aws',
                icon: CupertinoIcons.tag_fill,
              ),

              const SizedBox(height: 40),
              // ── Botón Guardar ──
              SpringInteraction(
                onTap: _saveTrailer,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [MployaTheme.brandAccent, Color(0xFF715092)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(color: MployaTheme.brandAccent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _isLoading 
                    ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                    : const Text(
                        'Activar Modo Stealth →',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String emoji, String title) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: MployaTheme.lightDivider, thickness: 0.5)),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          placeholderStyle: const TextStyle(color: MployaTheme.lightTertiary, fontSize: 14),
          style: const TextStyle(color: MployaTheme.lightText, fontSize: 15),
          maxLines: maxLines,
          keyboardType: keyboardType,
          prefix: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Icon(icon, size: 18, color: MployaTheme.brandAccent.withValues(alpha: 0.7)),
          ),
          decoration: BoxDecoration(
            color: MployaTheme.lightCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MployaTheme.lightDivider),
          ),
          padding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
        ),
      ],
    );
  }
}