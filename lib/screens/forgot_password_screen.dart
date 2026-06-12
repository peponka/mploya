import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Colors;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ForgotPasswordScreen — Flujo completo de recuperación de contraseña
//
// Flujo:
//  1. Usuario ingresa email
//  2. Se envía resetPasswordForEmail() vía Supabase
//  3. El usuario recibe un email con link de reset
//  4. La app muestra confirmación
// ─────────────────────────────────────────────────────────────────────────────

class ForgotPasswordScreen extends StatefulWidget {
  final String? prefilledEmail;

  const ForgotPasswordScreen({super.key, this.prefilledEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  late AnimationController _anim;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledEmail != null) {
      _emailController.text = widget.prefilledEmail!;
    }
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Ingresá un email válido.');
      return;
    }

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb
            ? 'http://localhost:8080/#/reset-callback'
            : 'io.supabase.mploya://reset-callback',
      );

      if (!mounted) return;
      setState(() {
        _loading = false;
        _sent = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      final msg = e.toString().toLowerCase();
      if (msg.contains('rate') || msg.contains('limit')) {
        _showError('Demasiados intentos. Esperá unos minutos.');
      } else {
        // Supabase no revela si el email existe o no (seguridad)
        // Mostramos éxito de todas formas
        setState(() => _sent = true);
      }
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Recuperar Contraseña'),
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: _sent ? _buildSuccessState() : _buildFormState(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),

        // Icono
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: MployaTheme.brandAccent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.lock_rotation,
            size: 36,
            color: MployaTheme.brandAccent,
          ),
        ),

        const SizedBox(height: 28),

        const Text(
          'Olvidé mi contraseña',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        Text(
          'Ingresá el email con el que te registraste y te enviaremos un link para restablecer tu contraseña.',
          style: TextStyle(
            fontSize: 15,
            color: CupertinoColors.systemGrey.resolveFrom(context),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),

        // Email field
        CupertinoTextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          placeholder: 'tu@email.com',
          autofocus: true,
          style: const TextStyle(fontSize: 17),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: CupertinoColors.systemGrey4.resolveFrom(context),
            ),
          ),
          onSubmitted: (_) => _sendResetEmail(),
        ),

        const SizedBox(height: 20),

        // Submit button
        CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 14),
          borderRadius: BorderRadius.circular(14),
          color: MployaTheme.brandAccent,
          onPressed: _loading ? null : _sendResetEmail,
          child: _loading
              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
              : const Text(
                  'Enviar link de recuperación',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.white,
                  ),
                ),
        ),

        const SizedBox(height: 16),

        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Volver al login',
            style: TextStyle(
              fontSize: 15,
              color: MployaTheme.brandAccent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF34C759).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.checkmark_circle_fill,
            size: 56,
            color: Color(0xFF34C759),
          ),
        ),

        const SizedBox(height: 28),

        const Text(
          '¡Correo enviado!',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.5,
            ),
            children: [
              const TextSpan(
                text: 'Si el email ',
              ),
              TextSpan(
                text: _emailController.text.trim(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(
                text: ' está registrado, recibirás un link para restablecer tu contraseña.\n\nRevisá también la carpeta de spam.',
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
          borderRadius: BorderRadius.circular(14),
          color: MployaTheme.brandAccent,
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Volver al login',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.white,
            ),
          ),
        ),

        const SizedBox(height: 16),

        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            setState(() => _sent = false);
          },
          child: const Text(
            'Reenviar correo',
            style: TextStyle(
              fontSize: 15,
              color: MployaTheme.brandAccent,
            ),
          ),
        ),
      ],
    );
  }
}
