import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/blind_hiring_service.dart';
import '../services/push_notification_service.dart';
import '../services/revenuecat_service.dart';
import '../services/block_user_service.dart';
import '../services/connectivity_service.dart';
import 'premium_paywall_screen.dart';
import 'admin_dashboard_screen.dart';
import 'splash_screen.dart';
import '../main.dart';

// Claves de persistencia — únicas por preferencia
const _kPushNotif    = 'settings_push_notifications';
const _kEmailNotif   = 'settings_email_notifications';
const _kJobAlerts    = 'settings_job_alerts';
const _kProfileVis   = 'settings_profile_visibility';
const _kDarkMode     = 'settings_dark_mode';
const _kBlindHiring  = 'settings_blind_hiring';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Valores iniciales conservadores hasta que SharedPreferences cargue
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _jobAlerts = true;
  bool _profileVisibility = true;
  String _themeMode = 'light'; // 'auto' | 'light' | 'dark'
  bool _blindHiring = false;
  bool _prefsLoaded = false;
  String _accountType = 'candidato';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkAdmin();
  }

  /// Chequeo aislado de admin (no rompe la carga si falta la columna is_admin).
  Future<void> _checkAdmin() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final row = await Supabase.instance.client
          .from('users')
          .select('is_admin')
          .eq('id', uid)
          .maybeSingle();
      if (mounted && row?['is_admin'] == true) {
        setState(() => _isAdmin = true);
      }
    } catch (_) {/* columna inexistente o sin permisos: no es admin */}
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pushNotifications = prefs.getBool(_kPushNotif)  ?? true;
      _emailNotifications = prefs.getBool(_kEmailNotif) ?? true;
      _jobAlerts          = prefs.getBool(_kJobAlerts)  ?? true;
      _profileVisibility  = prefs.getBool(_kProfileVis) ?? true;
      _themeMode          = readThemeMode(prefs);
      _blindHiring        = prefs.getBool(_kBlindHiring) ?? false;
      _prefsLoaded        = true;
    });
    // Load account type and notification prefs from DB
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final row = await Supabase.instance.client.from('users').select('account_type, blind_hiring_mode, push_enabled, email_notifications_enabled, job_alerts_enabled').eq('id', uid).maybeSingle();
        if (row != null && mounted) {
          setState(() {
            _accountType = row['account_type']?.toString() ?? 'candidato';
            _blindHiring = row['blind_hiring_mode'] == true;
            // Sincronizar con DB (source of truth)
            _pushNotifications = row['push_enabled'] == true;
            _emailNotifications = row['email_notifications_enabled'] == true;
            _jobAlerts = row['job_alerts_enabled'] == true;
          });
          // Actualizar SharedPreferences con los valores del servidor
          final prefs2 = await SharedPreferences.getInstance();
          await prefs2.setBool(_kPushNotif, _pushNotifications);
          await prefs2.setBool(_kEmailNotif, _emailNotifications);
          await prefs2.setBool(_kJobAlerts, _jobAlerts);
        }
      }
    } catch (_) {}
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    
    // Sincronizar preferencias de notificaciones con Supabase
    // para que la Edge Function send-fcm las respete
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      final Map<String, dynamic> updates = {};
      if (key == _kPushNotif) updates['push_enabled'] = value;
      if (key == _kEmailNotif) updates['email_notifications_enabled'] = value;
      if (key == _kJobAlerts) updates['job_alerts_enabled'] = value;
      if (updates.isNotEmpty) {
        try {
          await Supabase.instance.client.from('users').update(updates).eq('id', uid);
        } catch (e) {
          debugPrint('⚠️ Error syncing notification pref to DB: $e');
        }
      }
    }
  }

  Future<void> _signOut() async {
    await PushNotificationService.instance.clearToken();
    await RevenueCatService.instance.logout();
    BlockUserService.instance.clear();
    ConnectivityService.instance.dispose();
    final error = await AuthService.instance.signOut();
    if (!mounted) return;
    if (error != null) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Error al cerrar sesión'),
          content: Text(error),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }
    // Navegar a la pantalla de rol/login eliminando toda la pila de navegación
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Muestra spinner mientras SharedPreferences carga (evita flash de valores incorrectos)
    if (!_prefsLoaded) {
      return const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text('Configuración')),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Configuración'),
      ),
      child: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            const SizedBox(height: 20),

            // ══════ Cuenta ══════
            const _SectionHeader(title: 'CUENTA'),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: CupertinoIcons.person_fill,
                  iconBg: MployaTheme.brandAccent,
                  title: 'Información de cuenta',
                  onTap: _showAccountInfo,
                ),
                _SettingsTile(
                  icon: CupertinoIcons.lock_fill,
                  iconBg: const Color(0xFF5F3DC4),
                  title: 'Contraseña y seguridad',
                  onTap: _showChangePassword,
                ),
              ],
            ),

            // ══════ Privacidad ══════
            const _SectionHeader(title: 'PRIVACIDAD'),
            _SettingsGroup(
              children: [
                _SettingsToggle(
                  icon: CupertinoIcons.eye_fill,
                  iconBg: const Color(0xFF00838F),
                  title: 'Visibilidad de perfil',
                  value: _profileVisibility,
                  onChanged: (v) {
                    setState(() => _profileVisibility = v);
                    _save(_kProfileVis, v);
                  },
                ),
                // ── Blind Hiring (solo para empresas) ──
                if (_accountType == 'empresa' || _accountType == 'headhunter')
                  _SettingsToggle(
                    icon: CupertinoIcons.eye_slash_fill,
                    iconBg: const Color(0xFF5F3DC4),
                    title: 'Contratación a ciegas',
                    value: _blindHiring,
                    onChanged: (v) {
                      setState(() => _blindHiring = v);
                      _save(_kBlindHiring, v);
                      BlindHiringService.instance.toggleBlindMode(v);
                    },
                  ),
                _SettingsTile(
                  icon: CupertinoIcons.doc_text_fill,
                  iconBg: const Color(0xFF666666),
                  title: 'Datos y privacidad',
                  subtitle: 'Política de privacidad',
                  onTap: () => _openUrl('https://mploya.ai/privacy'),
                ),
                _SettingsTile(
                  icon: CupertinoIcons.nosign,
                  iconBg: const Color(0xFFFF3B30),
                  title: 'Usuarios bloqueados',
                  subtitle: '${BlockUserService.instance.blockedIds.length} bloqueados',
                  onTap: _showBlockedUsers,
                ),
              ],
            ),

            // ══════ Notificaciones ══════
            const _SectionHeader(title: 'NOTIFICACIONES'),
            _SettingsGroup(
              children: [
                _SettingsToggle(
                  icon: CupertinoIcons.bell_fill,
                  iconBg: MployaTheme.danger,
                  title: 'Notificaciones push',
                  value: _pushNotifications,
                  onChanged: (v) {
                    setState(() => _pushNotifications = v);
                    _save(_kPushNotif, v);
                  },
                ),
                _SettingsToggle(
                  icon: CupertinoIcons.mail_solid,
                  iconBg: MployaTheme.brandAccent,
                  title: 'Notificaciones por email',
                  value: _emailNotifications,
                  onChanged: (v) {
                    setState(() => _emailNotifications = v);
                    _save(_kEmailNotif, v);
                  },
                ),
                _SettingsToggle(
                  icon: CupertinoIcons.briefcase_fill,
                  iconBg: MployaTheme.brandAccent,
                  title: 'Alertas de trabajo',
                  value: _jobAlerts,
                  onChanged: (v) {
                    setState(() => _jobAlerts = v);
                    _save(_kJobAlerts, v);
                  },
                ),
              ],
            ),

            // ══════ Apariencia ══════
            const _SectionHeader(title: 'APARIENCIA'),
            _SettingsGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFF5F3DC4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(CupertinoIcons.moon_fill, size: 16, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Tema',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoSlidingSegmentedControl<String>(
                          groupValue: _themeMode,
                          children: const {
                            'auto': Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Text('Automático', style: TextStyle(fontSize: 13)),
                            ),
                            'light': Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Text('Claro', style: TextStyle(fontSize: 13)),
                            ),
                            'dark': Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Text('Oscuro', style: TextStyle(fontSize: 13)),
                            ),
                          },
                          onValueChanged: (v) async {
                            if (v == null) return;
                            setState(() => _themeMode = v);
                            applyThemeMode(v); // Actualizar tema global
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString(kThemeModeKey, v);
                            // Mantener el bool viejo sincronizado por compatibilidad
                            await prefs.setBool(_kDarkMode, darkModeNotifier.value);
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Automático sigue la configuración de tu teléfono.',
                        style: TextStyle(fontSize: 12, color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ══════ Premium ══════
            const _SectionHeader(title: 'PREMIUM'),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: CupertinoIcons.star_fill,
                  iconBg: const Color(0xFFD4A843),
                  title: 'Mploya Pro',
                  subtitle: 'Potenciá tu carrera',
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => const PremiumPaywallScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            // ══════ Administración (solo admins) ══════
            if (_isAdmin) ...[
              const _SectionHeader(title: 'ADMINISTRACIÓN'),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: CupertinoIcons.shield_lefthalf_fill,
                    iconBg: MployaTheme.brandAccent,
                    title: 'Panel de administración',
                    subtitle: 'Usuarios, ofertas, reportes y métricas',
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => const AdminDashboardScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],

            // ══════ Soporte ══════
            const _SectionHeader(title: 'SOPORTE'),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: CupertinoIcons.question_circle_fill,
                  iconBg: MployaTheme.brandAccent,
                  title: 'Centro de ayuda',
                  onTap: () => _openUrl('https://mploya.ai/help'),
                ),
                _SettingsTile(
                  icon: CupertinoIcons.chat_bubble_2_fill,
                  iconBg: const Color(0xFF057642),
                  title: 'Contactar soporte',
                  onTap: () => _openUrl('mailto:soporte@mploya.ai'),
                ),
                _SettingsTile(
                  icon: CupertinoIcons.info_circle_fill,
                  iconBg: const Color(0xFF666666),
                  title: 'Acerca de Mploya',
                  subtitle: 'Versión 1.0.0',
                  onTap: _showAbout,
                ),
              ],
            ),

            // ══════ Zona de riesgo ══════
            const SizedBox(height: 20),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: CupertinoIcons.arrow_right_square_fill,
                  iconBg: MployaTheme.danger,
                  title: 'Cerrar sesión',
                  textColor: MployaTheme.danger,
                  onTap: () => _showSignOut(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: CupertinoIcons.trash_fill,
                  iconBg: MployaTheme.danger,
                  title: 'Eliminar cuenta',
                  textColor: MployaTheme.danger,
                  onTap: () => _showDeleteAccount(context),
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Información de cuenta
  // ═══════════════════════════════════════════════════════════════════════════

  void _showAccountInfo() {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'No disponible';
    final provider = user?.appMetadata['provider']?.toString() ?? 'email';
    final createdAt = user?.createdAt ?? '';

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Información de cuenta'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              _InfoRow(label: 'Email', value: email),
              const SizedBox(height: 6),
              _InfoRow(label: 'Proveedor', value: provider == 'email' ? 'Email/Contraseña' : provider.toUpperCase()),
              const SizedBox(height: 6),
              _InfoRow(label: 'Miembro desde', value: createdAt.isNotEmpty ? createdAt.substring(0, 10) : '—'),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Cambiar contraseña
  // ═══════════════════════════════════════════════════════════════════════════

  void _showChangePassword() {
    final newPwCtrl = TextEditingController();
    final confirmPwCtrl = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              const Text(
                'Mínimo 8 caracteres, una mayúscula y un número.',
                style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: newPwCtrl,
                placeholder: 'Nueva contraseña',
                obscureText: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: confirmPwCtrl,
                placeholder: 'Confirmar contraseña',
                obscureText: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              newPwCtrl.dispose();
              confirmPwCtrl.dispose();
            },
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final newPw = newPwCtrl.text;
              final confirmPw = confirmPwCtrl.text;

              if (newPw != confirmPw) {
                _showAlert('Las contraseñas no coinciden.');
                return;
              }

              final error = await AuthService.instance.updatePassword(newPw);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              newPwCtrl.dispose();
              confirmPwCtrl.dispose();

              if (error != null) {
                _showAlert(error);
              } else {
                _showAlert('✅ Contraseña actualizada correctamente.');
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Eliminar cuenta (triple confirmación)
  // ═══════════════════════════════════════════════════════════════════════════

  void _showDeleteAccount(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('¿Eliminar tu cuenta?'),
        content: const Text(
          'Esta acción es PERMANENTE e irreversible.\n\n'
          'Se eliminarán:\n'
          '• Tu perfil y Video-Pitch\n'
          '• Todos tus matches y conexiones\n'
          '• Tus mensajes y notificaciones\n'
          '• Tus vacantes publicadas',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _showDeleteConfirmation2();
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation2() {
    final confirmCtrl = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              const Text(
                'Para confirmar, escribí ELIMINAR en mayúsculas:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: confirmCtrl,
                placeholder: 'ELIMINAR',
                textAlign: TextAlign.center,
                autocorrect: false,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              confirmCtrl.dispose();
            },
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              if (confirmCtrl.text.trim() != 'ELIMINAR') return;
              Navigator.pop(ctx);
              confirmCtrl.dispose();
              _executeDeleteAccount();
            },
            child: const Text('Eliminar para siempre'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDeleteAccount() async {
    // Mostrar loading
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        content: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(radius: 14),
              SizedBox(height: 16),
              Text('Eliminando cuenta...', style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ),
    );

    // Limpiar tokens
    await PushNotificationService.instance.clearToken();
    await RevenueCatService.instance.logout();

    // Eliminar cuenta
    final error = await AuthService.instance.deleteAccount();

    if (!mounted) return;
    Navigator.pop(context); // Cerrar loading

    if (error != null) {
      _showAlert('Error al eliminar cuenta: $error');
    } else {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (_) => const SplashScreen()),
        (_) => false,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  void _showSignOut(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Cerrar sesión'),
        message: const Text('¿Seguro que quieres salir de tu cuenta?'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _signOut();
            },
            child: const Text('Cerrar sesión'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  void _showAbout() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Mploya'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Column(
            children: [
              Text('Versión 1.0.0 (Build 1)'),
              SizedBox(height: 8),
              Text(
                'La red profesional basada en Video-Pitches.\n'
                '© 2026 Mploya. Todos los derechos reservados.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) _showAlert('No se pudo abrir: $url');
    }
  }

  void _showBlockedUsers() async {
    final blocked = await BlockUserService.instance.getBlockedUsersWithDetails();

    if (!mounted) return;

    if (blocked.isEmpty) {
      _showAlert('No tenés usuarios bloqueados.');
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _BlockedUsersSheet(
        blockedUsers: blocked,
        onUnblock: (blockedId) async {
          final error = await BlockUserService.instance.unblockUser(blockedId);
          if (error != null && mounted) {
            _showAlert(error);
          } else if (mounted) {
            setState(() {}); // Refresh count
            _showAlert('Usuario desbloqueado.');
          }
        },
      ),
    );
  }

  void _showAlert(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subwidgets reutilizables
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: context.textTertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(MployaTheme.radiusMD),
      ),
      child: Column(
        children: List.generate(children.length, (index) {
          return Column(
            children: [
              children[index],
              if (index < children.length - 1)
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  indent: 56,
                  color: context.dividerColor,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final Color? textColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    this.subtitle,
    this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 17, color: CupertinoColors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor ?? context.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: context.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 17, color: CupertinoColors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: context.textPrimary,
              ),
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: MployaTheme.brandAccent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Blocked Users Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _BlockedUsersSheet extends StatelessWidget {
  final List<Map<String, dynamic>> blockedUsers;
  final ValueChanged<String> onUnblock;

  const _BlockedUsersSheet({
    required this.blockedUsers,
    required this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Usuarios Bloqueados',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: blockedUsers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = blockedUsers[index];
                  final user = item['users'] as Map<String, dynamic>? ?? {};
                  final name = user['name']?.toString() ?? 'Usuario';
                  final headline = user['headline']?.toString() ?? '';
                  final blockedId = item['blocked_id']?.toString() ?? '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey5,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.person_fill, size: 22, color: CupertinoColors.systemGrey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              if (headline.isNotEmpty)
                                Text(
                                  headline,
                                  style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          color: CupertinoColors.systemRed,
                          borderRadius: BorderRadius.circular(8),
                          onPressed: () {
                            Navigator.pop(context);
                            onUnblock(blockedId);
                          },
                          child: const Text(
                            'Desbloquear',
                            style: TextStyle(fontSize: 13, color: CupertinoColors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}