import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';
import '../../services/auth_service.dart';
import '../../services/my_profile_service.dart';
import '../../services/push_notification_service.dart';
import '../splash_screen.dart';

class HeadhunterSettingsData {
  const HeadhunterSettingsData({
    required this.pushEnabled,
    required this.emailEnabled,
    required this.blindHiring,
    this.email,
  });

  final bool pushEnabled;
  final bool emailEnabled;
  final bool blindHiring;
  final String? email;
}

typedef HeadhunterSettingSaver =
    Future<void> Function(String column, bool value);

class HeadhunterSettingsScreen extends StatefulWidget {
  const HeadhunterSettingsScreen({
    super.key,
    this.previewData,
    this.saveOverride,
  });

  final HeadhunterSettingsData? previewData;
  final HeadhunterSettingSaver? saveOverride;

  @override
  State<HeadhunterSettingsScreen> createState() =>
      _HeadhunterSettingsScreenState();
}

class _HeadhunterSettingsScreenState extends State<HeadhunterSettingsScreen> {
  bool _loading = true;
  bool _error = false;
  bool _saving = false;
  bool _push = false;
  bool _email = false;
  bool _blind = false;
  String _theme = 'light';
  String? _accountEmail;
  String? _message;

  @override
  void initState() {
    super.initState();
    final preview = widget.previewData;
    if (preview != null) {
      _assign(preview);
      _loading = false;
    } else {
      _load();
    }
  }

  void _assign(HeadhunterSettingsData data) {
    _push = data.pushEnabled;
    _email = data.emailEnabled;
    _blind = data.blindHiring;
    _accountEmail = data.email;
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) throw StateError('Sin sesión');
      final row = await loadMyProfile(client: client);
      if (row == null || row['account_type']?.toString() != 'headhunter') {
        throw StateError('La cuenta no es Headhunter');
      }
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _assign(
          HeadhunterSettingsData(
            pushEnabled: row['push_enabled'] == true,
            emailEnabled: row['email_notifications_enabled'] == true,
            blindHiring: row['blind_hiring_mode'] == true,
            email: client.auth.currentUser?.email,
          ),
        );
        _theme = readThemeMode(prefs);
        _loading = false;
      });
    } catch (error) {
      debugPrint('Headhunter settings load: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _saveBool(
    String column,
    bool value,
    bool previous,
    void Function(bool) assign,
  ) async {
    if (_saving) return;
    setState(() {
      assign(value);
      _saving = true;
      _message = null;
    });
    try {
      if (widget.saveOverride != null) {
        await widget.saveOverride!(column, value);
      } else {
        final client = Supabase.instance.client;
        final uid = client.auth.currentUser?.id;
        if (uid == null) throw StateError('Sin sesión');
        await updateMySetting(column, value, client: client);
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = 'Preferencia guardada.';
      });
    } catch (error) {
      debugPrint('Headhunter settings save: $error');
      if (!mounted) return;
      setState(() {
        assign(previous);
        _saving = false;
        _message = 'No se pudo guardar. Se restauró el valor anterior.';
      });
    }
  }

  Future<void> _changeTheme(String value) async {
    setState(() => _theme = value);
    applyThemeMode(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kThemeModeKey, value);
  }

  void _showAccount() {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Cuenta Headhunter'),
        content: Text(_accountEmail ?? 'Email no disponible'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _changePassword() {
    final password = TextEditingController();
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: password,
            placeholder: 'Nueva contraseña',
            obscureText: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(dialogContext);
              password.dispose();
            },
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              final value = password.text;
              final error = await AuthService.instance.updatePassword(value);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              password.dispose();
              if (!mounted) return;
              setState(() {
                _message = error ?? 'Contraseña actualizada.';
              });
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await PushNotificationService.instance.clearToken();
    final error = await AuthService.instance.signOut();
    if (!mounted) return;
    if (error != null) {
      setState(() => _message = error);
      return;
    }
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  void _confirmDelete() {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Esta acción es permanente y elimina los datos asociados a tu cuenta.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(dialogContext);
              final error = await AuthService.instance.deleteAccount();
              if (!mounted) return;
              setState(
                () => _message = error ??
                    'La solicitud de eliminación estará disponible próximamente.',
              );
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Configuración'),
        backgroundColor: CupertinoColors.white,
        border: null,
      ),
      child: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CupertinoActivityIndicator());
    if (_error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 42,
                color: Color(0xFF8D98AA),
              ),
              const SizedBox(height: 14),
              const Text(
                'No pudimos cargar la configuración',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                onPressed: _load,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        const Text(
          'Tu cuenta Headhunter',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            color: Color(0xFF172033),
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Sólo opciones conectadas a preferencias reales.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B778C)),
        ),
        if (_message != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFEDEAFF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              _message!,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4C2CF3)),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _section('Notificaciones', [
          _toggle(
            'Notificaciones push',
            'users.push_enabled',
            _push,
            (value) =>
                _saveBool('push_enabled', value, _push, (next) => _push = next),
          ),
          _toggle(
            'Notificaciones por email',
            'users.email_notifications_enabled',
            _email,
            (value) => _saveBool(
              'email_notifications_enabled',
              value,
              _email,
              (next) => _email = next,
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _section('Reclutamiento', [
          _toggle(
            'Contratación a ciegas',
            'users.blind_hiring_mode',
            _blind,
            (value) => _saveBool(
              'blind_hiring_mode',
              value,
              _blind,
              (next) => _blind = next,
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _section('Apariencia', [
          Padding(
            padding: const EdgeInsets.all(14),
            child: CupertinoSlidingSegmentedControl<String>(
              groupValue: _theme,
              children: const {
                'auto': Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Auto'),
                ),
                'light': Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Claro'),
                ),
                'dark': Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Oscuro'),
                ),
              },
              onValueChanged: (value) {
                if (value != null) _changeTheme(value);
              },
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _section('Cuenta y seguridad', [
          _action('Información de cuenta', _showAccount),
          _action('Cambiar contraseña', _changePassword),
          _action('Cerrar sesión', _signOut, destructive: true),
          _action('Eliminar cuenta', _confirmDelete, destructive: true),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3E8F0)),
          ),
          child: const Text(
            'Visibilidad del perfil, autenticación en dos pasos, sesiones activas y descarga de datos todavía no están disponibles. No se simulan controles.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B778C),
              height: 1.45,
            ),
          ),
        ),
        if (_saving) ...[
          const SizedBox(height: 16),
          const Center(child: CupertinoActivityIndicator()),
        ],
      ],
    );
  }

  Widget _section(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7C879A),
            letterSpacing: 0.6,
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E8F0)),
        ),
        child: Column(children: children),
      ),
    ],
  );

  Widget _toggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF7C879A),
                ),
              ),
            ],
          ),
        ),
        CupertinoSwitch(value: value, onChanged: _saving ? null : onChanged),
      ],
    ),
  );

  Widget _action(
    String title,
    VoidCallback onTap, {
    bool destructive = false,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: destructive
                    ? CupertinoColors.systemRed
                    : const Color(0xFF172033),
              ),
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: Color(0xFF9AA4B5),
          ),
        ],
      ),
    ),
  );
}
