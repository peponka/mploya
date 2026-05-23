import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/features/profile/models/company_profile_store.dart';

/// Pantalla de onboarding para empresas.
///
/// Recopila información de la empresa: nombre, industria, tamaño,
/// ubicación, sitio web, descripción, perfiles buscados,
/// posiciones abiertas y rango salarial que ofrecen.
class CompanyFormScreen extends ConsumerStatefulWidget {
  const CompanyFormScreen({super.key});

  @override
  ConsumerState<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends ConsumerState<CompanyFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // ─── Section 1: Identidad de Marca ──────────────────────────
  final _nameController = TextEditingController();
  final _websiteController = TextEditingController();
  int _selectedOrgType = 0;
  int? _selectedYear;

  static const _orgTypes = ['Startup', 'Scaleup', 'Corp', 'HR Agency'];

  // ─── Section 2: Propuesta de Valor ──────────────────────────
  final _descriptionController = TextEditingController();
  final _cultureController = TextEditingController();
  final List<String> _selectedValues = [];

  static const _predefinedValues = [
    'Innovación',
    'Diversidad',
    'Colaboración',
    'Agilidad',
    'Impacto Social',
    'Transparencia',
    'Bienestar',
    'Crecimiento',
  ];

  // ─── Section 3: Beneficios y Perks ──────────────────────────
  final Map<String, bool> _perks = {
    'Trabajo remoto': false,
    'Horario flexible': false,
    'Stock options': false,
    'Capacitación': false,
    'Gym': false,
    'Almuerzo': false,
    'Vacaciones extra': false,
    'Bono anual': false,
  };

  static const _perkIcons = {
    'Trabajo remoto': Icons.home_work_outlined,
    'Horario flexible': Icons.schedule_outlined,
    'Stock options': Icons.trending_up_rounded,
    'Capacitación': Icons.school_outlined,
    'Gym': Icons.fitness_center_outlined,
    'Almuerzo': Icons.restaurant_outlined,
    'Vacaciones extra': Icons.beach_access_outlined,
    'Bono anual': Icons.card_giftcard_outlined,
  };

  // ─── Section 4: Búsqueda de Talento ─────────────────────────
  final _profilesTagController = TextEditingController();
  final List<String> _profileTags = [];
  String? _selectedTeamSize;
  final _techStackController = TextEditingController();
  final List<String> _techStackTags = [];
  int _selectedModality = 0;

  static const _teamSizeOptions = [
    '1-10',
    '11-50',
    '51-200',
    '201-500',
    '500+',
  ];

  static const _suggestedTechStack = [
    'React',
    'Flutter',
    'Python',
    'Node.js',
    'TypeScript',
    'Go',
    'Kotlin',
    'Swift',
    'AWS',
    'Docker',
  ];

  static const _modalityOptions = ['Remoto', 'Híbrido', 'Oficina', 'Global'];

  // ─── Section 5: Ubicación e Industria ───────────────────────
  final _locationController = TextEditingController();
  final List<String> _selectedIndustries = [];

  static const _industryTags = [
    'FinTech',
    'EdTech',
    'HealthTech',
    'SaaS',
    'E-commerce',
    'AI/ML',
    'Blockchain',
    'Gaming',
    'CleanTech',
    'InsurTech',
    'LegalTech',
    'FoodTech',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    _cultureController.dispose();
    _profilesTagController.dispose();
    _techStackController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    if (!_formKey.currentState!.validate()) return;

    CompanyProfileStore.store(
      name: _nameController.text.trim(),
      orgType: _orgTypes[_selectedOrgType],
      year: _selectedYear,
      website: _websiteController.text.trim(),
      description: _descriptionController.text.trim(),
      values: List.from(_selectedValues),
      cultureText: _cultureController.text.trim(),
      perks: Map.from(_perks),
      profiles: List.from(_profileTags),
      teamSize: _selectedTeamSize ?? '1-10',
      techStack: List.from(_techStackTags),
      modality: _modalityOptions[_selectedModality],
      location: _locationController.text.trim(),
      industries: List.from(_selectedIndustries),
    );

    context.go('/onboarding/video');
  }

  void _addProfileTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_profileTags.contains(trimmed)) {
      setState(() => _profileTags.add(trimmed));
    }
  }

  void _addTechTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_techStackTags.contains(trimmed)) {
      setState(() => _techStackTags.add(trimmed));
    }
  }

  void _showYearPicker() {
    final currentYear = DateTime.now().year;
    showModalBottomSheet(
      context: context,
      backgroundColor: MployaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      builder: (ctx) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.inter(
                          color: MployaColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      'Año de fundación',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Listo',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: MployaColors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 42,
                  scrollController: FixedExtentScrollController(
                    initialItem: _selectedYear != null
                        ? currentYear - _selectedYear!
                        : 0,
                  ),
                  onSelectedItemChanged: (index) {
                    setState(() => _selectedYear = currentYear - index);
                  },
                  children: List.generate(
                    75,
                    (i) => Center(
                      child: Text(
                        '${currentYear - i}',
                        style: GoogleFonts.inter(fontSize: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.background,
      appBar: AppBar(
        backgroundColor: MployaColors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/landing'),
        ),
        title: Text(
          'Perfil Empresa',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MployaColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Contenido scrolleable ───────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.sm),

                      // Step indicator
                      _StepIndicator()
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: -0.2, end: 0),

                      const SizedBox(height: AppSpacing.lg),

                      // ══════════════════════════════════════════
                      // SECTION 1: Identidad de Marca
                      // ══════════════════════════════════════════
                      _buildSectionCard(
                        index: 0,
                        icon: Icons.branding_watermark_outlined,
                        title: 'Identidad de Marca',
                        children: [
                          // Nombre de la empresa*
                          _buildLabel('Nombre de la empresa *'),
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: 'Ej: mploya.ai',
                              prefixIcon: Icon(
                                Icons.business_rounded,
                                color: MployaColors.textTertiary,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Ingresá el nombre de la empresa';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Tipo de organización
                          _buildLabel('Tipo de organización'),
                          const SizedBox(height: AppSpacing.sm),
                          _buildSegmentedControl(
                            options: _orgTypes,
                            selectedIndex: _selectedOrgType,
                            onChanged: (i) =>
                                setState(() => _selectedOrgType = i),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Año de fundación
                          _buildLabel('Año de fundación'),
                          const SizedBox(height: AppSpacing.sm),
                          GestureDetector(
                            onTap: _showYearPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: MployaColors.border),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    color: MployaColors.textTertiary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      _selectedYear != null
                                          ? '$_selectedYear'
                                          : 'Seleccioná el año',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        color: _selectedYear != null
                                            ? MployaColors.textPrimary
                                            : MployaColors.textTertiary,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: MployaColors.textTertiary,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Sitio web
                          _buildLabel('Sitio web'),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Opcional',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: MployaColors.textTertiary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            controller: _websiteController,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              hintText: 'https://www.ejemplo.com',
                              prefixIcon: Icon(
                                Icons.language_rounded,
                                color: MployaColors.textTertiary,
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Logo placeholder
                          _buildLabel('Logo'),
                          const SizedBox(height: AppSpacing.sm),
                          GestureDetector(
                            onTap: () {
                              // TODO: Implement logo upload
                            },
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: MployaColors.surfaceVariant,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.xl),
                                border: Border.all(
                                  color: MployaColors.border,
                                  width: 1.5,
                                  strokeAlign: BorderSide.strokeAlignInside,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt_outlined,
                                    size: 28,
                                    color: MployaColors.textTertiary,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Subir',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: MployaColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // ══════════════════════════════════════════
                      // SECTION 2: Propuesta de Valor
                      // ══════════════════════════════════════════
                      _buildSectionCard(
                        index: 1,
                        icon: Icons.auto_awesome_outlined,
                        title: 'Propuesta de Valor',
                        children: [
                          // ¿Qué hace tu empresa?
                          _buildLabel('¿Qué hace tu empresa?'),
                          const SizedBox(height: AppSpacing.sm),
                          _buildMultilineField(
                            controller: _descriptionController,
                            hint:
                                'Describí brevemente qué problema resuelve tu empresa...',
                            maxLength: 300,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Ingresá una descripción';
                              }
                              if (v.trim().length < 20) {
                                return 'Mínimo 20 caracteres';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Cultura y Valores
                          _buildLabel('Cultura y Valores'),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: _predefinedValues.map((value) {
                              final selected =
                                  _selectedValues.contains(value);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (selected) {
                                      _selectedValues.remove(value);
                                    } else {
                                      _selectedValues.add(value);
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? MployaColors.orange
                                        : MployaColors.white,
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.pill),
                                    border: Border.all(
                                      color: selected
                                          ? MployaColors.orange
                                          : MployaColors.border,
                                    ),
                                  ),
                                  child: Text(
                                    value,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: selected
                                          ? MployaColors.white
                                          : MployaColors.textPrimary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          _buildMultilineField(
                            controller: _cultureController,
                            hint:
                                'Agregá más sobre tu cultura (opcional)...',
                            maxLength: 200,
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // ══════════════════════════════════════════
                      // SECTION 3: Beneficios y Perks
                      // ══════════════════════════════════════════
                      _buildSectionCard(
                        index: 2,
                        icon: Icons.card_giftcard_outlined,
                        title: 'Beneficios y Perks',
                        children: [
                          ..._perks.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs),
                              child: _buildPerkToggle(
                                label: entry.key,
                                icon: _perkIcons[entry.key] ??
                                    Icons.check_circle_outline,
                                value: entry.value,
                                onChanged: (v) {
                                  setState(
                                      () => _perks[entry.key] = v);
                                },
                              ),
                            );
                          }),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // ══════════════════════════════════════════
                      // SECTION 4: Búsqueda de Talento
                      // ══════════════════════════════════════════
                      _buildSectionCard(
                        index: 3,
                        icon: Icons.person_search_outlined,
                        title: 'Búsqueda de Talento',
                        children: [
                          // Perfiles buscados
                          _buildLabel('Perfiles buscados'),
                          const SizedBox(height: AppSpacing.sm),
                          _buildTagInput(
                            controller: _profilesTagController,
                            tags: _profileTags,
                            hint: 'Ej: Frontend Developer',
                            onAdd: _addProfileTag,
                            onRemove: (t) =>
                                setState(() => _profileTags.remove(t)),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Tamaño del equipo
                          _buildLabel('Tamaño del equipo'),
                          const SizedBox(height: AppSpacing.sm),
                          _buildDropdown(
                            value: _selectedTeamSize,
                            hint: 'Seleccioná el tamaño',
                            icon: Icons.groups_outlined,
                            items: _teamSizeOptions,
                            onChanged: (v) =>
                                setState(() => _selectedTeamSize = v),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Tech Stack
                          _buildLabel('Tech Stack'),
                          const SizedBox(height: AppSpacing.sm),
                          _buildTagInput(
                            controller: _techStackController,
                            tags: _techStackTags,
                            hint: 'Ej: React',
                            onAdd: _addTechTag,
                            onRemove: (t) =>
                                setState(() => _techStackTags.remove(t)),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Sugeridos',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: MployaColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: _suggestedTechStack
                                .where(
                                    (t) => !_techStackTags.contains(t))
                                .map((tag) {
                              return GestureDetector(
                                onTap: () => _addTechTag(tag),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.pill),
                                    border: Border.all(
                                        color: MployaColors.border),
                                  ),
                                  child: Text(
                                    tag,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: MployaColors.textPrimary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Modalidad
                          _buildLabel('Modalidad'),
                          const SizedBox(height: AppSpacing.sm),
                          _buildSegmentedControl(
                            options: _modalityOptions,
                            selectedIndex: _selectedModality,
                            onChanged: (i) =>
                                setState(() => _selectedModality = i),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // ══════════════════════════════════════════
                      // SECTION 5: Ubicación e Industria
                      // ══════════════════════════════════════════
                      _buildSectionCard(
                        index: 4,
                        icon: Icons.location_on_outlined,
                        title: 'Ubicación e Industria',
                        children: [
                          // Sede/Ciudad
                          _buildLabel('Sede / Ciudad'),
                          const SizedBox(height: AppSpacing.sm),
                          TextFormField(
                            controller: _locationController,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: 'Ej: Buenos Aires, Argentina',
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: MployaColors.textTertiary,
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Industria tags
                          _buildLabel('Industria'),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: _industryTags.map((tag) {
                              final selected =
                                  _selectedIndustries.contains(tag);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (selected) {
                                      _selectedIndustries.remove(tag);
                                    } else {
                                      _selectedIndustries.add(tag);
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? MployaColors.orange
                                        : MployaColors.white,
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.pill),
                                    border: Border.all(
                                      color: selected
                                          ? MployaColors.orange
                                          : MployaColors.border,
                                    ),
                                  ),
                                  child: Text(
                                    tag,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: selected
                                          ? MployaColors.white
                                          : MployaColors.textPrimary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Botón fijo abajo ────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: MployaColors.white,
                border: const Border(
                  top: BorderSide(color: MployaColors.borderLight),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: MployaButton(
                label: 'Continuar al Video-Pitch',
                onPressed: _handleContinue,
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 500.ms)
                .slideY(begin: 0.3, end: 0),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────

  Widget _buildSectionCard({
    required int index,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: MployaColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: MployaColors.borderLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: MployaColors.orangeSurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 18, color: MployaColors.orange),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (100 + index * 80).ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: MployaColors.textPrimary,
      ),
    );
  }

  Widget _buildSegmentedControl({
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: MployaColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: List.generate(options.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:
                      selected ? MployaColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  options[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? MployaColors.orange
                        : MployaColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMultilineField({
    required TextEditingController controller,
    required String hint,
    int? maxLength,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.newline,
      maxLines: 4,
      maxLength: maxLength,
      decoration: InputDecoration(
        hintText: hint,
        alignLabelWithHint: true,
        counterStyle: GoogleFonts.inter(
          fontSize: 11,
          color: MployaColors.textTertiary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: const BorderSide(color: MployaColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: const BorderSide(color: MployaColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: const BorderSide(
            color: MployaColors.orange,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: const BorderSide(color: MployaColors.red),
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.md),
      ),
      validator: validator,
    );
  }

  Widget _buildPerkToggle({
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: value
              ? MployaColors.orangeSurface
              : MployaColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: value
                ? MployaColors.orangeLight
                : MployaColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: value
                  ? MployaColors.orange
                  : MployaColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                  color: value
                      ? MployaColors.textPrimary
                      : MployaColors.textSecondary,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 26,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value
                    ? MployaColors.orange
                    : MployaColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: MployaColors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagInput({
    required TextEditingController controller,
    required List<String> tags,
    required String hint,
    required ValueChanged<String> onAdd,
    required ValueChanged<String> onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tags.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: tags.map((tag) {
              return Chip(
                label: Text(
                  tag,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.white,
                  ),
                ),
                backgroundColor: MployaColors.orange,
                deleteIcon: const Icon(
                  Icons.close,
                  size: 16,
                  color: MployaColors.white,
                ),
                onDeleted: () => onRemove(tag),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextFormField(
          controller: controller,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(
              Icons.add_circle_outline,
              color: MployaColors.textTertiary,
            ),
            suffixIcon: IconButton(
              icon: const Icon(
                Icons.send_rounded,
                color: MployaColors.orange,
                size: 20,
              ),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  onAdd(text);
                  controller.clear();
                }
              },
            ),
          ),
          onFieldSubmitted: (value) {
            final text = value.trim();
            if (text.isNotEmpty) {
              onAdd(text);
              controller.clear();
            }
          },
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: MployaColors.textTertiary),
      ),
      hint: Text(
        hint,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: MployaColors.textTertiary,
        ),
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: MployaColors.textTertiary,
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(
                e,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: MployaColors.textPrimary,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ─── Step Indicator ──────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MployaColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: MployaColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: MployaColors.orangeSurface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'Paso 1 de 2',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.orange,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '50%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MployaColors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: 0.5,
              minHeight: 6,
              backgroundColor: MployaColors.borderLight,
              color: MployaColors.orange,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Configurá el perfil de tu empresa',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MployaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
