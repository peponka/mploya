import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/spring_interaction.dart';
import '../screens/onboarding_pitch_screen.dart';
import '../widgets/unsaved_changes_guard.dart';

class CompanyProfileFormScreen extends StatefulWidget {
  const CompanyProfileFormScreen({super.key});

  @override
  State<CompanyProfileFormScreen> createState() => _CompanyProfileFormScreenState();
}

class _CompanyProfileFormScreenState extends State<CompanyProfileFormScreen> {
  final _nombreEmpresaController = TextEditingController();
  final _ubicacionController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _sectoresController = TextEditingController();
  final _buscaController = TextEditingController();
  // ── Nuevos campos ──
  final _tamanoController = TextEditingController();
  final _culturaController = TextEditingController();
  final _beneficiosController = TextEditingController();
  final _webController = TextEditingController();
  final _fundadaController = TextEditingController();
  final _stackController = TextEditingController();

  bool _isLoading = false;

  // Tipo de empresa
  int _tipoIndex = 0;
  final _tipos = ['Startup', 'Scaleup', 'Corporación', 'Agencia/HR'];

  // Modalidad contratación
  int _modalidadIndex = 0;
  final _modalidades = ['Remoto', 'Híbrido', 'Presencial', 'Global'];

  Future<void> _saveCompanyProfile() async {
    final nombre = _nombreEmpresaController.text.trim();
    if (nombre.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Completar datos'),
          content: const Text('Por favor, ingresa al menos el nombre de tu empresa.'),
          actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final descripcion = _descripcionController.text.trim();
        final sectoresStr = _sectoresController.text.trim();
        final busca = _buscaController.text.trim();
        final ubicacion = _ubicacionController.text.trim();
        final tamano = _tamanoController.text.trim();
        final cultura = _culturaController.text.trim();
        final beneficios = _beneficiosController.text.trim();
        final web = _webController.text.trim();
        final fundada = _fundadaController.text.trim();
        final stack = _stackController.text.trim();

        List<String> cleanTags = sectoresStr
            .split(',')
            .map((t) => t.trim().replaceAll('#', ''))
            .where((t) => t.isNotEmpty)
            .toList();

        final String locationText = ubicacion.isEmpty ? 'Sede Global' : ubicacion;
        final String finalAbout = descripcion.isEmpty ? 'Buscando talento en Mploya.' : descripcion;

        // Construir about enriquecido
        final aboutParts = <String>[finalAbout];
        aboutParts.add('\n──────────────');
        aboutParts.add('🏢 Tipo: ${_tipos[_tipoIndex]}');
        if (tamano.isNotEmpty) aboutParts.add('👥 Tamaño: $tamano empleados');
        if (fundada.isNotEmpty) aboutParts.add('📅 Fundada: $fundada');
        aboutParts.add('📍 Ubicación: $locationText');
        aboutParts.add('🏠 Modalidad: ${_modalidades[_modalidadIndex]}');
        if (web.isNotEmpty) aboutParts.add('🌐 Web: $web');
        if (stack.isNotEmpty) aboutParts.add('\n⚡ Tech Stack: $stack');
        if (cultura.isNotEmpty) aboutParts.add('\n🎯 Cultura: $cultura');
        if (beneficios.isNotEmpty) aboutParts.add('\n🎁 Beneficios: $beneficios');

        await Supabase.instance.client.from('users').update({
          'account_type': 'empresa',
          'company': nombre,
          'onboarding_step': 2,
          'name': nombre,
          'headline': busca.isNotEmpty ? busca : 'Reclutador Corporativo',
          'about': aboutParts.join('\n'),
          'tags': cleanTags.isNotEmpty ? cleanTags : null,
          'is_hiring': true,
        }).eq('id', user.id);
      }
      if (!mounted) return;
      
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => const OnboardingPitchScreen(isCompany: true)),
      );
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('No se pudo guardar el perfil: $e'),
            actions: [
              CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(ctx))
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nombreEmpresaController.dispose();
    _ubicacionController.dispose();
    _descripcionController.dispose();
    _sectoresController.dispose();
    _buscaController.dispose();
    _tamanoController.dispose();
    _culturaController.dispose();
    _beneficiosController.dispose();
    _webController.dispose();
    _fundadaController.dispose();
    _stackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      hasUnsavedChanges: () => _nombreEmpresaController.text.trim().isNotEmpty || _descripcionController.text.trim().isNotEmpty,
      child: CupertinoPageScaffold(
        backgroundColor: MployaTheme.lightBg,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: MployaTheme.lightNavBar,
        border: null,
        middle: Text(
          'Perfil Institucional',
          style: TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w700),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Banner ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      MployaTheme.brandAccent.withValues(alpha: 0.15),
                      NexTheme.brandAccent.withValues(alpha: 0.1),
                    ],
                  ),
                  border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(CupertinoIcons.building_2_fill, color: MployaTheme.brandAccent, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Modo Organización', style: TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w700, fontSize: 16)),
                          SizedBox(height: 4),
                          Text('Cuanto más completo, más confianza genera tu marca empleadora en los candidatos.', style: TextStyle(color: MployaTheme.lightSecondary, fontSize: 13, height: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Sección 1: Identidad de Marca ──
              _sectionHeader('🏢', 'Identidad de Marca'),
              const SizedBox(height: 12),
              _buildField(
                controller: _nombreEmpresaController,
                label: 'Nombre de la Organización *',
                placeholder: 'Ej: Google, Spotify, Mploya...',
                icon: CupertinoIcons.building_2_fill,
              ),
              const SizedBox(height: 16),
              // Tipo de empresa
              const Text('Tipo de Organización', style: TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _tipoIndex,
                  backgroundColor: MployaTheme.lightCard,
                  thumbColor: MployaTheme.brandAccent,
                  children: {
                    0: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                      child: Text('🚀 Startup', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _tipoIndex == 0 ? Colors.white : MployaTheme.lightText)),
                    ),
                    1: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                      child: Text('📈 Scaleup', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _tipoIndex == 1 ? Colors.white : MployaTheme.lightText)),
                    ),
                    2: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                      child: Text('🏛️ Corp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _tipoIndex == 2 ? Colors.white : MployaTheme.lightText)),
                    ),
                    3: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                      child: Text('🎯 HR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _tipoIndex == 3 ? Colors.white : MployaTheme.lightText)),
                    ),
                  },
                  onValueChanged: (val) => setState(() => _tipoIndex = val ?? 0),
                ),
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _fundadaController,
                label: 'Año de Fundación',
                placeholder: 'Ej: 2018',
                icon: CupertinoIcons.calendar,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _webController,
                label: 'Sitio Web',
                placeholder: 'Ej: https://tuempresa.com',
                icon: CupertinoIcons.globe,
                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 28),
              // ── Sección 2: Lo que ofrecen ──
              _sectionHeader('🎯', 'Propuesta de Valor'),
              const SizedBox(height: 12),
              _buildField(
                controller: _descripcionController,
                label: '¿Qué hace tu empresa?',
                placeholder: 'Ej: Somos una fintech escalando en LatAm que democratiza la inversión...',
                icon: CupertinoIcons.doc_text_fill,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _culturaController,
                label: 'Cultura y Valores',
                placeholder: 'Ej: Innovación, autonomía, ownership, data-driven',
                icon: CupertinoIcons.heart_fill,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _beneficiosController,
                label: 'Beneficios y Perks',
                placeholder: 'Ej: Equity, gimnasio, home office, vacas ilimitadas',
                icon: CupertinoIcons.gift_fill,
                maxLines: 2,
              ),

              const SizedBox(height: 28),
              // ── Sección 3: Búsqueda Activa ──
              _sectionHeader('🔍', 'Búsqueda de Talento'),
              const SizedBox(height: 12),
              _buildField(
                controller: _buscaController,
                label: '¿Qué perfiles buscan?',
                placeholder: 'Ej: Buscamos Ing. Senior y C-Level en US',
                icon: CupertinoIcons.person_2_fill,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _tamanoController,
                label: 'Tamaño del Equipo',
                placeholder: 'Ej: 50-200 personas',
                icon: CupertinoIcons.group_solid,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _stackController,
                label: 'Tech Stack / Herramientas',
                placeholder: 'Ej: React, Node.js, AWS, Figma, Notion',
                icon: CupertinoIcons.wrench_fill,
              ),
              const SizedBox(height: 16),
              // Modalidad
              const Text('Modalidad de Contratación', style: TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w600, fontSize: 14)),
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
                      child: Text('🌍 Global', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _modalidadIndex == 3 ? Colors.white : MployaTheme.lightText)),
                    ),
                  },
                  onValueChanged: (val) => setState(() => _modalidadIndex = val ?? 0),
                ),
              ),

              const SizedBox(height: 28),
              // ── Sección 4: Ubicación e Industrias ──
              _sectionHeader('📍', 'Ubicación e Industrias'),
              const SizedBox(height: 12),
              _buildField(
                controller: _ubicacionController,
                label: 'Sede / Ciudad',
                placeholder: 'Ej: Buenos Aires, Miami, Londres',
                icon: CupertinoIcons.location_fill,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _sectoresController,
                label: 'Industrias / Tags (separados por coma)',
                placeholder: 'Ej: IT, Finanzas, Blockchain, SaaS',
                icon: CupertinoIcons.tag_fill,
              ),

              const SizedBox(height: 48),
              // ── Botón Guardar ──
              SpringInteraction(
                onTap: _saveCompanyProfile,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: MployaTheme.brandAccent,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(color: MployaTheme.brandAccent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _isLoading 
                    ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                    : const Text(
                        'Continuar al Video-Pitch →',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
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