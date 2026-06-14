import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Divider;
import 'package:cached_network_image/cached_network_image.dart';
import '../services/search_service.dart';
import '../theme/app_theme.dart';


// ─────────────────────────────────────────────────────────────────────────────
// SearchOverlay — Dropdown de resultados de búsqueda con debounce
//
// Se posiciona debajo del search bar y muestra:
//  • Sugerencias de búsquedas recientes
//  • Resultados en tiempo real con debounce
//  • Tags trending cuando el campo está vacío
//
// Uso:
//   SearchOverlay(
//     visible: _showOverlay,
//     onUserTap: (userId) { ... },
//   )
// ─────────────────────────────────────────────────────────────────────────────

class SearchOverlay extends StatefulWidget {
  final bool visible;
  final void Function(String userId)? onUserTap;
  final void Function(String query)? onTagTap;

  const SearchOverlay({
    super.key,
    required this.visible,
    this.onUserTap,
    this.onTagTap,
  });

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  List<String>? _trendingTags;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  void _loadTrending() async {
    final tags = await SearchService.instance.getTrendingTags();
    if (mounted) setState(() => _trendingTags = tags);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: widget.visible ? 1.0 : 0.0,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: StreamBuilder<SearchResults>(
          stream: SearchService.instance.resultsStream,
          builder: (context, snap) {
            final results = snap.data;

            // Loading state
            if (results?.isLoading == true) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CupertinoActivityIndicator(radius: 12),
                ),
              );
            }

            // Results
            if (results != null && results.hasResults) {
              return _buildResultsList(results);
            }

            // Error
            if (results?.hasError == true) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  results!.error!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              );
            }

            // Empty state: show recent + trending
            return _buildEmptyState();
          },
        ),
      ),
    );
  }

  Widget _buildResultsList(SearchResults results) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.users.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
      itemBuilder: (context, index) {
        final user = results.users[index];
        final name = user['name']?.toString() ?? 'Usuario';
        final headline = user['headline']?.toString() ?? '';
        final avatarUrl = user['avatar_url']?.toString();
        final isPremium = user['is_premium'] == true;
        final accountType = user['account_type']?.toString() ?? 'candidato';
        final userId = user['id']?.toString() ?? '';

        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            SearchService.instance.cancel();
            if (widget.onUserTap != null) {
              widget.onUserTap!(userId);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: CupertinoColors.systemGrey5,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const CupertinoActivityIndicator(radius: 8),
                          errorWidget: (_, __, ___) => Icon(
                            accountType == 'empresa'
                                ? CupertinoIcons.building_2_fill
                                : CupertinoIcons.person_fill,
                            size: 22,
                            color: CupertinoColors.systemGrey,
                          ),
                        )
                      : Icon(
                          accountType == 'empresa'
                              ? CupertinoIcons.building_2_fill
                              : CupertinoIcons.person_fill,
                          size: 22,
                          color: CupertinoColors.systemGrey,
                        ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.label,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPremium) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              CupertinoIcons.checkmark_seal_fill,
                              size: 14,
                              color: MployaTheme.brandAccent,
                            ),
                          ],
                        ],
                      ),
                      if (headline.isNotEmpty)
                        Text(
                          headline,
                          style: const TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.systemGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accountType == 'empresa'
                        ? const Color(0xFF0A84FF).withValues(alpha: 0.1)
                        : MployaTheme.brandAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    accountType == 'empresa' ? 'Empresa' : 'Candidato',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accountType == 'empresa'
                          ? const Color(0xFF0A84FF)
                          : MployaTheme.brandAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent searches
          if (SearchService.instance.recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recientes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () {
                    SearchService.instance.clearRecent();
                    setState(() {});
                  },
                  child: const Text(
                    'Limpiar',
                    style: TextStyle(fontSize: 13, color: MployaTheme.brandAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: SearchService.instance.recentSearches.map((q) {
                return GestureDetector(
                  onTap: () => SearchService.instance.search(q, debounce: Duration.zero),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.clock, size: 12, color: CupertinoColors.systemGrey),
                        const SizedBox(width: 6),
                        Text(
                          q,
                          style: const TextStyle(fontSize: 13, color: CupertinoColors.label),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Trending tags
          if (_trendingTags != null && _trendingTags!.isNotEmpty) ...[
            const Text(
              'Trending',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _trendingTags!.map((tag) {
                return GestureDetector(
                  onTap: () {
                    if (widget.onTagTap != null) {
                      widget.onTagTap!(tag);
                    } else {
                      SearchService.instance.search(tag, debounce: Duration.zero);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: MployaTheme.brandAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MployaTheme.brandAccent,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
