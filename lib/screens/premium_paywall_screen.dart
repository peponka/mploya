import 'dart:ui';
import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/revenuecat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PremiumPaywallScreen — Paywall unificado para Candidatos y Empresas
//
// Detecta automáticamente el account_type del usuario y muestra features
// relevantes para cada perfil. RevenueCat maneja los pagos reales.
//
// Reemplaza el anterior stub "Próximamente" con integración real.
// ─────────────────────────────────────────────────────────────────────────────

class PremiumPaywallScreen extends StatefulWidget {
  const PremiumPaywallScreen({super.key});

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> {
  bool _isLoading = true;
  String _accountType = 'candidato';

  // ── Theme "Mploya Green" ──
  static const _green = NexTheme.brandAccent;
  static const _greenLight = NexTheme.premiumEnd;
  static const _bgDark = Color(0xFF0A1A14);
  static const _cardSelected = Color(0xFF0F2A1F);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      // Detectar tipo de cuenta
      try {
        final res = await Supabase.instance.client
            .from('users')
            .select('account_type')
            .eq('id', uid)
            .maybeSingle();
        _accountType = res?['account_type']?.toString() ?? 'candidato';
      } catch (e) {
        debugPrint('⚠️ PremiumPaywall._init account_type: $e');
      }

      await RevenueCatService.instance.initialize(uid);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _processPurchase() async {
    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Próximamente 🚀'),
          content: const Text(
            'La suscripción Premium estará disponible muy pronto. '
            'Te notificaremos cuando esté activa.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Entendido'),
              onPressed: () => Navigator.pop(ctx),
            )
          ],
        ),
      );
    }
  }

  // Features según el tipo de cuenta
  List<_FeatureConfig> get _features {
    if (_accountType == 'empresa') {
      return [
        const _FeatureConfig(
          icon: CupertinoIcons.lock_open_fill,
          title: 'Revelar perfiles confidenciales',
          subtitle: 'Desbloquea la identidad completa del talento confidencial.',
        ),
        const _FeatureConfig(
          icon: CupertinoIcons.graph_square_fill,
          title: 'Analytics de reclutamiento',
          subtitle: 'Métricas de views, engagement y conversión de tus vacantes.',
        ),
        const _FeatureConfig(
          icon: CupertinoIcons.chat_bubble_2_fill,
          title: 'Mensajes VIP ilimitados',
          subtitle: 'Contacta candidatos C-Level con 85% de tasa de respuesta.',
        ),
      ];
    }
    return [
      const _FeatureConfig(
        icon: CupertinoIcons.eye_fill,
        title: 'Saber quién ve tu perfil',
        subtitle: 'Acceso total al listado de empresas interesadas en tu Video-Pitch.',
      ),
      const _FeatureConfig(
        icon: CupertinoIcons.rocket_fill,
        title: 'Boost de Visibilidad IA',
        subtitle: 'El algoritmo te pondrá primero en el feed de las empresas de tu sector.',
      ),
      const _FeatureConfig(
        icon: CupertinoIcons.envelope_badge_fill,
        title: 'Mensajes directos ilimitados',
        subtitle: 'Enviá mensajes directos a reclutadores sin esperar a hacer Match.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isB2B = _accountType == 'empresa';

    return CupertinoPageScaffold(
      backgroundColor: _bgDark,
      child: Stack(
        children: [
          // ── Ambient Glow (top-right) ──
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_green.withValues(alpha: 0.15), _green.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),

          // ── Ambient Glow (bottom-left) ──
          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_green.withValues(alpha: 0.08), _green.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // ── Nav Bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.xmark, size: 16, color: Colors.white54),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () async {
                          setState(() => _isLoading = true);
                          final success = await RevenueCatService.instance.restorePurchases();
                          if (!context.mounted) return;
                          setState(() => _isLoading = false);
                          if (success) Navigator.pop(context, true);
                        },
                        child: Text(
                          'Restaurar compras',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),

                        // ── Logo Icon ──
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_green, _greenLight],
                            ),
                            borderRadius: const BorderRadius.all(Radius.circular(18)),
                            boxShadow: [
                              BoxShadow(
                                color: _green.withValues(alpha: 0.30),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            isB2B ? CupertinoIcons.building_2_fill : CupertinoIcons.person_crop_circle_badge_checkmark,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 28),
                        
                        // ── Title ──
                        Text(
                          isB2B ? 'Mploya B2B' : 'Mploya',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _green,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isB2B ? 'Corporate\nGreen' : 'Premium\nGreen',
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1.5,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isB2B
                              ? 'Desbloquea identidades confidenciales. Contrata talento Top Tier y ahorrá meses de reclutamiento.'
                              : 'Desbloquea el algoritmo de IA, visualiza quién vio tu perfil y multiplicá tus matches un 400%.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.50),
                            height: 1.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // ── Tier Card ──
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CupertinoActivityIndicator(radius: 16),
                            ),
                          )
                        else
                          _buildFallbackTierCard(),

                        const SizedBox(height: 32),
                        
                        // ── Features ──
                        ..._features.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _buildFeatureRow(f.icon, f.title, f.subtitle),
                        )),
                        
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom CTA ──
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  decoration: BoxDecoration(
                    color: _bgDark.withValues(alpha: 0.85),
                    border: Border(top: BorderSide(color: _green.withValues(alpha: 0.10), width: 0.5)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _isLoading ? null : _processPurchase,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [_green, _greenLight]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(color: Color(0x59185FA5), blurRadius: 16, offset: Offset(0, 6)),
                            ],
                          ),
                          child: _isLoading
                              ? const CupertinoActivityIndicator(color: Colors.white)
                              : const Column(
                                  children: [
                                    Text(
                                      'Comenzar prueba gratis de 7 días',
                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Luego \$14.99 / mes · Cancela cuando quieras',
                                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Al suscribirte, aceptas nuestros Términos de Servicio. Facturación vía App Store o Google Play.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.20), fontSize: 10, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Bypass Button (Develop Only) ──
          if (!kReleaseMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 16,
              child: GestureDetector(
                onTap: () async {
                  setState(() => _isLoading = true);
                  final uid = Supabase.instance.client.auth.currentUser?.id;
                  if (uid != null) {
                    try {
                      await Supabase.instance.client
                          .from('users')
                          .update({'is_premium': true})
                          .eq('id', uid);
                      await RevenueCatService.instance.forceRefreshFromSupabase();
                      // ignore: use_build_context_synchronously
                      if (mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                  ),
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.ant, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('DEBUG BYPASS', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Widget _buildFallbackTierCard() {
    return _buildTierCard(
      title: _accountType == 'empresa' ? 'Acceso Confidencial B2B' : 'Mploya Premium',
      price: _accountType == 'empresa' ? r'$99' : r'$14.99',
      period: '/mes',
      description: _accountType == 'empresa'
          ? '20 Tokens de Reclutamiento mensuales.'
          : 'Prueba gratis de 7 días incluida.',
      isRecommended: false,
      isSelected: true,
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _green.withValues(alpha: 0.15), width: 0.5),
          ),
          child: Icon(icon, color: _green, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 14, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTierCard({
    required String title,
    required String price,
    required String period,
    required String description,
    required bool isRecommended,
    required bool isSelected,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? _cardSelected : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? _green : Colors.white.withValues(alpha: 0.08), width: isSelected ? 1.5 : 0.5),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isRecommended)
            Positioned(
              top: -12, right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Recomendado', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: isSelected ? _green : Colors.white, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                      const SizedBox(height: 6),
                      Text(description, style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, fontFamily: '.SF Pro Display')),
                    Text(period, style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureConfig {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureConfig({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}