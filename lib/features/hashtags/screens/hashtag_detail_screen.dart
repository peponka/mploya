/// Pantalla de detalle de un hashtag en mploya.
///
/// Muestra el hashtag, conteo de profesionales, tags relacionados
/// y lista de profesionales que usan ese hashtag.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

// ─── Mock Data ─────────────────────────────────────────────────────

class _MockProfessional {
  const _MockProfessional({
    required this.name,
    required this.role,
    required this.avatarUrl,
    this.isVerified = false,
    this.hashtags = const [],
  });

  final String name;
  final String role;
  final String avatarUrl;
  final bool isVerified;
  final List<String> hashtags;
}

class _MockVideo {
  const _MockVideo({
    required this.views,
    required this.duration,
    required this.gradientColors,
  });

  final String views;
  final String duration;
  final List<Color> gradientColors;
}

const _mockRelatedTags = [
  'inversiones',
  'finanzas',
  'portfolio',
  'wealth management',
  'patrimonio',
  'advisory',
  'banca privada',
  'activos',
];

const _mockProfessionals = [
  _MockProfessional(
    name: 'Alejandro Ruiz',
    role: 'Wealth Manager Sr.',
    avatarUrl: 'https://i.pravatar.cc/150?img=14',
    isVerified: true,
    hashtags: ['wealth', 'finanzas', 'inversiones'],
  ),
  _MockProfessional(
    name: 'Valentina Torres',
    role: 'Private Banker',
    avatarUrl: 'https://i.pravatar.cc/150?img=20',
    isVerified: true,
    hashtags: ['wealth', 'banca', 'patrimonio'],
  ),
  _MockProfessional(
    name: 'Roberto Sánchez',
    role: 'Financial Advisor',
    avatarUrl: 'https://i.pravatar.cc/150?img=33',
    isVerified: false,
    hashtags: ['wealth', 'advisory', 'portfolio'],
  ),
  _MockProfessional(
    name: 'Camila Herrera',
    role: 'Investment Analyst',
    avatarUrl: 'https://i.pravatar.cc/150?img=25',
    isVerified: false,
    hashtags: ['wealth', 'inversiones', 'activos'],
  ),
  _MockProfessional(
    name: 'Fernando López',
    role: 'Portfolio Manager',
    avatarUrl: 'https://i.pravatar.cc/150?img=53',
    isVerified: true,
    hashtags: ['wealth', 'portfolio', 'fondos'],
  ),
];

const _mockVideos = [
  _MockVideo(
    views: '12.4K',
    duration: '0:45',
    gradientColors: [Color(0xFFF97316), Color(0xFFEA580C)],
  ),
  _MockVideo(
    views: '8.1K',
    duration: '1:20',
    gradientColors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
  ),
  _MockVideo(
    views: '5.7K',
    duration: '0:58',
    gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
  ),
  _MockVideo(
    views: '24.3K',
    duration: '0:30',
    gradientColors: [Color(0xFFEA580C), Color(0xFFDC2626)],
  ),
  _MockVideo(
    views: '3.2K',
    duration: '1:00',
    gradientColors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
  ),
  _MockVideo(
    views: '15.9K',
    duration: '0:42',
    gradientColors: [Color(0xFFEC4899), Color(0xFFDB2777)],
  ),
  _MockVideo(
    views: '7.6K',
    duration: '1:15',
    gradientColors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
  ),
  _MockVideo(
    views: '19.8K',
    duration: '0:35',
    gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
  ),
  _MockVideo(
    views: '4.5K',
    duration: '0:55',
    gradientColors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
  ),
];

// ─── Screen ────────────────────────────────────────────────────────

class HashtagDetailScreen extends ConsumerStatefulWidget {
  const HashtagDetailScreen({
    this.hashtag = 'wealth',
    super.key,
  });

  final String hashtag;

  @override
  ConsumerState<HashtagDetailScreen> createState() =>
      _HashtagDetailScreenState();
}

class _HashtagDetailScreenState extends ConsumerState<HashtagDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.white,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // ─── Custom App Bar ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 20),
                      onPressed: () => context.pop(),
                      color: MployaColors.textPrimary,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 22),
                      onPressed: () {},
                      color: MployaColors.textSecondary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_horiz, size: 22),
                      onPressed: () {},
                      color: MployaColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),

            // ─── Hashtag Header ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.md),

                    // Hashtag icon circle
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFB923C),
                            Color(0xFFF97316),
                            Color(0xFFEA580C),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        boxShadow: [
                          BoxShadow(
                            color:
                                MployaColors.orange.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '#',
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Hashtag name prominently
                    Text(
                      '#${widget.hashtag}',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: MployaColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Publication count stat
                    Text(
                      '1.2K publicaciones',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: MployaColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Professional count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: MployaColors.orangeSurface,
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color:
                              MployaColors.orange.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 16,
                            color: MployaColors.orange,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '${_mockProfessionals.length} profesionales',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: MployaColors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ─── Search Bar ──────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: MployaColors.surfaceVariant,
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: MployaColors.borderLight,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: MployaColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Buscar en #${widget.hashtag}...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: MployaColors.textTertiary,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 20,
                            color: MployaColors.textTertiary,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: AppSpacing.md,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ─── Related Tags ────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'RELACIONADOS',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: MployaColors.textTertiary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Related tags pills
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _mockRelatedTags.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final tag = _mockRelatedTags[index];
                          return GestureDetector(
                            onTap: () => context
                                .push('/hashtags/detail?name=$tag'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    AppRadius.pill),
                                border: Border.all(
                                  color: MployaColors.orange
                                      .withValues(alpha: 0.35),
                                ),
                                color: MployaColors.orangeSurface
                                    .withValues(alpha: 0.5),
                              ),
                              child: Text(
                                '#$tag',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: MployaColors.orange,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),

            // ─── Tab Bar ──────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                child: Container(
                  color: MployaColors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: MployaColors.orange,
                    unselectedLabelColor: MployaColors.textTertiary,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    indicatorColor: MployaColors.orange,
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: MployaColors.borderLight,
                    tabs: const [
                      Tab(text: 'Top Videos'),
                      Tab(text: 'Recientes'),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              // ─── Top Videos Tab ──────────────────────────────
              _buildVideoGrid(),
              // ─── Recientes Tab ───────────────────────────────
              _buildRecentContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoGrid() {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.md),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.65,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final video = _mockVideos[index % _mockVideos.length];
                return _VideoThumbnailCard(video: video);
              },
              childCount: 9,
            ),
          ),
        ),
        // Professionals section below the grid
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              const Divider(color: MployaColors.borderLight),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Text(
                      'PROFESIONALES',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: MployaColors.textTertiary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {},
                      child: Text(
                        'Ver todos',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: MployaColors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final professional = _mockProfessionals[index];
              return GestureDetector(
                onTap: () => context.push('/profile/user'),
                child: _ProfessionalTile(professional: professional),
              );
            },
            childCount: _mockProfessionals.length,
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.xl),
        ),
      ],
    );
  }

  Widget _buildRecentContent() {
    // Recientes tab: same grid, shuffled order
    final recentVideos = _mockVideos.reversed.toList();
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.md),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.65,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final video =
                    recentVideos[index % recentVideos.length];
                return _VideoThumbnailCard(video: video);
              },
              childCount: 9,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.xl),
        ),
      ],
    );
  }
}

// ─── Sticky Tab Bar Delegate ───────────────────────────────────────

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabBarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) =>
      child != oldDelegate.child;
}

// ─── Video Thumbnail Card ──────────────────────────────────────────

class _VideoThumbnailCard extends StatelessWidget {
  const _VideoThumbnailCard({required this.video});

  final _MockVideo video;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient thumbnail placeholder
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: video.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.play_circle_outline,
                  size: 32,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),

            // Bottom gradient overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),

            // View count
            Positioned(
              left: 6,
              bottom: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_arrow,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    video.views,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Duration badge
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  video.duration,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Professional Tile ─────────────────────────────────────────────

class _ProfessionalTile extends StatelessWidget {
  const _ProfessionalTile({required this.professional});

  final _MockProfessional professional;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 1,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: MployaColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(professional.avatarUrl),
            backgroundColor: MployaColors.surfaceVariant,
          ),

          const SizedBox(width: AppSpacing.md),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      professional.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: MployaColors.textPrimary,
                      ),
                    ),
                    if (professional.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        size: 16,
                        color: MployaColors.orange,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  professional.role,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MployaColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                // Hashtag pills
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: professional.hashtags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: MployaColors.orangeSurface,
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '#$tag',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: MployaColors.orange,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Chevron
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: MployaColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
