import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';
import '../../services/auth_service.dart';
import '../../services/my_profile_service.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../splash_screen.dart';

/// Configuración de Headhunter.
///
/// Migrada al sistema de diseño (18/8/2026), 10ª y última pantalla de este
/// rediseño — mismo patrón de `headhunter_dashboard_screen.dart`.
///
/// SIN mockup 1:1 (genérico, "configuración y privacidad.png", compartido
/// con Empresa). Patrón:
///
///   · Secciones → label mayúscula chica (sin cambios, no hay widget de
///     ds/ para ese estilo puntual) + [MpRowGroup] de [MpListRow] en vez
///     del `Container` a mano.
///   · Toggles → [MpListRow] (`title`+`subtitle`+`trailing`:
///     `CupertinoSwitch`).
///   · Acciones de cuenta → [MpListRow] para las NO destructivas
///     ("Información de cuenta", "Cambiar contraseña"). Las 2
///     destructivas ("Cerrar sesión", "Eliminar cuenta") NO usan
///     [MpListRow] — ese widget no tiene forma de pintar el título en
///     rojo, y perder esa señal en una acción irreversible no es un
///     detalle menor. Quedaron como fila a mano, tokenizada
///     (`MpTokens.danger`).
///   · Aviso/mensaje → [MpBanner], mismo color siempre (violeta), igual
///     que el original: no distinguía éxito de error visualmente, sólo
///     por texto.
///   · Aviso "todavía no disponible" → [MpCard].
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
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: Builder(
        builder: (context) {
          final s = context.mp;
          return CupertinoPageScaffold(
            backgroundColor: s.bg,
            navigationBar: CupertinoNavigationBar(
              middle: const Text('Configuración'),
              backgroundColor: s.card,
              border: null,
            ),
            child: SafeArea(child: _body(context)),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context) {
    final s = context.mp;
    if (_loading) return const Center(child: CupertinoActivityIndicator());
    if (_error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(MpTokens.space32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.exclamationmark_triangle, size: 42, color: s.textTertiary),
              const SizedBox(height: MpTokens.space16),
              Text(
                'No pudimos cargar la configuración',
                textAlign: TextAlign.center,
                style: TextStyle(color: s.text, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: MpTokens.space12),
              CupertinoButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        MpTokens.space20,
        MpTokens.screenPadding,
        MpTokens.space40,
      ),
      children: [
        Text('Tu cuenta Headhunter', style: MpTokens.h2.copyWith(color: s.text, fontSize: 24)),
        const SizedBox(height: MpTokens.space4),
        Text(
          'Sólo opciones conectadas a preferencias reales.',
          style: MpTokens.body.copyWith(color: s.textSecondary),
        ),
        if (_message != null) ...[
          const SizedBox(height: MpTokens.space12),
          MpBanner(
            icon: CupertinoIcons.info_circle_fill,
            title: 'Aviso',
            message: _message!,
            color: MpTokens.primary,
          ),
        ],
        const SizedBox(height: MpTokens.space20),
        _sectionLabel(s, 'Notificaciones'),
        MpRowGroup(
          rows: [
            MpListRow(
              title: 'Notificaciones push',
              subtitle: 'users.push_enabled',
              showChevron: false,
              trailing: CupertinoSwitch(
                value: _push,
                onChanged: _saving
                    ? null
                    : (value) => _saveBool('push_enabled', value, _push, (next) => _push = next),
              ),
            ),
            MpListRow(
              title: 'Notificaciones por email',
              subtitle: 'users.email_notifications_enabled',
              showChevron: false,
              trailing: CupertinoSwitch(
                value: _email,
                onChanged: _saving
                    ? null
                    : (value) => _saveBool(
                        'email_notifications_enabled',
                        value,
                        _email,
                        (next) => _email = next,
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MpTokens.space16),
        _sectionLabel(s, 'Reclutamiento'),
        MpRowGroup(
          rows: [
            MpListRow(
              title: 'Contratación a ciegas',
              subtitle: 'users.blind_hiring_mode',
              showChevron: false,
              trailing: CupertinoSwitch(
                value: _blind,
                onChanged: _saving
                    ? null
                    : (value) => _saveBool(
                        'blind_hiring_mode',
                        value,
                        _blind,
                        (next) => _blind = next,
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MpTokens.space16),
        _sectionLabel(s, 'Apariencia'),
        MpCard(
          padding: const EdgeInsets.all(MpTokens.space12),
          child: CupertinoSlidingSegmentedControl<String>(
            groupValue: _theme,
            children: const {
              'auto': Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Auto')),
              'light': Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Claro')),
              'dark': Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Oscuro')),
            },
            onValueChanged: (value) {
              if (value != null) _changeTheme(value);
            },
          ),
        ),
        const SizedBox(height: MpTokens.space16),
        _sectionLabel(s, 'Cuenta y seguridad'),
        MpCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              MpListRow(title: 'Información de cuenta', onTap: _showAccount),
              _divider(s),
              MpListRow(title: 'Cambiar contraseña', onTap: _changePassword),
              _divider(s),
              _destructiveAction('Cerrar sesión', _signOut),
              _divider(s),
              _destructiveAction('Eliminar cuenta', _confirmDelete),
            ],
          ),
        ),
        const SizedBox(height: MpTokens.space16),
        MpCard(
          child: Text(
            'Visibilidad del perfil, autenticación en dos pasos, sesiones activas y descarga de datos todavía no están disponibles. No se simulan controles.',
            style: MpTokens.caption.copyWith(color: s.textSecondary, height: 1.45),
          ),
        ),
        if (_saving) ...[
          const SizedBox(height: MpTokens.space16),
          const Center(child: CupertinoActivityIndicator()),
        ],
      ],
    );
  }

  Widget _sectionLabel(MpSurfaceStyle s, String title) => Padding(
    padding: const EdgeInsets.only(left: MpTokens.space4, bottom: MpTokens.space8),
    child: Text(
      title.toUpperCase(),
      style: MpTokens.micro.copyWith(
        color: s.textTertiary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    ),
  );

  Widget _divider(MpSurfaceStyle s) =>
      Padding(padding: const EdgeInsets.only(left: MpTokens.space16), child: Container(height: 1, color: s.border));

  Widget _destructiveAction(String title, VoidCallback onTap) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: MpTokens.space16, vertical: MpTokens.space12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: MpTokens.danger),
            ),
          ),
          const Icon(CupertinoIcons.chevron_right, size: 15, color: MpTokens.danger),
        ],
      ),
    ),
  );
}
