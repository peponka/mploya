import 'package:flutter/cupertino.dart';
import 'premium_paywall_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// B2BPaywallScreen — Redirect al paywall unificado
//
// Este archivo existe solo por backward-compatibility. Todas las referencias
// existentes (tiktok_reel_card, profile_screen, ats_dashboard) siguen
// funcionando sin necesidad de cambiar imports.
//
// La lógica real está en PremiumPaywallScreen, que auto-detecta account_type
// y muestra features B2B o Candidato según corresponda.
// ─────────────────────────────────────────────────────────────────────────────

class B2BPaywallScreen extends StatelessWidget {
  const B2BPaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PremiumPaywallScreen();
  }
}
