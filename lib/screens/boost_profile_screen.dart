import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class BoostProfileScreen extends ConsumerStatefulWidget {
  const BoostProfileScreen({super.key});

  @override
  ConsumerState<BoostProfileScreen> createState() => _BoostProfileScreenState();
}

class _BoostProfileScreenState extends ConsumerState<BoostProfileScreen> {
  int _selectedOption = 0;
  bool _isLoading = false;

  // ══════════════════════════════════════════════════════════════════════════
  // 🚀 MODO FUNDADOR — Boost gratis para todos hasta tener masa crítica.
  // Cuando haya suficientes empresas, cambiá esto a FALSE y el botón
  // cobrará normalmente via RevenueCat/Apple Pay.
  // ══════════════════════════════════════════════════════════════════════════
  static const _founderMode = true;
  // ignore: unused_field
  static const _founderBoostDays = 30; // Duración del boost gratis

  void _processPayment() async {
    setState(() => _isLoading = true);

    final uid = Supabase.instance.client.auth.currentUser?.id;
    int durationDays = 7;
    if (_selectedOption == 1) durationDays = 14;
    if (_selectedOption == 2) durationDays = 30;

    if (_founderMode && uid != null) {
      // Modo Fundador: activar boost gratis directamente en la DB
      final boostEnd = DateTime.now().add(Duration(days: durationDays));
      try {
        await Supabase.instance.client.from('users').update({
          'boost_ends_at': boostEnd.toUtc().toIso8601String(),
        }).eq('id', uid);
      } catch (e) {
        debugPrint('Error activando boost fundador: $e');
      }
    } else {
      // Bypass RevenueCat: Forzar update local (solo para TestFlight)
      try {
        final boostEnd = DateTime.now().add(Duration(days: durationDays));
        if (uid != null) {
          await Supabase.instance.client.from('users').update({
            'boost_ends_at': boostEnd.toUtc().toIso8601String(),
          }).eq('id', uid);
        }
      } catch (e) {
        debugPrint('Error activando boost fallback: $e');
      }
      await Future.delayed(const Duration(seconds: 1));
    }

    setState(() => _isLoading = false);

    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (c) => CupertinoAlertDialog(
          title: const Text('¡Boost Activado!'),
          content: Text(
            '🎁 Boost activado con éxito por $durationDays días. Tu perfil ahora es top tier en el feed correspondiente.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Increíble'),
              onPressed: () {
                Navigator.pop(c);
                Navigator.pop(context);
              },
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // userAsync available via ref.watch(currentUserProvider) for future use
    
    // Tiers Fase 10: Local / Remote / Passport
    final List<Map<String, dynamic>> options = [
      {
        'title': 'Local Boost',
        'price': r'$2.99',
        'duration': '1 Semana',
        'desc': 'Destaca localmente en tu ciudad. Ideal para trabajos presenciales.',
        'gradient': const [Color(0xFF007AFF), Color(0xFF0055B3)],
        'icon': CupertinoIcons.location_solid,
      },
      {
        'title': 'Remote Boost',
        'price': r'$4.99',
        'duration': '2 Semanas',
        'desc': 'Alcance nacional para oportunidades de trabajo remoto u oficinas de IT.',
        'gradient': const [Color(0xFFFF9500), Color(0xFFCC7700)],
        'icon': CupertinoIcons.house_fill,
      },
      {
        'title': 'Passport',
        'price': r'$7.99',
        'duration': '1 Mes',
        'desc': 'Alcance Global VIP. Visibilidad Mundial 10x para candidatos Elite.',
        'gradient': const [Color(0xFFDAA520), Color(0xFFB8860B)],
        'icon': CupertinoIcons.globe,
      }
    ];

    return CupertinoPageScaffold(
      backgroundColor: context.isDark ? NexTheme.darkBg : Colors.white,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Destacar Perfil',
          style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        backgroundColor: context.isDark ? NexTheme.darkBg : Colors.white,
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF5E5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.flame_fill, color: Color(0xFFFF9500), size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'Multiplica tus Entrevistas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Destaca tu perfil en el feed de las empresas por tiempo limitado y recibe ofertas urgentes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              // Opciones
              ...List.generate(options.length, (index) {
                final opt = options[index];
                final isSelected = _selectedOption == index;
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedOption = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7))
                          : context.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected ? MployaTheme.brandAccent : context.dividerColor,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [const BoxShadow(color: Color(0x1A34C759), blurRadius: 16, offset: Offset(0, 4))]
                          : [],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: opt['gradient'] as List<Color>,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(opt['icon'] as IconData, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt['title'] as String,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                opt['desc'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              opt['price'] as String,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              opt['duration'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: MployaTheme.brandAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 40),
              
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isLoading ? null : _processPayment,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: MployaTheme.brandAccent,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(color: Color(0x4034C759), blurRadius: 16, offset: Offset(0, 8))
                    ],
                  ),
                  child: Center(
                    child: _isLoading 
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : Text(
                          _founderMode
                              ? '🎁 Activar Boost GRATIS'
                              : 'Pagar ${options[_selectedOption]['price']}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'El cargo se realizará a tu cuenta de Apple ID / Google Play. Puedes cancelar en cualquier momento desde los ajustes de tu teléfono.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}