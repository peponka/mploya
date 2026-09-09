import 'package:flutter/cupertino.dart';
import 'package:mploya/screens/candidate_profile_form_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/company_profile_form_screen.dart';
import '../screens/headhunter_profile_form_screen.dart';
import '../services/my_profile_service.dart';
import '../screens/splash_screen.dart';
import '../screens/stealth_profile_form_screen.dart';
import '../widgets/web_centered.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  static const Color _accent = Color(0xFFF97316);
  static const Color _textPrimary = Color(0xFF121826);
  static const Color _textSecondary = Color(0xFF6B7280);

  bool _isLoading = false;
  String _selectedRole = 'candidato';

  Future<void> _persistSelectedRole({required String role}) async {
    await setMyInitialRole(role: role, completeSelection: true);
  }

  Future<void> _selectRole(String role) async {
    setState(() {
      _isLoading = true;
      _selectedRole = role;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('mploya_account_type', role);
        // Guardamos primero la experiencia elegida. Si el servidor todavía
        // conserva un rol anterior, la navegación no puede devolver al usuario
        // al feed equivocado mientras se sincroniza.
        try {
          await _persistSelectedRole(role: role);
        } catch (e) {
          debugPrint('Rol activo guardado localmente; sync pendiente: $e');
        }
        if (!mounted) return;
        if (role == 'confidencial') {
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(
              builder: (_) => const StealthProfileFormScreen(),
            ),
          );
        } else if (role == 'candidato') {
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(
              builder: (_) => const CandidateProfileFormScreen(),
            ),
          );
        } else if (role == 'headhunter') {
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(
              builder: (_) => const HeadhunterProfileFormScreen(),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(
              builder: (_) => const CompanyProfileFormScreen(),
            ),
          );
        }
      } else {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const SplashScreen()),
        );
      }
    } catch (e) {
      debugPrint('Error saving role: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    const cards = [
      _RoleCardData(
        title: 'Talento',
        subtitle: 'Mostrá tu video, skills y activá matches con IA.',
        role: 'candidato',
        icon: CupertinoIcons.person_crop_circle_fill,
        tint: Color(0xFFF97316),
        background: Color(0xFFFFF0E5),
      ),
      _RoleCardData(
        title: 'Confidencial',
        subtitle: 'Explorá oportunidades con perfil stealth.',
        role: 'confidencial',
        icon: CupertinoIcons.eye_slash_fill,
        tint: Color(0xFF4F46E5),
        background: Color(0xFFEEF2FF),
        badge: 'Premium',
      ),
      _RoleCardData(
        title: 'Empresa',
        subtitle: 'Publicá vacantes y descubrí talento en video.',
        role: 'empresa',
        icon: CupertinoIcons.building_2_fill,
        tint: Color(0xFF0F766E),
        background: Color(0xFFECFDF5),
      ),
      _RoleCardData(
        title: 'Headhunter',
        subtitle: 'Gestioná búsquedas y conectá empresas con candidatos.',
        role: 'headhunter',
        icon: CupertinoIcons.person_2_square_stack_fill,
        tint: Color(0xFF7C3AED),
        background: Color(0xFFF5F3FF),
      ),
    ];

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFFFBF7),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBF7), Color(0xFFFFF3E8), Color(0xFFFFFFFF)],
            stops: [0.0, 0.42, 1.0],
          ),
        ),
        child: SafeArea(
          child: WebCentered(
            maxWidth: 880,
            child: Stack(
              children: [
                Positioned(
                  top: -20,
                  right: isWide ? 40 : -30,
                  child: _GlowOrb(
                    size: isWide ? 230 : 180,
                    color: const Color(0x33F97316),
                  ),
                ),
                Positioned(
                  left: isWide ? 32 : -24,
                  bottom: 80,
                  child: _GlowOrb(
                    size: isWide ? 160 : 120,
                    color: const Color(0x14FDBA74),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isWide ? 40 : 22,
                    isWide ? 34 : 20,
                    isWide ? 40 : 22,
                    18,
                  ),
                  child: _isLoading
                      ? const Center(
                          child: CupertinoActivityIndicator(radius: 18),
                        )
                      : Column(
                          children: [
                            const SizedBox(height: 6),
                            const _BrandLockup(),
                            const SizedBox(height: 22),
                            const Text(
                              '¿Cómo querés usar\nMploya hoy?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.4,
                                height: 1.02,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFFF97316), Color(0xFFF59E0B)],
                              ).createShader(bounds),
                              child: const Text(
                                'Elegí tu punto de partida',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  color: CupertinoColors.white,
                                  letterSpacing: -0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 560),
                              child: Text(
                                'Te llevamos al flujo correcto desde el primer paso. Si entrás como talento, abrimos el assistant de onboarding con video, perfil y match IA.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.45,
                                  color: _textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            Expanded(
                              child: GridView.builder(
                                physics: const BouncingScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: isWide ? 2 : 1,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      mainAxisExtent: isWide ? 214 : 188,
                                    ),
                                itemCount: cards.length,
                                itemBuilder: (context, index) {
                                  final card = cards[index];
                                  return _RoleCard(
                                    data: card,
                                    isSelected: _selectedRole == card.role,
                                    onTap: () => _selectRole(card.role),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Continuar con',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: const [
                                _AuthCta(
                                  label: 'Email',
                                  icon: CupertinoIcons.mail_solid,
                                ),
                                _AuthCta(
                                  label: 'Google',
                                  icon: CupertinoIcons.globe,
                                ),
                                _AuthCta(
                                  label: 'Apple',
                                  icon: CupertinoIcons.device_laptop,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Al continuar aceptás nuestros Términos y Política de privacidad.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                                height: 1.4,
                              ),
                            ),
                          ],
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

class _RoleCardData {
  final String title;
  final String subtitle;
  final String role;
  final IconData icon;
  final Color tint;
  final Color background;
  final String? badge;

  const _RoleCardData({
    required this.title,
    required this.subtitle,
    required this.role,
    required this.icon,
    required this.tint,
    required this.background,
    this.badge,
  });
}

class _RoleCard extends StatelessWidget {
  final _RoleCardData data;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected
                ? _RoleSelectionScreenState._accent
                : const Color(0xFFFFE7D2),
            width: isSelected ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (isSelected
                          ? _RoleSelectionScreenState._accent
                          : const Color(0xFFF97316))
                      .withValues(alpha: isSelected ? 0.18 : 0.08),
              blurRadius: isSelected ? 28 : 22,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: data.background,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(data.icon, size: 32, color: data.tint),
                ),
                const Spacer(),
                if (data.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Premium',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6D28D9),
                      ),
                    ),
                  )
                else
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _RoleSelectionScreenState._accent
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? _RoleSelectionScreenState._accent
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Icon(
                      CupertinoIcons.check_mark,
                      size: 15,
                      color: isSelected
                          ? CupertinoColors.white
                          : const Color(0xFFD1D5DB),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              data.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _RoleSelectionScreenState._textPrimary,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.subtitle,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: _RoleSelectionScreenState._textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  isSelected ? 'Entrar ahora' : 'Seleccionar',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? _RoleSelectionScreenState._accent
                        : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.arrow_right,
                  size: 16,
                  color: isSelected
                      ? _RoleSelectionScreenState._accent
                      : const Color(0xFF111827),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF97316), Color(0xFFF59E0B)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _RoleSelectionScreenState._accent.withValues(
                  alpha: 0.26,
                ),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: const Icon(
            CupertinoIcons.sparkles,
            color: CupertinoColors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'mploya.ai',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.9,
            color: _RoleSelectionScreenState._textPrimary,
          ),
        ),
      ],
    );
  }
}

class _AuthCta extends StatelessWidget {
  final String label;
  final IconData icon;

  const _AuthCta({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF111827)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
