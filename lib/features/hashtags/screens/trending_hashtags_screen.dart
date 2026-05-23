/// Pantalla de trending hashtags en mploya.
///
/// Muestra una lista ranqueada de hashtags con barras de progreso
/// proporcionales a su conteo de uso.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/core/models/hashtag_model.dart';

// ─── Mock Data ─────────────────────────────────────────────────────

const List<HashtagModel> _trendingHashtags = [
  HashtagModel(id: 't1', name: 'flutter', count: 9, relatedTags: ['dart', 'mobile', 'ui']),
  HashtagModel(id: 't2', name: 'finanzas', count: 7, relatedTags: ['contabilidad', 'excel', 'analista']),
  HashtagModel(id: 't3', name: 'fintech', count: 6, relatedTags: ['cripto', 'blockchain', 'pagos']),
  HashtagModel(id: 't4', name: 'it', count: 5, relatedTags: ['software', 'devops', 'cloud']),
  HashtagModel(id: 't5', name: 'lider', count: 4, relatedTags: ['management', 'equipo', 'gestión']),
  HashtagModel(id: 't6', name: 'cripto', count: 3, relatedTags: ['blockchain', 'defi', 'web3']),
  HashtagModel(id: 't7', name: 'react', count: 3, relatedTags: ['javascript', 'frontend', 'nextjs']),
  HashtagModel(id: 't8', name: 'ia', count: 2, relatedTags: ['ml', 'python', 'datos']),
  HashtagModel(id: 't9', name: 'contenidos', count: 2, relatedTags: ['marketing', 'social', 'copywriting']),
  HashtagModel(id: 't10', name: 'social', count: 2, relatedTags: ['marketing', 'contenidos', 'redes']),
  HashtagModel(id: 't11', name: 'ingeniero', count: 1, relatedTags: ['software', 'civil', 'industrial']),
  HashtagModel(id: 't12', name: 'global', count: 1, relatedTags: ['remoto', 'internacional', 'multicultural']),
  HashtagModel(id: 't13', name: 'payments', count: 1, relatedTags: ['fintech', 'stripe', 'pasarelas']),
  HashtagModel(id: 't14', name: 'consumo masivo', count: 1, relatedTags: ['retail', 'cpg', 'ventas']),
];

// ─── Screen ────────────────────────────────────────────────────────

class TrendingHashtagsScreen extends ConsumerWidget {
  const TrendingHashtagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxCount = _trendingHashtags.first.count;

    return Scaffold(
      backgroundColor: MployaColors.white,
      appBar: AppBar(
        backgroundColor: MployaColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Trending Hashtags',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MployaColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              'DESCUBRIR TALENTO',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MployaColors.textTertiary,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // Hashtag list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _trendingHashtags.length,
              itemBuilder: (context, index) {
                final hashtag = _trendingHashtags[index];
                final rank = index + 1;
                final progress = hashtag.count / maxCount;

                return _HashtagListTile(
                  rank: rank,
                  hashtag: hashtag,
                  progress: progress,
                  onTap: () {
                    context.push('/hashtags/detail?name=${hashtag.name}');
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hashtag List Tile ─────────────────────────────────────────────

class _HashtagListTile extends StatelessWidget {
  const _HashtagListTile({
    required this.rank,
    required this.hashtag,
    required this.progress,
    required this.onTap,
  });

  final int rank;
  final HashtagModel hashtag;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Rank number
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MployaColors.orange,
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            // Hashtag name + progress bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${hashtag.name}',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: MployaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: MployaColors.borderLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        MployaColors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            // Count
            Text(
              '${hashtag.count}',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: MployaColors.orange,
              ),
            ),

            const SizedBox(width: AppSpacing.xs),

            // Chevron
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: MployaColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

