import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/web_centered.dart';

import '../screens/splash_screen.dart';
import '../screens/candidate_profile_form_screen.dart';
import '../screens/stealth_profile_form_screen.dart';
import '../screens/company_profile_form_screen.dart';
import '../screens/headhunter_profile_form_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isLoading = false;

  Future<void> _selectRole(String role) async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final email = user.email ?? '';
        final fallbackName = email.contains('@') ? email.split('@')[0] : 'Usuario';

        await Supabase.instance.client
            .from('users')
            .upsert({
              'id': user.id, 
              'account_type': role, 
              'onboarding_step': 1,
              'name': fallbackName,
              'email': email,
            });
        if (!mounted) return;
        
        if (role == 'confidencial') {
          // El talento C-Level va primero a configurar su bóveda secreta
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(builder: (_) => const StealthProfileFormScreen()),
          );
        } else if (role == 'candidato') {
          // El talento NORMAL va primero a rellenar sus datos y hashtags
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(builder: (_) => const CandidateProfileFormScreen()),
          );
        } else if (role == 'headhunter') {
          // El headhunter (comisionista) tiene un formulario propio, más simple
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(builder: (_) => const HeadhunterProfileFormScreen()),
          );
        } else {
          // La EMPRESA va a rellenar su nombre y datos, luego pasará a su Video Pitch
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(builder: (_) => const CompanyProfileFormScreen()),
          );
        }
      } else {
        // Redirigimos al SplashScreen para que el usuario inicie sesión
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const SplashScreen()),
        );
      }
    } catch (e) {
      debugPrint('Error saving role: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: WebCentered(
          maxWidth: 540,
          child: SingleChildScrollView(
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Icon Header
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.symmetric(horizontal: 140),
                decoration: BoxDecoration(
                  color: MployaTheme.brandAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.person_2_alt,
                  size: 40,
                  color: MployaTheme.brandAccent,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Selecciona tu Perfil',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                  letterSpacing: -0.5,
                  decoration: TextDecoration.none,
                  fontFamily: '.SF Pro Display',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '¿Cómo vas a utilizar Mploya?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: context.textSecondary,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                  fontFamily: '.SF Pro Text',
                ),
              ),
              const SizedBox(height: 40),

              if (_isLoading)
                const Center(child: CupertinoActivityIndicator(radius: 16))
              else ...[
                // Role 1: Candidato
                _RoleButton(
                  title: 'Candidato',
                  subtitle: 'Perfil público para conectar y buscar oportunidades activamente.',
                  icon: CupertinoIcons.person_crop_circle_fill,
                  onTap: () => _selectRole('candidato'),
                ),
                const SizedBox(height: 12),
                
                // Role 2: Confidencial (Premium)
                _RoleButton(
                  title: 'Confidencial',
                  subtitle: 'Perfil anónimo. Explora el mercado sin revelar tu identidad actual.',
                  icon: CupertinoIcons.lock_shield_fill,
                  isPremium: true,
                  onTap: () => _selectRole('confidencial'),
                ),
                const SizedBox(height: 12),

                // Role 3: Empresa
                _RoleButton(
                  title: 'Empresa',
                  subtitle: 'Cuenta corporativa. Recluta talento y muestra tu marca empleadora.',
                  icon: CupertinoIcons.building_2_fill,
                  onTap: () => _selectRole('empresa'),
                ),
                const SizedBox(height: 12),

                // Role 4: Headhunter
                _RoleButton(
                  title: 'Headhunter',
                  subtitle: 'Reclutador independiente. Descubre al mejor talento para tus clientes.',
                  icon: CupertinoIcons.person_2_square_stack_fill,
                  onTap: () => _selectRole('headhunter'), // En DB lo trataremos igual que empresa
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isPremium;
  final VoidCallback onTap;

  const _RoleButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isPremium = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPremium ? MployaTheme.brandAccent : context.dividerColor, 
            width: isPremium ? 1.5 : 1.0
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MployaTheme.brandAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon, 
                size: 28, 
                color: MployaTheme.brandAccent
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                      decoration: TextDecoration.none,
                      fontFamily: '.SF Pro Text',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isPremium ? CupertinoColors.systemGrey : context.textSecondary,
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                      fontFamily: '.SF Pro Text',
                    ),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, color: context.textTertiary),
          ],
        ),
      ),
    );
  }
}
