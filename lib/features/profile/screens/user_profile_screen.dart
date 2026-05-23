/// Pantalla de perfil de otro usuario en mploya.
///
/// Layout sin tabs - todo en un SingleChildScrollView.
/// Muestra avatar, stats, botones de acción, video pitch,
/// análisis IA, hashtags y portfolio.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

// ─── Mock Data ─────────────────────────────────────────────────────

class _MockProfileData {
  const _MockProfileData({
    required this.name,
    required this.role,
    required this.avatarUrl,
    this.isVerified = false,
    this.isActive = false,
    this.isHiring = false,
    this.conexiones = 0,
    this.vistas = 0,
    this.matches = 0,
    this.aiScore = 0,
    this.aiAnalysis,
    this.hashtags = const [],
    this.portfolioItems = const [],
  });

  final String name;
  final String role;
  final String avatarUrl;
  final bool isVerified;
  final bool isActive;
  final bool isHiring;
  final int conexiones;
  final int vistas;
  final int matches;
  final int aiScore;
  final String? aiAnalysis;
  final List<_MockHashtag> hashtags;
  final List<_MockPortfolioItem> portfolioItems;
}

class _MockHashtag {
  const _MockHashtag(this.name, this.count);
  final String name;
  final int count;
}

class _MockPortfolioItem {
  const _MockPortfolioItem({
    required this.title,
    required this.duration,
    this.views = 0,
    this.likes = 0,
  });
  final String title;
  final String duration;
  final int views;
  final int likes;
}

const _mockProfile = _MockProfileData(
  name: 'Carlos Mendoza',
  role: 'Flutter Developer Sr.',
  avatarUrl: 'https://i.pravatar.cc/150?img=3',
  isVerified: true,
  isActive: true,
  isHiring: false,
  conexiones: 48,
  vistas: 312,
  matches: 15,
  aiScore: 92,
  aiAnalysis:
      'Perfil técnico con alta competencia en desarrollo móvil multiplataforma. '
      'Demuestra capacidad de liderazgo técnico y comunicación efectiva. '
      'Fortalezas en resolución de problemas y trabajo en equipo.',
  hashtags: [
    _MockHashtag('flutter', 10),
    _MockHashtag('react', 3),
    _MockHashtag('mobile', 5),
    _MockHashtag('dart', 4),
  ],
  portfolioItems: [
    _MockPortfolioItem(
      title: 'App de Fintech',
      duration: '30s',
      views: 245,
      likes: 32,
    ),
    _MockPortfolioItem(
      title: 'Dashboard IoT',
      duration: '28s',
      views: 189,
      likes: 24,
    ),
  ],
);

// ─── Screen ────────────────────────────────────────────────────────

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({
    this.userId,
    super.key,
  });

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const profile = _mockProfile;

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
          profile.name,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MployaColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          // Share icon
          IconButton(
            icon: const Icon(Icons.ios_share, size: 22),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enlace del perfil copiado al portapapeles'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          // 3-dot menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            onSelected: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(value == 'report' ? 'Perfil reportado' : 'Usuario bloqueado')),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'report', child: Text('Reportar')),
              const PopupMenuItem(value: 'block', child: Text('Bloquear')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: AppSpacing.lg),

            // 1. Avatar with verified overlay
            Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: NetworkImage(profile.avatarUrl),
                  backgroundColor: MployaColors.surfaceVariant,
                ),
                // Verified overlay icon
                if (profile.isVerified)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: MployaColors.teal,
                        shape: BoxShape.circle,
                        border: Border.all(color: MployaColors.white, width: 3),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              profile.name,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: MployaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              profile.role,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: MployaColors.textSecondary,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // 2. Badges (Verificado + Activo/Contratando)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (profile.isVerified)
                  _Badge(
                    label: 'Verificado',
                    color: MployaColors.teal,
                    icon: Icons.verified,
                  ),
                if (profile.isActive) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _Badge(
                    label: 'Activo',
                    color: MployaColors.orange,
                    icon: Icons.circle,
                    iconSize: 8,
                  ),
                ],
                if (profile.isHiring) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _Badge(
                    label: 'Contratando',
                    color: MployaColors.blue,
                    icon: Icons.work,
                  ),
                ],
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // 3. Stats row with dividers
            IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatItem(count: profile.conexiones, label: 'Conexiones'),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: MployaColors.border,
                    indent: 6,
                    endIndent: 6,
                  ),
                  _StatItem(count: profile.vistas, label: 'Vistas'),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: MployaColors.border,
                    indent: 6,
                    endIndent: 6,
                  ),
                  _StatItem(count: profile.matches, label: 'Matches'),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // 4. TWO action buttons side by side
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('¡Interés enviado! El usuario será notificado.'),
                          backgroundColor: Color(0xFF00B894),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MployaColors.orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    child: Text(
                      'Mostrar Interés',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      context.push('/chat/new-${profile.name.toLowerCase().replaceAll(' ', '-')}');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MployaColors.orange,
                      side: const BorderSide(color: MployaColors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    child: Text(
                      'Mensaje',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // 5. '★ Ver Reviews' full width orange outlined button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.push('/reviews?company=${Uri.encodeComponent(profile.name)}');
                },
                icon: const Icon(Icons.star, size: 18),
                label: Text(
                  'Ver Reviews',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MployaColors.orange,
                  side: const BorderSide(color: MployaColors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 6. Video Pitch
            _SectionTitle(title: 'Video-Pitch'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Stack(
                children: [
                  // Play button
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 56,
                      color: MployaColors.orange,
                    ),
                  ),
                  // Video badge
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MployaColors.orange,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        'Video',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Score
                  Positioned(
                    top: AppSpacing.md,
                    right: AppSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '${profile.aiScore} pts',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 7. AI Personality Analysis
            if (profile.aiAnalysis != null) ...[
              _SectionTitle(title: 'Análisis de Personalidad IA'),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: MployaColors.orangeSurface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: MployaColors.orange.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🧠', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: MployaColors.orangeGradient,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            'IA',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      profile.aiAnalysis!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MployaColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // 8. Hashtags
            if (profile.hashtags.isNotEmpty) ...[
              _SectionTitle(title: 'Hashtags'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: profile.hashtags.map(
                  (h) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: MployaColors.orangeSurface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '#${h.name}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: MployaColors.orange,
                      ),
                    ),
                  ),
                ).toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // 9. Portfolio
            if (profile.portfolioItems.isNotEmpty) ...[
              _SectionTitle(
                title: 'Portfolio ${profile.portfolioItems.length}/3',
              ),
              const SizedBox(height: AppSpacing.sm),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 0.85,
                ),
                itemCount: profile.portfolioItems.length,
                itemBuilder: (context, index) {
                  final item = profile.portfolioItems[index];
                  return _PortfolioCard(item: item);
                },
              ),
            ],

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ─── Helper Widgets ────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.icon,
    this.iconSize = 14,
  });

  final String label;
  final Color color;
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.count, required this.label});
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          Text(
            '$count',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: MployaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MployaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: MployaColors.textPrimary,
        ),
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({required this.item});
  final _MockPortfolioItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Stack(
        children: [
          // Play button
          const Center(
            child: Icon(
              Icons.play_circle_fill,
              size: 40,
              color: MployaColors.orange,
            ),
          ),
          // Duration badge
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                item.duration,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Title + stats at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.visibility,
                          size: 12, color: Colors.white60),
                      const SizedBox(width: 3),
                      Text(
                        '${item.views}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.favorite,
                          size: 12, color: Colors.white60),
                      const SizedBox(width: 3),
                      Text(
                        '${item.likes}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
