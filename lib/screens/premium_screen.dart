import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import '../services/revenuecat_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isAnnual = true;

  Future<void> _processPurchase() async {
    // ⚠️ Pagos reales requieren In-App Purchase (Apple) / Google Play Billing.
    // Hasta que se integre RevenueCat o un servicio IAP, mostramos "Próximamente".
    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Próximamente 🚀'),
          content: const Text(
            'La suscripción Mploya Black estará disponible muy pronto. '
            'Te notificaremos cuando esté activa.',
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Entendido'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.xmark, size: 20, color: Colors.white70),
        ),
        middle: const Text(
          'MPLOYA BLACK',
          style: TextStyle(
            color: Color(0xFFF5B300),
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            fontFamily: '.SF Pro Display',
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ── Hero Section (Glassmorphism VIP) ──
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A2A2A), Color(0xFF141414)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFF5B300).withValues(alpha: 0.35), width: 1.5),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFF5B300).withValues(alpha: 0.12), blurRadius: 40, offset: const Offset(0, 12)),
                  BoxShadow(color: const Color(0xFFF5B300).withValues(alpha: 0.06), blurRadius: 80, spreadRadius: 10),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF5B300), Color(0xFFFF8C00)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFF5B300).withValues(alpha: 0.4), blurRadius: 20),
                      ],
                    ),
                    child: const Icon(CupertinoIcons.star_fill, size: 38, color: Colors.black87),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Mploya Black',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      fontFamily: '.SF Pro Display',
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Impulsa tu perfil con tecnología premium',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white60,
                      fontWeight: FontWeight.w400,
                      fontFamily: '.SF Pro Text',
                      decoration: TextDecoration.none,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Billing Toggle ──
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                   _buildToggleOption(title: 'Mensual', isSelected: !_isAnnual, onTap: () => setState(() => _isAnnual = false)),
                   _buildToggleOption(title: 'Anual', isSelected: _isAnnual, discount: 'AHORRA 33%', onTap: () => setState(() => _isAnnual = true)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Feature Items ──
            const _FeatureItem(
              icon: CupertinoIcons.sparkles,
              title: 'Algoritmo Prioritario',
              subtitle: 'Aparece en el Top 3 de búsquedas ATS.',
            ),
            const _FeatureItem(
              icon: CupertinoIcons.eye_slash_fill,
              title: 'Modo Incógnito',
              subtitle: 'Visitas secretas a corporativos e inversores.',
            ),
            const _FeatureItem(
              icon: CupertinoIcons.graph_square_fill,
              title: 'Insights Exclusivos',
              subtitle: 'Métricas detalladas sobre quién ve tu perfil.',
            ),
            
            const SizedBox(height: 32),

            // ── Subscribe Button ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 18),
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                onPressed: _processPurchase,
                child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.star_fill, color: Color(0xFFF5B300), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            _isAnnual ? 'Suscribirse — \$9.99/mes' : 'Suscribirse — \$14.99/mes',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            CupertinoButton(
              onPressed: () async {
                 final nav = Navigator.of(context);
                 final bool restored = await RevenueCatService.instance.restorePurchases();
                 if (restored && mounted) nav.pop();
              },
              child: const Text(
                'Restaurar Compras',
                style: TextStyle(color: Color(0xFFF5B300), fontSize: 14),
              ),
           ),
           const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required String title,
    required bool isSelected,
    String? discount,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF333333) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.white54,
                  ),
                ),
              ),
              if (discount != null && isSelected)
                Positioned(
                  top: -22,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      discount,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureItem({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF5B300).withValues(alpha: 0.15),
                  const Color(0xFFF5B300).withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF5B300).withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Icon(icon, size: 24, color: const Color(0xFFF5B300)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                    fontFamily: '.SF Pro Display',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white54,
                    height: 1.3,
                    fontFamily: '.SF Pro Text',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}