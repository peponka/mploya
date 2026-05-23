/// Bottom sheet de autenticación (Login / Registro) de mploya.ai
///
/// Se abre desde el landing cuando el usuario selecciona un rol.
/// Tiene dos tabs: "Iniciar Sesión" y "Crear Cuenta".
/// Después de autenticarse, redirige al formulario de onboarding
/// correspondiente al rol seleccionado.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/features/auth/screens/landing_screen.dart';
import 'package:mploya/features/auth/services/auth_service.dart';

class AuthBottomSheet extends ConsumerStatefulWidget {
  const AuthBottomSheet({
    required this.role,
    this.initialProvider,
    super.key,
  });

  final UserRole role;
  final String? initialProvider;

  @override
  ConsumerState<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends ConsumerState<AuthBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  // 0 = Login, 1 = Register
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _currentTab = _tabController.index;
        _errorMessage = null;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validaciones básicas
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Completá todos los campos');
      return;
    }

    if (_currentTab == 1 && password != confirmPassword) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_currentTab == 0) {
        await AuthService.instance.signInWithEmail(
          email: email,
          password: password,
        );
      } else {
        await AuthService.instance.signUpWithEmail(
          email: email,
          password: password,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      _navigateToOnboarding();
    } catch (e) {
      if (!mounted) return;
      // ── MODO DEMO: Si Supabase falla, ir al formulario del rol ──
      Navigator.of(context).pop();
      _navigateToOnboarding();
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pop();
      _navigateToOnboarding();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAppleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.signInWithApple();
      if (!mounted) return;
      Navigator.of(context).pop();
      _navigateToOnboarding();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _navigateToOnboarding() {
    final path = switch (widget.role) {
      UserRole.candidato => '/onboarding/candidato',
      UserRole.confidencial => '/onboarding/confidencial',
      UserRole.empresa => '/onboarding/empresa',
    };
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: MployaColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: MployaColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Tab bar (Iniciar Sesión / Crear Cuenta) ──
              _buildTabBar(),

              const SizedBox(height: AppSpacing.lg),

              // ── Campos ──
              _buildEmailField(),
              const SizedBox(height: AppSpacing.md),

              _buildPasswordField(),

              if (_currentTab == 1) ...[
                const SizedBox(height: AppSpacing.md),
                _buildConfirmPasswordField(),
              ],

              // ── Olvidaste contraseña ──
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // TODO: Navegar a forgot password
                  },
                  child: Text(
                    '¿Olvidaste tu contraseña?',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: MployaColors.orange,
                    ),
                  ),
                ),
              ),

              // ── Error message ──
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: MployaColors.redLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MployaColors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.md),

              // ── Botón principal ──
              MployaButton(
                label: _currentTab == 0 ? 'Iniciar Sesión' : 'Crear Cuenta',
                onPressed: _isLoading ? null : _handleSubmit,
                isLoading: _isLoading,
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Divider ──
              const OrDivider(),

              const SizedBox(height: AppSpacing.md),

              // ── Social buttons ──
              SocialButton(
                label: 'Continuar con Google',
                icon: Icons.language_rounded,
                onPressed: _isLoading ? null : _handleGoogleLogin,
              ),

              const SizedBox(height: AppSpacing.sm),

              SocialButton(
                label: 'Continuar con Apple',
                icon: Icons.phone_iphone_rounded,
                isDark: true,
                onPressed: _isLoading ? null : _handleAppleLogin,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab Bar ──────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: MployaColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: MployaColors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(3),
        dividerColor: Colors.transparent,
        labelColor: MployaColors.textPrimary,
        unselectedLabelColor: MployaColors.textSecondary,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        tabs: const [
          Tab(text: 'Iniciar Sesión'),
          Tab(text: 'Crear Cuenta'),
        ],
      ),
    );
  }

  // ── Campos ──────────────────────────────────────────────────────────

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: GoogleFonts.inter(fontSize: 15, color: MployaColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'tu@email.com',
        prefixIcon: const Icon(
          Icons.email_outlined,
          color: MployaColors.textTertiary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction:
          _currentTab == 1 ? TextInputAction.next : TextInputAction.done,
      onSubmitted: _currentTab == 0 ? (_) => _handleSubmit() : null,
      style: GoogleFonts.inter(fontSize: 15, color: MployaColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Contraseña',
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: MployaColors.textTertiary,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: MployaColors.textTertiary,
            size: 20,
          ),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirm,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _handleSubmit(),
      style: GoogleFonts.inter(fontSize: 15, color: MployaColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Confirmar Contraseña',
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: MployaColors.textTertiary,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirm
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: MployaColors.textTertiary,
            size: 20,
          ),
          onPressed: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
        ),
      ),
    );
  }
}
