import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

/// Pantalla de onboarding para candidatos.
///
/// Recopila información profesional del candidato:
/// nombre, teléfono, ubicación, profesión, experiencia,
/// educación, habilidades, disponibilidad y salario esperado.
class CandidateFormScreen extends ConsumerStatefulWidget {
  const CandidateFormScreen({super.key});

  @override
  ConsumerState<CandidateFormScreen> createState() =>
      _CandidateFormScreenState();
}

class _CandidateFormScreenState extends ConsumerState<CandidateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _professionController = TextEditingController();
  final _skillsController = TextEditingController();
  final _salaryController = TextEditingController();

  String? _selectedExperience;
  String? _selectedEducation;
  String? _selectedAvailability;

  static const _experienceOptions = [
    'Sin experiencia',
    '1-2 años',
    '3-5 años',
    '5-10 años',
    '+10 años',
  ];

  static const _educationOptions = [
    'Secundario',
    'Terciario',
    'Universitario',
    'Posgrado',
  ];

  static const _availabilityOptions = [
    'Inmediata',
    '2 semanas',
    '1 mes',
    'Negociable',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _professionController.dispose();
    _skillsController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    if (!_formKey.currentState!.validate()) return;
    context.go('/onboarding/video');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/landing'),
        ),
        title: Text(
          'Perfil Candidato',
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
                  horizontal: AppSpacing.lg,
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

                      // Nombre completo
                      _buildLabel('Nombre completo'),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Ej: María García López',
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            color: MployaColors.textTertiary,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresá tu nombre completo';
                          }
                          if (v.trim().length < 3) {
                            return 'El nombre debe tener al menos 3 caracteres';
                          }
                          return null;
                        },
                      ).animate().fadeIn(duration: 400.ms, delay: 50.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: AppSpacing.md),

                      // Teléfono
                      _buildLabel('Teléfono'),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[\d\s\+\-\(\)]'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          hintText: '+54 11 1234-5678',
                          prefixIcon: Icon(
                            Icons.phone_outlined,
                            color: MployaColors.textTertiary,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresá tu número de teléfono';
                          }
                          return null;
                        },
                      ).animate().fadeIn(duration: 400.ms, delay: 100.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: AppSpacing.md),

                      // Ubicación
                      _buildLabel('Ubicación'),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _locationController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Ej: Buenos Aires, Argentina',
                          prefixIcon: Icon(
                            Icons.location_on_outlined,
                            color: MployaColors.textTertiary,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresá tu ciudad y país';
                          }
                          return null;
                        },
                      ).animate().fadeIn(duration: 400.ms, delay: 150.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: AppSpacing.md),

                      // Profesión / Título
                      _buildLabel('Profesión / Título'),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _professionController,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Ej: Desarrollador Full Stack',
                          prefixIcon: Icon(
                            Icons.work_outline_rounded,
                            color: MployaColors.textTertiary,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresá tu profesión o título';
                          }
                          return null;
                        },
                      ).animate().fadeIn(duration: 400.ms, delay: 200.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: AppSpacing.md),

                      // Experiencia
                      _buildLabel('Experiencia'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildDropdown(
                        value: _selectedExperience,
                        hint: 'Seleccioná tu experiencia',
                        icon: Icons.timeline_rounded,
                        items: _experienceOptions,
                        onChanged: (v) =>
                            setState(() => _selectedExperience = v),
                        validator: (v) {
                          if (v == null) return 'Seleccioná tu experiencia';
                          return null;
                        },
                      ).animate().fadeIn(duration: 400.ms, delay: 250.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: AppSpacing.md),

                      // Educación
                      _buildLabel('Educación'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildDropdown(
                        value: _selectedEducation,
                        hint: 'Seleccioná tu nivel educativo',
                        icon: Icons.school_outlined,
                        items: _educationOptions,
                        onChanged: (v) =>
                            setState(() => _selectedEducation = v),
                        validator: (v) {
                          if (v == null) return 'Seleccioná tu nivel educativo';
                          return null;
                        },
                      ).animate().fadeIn(duration: 400.ms, delay: 300.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: AppSpacing.md),

                      // Habilidades principales
                      _buildLabel('Habilidades principales'),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _skillsController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Ej: Flutter, React, Diseño UI',
                          prefixIcon: Icon(
                            Icons.star_outline_rounded,
                            color: MployaColors.textTertiary,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresá al menos una habilidad';
                          }
                          return null;
                        },
                      ).animate().fadeIn(duration: 400.ms, delay: 350.ms)
                          .slideY(begin: 0.1, end: 0),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AppSpacing.md,
                          top: AppSpacing.xs,
                        ),
                        child: Text(
                          'Separadas por coma',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: MployaColors.textTertiary,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Disponibilidad
                      _buildLabel('Disponibilidad'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildDropdown(
                        value: _selectedAvailability,
                        hint: 'Seleccioná tu disponibilidad',
                        icon: Icons.access_time_rounded,
                        items: _availabilityOptions,
                        onChanged: (v) =>
                            setState(() => _selectedAvailability = v),
                        validator: (v) {
                          if (v == null) return 'Seleccioná tu disponibilidad';
                          return null;
                        },
                      ).animate().fadeIn(duration: 400.ms, delay: 400.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: AppSpacing.md),

                      // Salario esperado
                      _buildLabel('Salario esperado'),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _salaryController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[\d\.,]'),
                          ),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Ej: 150000',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.md,
                              right: AppSpacing.sm,
                            ),
                            child: Text(
                              '\$',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: MployaColors.textSecondary,
                              ),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 0,
                            minHeight: 0,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresá tu salario esperado';
                          }
                          return null;
                        },
                      ).animate().fadeIn(duration: 400.ms, delay: 450.ms)
                          .slideY(begin: 0.1, end: 0),

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
              decoration: const BoxDecoration(
                color: MployaColors.white,
                border: Border(
                  top: BorderSide(color: MployaColors.borderLight),
                ),
              ),
              child: MployaButton(
                label: 'Continuar',
                onPressed: _handleContinue,
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 500.ms)
                .slideY(begin: 0.3, end: 0),
          ],
        ),
      ),
    );
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

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required FormFieldValidator<String> validator,
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
      validator: validator,
    );
  }
}

// ─── Step Indicator ──────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paso 1 de 2',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: MployaColors.orange,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: 0.5,
            minHeight: 4,
            backgroundColor: MployaColors.borderLight,
            color: MployaColors.orange,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Completá tu perfil para que las empresas te encuentren',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MployaColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
