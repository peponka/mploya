/// Pantalla de Boost / Destacar Perfil en mploya.
///
/// Permite al usuario seleccionar un plan de visibilidad
/// para destacar su perfil ante empresas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/features/payment/screens/payment_screen.dart';

// ─── Plan data ─────────────────────────────────────────────────────

class _BoostPlan {
  const _BoostPlan({
    required this.emoji,
    required this.emojiBgColor,
    required this.title,
    required this.description,
    required this.price,
    required this.duration,
  });

  final String emoji;
  final Color emojiBgColor;
  final String title;
  final String description;
  final String price;
  final String duration;
}

const _plans = [
  _BoostPlan(
    emoji: '📍',
    emojiBgColor: Color(0xFF3B82F6), // blue
    title: 'Local Boost',
    description:
        'Destaca localmente en tu ciudad. Ideal para trabajos presenciales.',
    price: '\$4.99',
    duration: '7 Días',
  ),
  _BoostPlan(
    emoji: '🏠',
    emojiBgColor: Color(0xFFF97316), // orange
    title: 'Remote Boost',
    description:
        'Alcance nacional para oportunidades de trabajo remoto u oficinas de IT.',
    price: '\$9.99',
    duration: '14 Días',
  ),
  _BoostPlan(
    emoji: '🌐',
    emojiBgColor: Color(0xFFF59E0B), // gold
    title: 'Passport',
    description:
        'Alcance Global VIP. Visibilidad Mundial 10x para candidatos Elite.',
    price: '\$19.99',
    duration: '30 Días',
  ),
];

// ─── Screen ────────────────────────────────────────────────────────

class BoostScreen extends StatefulWidget {
  const BoostScreen({super.key});

  @override
  State<BoostScreen> createState() => _BoostScreenState();
}

class _BoostScreenState extends State<BoostScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.background,
      appBar: AppBar(
        backgroundColor: MployaColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.chevron_left,
                  color: MployaColors.orange,
                  size: 24,
                ),
                Text(
                  'Perfil',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),
        leadingWidth: 100,
        title: Text(
          'Destacar Perfil',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MployaColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ─── Scrollable content ────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                children: [
                  // ─── Fire emoji hero ─────────────────────────
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: MployaColors.orangeSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('🔥', style: TextStyle(fontSize: 36)),
                    ),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.6, 0.6),
                        end: const Offset(1.0, 1.0),
                        duration: 500.ms,
                        curve: Curves.elasticOut,
                      )
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: AppSpacing.lg),

                  // ─── Title ──────────────────────────────────
                  Text(
                    'Multiplica tus Entrevistas',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: MployaColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                  const SizedBox(height: AppSpacing.sm),

                  // ─── Subtitle ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      'Destaca tu perfil en el feed de las empresas por '
                      'tiempo limitado y recibe ofertas urgentes.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: MployaColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                  const SizedBox(height: AppSpacing.xl),

                  // ─── Plan cards ────────────────────────────
                  ...List.generate(_plans.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _PlanCard(
                        plan: _plans[i],
                        isSelected: _selectedIndex == i,
                        onTap: () => setState(() => _selectedIndex = i),
                      ),
                    )
                        .animate()
                        .fadeIn(
                          delay: (300 + i * 100).ms,
                          duration: 400.ms,
                        )
                        .slideY(
                          begin: 0.15,
                          end: 0,
                          delay: (300 + i * 100).ms,
                          duration: 400.ms,
                          curve: Curves.easeOut,
                        );
                  }),
                ],
              ),
            ),
          ),

          // ─── Sticky button ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              color: MployaColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: MployaButton(
              label: 'Activar Boost',
              onPressed: () {
                final plan = _plans[_selectedIndex];
                final price = double.tryParse(
                      plan.price.replaceAll('\$', ''),
                    ) ??
                    0.0;
                context.push(
                  '/payment',
                  extra: PaymentProduct(
                    name: plan.title,
                    description: plan.description,
                    price: price,
                    duration: plan.duration,
                    icon: Icons.rocket_launch_rounded,
                    color: plan.emojiBgColor,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Plan card widget ──────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  final _BoostPlan plan;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: MployaColors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isSelected ? MployaColors.orange : MployaColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? MployaColors.orange.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // ─── Emoji circle ───────────────────────────────
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: plan.emojiBgColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  plan.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // ─── Text content ───────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: MployaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MployaColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // ─── Price & duration ────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.price,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: MployaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  plan.duration,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.orange,
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
