import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/features/auth/providers/auth_provider.dart';

/// Settings screen with account, notifications, and app preferences.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // ─── Notification toggle state ──────────────────────────────────
  bool _pushEnabled = true;
  bool _emailEnabled = true;
  bool _matchAlerts = true;
  bool _messageAlerts = false;

  // ─── Appearance state ───────────────────────────────────────────
  String _selectedTheme = 'Sistema';
  String _selectedLanguage = 'Español';

  // ─── Dialogs ────────────────────────────────────────────────────

  Future<void> _showChangePasswordDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Cambiar contraseña',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Nueva contraseña',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada ✓'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showChangeEmailDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Cambiar email',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Nuevo email',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email actualizado ✓'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Política de privacidad',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Text(
            'En mploya nos comprometemos a proteger tu privacidad. '
            'Recopilamos únicamente la información necesaria para '
            'brindarte una experiencia personalizada de búsqueda de '
            'empleo. Tus datos personales nunca serán vendidos a '
            'terceros.\n\n'
            'Utilizamos medidas de seguridad estándar de la industria '
            'para proteger tu información. Puedes solicitar la '
            'eliminación de tus datos en cualquier momento desde la '
            'configuración de tu cuenta.\n\n'
            'Para más información, contáctanos a soporte@mploya.com.',
            style: GoogleFonts.inter(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Términos y condiciones',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Text(
            'Al utilizar mploya aceptas los siguientes términos:\n\n'
            '1. Debes ser mayor de 18 años para crear una cuenta.\n'
            '2. La información que proporcionas debe ser veraz.\n'
            '3. No está permitido publicar contenido ofensivo o '
            'discriminatorio.\n'
            '4. mploya se reserva el derecho de suspender cuentas que '
            'violen estas condiciones.\n'
            '5. El servicio se proporciona "tal cual" sin garantías '
            'expresas o implícitas.\n\n'
            'Última actualización: mayo 2026.',
            style: GoogleFonts.inter(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRatingDialog() async {
    int selectedStars = 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Calificar la app',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¿Cómo calificarías tu experiencia?',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  return IconButton(
                    icon: Icon(
                      starIndex <= selectedStars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 36,
                      color: starIndex <= selectedStars
                          ? Colors.amber
                          : Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      setDialogState(() => selectedStars = starIndex);
                    },
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: selectedStars > 0
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gracias por calificar ⭐'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showThemeSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    const options = ['Sistema', 'Claro', 'Oscuro'];
    showDialog(
      context: context,
      builder: (ctx) {
        String tempTheme = _selectedTheme;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(
              'Seleccionar tema',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: options
                  .map(
                    (option) => RadioListTile<String>(
                      title: Text(option, style: GoogleFonts.inter()),
                      value: option,
                      groupValue: tempTheme,
                      activeColor: colorScheme.primary,
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => tempTheme = v);
                        }
                      },
                    ),
                  )
                  .toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  setState(() => _selectedTheme = tempTheme);
                  Navigator.pop(ctx);
                },
                child: const Text('Aplicar'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLanguageSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    const options = ['Español', 'English', 'Português'];
    showDialog(
      context: context,
      builder: (ctx) {
        String tempLang = _selectedLanguage;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(
              'Seleccionar idioma',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: options
                  .map(
                    (option) => RadioListTile<String>(
                      title: Text(option, style: GoogleFonts.inter()),
                      value: option,
                      groupValue: tempLang,
                      activeColor: colorScheme.primary,
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => tempLang = v);
                        }
                      },
                    ),
                  )
                  .toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  setState(() => _selectedLanguage = tempLang);
                  Navigator.pop(ctx);
                },
                child: const Text('Aplicar'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Configuración',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Account section
          _SectionTitle(title: 'Cuenta', colorScheme: colorScheme),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: 'Editar perfil',
                  onTap: () => context.push('/profile/edit'),
                  colorScheme: colorScheme,
                ),
                _Divider(colorScheme: colorScheme),
                _SettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Cambiar contraseña',
                  onTap: _showChangePasswordDialog,
                  colorScheme: colorScheme,
                ),
                _Divider(colorScheme: colorScheme),
                _SettingsTile(
                  icon: Icons.email_outlined,
                  title: 'Cambiar email',
                  onTap: _showChangeEmailDialog,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Notifications section
          _SectionTitle(title: 'Notificaciones', colorScheme: colorScheme),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                _SettingsSwitch(
                  icon: Icons.notifications_outlined,
                  title: 'Push notifications',
                  value: _pushEnabled,
                  onChanged: (v) => setState(() => _pushEnabled = v),
                  colorScheme: colorScheme,
                ),
                _Divider(colorScheme: colorScheme),
                _SettingsSwitch(
                  icon: Icons.email_outlined,
                  title: 'Notificaciones por email',
                  value: _emailEnabled,
                  onChanged: (v) => setState(() => _emailEnabled = v),
                  colorScheme: colorScheme,
                ),
                _Divider(colorScheme: colorScheme),
                _SettingsSwitch(
                  icon: Icons.work_outline,
                  title: 'Alertas de nuevos empleos',
                  value: _matchAlerts,
                  onChanged: (v) => setState(() => _matchAlerts = v),
                  colorScheme: colorScheme,
                ),
                _Divider(colorScheme: colorScheme),
                _SettingsSwitch(
                  icon: Icons.chat_bubble_outline,
                  title: 'Sonidos de mensajes',
                  value: _messageAlerts,
                  onChanged: (v) => setState(() => _messageAlerts = v),
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Appearance section
          _SectionTitle(title: 'Apariencia', colorScheme: colorScheme),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Tema',
                  trailing: Text(
                    _selectedTheme,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: _showThemeSelector,
                  colorScheme: colorScheme,
                ),
                _Divider(colorScheme: colorScheme),
                _SettingsTile(
                  icon: Icons.language_outlined,
                  title: 'Idioma',
                  trailing: Text(
                    _selectedLanguage,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: _showLanguageSelector,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // About section
          _SectionTitle(title: 'Acerca de', colorScheme: colorScheme),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'Versión',
                  trailing: Text(
                    '1.0.0+1',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('mploya v1.0.0+1'), behavior: SnackBarBehavior.floating),
                    );
                  },
                  colorScheme: colorScheme,
                ),
                _Divider(colorScheme: colorScheme),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Política de privacidad',
                  onTap: _showPrivacyPolicyDialog,
                  colorScheme: colorScheme,
                ),
                _Divider(colorScheme: colorScheme),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Términos y condiciones',
                  onTap: _showTermsDialog,
                  colorScheme: colorScheme,
                ),
                _Divider(colorScheme: colorScheme),
                _SettingsTile(
                  icon: Icons.star_outline,
                  title: 'Calificar la app',
                  onTap: _showRatingDialog,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Danger zone
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            color: colorScheme.error.withValues(alpha: 0.05),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Cerrar sesión',
                  iconColor: colorScheme.error,
                  titleColor: colorScheme.error,
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Cerrar sesión'),
                        content: const Text(
                          '¿Estás seguro que quieres cerrar sesión?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Cerrar sesión'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await ref.read(authProvider.notifier).signOut();
                      if (context.mounted) context.go('/landing');
                    }
                  },
                  colorScheme: colorScheme,
                ),
                _Divider(colorScheme: colorScheme),
                _SettingsTile(
                  icon: Icons.delete_forever_outlined,
                  title: 'Eliminar cuenta',
                  iconColor: colorScheme.error,
                  titleColor: colorScheme.error,
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Eliminar cuenta'),
                        content: const Text(
                          '¿Estás seguro? Esta acción es irreversible y se perderán todos tus datos.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cuenta eliminada (demo)'), behavior: SnackBarBehavior.floating),
                      );
                      context.go('/landing');
                    }
                  },
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.colorScheme});
  final String title;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.colorScheme,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });
  final IconData icon;
  final String title;
  final ColorScheme colorScheme;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? colorScheme.primary),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: titleColor ?? colorScheme.onSurface,
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.colorScheme,
  });
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 56,
      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }
}
