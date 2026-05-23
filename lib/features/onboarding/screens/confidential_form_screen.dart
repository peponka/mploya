import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/features/feed/providers/feed_provider.dart';

/// Pantalla de onboarding confidencial para candidatos.
///
/// Protege la identidad del candidato: las empresas solo ven
/// experiencia y habilidades, nunca el nombre completo.
/// Incluye: nombre (sin apellido), empresa actual, cargo, experiencia,
/// industria, habilidades, qué busca, rango salarial, disponibilidad e idiomas.
class ConfidentialFormScreen extends ConsumerStatefulWidget {
  const ConfidentialFormScreen({super.key});

  @override
  ConsumerState<ConfidentialFormScreen> createState() =>
      _ConfidentialFormScreenState();
}

class _ConfidentialFormScreenState
    extends ConsumerState<ConfidentialFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Section 1: Identidad Blind
  final _nameController = TextEditingController();
  final _titularController = TextEditingController();
  final _empresaRefController = TextEditingController();

  // Section 2: Trayectoria
  final _experienceController = TextEditingController();
  final _logrosController = TextEditingController();
  final _languagesController = TextEditingController();

  // Section 3: Preferencias Laborales
  final _salaryController = TextEditingController();
  final _zonaController = TextEditingController();

  // Section 4: Keywords
  final _skillsController = TextEditingController();

  // Modality selection
  int _selectedModality = 0;
  static const _modalityOptions = [
    ('🏠', 'Remoto'),
    ('🏢', 'Híbrido'),
    ('🏛️', 'Oficina'),
    ('✈️', 'Reloc.'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _titularController.dispose();
    _empresaRefController.dispose();
    _experienceController.dispose();
    _logrosController.dispose();
    _languagesController.dispose();
    _salaryController.dispose();
    _zonaController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    if (!_formKey.currentState!.validate()) return;

    // Save form data to providers for the feed
    final keywords = _skillsController.text
        .split(',')
        .map((k) => '#${k.trim()}')
        .where((k) => k.length > 1)
        .toList();
    ref.read(userHashtagsProvider.notifier).state = keywords;
    ref.read(userStealthTitleProvider.notifier).state =
        _titularController.text.trim();
    ref.read(userStealthNameProvider.notifier).state =
        _nameController.text.trim();
    ref.read(userCompanyProvider.notifier).state =
        _empresaRefController.text.trim();

    context.go('/onboarding/video');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.background,
      appBar: AppBar(
        backgroundColor: MployaColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/landing'),
        ),
        title: Text(
          'Tráiler Confidencial',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MployaColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Contenido scrolleable ───────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.md),

                      // ── Stealth Banner ──
                      _buildStealthBanner()
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideY(begin: -0.15, end: 0),

                      const SizedBox(height: AppSpacing.lg),

                      // ─── Section 1: Identidad Blind ─────────
                      _buildSectionTitle('🥸', 'Identidad Blind', 0),

                      const SizedBox(height: AppSpacing.md),

                      _buildFieldCard(
                        label: 'Seudónimo o Nombre Real',
                        child: _buildTextField(
                          controller: _nameController,
                          hint: 'Ej: Martín (o un alias creativo)',
                          icon: Icons.person_outline_rounded,
                          textCapitalization: TextCapitalization.words,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresá tu nombre o alias';
                            }
                            return null;
                          },
                        ),
                        delay: 100,
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      _buildFieldCard(
                        label: 'Titular Blind (tu puesto objetivo)',
                        child: _buildTextField(
                          controller: _titularController,
                          hint: 'Ej: VP Engineering, CTO Fintech',
                          icon: Icons.work_outline_rounded,
                          textCapitalization: TextCapitalization.words,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresá tu titular blind';
                            }
                            return null;
                          },
                        ),
                        delay: 150,
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      _buildFieldCard(
                        label: 'Empresa Referencia (Opcional)',
                        child: _buildTextField(
                          controller: _empresaRefController,
                          hint: 'Ej: Ex-MercadoLibre / Actual Globant',
                          icon: Icons.business_outlined,
                          textCapitalization: TextCapitalization.words,
                        ),
                        delay: 200,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ─── Section 2: Trayectoria ─────────────
                      _buildSectionTitle('📊', 'Trayectoria', 1),

                      const SizedBox(height: AppSpacing.md),

                      _buildFieldCard(
                        label: 'Años de Experiencia',
                        child: _buildTextField(
                          controller: _experienceController,
                          hint: 'Ej: 12',
                          icon: Icons.bar_chart_rounded,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresá tus años de experiencia';
                            }
                            return null;
                          },
                        ),
                        delay: 250,
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      _buildFieldCard(
                        label: 'Logros Clave (tus hitos más importantes)',
                        child: _buildTextField(
                          controller: _logrosController,
                          hint:
                              'Ej: Escalé equipo de 5 a 80 devs, Exit de USD 20M',
                          icon: Icons.star_outline_rounded,
                          maxLines: 3,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Contanos tus logros clave';
                            }
                            return null;
                          },
                        ),
                        delay: 300,
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      _buildFieldCard(
                        label: 'Idiomas',
                        child: _buildTextField(
                          controller: _languagesController,
                          hint: 'Ej: Español nativo, Inglés avanzado',
                          icon: Icons.language_rounded,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresá al menos un idioma';
                            }
                            return null;
                          },
                        ),
                        delay: 350,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ─── Section 3: Preferencias Laborales ──
                      _buildSectionTitle(
                          '💼', 'Preferencias Laborales', 2),

                      const SizedBox(height: AppSpacing.md),

                      _buildFieldCard(
                        label: 'Expectativa Salarial (USD/año)',
                        child: _buildTextField(
                          controller: _salaryController,
                          hint: 'Ej: 80K-120K USD',
                          icon: Icons.attach_money_rounded,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresá tu expectativa salarial';
                            }
                            return null;
                          },
                        ),
                        delay: 400,
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      // Modality segmented control
                      _buildFieldCard(
                        label: 'Modalidad Preferida',
                        child: _buildModalitySelector(),
                        delay: 450,
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      _buildFieldCard(
                        label: 'Zona / Ciudad (para matches locales)',
                        child: _buildTextField(
                          controller: _zonaController,
                          hint: 'Ej: Buenos Aires, Miami, Remote LatAm',
                          icon: Icons.navigation_outlined,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresá tu zona o ciudad';
                            }
                            return null;
                          },
                        ),
                        delay: 500,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ─── Section 4: Keywords para IA ────────
                      _buildSectionTitle('🏷️', 'Keywords para IA', 3),

                      const SizedBox(height: AppSpacing.md),

                      _buildFieldCard(
                        label: 'Skills y Keywords (separadas por coma)',
                        child: _buildTextField(
                          controller: _skillsController,
                          hint:
                              'Ej: leadership, fintech, agile, python, aws',
                          icon: Icons.label_outline_rounded,
                          maxLines: 2,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresá al menos un keyword';
                            }
                            return null;
                          },
                        ),
                        delay: 550,
                      ),

                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Botón fijo abajo ────────────────────────────
            _buildBottomCTA()
                .animate()
                .fadeIn(duration: 500.ms, delay: 600.ms)
                .slideY(begin: 0.3, end: 0),
          ],
        ),
      ),
    );
  }

  // ─── Stealth Banner ──────────────────────────────────────────────

  Widget _buildStealthBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: MployaColors.orange.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modo Stealth Activado',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Tu identidad permanece en bóveda. Cuanto más completes, mejores serán tus matches IA.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Title ───────────────────────────────────────────────

  Widget _buildSectionTitle(String emoji, String title, int index) {
    return Row(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MployaColors.textPrimary,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (80 + index * 50).ms)
        .slideX(begin: -0.1, end: 0);
  }

  // ─── Field Card ──────────────────────────────────────────────────

  Widget _buildFieldCard({
    required String label,
    required Widget child,
    int delay = 0,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MployaColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: MployaColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MployaColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: delay.ms)
        .slideY(begin: 0.08, end: 0);
  }

  // ─── Text Field Builder ──────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    FormFieldValidator<String>? validator,
  }) {
    final isMultiline = maxLines > 1;

    return TextFormField(
      controller: controller,
      textCapitalization: textCapitalization,
      textInputAction:
          isMultiline ? TextInputAction.newline : TextInputAction.next,
      keyboardType:
          isMultiline ? TextInputType.multiline : keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      style: GoogleFonts.inter(
        fontSize: 15,
        color: MployaColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: MployaColors.textTertiary,
        ),
        prefixIcon: Padding(
          padding: EdgeInsets.only(
            bottom: isMultiline ? (maxLines - 1) * 20.0 : 0,
          ),
          child: Icon(
            icon,
            color: MployaColors.textTertiary.withValues(alpha: 0.6),
            size: 20,
          ),
        ),
        filled: true,
        fillColor: MployaColors.surfaceVariant.withValues(alpha: 0.5),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: isMultiline ? AppSpacing.md : AppSpacing.sm + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
              isMultiline ? AppRadius.lg : AppRadius.pill),
          borderSide: const BorderSide(color: MployaColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
              isMultiline ? AppRadius.lg : AppRadius.pill),
          borderSide: const BorderSide(color: MployaColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
              isMultiline ? AppRadius.lg : AppRadius.pill),
          borderSide: const BorderSide(
            color: MployaColors.orange,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
              isMultiline ? AppRadius.lg : AppRadius.pill),
          borderSide: const BorderSide(color: MployaColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
              isMultiline ? AppRadius.lg : AppRadius.pill),
          borderSide: const BorderSide(color: MployaColors.red, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  // ─── Modality Segmented Control ──────────────────────────────────

  Widget _buildModalitySelector() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: MployaColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: List.generate(_modalityOptions.length, (index) {
          final isSelected = _selectedModality == index;
          final option = _modalityOptions[index];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedModality = index);
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? MployaColors.orange : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color:
                                MployaColors.orange.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.$1,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.$2,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : MployaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Bottom CTA Button ───────────────────────────────────────────

  Widget _buildBottomCTA() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: MployaColors.background,
        border: const Border(
          top: BorderSide(color: MployaColors.borderLight),
        ),
      ),
      child: GestureDetector(
        onTap: _handleContinue,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFF97316), // Orange
                Color(0xFFE040FB), // Purple/Violet
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF97316).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: const Color(0xFFE040FB).withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(4, 6),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Activar Modo Stealth',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Text(
                  '→',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
