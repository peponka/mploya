import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/features/auth/providers/auth_provider.dart';
import 'package:mploya/features/auth/services/auth_service.dart';
import 'package:mploya/features/profile/models/company_profile_store.dart';

/// Edit Profile screen with form fields for user information.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _headlineController = TextEditingController();
  final _locationController = TextEditingController();
  final _isCompany = CompanyProfileStore.isCompany;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final profile = ref.read(currentProfileProvider);
    if (profile != null) {
      _nameController.text = profile.fullName ?? '';
      _phoneController.text = profile.phone ?? '';
      _bioController.text = profile.bio ?? '';
      _headlineController.text = profile.headline ?? '';
      _locationController.text = profile.location ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _headlineController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.instance.updateProfile({
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'bio': _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        'headline': _headlineController.text.trim().isEmpty
            ? null
            : _headlineController.text.trim(),
        'location': _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
      });

      await ref.read(authProvider.notifier).refreshProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Perfil actualizado correctamente'),
            backgroundColor: const Color(0xFF00B894),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Editar perfil',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleSave,
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                : Text(
                    'Guardar',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          onChanged: () {
            if (!_hasChanges) setState(() => _hasChanges = true);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      profile?.initials ?? 'U',
                      style: GoogleFonts.outfit(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 3,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Selector de foto próximamente'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Form fields
              _buildField(
                controller: _nameController,
                label: _isCompany ? 'Nombre de la empresa' : 'Nombre completo',
                icon: _isCompany ? Icons.business_outlined : Icons.person_outlined,
                required: true,
              ),
              const SizedBox(height: AppSpacing.md),

              _buildField(
                controller: _headlineController,
                label: _isCompany ? 'Industria / Sector' : 'Título profesional',
                icon: Icons.work_outline,
                hint: _isCompany
                    ? 'ej: Tecnología, Fintech...'
                    : 'ej: Desarrollador Flutter Senior',
              ),
              const SizedBox(height: AppSpacing.md),

              _buildField(
                controller: _phoneController,
                label: 'Teléfono',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.md),

              _buildField(
                controller: _locationController,
                label: 'Ubicación',
                icon: Icons.location_on_outlined,
                hint: 'ej: Buenos Aires, Argentina',
              ),
              const SizedBox(height: AppSpacing.md),

              _buildField(
                controller: _bioController,
                label: _isCompany ? 'Descripción de la empresa' : 'Biografía',
                icon: Icons.info_outline,
                hint: _isCompany
                    ? 'Describe tu empresa...'
                    : 'Cuéntanos sobre ti...',
                maxLines: 4,
                maxLength: 500,
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Skills / Tech Stack section – hidden for companies
              if (!_isCompany) ...[
                _buildSectionHeader(
                  'Habilidades',
                  Icons.psychology_outlined,
                  colorScheme,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ...(profile?.skills ?? ['Flutter', 'Dart', 'Firebase']).map(
                      (skill) => Chip(
                        label: Text(skill),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Habilidad "$skill" eliminada'),
                              action: SnackBarAction(
                                label: 'Deshacer',
                                onPressed: () {},
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    ActionChip(
                      label: const Text('+ Agregar'),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) {
                            final controller = TextEditingController();
                            return AlertDialog(
                              title: const Text('Agregar habilidad'),
                              content: TextField(
                                controller: controller,
                                decoration: const InputDecoration(
                                  hintText: 'ej: React, Node.js...',
                                ),
                                autofocus: true,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    if (controller.text.trim().isNotEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Habilidad "${controller.text.trim()}" agregada')),
                                      );
                                    }
                                  },
                                  child: const Text('Agregar'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      avatar: Icon(
                        Icons.add,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              // Experience section – candidates only
              if (!_isCompany) ...[
                _buildSectionHeader(
                  'Experiencia laboral',
                  Icons.business_center_outlined,
                  colorScheme,
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Formulario de experiencia próximamente'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar experiencia'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              // Education section – candidates only
              if (!_isCompany) ...[
                _buildSectionHeader(
                  'Educación',
                  Icons.school_outlined,
                  colorScheme,
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Formulario de educación próximamente'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar educación'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: maxLines > 1
          ? TextCapitalization.sentences
          : TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Este campo es requerido';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
