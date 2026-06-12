import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/hashtag_service.dart';
import 'profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TrendingHashtagsScreen — Descubrir talento por trending hashtags
//
// Muestra:
//  • Top 20 hashtags con barra de frecuencia visual
//  • Al tocar un hashtag, muestra los usuarios que lo tienen
//  • Related hashtags para explorar lateralmente
// ─────────────────────────────────────────────────────────────────────────────

class TrendingHashtagsScreen extends StatefulWidget {
  final String? initialTag;

  const TrendingHashtagsScreen({super.key, this.initialTag});

  @override
  State<TrendingHashtagsScreen> createState() => _TrendingHashtagsScreenState();
}

class _TrendingHashtagsScreenState extends State<TrendingHashtagsScreen> {
  String? _selectedTag;
  List<HashtagData> _trending = [];
  List<Map<String, dynamic>> _tagUsers = [];
  List<String> _relatedTags = [];
  bool _isLoadingTrending = true;
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    _loadTrending();
    if (widget.initialTag != null) {
      _selectTag(widget.initialTag!);
    }
  }

  Future<void> _loadTrending() async {
    final trending = await HashtagService.instance.getTrendingHashtags(limit: 20);
    if (mounted) {
      setState(() {
        _trending = trending;
        _isLoadingTrending = false;
      });
    }
  }

  Future<void> _selectTag(String tag) async {
    setState(() {
      _selectedTag = tag;
      _isLoadingUsers = true;
    });

    final users = await HashtagService.instance.searchByHashtag(tag);
    final related = await HashtagService.instance.getRelatedHashtags(tag);

    if (mounted) {
      setState(() {
        _tagUsers = users;
        _relatedTags = related;
        _isLoadingUsers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          _selectedTag != null ? '#$_selectedTag' : 'Trending Hashtags',
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        trailing: _selectedTag != null
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => setState(() {
                  _selectedTag = null;
                  _tagUsers = [];
                  _relatedTags = [];
                }),
                child: const Text('Todos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              )
            : null,
      ),
      child: SafeArea(
        child: _selectedTag != null
            ? _buildTagDetailView()
            : _buildTrendingList(),
      ),
    );
  }

  Widget _buildTrendingList() {
    if (_isLoadingTrending) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }

    if (_trending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏷️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Aún no hay hashtags', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.textPrimary)),
            const SizedBox(height: 6),
            Text('¡Sé el primero en agregar tags a tu perfil!', style: TextStyle(fontSize: 14, color: context.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _trending.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DESCUBRIR TALENTO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Los hashtags más populares en la comunidad',
                  style: TextStyle(fontSize: 15, color: context.textSecondary, height: 1.4),
                ),
              ],
            ),
          );
        }

        final hashtag = _trending[index - 1];
        return _TrendingHashtagTile(
          hashtag: hashtag,
          rank: index,
          onTap: () => _selectTag(hashtag.tag),
        );
      },
    );
  }

  Widget _buildTagDetailView() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Tag Header ──
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag pill grande
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [NexTheme.premiumStart, NexTheme.premiumEnd],
                    ),
                    borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
                    boxShadow: [
                      BoxShadow(
                        color: NexTheme.brandAccent.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.number, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _selectedTag!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${_tagUsers.length} profesionales',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textSecondary),
                ),
              ],
            ),
          ),
        ),

        // ── Related Tags ──
        if (_relatedTags.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RELACIONADOS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: context.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _relatedTags.map((t) => GestureDetector(
                      onTap: () => _selectTag(t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: context.brandAccent.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
                          border: Border.all(
                            color: context.brandAccent.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          '#$t',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.brandAccent,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),

        // ── Separator ──
        SliverToBoxAdapter(
          child: Container(height: 0.5, color: context.dividerColor),
        ),

        // ── Users List ──
        if (_isLoadingUsers)
          const SliverFillRemaining(
            child: Center(child: CupertinoActivityIndicator(radius: 14)),
          )
        else if (_tagUsers.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔍', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    'Nadie más tiene #$_selectedTag',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '¡Sos pionero en esta habilidad!',
                    style: TextStyle(fontSize: 14, color: context.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final user = NexUser.fromJson(_tagUsers[index]);
                return _UserTagTile(user: user, tag: _selectedTag!);
              },
              childCount: _tagUsers.length,
            ),
          ),
      ],
    );
  }
}

// ── Trending Hashtag Tile ────────────────────────────────────────────────────

class _TrendingHashtagTile extends StatelessWidget {
  final HashtagData hashtag;
  final int rank;
  final VoidCallback onTap;

  const _TrendingHashtagTile({
    required this.hashtag,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // Rank number
            SizedBox(
              width: 32,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: isTop3 ? 22 : 16,
                  fontWeight: FontWeight.w800,
                  color: isTop3 ? MployaTheme.brandAccent : context.textTertiary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Tag + bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${hashtag.tag}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Frequency bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 4,
                      child: Stack(
                        children: [
                          Container(color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7)),
                          FractionallySizedBox(
                            widthFactor: (hashtag.trendScore / 100).clamp(0.05, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isTop3
                                      ? [NexTheme.premiumStart, NexTheme.premiumEnd]
                                      : [context.brandAccent.withValues(alpha: 0.4), context.brandAccent.withValues(alpha: 0.6)],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.brandAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${hashtag.count}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.brandAccent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(CupertinoIcons.chevron_right, size: 14, color: context.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ── User Tag Tile ────────────────────────────────────────────────────────────

class _UserTagTile extends StatelessWidget {
  final NexUser user;
  final String tag;

  const _UserTagTile({required this.user, required this.tag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => ProfileScreen(user: user)),
      ),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: MployaTheme.brandAccent.withValues(alpha: 0.1),
              backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                  ? Text(user.initials,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: MployaTheme.brandAccent))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isVerified || user.isPremium)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            size: 14,
                            color: context.brandAccent,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.headline,
                    style: TextStyle(fontSize: 14, color: context.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.tags.length > 1) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: user.tags
                          .where((t) => t.toLowerCase() != tag.toLowerCase())
                          .take(3)
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '#$t',
                                  style: TextStyle(fontSize: 11, color: context.textTertiary, fontWeight: FontWeight.w500),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}