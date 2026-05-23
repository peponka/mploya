/// Pantalla de Analytics en mploya.
///
/// Muestra un resumen semanal con estadísticas de vistas, matches y videos,
/// además de búsquedas y mensajes, y un placeholder para datos de 30 días.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

// ─── Screen ────────────────────────────────────────────────────────

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.white,
      appBar: AppBar(
        backgroundColor: MployaColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Center(
              child: Text(
                '< Perfil',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: MployaColors.orange,
                ),
              ),
            ),
          ),
        ),
        leadingWidth: 80,
        title: Text(
          'Analytics',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MployaColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Weekly Summary Card ──────────────────────────
            _buildWeeklySummaryCard()
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.1, end: 0, duration: 500.ms),

            const SizedBox(height: AppSpacing.md),

            // ─── Search & Messages Mini Cards ─────────────────
            _buildMiniCards()
                .animate()
                .fadeIn(duration: 500.ms, delay: 150.ms)
                .slideY(begin: 0.1, end: 0, duration: 500.ms, delay: 150.ms),

            const SizedBox(height: AppSpacing.lg),

            // ─── Last 30 Days Section ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'Últimos 30 días',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MployaColors.textPrimary,
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms, delay: 300.ms),

            const SizedBox(height: AppSpacing.md),

            // ─── Empty Data Card ──────────────────────────────
            _buildEmptyDataCard()
                .animate()
                .fadeIn(duration: 500.ms, delay: 400.ms)
                .slideY(begin: 0.1, end: 0, duration: 500.ms, delay: 400.ms),
          ],
        ),
      ),
    );
  }

  // ─── Weekly Summary Blue Gradient Card ───────────────────────────

  Widget _buildWeeklySummaryCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Resumen Semanal',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Stat boxes row
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  emoji: '👁️',
                  label: 'Vistas',
                  value: '0',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatBox(
                  emoji: '❤️',
                  label: 'Matches',
                  value: '0',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatBox(
                  emoji: '▶️',
                  label: 'Videos',
                  value: '0',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Search & Messages Mini Cards ────────────────────────────────

  Widget _buildMiniCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _MiniCard(
              icon: Icons.search_rounded,
              iconBgColor: MployaColors.orange,
              label: '0 Búsquedas',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _MiniCard(
              icon: Icons.chat_bubble_outline_rounded,
              iconBgColor: const Color(0xFF8B5CF6),
              label: '0 Mensajes',
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty Data Card ─────────────────────────────────────────────

  Widget _buildEmptyDataCard() {
    return Container(
      width: double.infinity,
      height: 150,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: MployaColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: MployaColors.borderLight),
      ),
      child: Center(
        child: Text(
          'Sin datos aún',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: MployaColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

// ─── Stat Box Widget ───────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.emoji,
    required this.label,
    required this.value,
  });

  final String emoji;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mini Card Widget ──────────────────────────────────────────────

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.icon,
    required this.iconBgColor,
    required this.label,
  });

  final IconData icon;
  final Color iconBgColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MployaColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: MployaColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MployaColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
