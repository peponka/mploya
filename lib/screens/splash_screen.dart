import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../navigation/main_navigation.dart';
import '../services/deep_link_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/role_selection_screen.dart';
import '../screens/onboarding_pitch_screen.dart';
import '../screens/onboarding_tour_screen.dart';

import '../screens/candidate_profile_form_screen.dart';
import '../screens/stealth_profile_form_screen.dart';
import '../screens/company_profile_form_screen.dart';
import '../screens/headhunter_profile_form_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../services/video_preload_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOTA SQL — Ejecuta esto en Supabase SQL Editor para que el trigger cree
// el registro en public.users automáticamente al registrarse:
//
// CREATE OR REPLACE FUNCTION public.handle_new_user()
// RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
// BEGIN
//   INSERT INTO public.users (id, email, name)
//   VALUES (
//     NEW.id,
//     NEW.email,
//     COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email,'@',1))
//   )
//   ON CONFLICT (id) DO NOTHING;
//   RETURN NEW;
// END;
// $$;
//
// CREATE OR REPLACE TRIGGER on_auth_user_created
//   AFTER INSERT ON auth.users
//   FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
//
// CREATE POLICY "Users can upsert own profile"
//   ON public.users FOR ALL USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
// ─────────────────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _contentController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentOpacity;
  StreamSubscription<AuthState>? _authSubscription;

  // true mientras Supabase procesa el ?code= del callback OAuth
  bool _processingOAuth = false;

  @override
  void initState() {
    super.initState();

    // Detectar callback OAuth en web (?code= en la URL) — mostrar spinner
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('code') ||
          uri.queryParameters.containsKey('access_token')) {
        _processingOAuth = true;
      }
    }

    // ── Animaciones ──
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic),
    );
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    _logoController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_processingOAuth) _contentController.forward();
      });
    });

    // ── Escuchar cambios de Auth State vía AuthService ──
    _authSubscription =
        AuthService.instance.authStateStream.listen((data) async {
      if (!mounted || _hasNavigated) return;
      if ((data.event == AuthChangeEvent.signedIn || data.event == AuthChangeEvent.initialSession) && data.session != null) {
        if (mounted && _processingOAuth) {
          setState(() => _processingOAuth = false);
        }
        // El trigger on_auth_user_created crea la fila en public.users.
        // upsertUserProfile solo actúa de red de seguridad sin escribir name.
        try {
          await AuthService.instance.upsertUserProfile(data.session!.user);
        } catch (e) {
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('refresh_token') || errorStr.contains('already_used')) {
            debugPrint('⚠️ Refresh token corrupto en authStateStream → forzando sign-out');
            AuthService.instance.forceSignOutCorruptSession();
            return; // Quedarse en login
          }
        }
        if (mounted && !_hasNavigated) {
          _hasNavigated = true;
          _navigateToHome();
        }
      }
    }, onError: (Object error) {
      // Capturar errores del stream de auth (incluye refresh_token_already_used)
      final errorStr = error.toString().toLowerCase();
      debugPrint('⚠️ authStateStream onError: $error');
      if (errorStr.contains('refresh_token') || errorStr.contains('already_used')) {
        AuthService.instance.forceSignOutCorruptSession();
      }
    });

    // ── Sesión ya activa al abrir la app ──
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (AuthService.instance.currentSession != null && mounted && !_hasNavigated) {
        // Verificar que la sesión sea válida antes de navegar.
        // Si el refresh token está corrupto (ya usado/expirado),
        // la sesión parece existir pero falla en cualquier query.
        try {
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            // Test query para verificar que el token funciona
            await Supabase.instance.client
                .from('users')
                .select('id')
                .eq('id', user.id)
                .maybeSingle();
          }
          // Si llegamos aquí, la sesión es válida
          if (mounted && !_hasNavigated) {
            _hasNavigated = true;
            _navigateToHome();
          }
        } catch (e) {
          // Token corrupto/expirado → limpiar sesión y quedarse en login
          debugPrint('⚠️ Sesión corrupta detectada: $e → cerrando sesión');
          try {
            VideoPreloadManager.instance.disposeAll();
            await Supabase.instance.client.auth.signOut();
          } catch (_) {}
          // Quedarse en SplashScreen/Login — no navegar
        }
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _contentController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  bool _hasNavigated = false;

  static const _termsUrl = 'https://mploya.ai/terms.html';
  static const _privacyUrl = 'https://mploya.ai/privacy.html';

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _navigateToHome() async {
    if (!mounted) return;

    // Esperar hasta 3 segundos a que la sesión se propague completamente.
    // signInWithPassword puede retornar éxito antes de que currentUser esté listo.
    User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      for (int i = 0; i < 6; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        user = Supabase.instance.client.auth.currentUser;
        if (user != null) break;
      }
    }

    if (user == null) {
      // Después de 3 segundos sin sesión → probablemente requiere confirmar email.
      if (!mounted) return;
      setState(() => _hasNavigated = false);
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Verifica tu Email'),
          content: const Text(
            'Si acabas de crear tu cuenta, revisa tu bandeja de entrada y confirma tu email para poder entrar.'
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return; 
    }

    try {
      final data = await Supabase.instance.client
          .from('users')
          .select('onboarding_step, account_type')
          .eq('id', user.id)
          .maybeSingle();

      // onboarding_step es la única fuente de verdad del flujo de registro.
      // 0 = nuevo sin rol · 1 = rol elegido · 2 = perfil completo · 3 = video subido
      final step = (data?['onboarding_step'] as int?) ?? 0;

      if (!mounted) return;

      if (step == 0) {
        // Si el usuario vino de Google/Apple OAuth y ya eligió rol antes del redirect, aplicarlo directo
        final prefs = await SharedPreferences.getInstance();
        final pendingRole = prefs.getString('pending_oauth_account_type');
        if (pendingRole != null) {
          await prefs.remove('pending_oauth_account_type');
          try {
            await Supabase.instance.client.from('users').update({
              'account_type': pendingRole,
              'onboarding_step': 1,
            }).eq('id', user.id);
          } catch (e) {
            debugPrint('Error applying pending OAuth role: $e');
          }
          if (!mounted) return;
          final Widget form;
          if (pendingRole == 'headhunter') {
            form = const HeadhunterProfileFormScreen();
          } else if (pendingRole == 'empresa') {
            form = const CompanyProfileFormScreen();
          } else if (pendingRole == 'confidencial') {
            form = const StealthProfileFormScreen();
          } else {
            form = const CandidateProfileFormScreen();
          }
          Navigator.of(context).pushReplacement(CupertinoPageRoute(builder: (_) => form));
          return;
        }
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const RoleSelectionScreen()),
        );
        return;
      }

      if (step == 1) {
        final role = (data?['account_type'] as String?) ?? '';
        final Widget form;
        // El headhunter tiene su propio formulario (más simple, de comisionista).
        // Antes caía al else → formulario de candidato y terminaba como candidato.
        if (role == 'headhunter') {
          form = const HeadhunterProfileFormScreen();
        } else if (role == 'empresa') {
          form = const CompanyProfileFormScreen();
        } else if (role == 'confidencial') {
          form = const StealthProfileFormScreen();
        } else {
          form = const CandidateProfileFormScreen();
        }
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => form),
        );
        return;
      }

      if (step == 2) {
        final isCompany = (data?['account_type'] as String?) == 'empresa';
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
              builder: (_) => OnboardingPitchScreen(isCompany: isCompany)),
        );
        return;
      }

      // step >= 3: onboarding completo → check if tour was seen
      // Cuentas creadas hace más de 7 días nunca muestran el tour (reinstala / usuario existente)
      final createdAt = DateTime.tryParse(user.createdAt);
      final isNewAccount = createdAt == null ||
          DateTime.now().difference(createdAt).inDays <= 7;
      final hasSeenTour =
          !isNewAccount || await OnboardingTourScreen.hasSeenTour(user.id);
      if (!mounted) return;

      if (!hasSeenTour) {
        final accountType = data?['account_type']?.toString();
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => OnboardingTourScreen(accountType: accountType)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const MainNavigation()),
        );
      }

      // Resolver deep links pendientes (si el usuario llegó desde un link sin estar logueado)
      Future.delayed(const Duration(milliseconds: 500), () {
        DeepLinkService.instance.resolvePendingDeepLink();
      });
    } catch (e) {
      debugPrint('Error en routing post-auth (¿falta migración SQL?): $e');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const RoleSelectionScreen()),
        );
      }
    }
  }
  /// Guarda el rol seleccionado y abre el bottom sheet de auth
  String _selectedRole = 'candidato';

  void _startAsRole(String role) {
    _selectedRole = role;
    _showEmailAuth();
  }

  void _showEmailAuth() {
    showCupertinoModalPopup<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => _AuthBottomSheet(
        accountType: _selectedRole,
        onAuthSuccess: () {
          if (mounted && !_hasNavigated) {
            _hasNavigated = true;
            _navigateToHome();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mientras se procesa el callback OAuth mostrar spinner — no el formulario
    if (_processingOAuth) {
      return const CupertinoPageScaffold(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoActivityIndicator(radius: 18),
              SizedBox(height: 16),
              Text(
                'Verificando sesión...',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF8E8E93),
                  decoration: TextDecoration.none,
                  fontFamily: '.SF Pro Text',
                ),
              ),
            ],
          ),
        ),
      );
    }
    final isWideWeb = kIsWeb && MediaQuery.of(context).size.width > 700;
    return CupertinoPageScaffold(
      child: isWideWeb ? _buildWebLayout(context) : _buildMobileLayout(context),
    );
  }

  // ── Layout móvil / ventana angosta (diseño original) ──
  Widget _buildMobileLayout(BuildContext context) {
    return Container(
      color: CupertinoColors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              _buildLogo(),
              const Spacer(flex: 3),
              _buildAuthActions(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Layout web: panel de marca (izq) + card de acceso (der) ──
  Widget _buildWebLayout(BuildContext context) {
    return Container(
      color: CupertinoColors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panel de marca
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF378ADD), Color(0xFF0C447C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(64),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/branding/app_icon_1024.png',
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Mutea el papel.\nDale Play a tu carrera.',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -1,
                      decoration: TextDecoration.none,
                      fontFamily: '.SF Pro Display',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'La primera red profesional 100% en video. '
                    'Grabá tu pitch en 60 segundos, conectá con empresas '
                    'al instante y olvidate de los CVs.',
                    style: TextStyle(
                      fontSize: 17,
                      color: Color(0xFFE6F1FB),
                      height: 1.5,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.w400,
                      fontFamily: '.SF Pro Text',
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    children: const [
                      _WebBrandStat(value: '60s', label: 'Video-pitch'),
                      SizedBox(width: 40),
                      _WebBrandStat(value: '0', label: 'CVs'),
                      SizedBox(width: 40),
                      _WebBrandStat(value: '100%', label: 'Gratis'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Card de acceso
          Expanded(
            flex: 4,
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 48),
                      _buildAuthActions(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logo + tagline ──
  Widget _buildLogo() {
    return AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: NexTheme.brandAccent.withValues(alpha: 0.25),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/branding/app_icon_1024.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'mploya',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1C1C1E),
                                letterSpacing: -0.5,
                                fontFamily: '.SF Pro Display',
                              ),
                            ),
                            TextSpan(
                              text: '.ai',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: NexTheme.brandAccent,
                                letterSpacing: -0.5,
                                fontFamily: '.SF Pro Display',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Mutea el papel. Dale Play a tu carrera.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8E8E93),
                          fontFamily: '.SF Pro Text',
                          decoration: TextDecoration.none,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                );
  }

  // ── Acciones de acceso (roles + login social) ──
  Widget _buildAuthActions(BuildContext context) {
    return SlideTransition(
                  position: _contentSlide,
                  child: FadeTransition(
                    opacity: _contentOpacity,
                    child: Column(
                      children: [
                        // ── Tipo de cuenta ──
                        const Text(
                          '¿Cómo querés usar Mploya?',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3A3A3C),
                            decoration: TextDecoration.none,
                            fontFamily: '.SF Pro Text',
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Candidato — principal
                        _SignInButton(
                          label: 'Soy Candidato',
                          icon: CupertinoIcons.person_fill,
                          backgroundColor: const Color(0xFF1C1C1E),
                          textColor: Colors.white,
                          onTap: () => _startAsRole('candidato'),
                        ),
                        const SizedBox(height: 10),

                        // Candidato Confidencial
                        _SignInButton(
                          label: 'Candidato Confidencial',
                          icon: CupertinoIcons.eye_slash_fill,
                          backgroundColor: Colors.white,
                          textColor: const Color(0xFF3A3A3C),
                          borderColor: const Color(0xFFD1D1D6),
                          onTap: () => _startAsRole('confidencial'),
                        ),
                        const SizedBox(height: 10),

                        // Empresa
                        _SignInButton(
                          label: 'Soy Empresa',
                          icon: CupertinoIcons.building_2_fill,
                          backgroundColor: Colors.white,
                          textColor: const Color(0xFF3A3A3C),
                          borderColor: const Color(0xFFD1D1D6),
                          onTap: () => _startAsRole('empresa'),
                        ),
                        const SizedBox(height: 10),

                        // Headhunter — recluta y ve candidatos Y empresas
                        _SignInButton(
                          label: 'Soy Headhunter',
                          icon: CupertinoIcons.person_2_square_stack_fill,
                          backgroundColor: Colors.white,
                          textColor: const Color(0xFF3A3A3C),
                          borderColor: const Color(0xFFD1D1D6),
                          onTap: () => _startAsRole('headhunter'),
                        ),

                        // ── Separador ──
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              Expanded(child: Container(height: 0.5, color: const Color(0xFFD1D1D6))),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'o entrá con',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8E8E93),
                                    decoration: TextDecoration.none,
                                    fontFamily: '.SF Pro Text',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                              Expanded(child: Container(height: 0.5, color: const Color(0xFFD1D1D6))),
                            ],
                          ),
                        ),

                        // ── Métodos de login ──
                        Row(
                          children: [
                            // Email
                            Expanded(
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                onPressed: _showEmailAuth,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.mail_solid, size: 18, color: const Color(0xFF3A3A3C)),
                                    const SizedBox(width: 6),
                                    const Text('Email', style: TextStyle(fontSize: 14, color: Color(0xFF3A3A3C), fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Google
                            Expanded(
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('pending_oauth_account_type', _selectedRole);
                                  try {
                                    final error = await AuthService.instance.signInWithGoogle();
                                    if (!context.mounted) return;
                                    if (error != null) _showEmailAuth();
                                  } catch (_) {
                                    if (context.mounted) _showEmailAuth();
                                  }
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.globe, size: 18, color: const Color(0xFF3A3A3C)),
                                    const SizedBox(width: 6),
                                    const Text('Google', style: TextStyle(fontSize: 14, color: Color(0xFF3A3A3C), fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Apple
                            Expanded(
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                color: const Color(0xFF1C1C1E),
                                borderRadius: BorderRadius.circular(14),
                                onPressed: () async {
                                  try {
                                    final error = await AuthService.instance.signInWithApple();
                                    if (!context.mounted) return;
                                    if (error != null) _showEmailAuth();
                                  } catch (_) {
                                    if (context.mounted) _showEmailAuth();
                                  }
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.device_phone_portrait, size: 18, color: Colors.white),
                                    const SizedBox(width: 6),
                                    const Text('Apple', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            const Text(
                              'Al continuar, aceptas los ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFC7C7CC),
                                height: 1.4,
                                decoration: TextDecoration.none,
                                fontFamily: '.SF Pro Text',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _launchUrl(_termsUrl),
                              child: const Text(
                                'Términos de Uso',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: NexTheme.brandAccent,
                                  height: 1.4,
                                  decoration: TextDecoration.underline,
                                  decorationColor: NexTheme.brandAccent,
                                  fontFamily: '.SF Pro Text',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Text(
                              ' y ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFC7C7CC),
                                height: 1.4,
                                decoration: TextDecoration.none,
                                fontFamily: '.SF Pro Text',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _launchUrl(_privacyUrl),
                              child: const Text(
                                'Política de Privacidad',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: NexTheme.brandAccent,
                                  height: 1.4,
                                  decoration: TextDecoration.underline,
                                  decorationColor: NexTheme.brandAccent,
                                  fontFamily: '.SF Pro Text',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WebBrandStat — métrica del panel de marca (layout web)
// ─────────────────────────────────────────────────────────────────────────────
class _WebBrandStat extends StatelessWidget {
  final String value;
  final String label;
  const _WebBrandStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -1,
            decoration: TextDecoration.none,
            fontFamily: '.SF Pro Display',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFFE6F1FB),
            decoration: TextDecoration.none,
            fontFamily: '.SF Pro Text',
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AuthBottomSheet — Login / Registro clásico con Email + Contraseña
// ─────────────────────────────────────────────────────────────────────────────

class _AuthBottomSheet extends StatefulWidget {
  final VoidCallback onAuthSuccess;
  final String accountType;
  const _AuthBottomSheet({required this.onAuthSuccess, this.accountType = 'candidato'});

  @override
  State<_AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends State<_AuthBottomSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  int _tabIndex = 0; // 0: Login, 1: Registro

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(_tabIndex == 0 ? 'Error de Ingreso' : 'Error de Registro'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog('Completa el email y la contraseña.');
      return;
    }

    if (_tabIndex == 1) {
      final confirm = _confirmPasswordController.text;
      if (password != confirm) {
        _showErrorDialog('Las contraseñas no coinciden.');
        return;
      }
    }

    setState(() => _loading = true);

    String? error;
    if (_tabIndex == 0) {
      error = await AuthService.instance.signInWithEmail(email, password);
    } else {
      error = await AuthService.instance.signUpWithEmail(email, password);
      // Guardar el account_type seleccionado en la tabla users
      if (error == null) {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          await Supabase.instance.client.from('users').upsert({
            'id': uid,
            'account_type': widget.accountType,
          }, onConflict: 'id');
        }
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      _showErrorDialog(error);
      return;
    }

    // Auth exitoso — cerramos el bottom sheet
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }

    // Callback al SplashScreen parent para que navegue desde su contexto
    widget.onAuthSuccess();
  }

  Future<void> _submitGoogle() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_oauth_account_type', widget.accountType);
    final error = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) _showErrorDialog(error);
  }

  Future<void> _submitApple() async {
    setState(() => _loading = true);
    final error = await AuthService.instance.signInWithApple();
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) _showErrorDialog(error);
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    // Cerrar el bottom sheet antes de navegar
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    // Esperar a que el bottom sheet se cierre
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => ForgotPasswordScreen(prefilledEmail: email.isNotEmpty ? email : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: const BoxDecoration(
          color: MployaTheme.lightCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Handle ──
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MployaTheme.lightDivider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Segmented Control (Tabs) ──
                SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<int>(
                    groupValue: _tabIndex,
                    children: const {
                      0: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Iniciar Sesión')),
                      1: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Crear Cuenta')),
                    },
                    onValueChanged: (val) {
                      if (val != null) {
                        setState(() {
                        _tabIndex = val;
                        // Opcional: reset fields al cambiar de tab
                        _confirmPasswordController.clear();
                      });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // ── Campo Email ──
                CupertinoTextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  placeholder: 'tu@email.com',
                  autofocus: true,
                  style: const TextStyle(color: MployaTheme.lightText, fontSize: 17),
                  placeholderStyle: const TextStyle(color: MployaTheme.lightTertiary, fontSize: 17),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: MployaTheme.lightBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MployaTheme.lightDivider),
                  ),
                  onSubmitted: (_) => _submitAuth(),
                ),
                const SizedBox(height: 12),

                // ── Campo Contraseña ──
                CupertinoTextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  placeholder: 'Contraseña',
                  style: const TextStyle(color: MployaTheme.lightText, fontSize: 17),
                  placeholderStyle: const TextStyle(color: MployaTheme.lightTertiary, fontSize: 17),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: MployaTheme.lightBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MployaTheme.lightDivider),
                  ),
                  suffix: CupertinoButton(
                    padding: const EdgeInsets.only(right: 16),
                    minimumSize: const Size(0, 0),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    child: Icon(
                      _obscurePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                      color: MployaTheme.lightTertiary,
                      size: 20,
                    ),
                  ),
                  onSubmitted: (_) => _submitAuth(),
                ),
                
                // ── Campo Confirmar Contraseña (solo si tabIndex == 1) ──
                if (_tabIndex == 1) ...[
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    placeholder: 'Confirmar Contraseña',
                    style: const TextStyle(color: MployaTheme.lightText, fontSize: 17),
                    placeholderStyle: const TextStyle(color: MployaTheme.lightTertiary, fontSize: 17),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: MployaTheme.lightBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: MployaTheme.lightDivider),
                    ),
                    suffix: CupertinoButton(
                      padding: const EdgeInsets.only(right: 16),
                      minimumSize: const Size(0, 0),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      child: Icon(
                        _obscureConfirm ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                        color: MployaTheme.lightTertiary,
                        size: 20,
                      ),
                    ),
                    onSubmitted: (_) => _submitAuth(),
                  ),
                ],

                // ── "Olvidaste tu contraseña" ──
                Align(
                  alignment: Alignment.centerRight,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: Size.zero,
                    onPressed: _loading ? null : _forgotPassword,
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MployaTheme.brandAccent,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Botón Autenticación ──
                GestureDetector(
                  onTap: _loading ? null : _submitAuth,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 52,
                    decoration: BoxDecoration(
                      color: _loading
                          ? MployaTheme.brandAccent.withValues(alpha: 0.5)
                          : MployaTheme.brandAccent,
                      borderRadius:
                          BorderRadius.circular(MployaTheme.radiusPill),
                      boxShadow: _loading
                          ? null
                          : [
                              BoxShadow(
                                color: MployaTheme.brandAccent.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Center(
                      child: _loading
                          ? const CupertinoActivityIndicator(
                              color: Colors.white,
                            )
                          : Text(
                              _tabIndex == 0 ? 'Iniciar Sesión  →' : 'Crear Cuenta  →',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                decoration: TextDecoration.none,
                                fontFamily: '.SF Pro Text',
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Divisor ──
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: MployaTheme.lightDivider,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'o continúa con',
                        style: TextStyle(
                          fontSize: 12,
                          color: MployaTheme.lightTertiary,
                          decoration: TextDecoration.none,
                          fontFamily: '.SF Pro Text',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: MployaTheme.lightDivider,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Botón Google ──
                GestureDetector(
                  onTap: _loading ? null : _submitGoogle,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: MployaTheme.lightBg,
                      borderRadius:
                          BorderRadius.circular(MployaTheme.radiusPill),
                      border: Border.all(
                        color: MployaTheme.lightDivider,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.globe,
                          color: MployaTheme.lightText,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Continuar con Google',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: MployaTheme.lightText,
                            decoration: TextDecoration.none,
                            fontFamily: '.SF Pro Text',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Botón Apple ──
                GestureDetector(
                  onTap: _loading ? null : _submitApple,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius:
                          BorderRadius.circular(MployaTheme.radiusPill),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.device_phone_portrait,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Continuar con Apple',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                            fontFamily: '.SF Pro Text',
                          ),
                        ),
                      ],
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// _SignInButton — reutilizable para los botones de la pantalla principal
// ─────────────────────────────────────────────────────────────────────────────

class _SignInButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _SignInButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
                fontFamily: '.SF Pro Text',
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}