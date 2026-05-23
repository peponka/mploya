/// Pantalla de reviews de un usuario/empresa.
///
/// Muestra rating card con score, estrellas, categorías,
/// lista de reviews o estado vacío, y botón para escribir review.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

// ─── Reviews Screen ──────────────────────────────────────────────────

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({
    this.userName = 'Tagua',
    super.key,
  });

  final String userName;

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  void _showWriteReviewSheet() {
    int selectedStars = 0;
    final reviewController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Escribir Review',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: MployaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedStars = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            i < selectedStars ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: i < selectedStars ? MployaColors.orange : MployaColors.textTertiary,
                            size: 36,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: reviewController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu opinión...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('¡Review enviada con éxito!'),
                            backgroundColor: Color(0xFF00B894),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MployaColors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      child: Text(
                        'Enviar Review',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.white,
      appBar: AppBar(
        backgroundColor: MployaColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
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
                  'Atrás',
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
        centerTitle: true,
        title: Text(
          widget.userName,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MployaColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: GestureDetector(
              onTap: _showWriteReviewSheet,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: MployaColors.teal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: MployaColors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),

            // ── Rating card ──
            _buildRatingCard()
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.03, curve: Curves.easeOut),

            const SizedBox(height: AppSpacing.xxl),

            // ── Empty state ──
            _buildEmptyState()
                .animate()
                .fadeIn(delay: 150.ms, duration: 400.ms),

            const SizedBox(height: AppSpacing.xxl),

            // ── Write review button ──
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _showWriteReviewSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MployaColors.orange,
                    foregroundColor: MployaColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  child: Text(
                    'Escribir Review',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MployaColors.white,
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 250.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  // ─── Rating card ───────────────────────────────────────────────────

  Widget _buildRatingCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: MployaColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: MployaColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Score
            Text(
              '0.0',
              style: GoogleFonts.outfit(
                fontSize: 44,
                fontWeight: FontWeight.w700,
                color: MployaColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    Icons.star_outline_rounded,
                    color: MployaColors.textTertiary,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Reviews count
            Text(
              '0 reviews',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MployaColors.textTertiary,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Category sub-cards
            Row(
              children: [
                // Cultura
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: MployaColors.tealLight,
                      borderRadius:
                          BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Cultura',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MployaColors.teal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '-',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: MployaColors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Entrevista
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius:
                          BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Entrevista',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MployaColors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '-',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: MployaColors.blue,
                          ),
                        ),
                      ],
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

  // ─── Empty state ───────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.chat_bubble_outline_rounded,
          size: 56,
          color: MployaColors.textTertiary.withValues(alpha: 0.4),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Sin reviews aún',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MployaColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
