import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../screens/profile_screen.dart';
import '../screens/search_screen.dart';
import '../screens/trending_hashtags_screen.dart';
import '../screens/micro_pitch_camera.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reel Card Info Panel — Bottom-left info overlay del TikTokReelCard
//
// Muestra: tags, nombre + status badge, headline, company, mutuals,
// video reply button, y video reply indicator.
// Extraído de tiktok_reel_card.dart para reducir el tamaño del god file.
// ─────────────────────────────────────────────────────────────────────────────

/// Tag pill — pill con hashtag clickeable que navega a búsqueda.
class ReelTagPill extends StatelessWidget {
  final String tag;
  const ReelTagPill({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Buscar hashtag $tag',
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(CupertinoPageRoute(
            builder: (_) => TrendingHashtagsScreen(initialTag: tag),
          ));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
          ),
          child: Text(
            '#$tag',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tag pill claro (fondo blanco/gris) para el panel de info en tarjeta blanca.
class _WhiteTagPill extends StatelessWidget {
  final String tag;
  const _WhiteTagPill({required this.tag});

  @override
  Widget build(BuildContext context) {
    final label = tag.isEmpty ? tag : tag[0].toUpperCase() + tag.substring(1);
    return Semantics(
      button: true,
      label: 'Buscar hashtag $tag',
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(CupertinoPageRoute(
            builder: (_) => TrendingHashtagsScreen(initialTag: tag),
          ));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: NexTheme.brandAccent, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status badge (Disponible / Contratando) junto al nombre.
class ReelStatusBadge extends StatelessWidget {
  final NexUser author;
  const ReelStatusBadge({super.key, required this.author});

  @override
  Widget build(BuildContext context) {
    // Solo mostrar badge si tiene un estado explícito
    if (!author.isOpenToWork && !author.isHiring) {
      return const SizedBox.shrink();
    }
    final statusText = author.isOpenToWork ? 'Disponible' : 'Contratando';
    final statusColor = author.isOpenToWork
        ? NexTheme.brandAccent
        : const Color(0xFF3B82F6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mutual connections row with overlapping avatars.
class ReelMutualConnections extends StatelessWidget {
  final List<Map<String, dynamic>> mutualConnections;
  const ReelMutualConnections({super.key, required this.mutualConnections});

  @override
  Widget build(BuildContext context) {
    if (mutualConnections.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Overlapping avatars
          SizedBox(
            width: 16.0 + (mutualConnections.length.clamp(0, 3) * 14.0),
            height: 20,
            child: Stack(
              children: List.generate(
                mutualConnections.length.clamp(0, 3),
                (i) {
                  final m = mutualConnections[i];
                  final avatarUrl = m['avatar_url']?.toString();
                  final initials = (m['name']?.toString() ?? '?')[0].toUpperCase();
                  return Positioned(
                    left: i * 14.0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF5F3DC4),
                        border: Border.all(color: Colors.black54, width: 1.5),
                        image: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? DecorationImage(image: CachedNetworkImageProvider(avatarUrl), fit: BoxFit.cover)
                            : null,
                      ),
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)))
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            mutualConnections.length == 1
                ? '${mutualConnections.first['name']} en común'
                : '${mutualConnections.length} en común',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Responder con Video" button.
class ReelVideoReplyButton extends StatelessWidget {
  final NexUser author;
  const ReelVideoReplyButton({super.key, required this.author});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Responder con un video a ${author.name}',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => MicroPitchCamera(
                receiverId: author.id,
                receiverName: author.name,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.reply, color: Colors.white70, size: 13),
              SizedBox(width: 5),
              Text(
                'Responder con Video',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Video Reply received indicator.
class ReelVideoReplyIndicator extends StatelessWidget {
  final String? replyVideoUrl;
  final VoidCallback onTap;

  const ReelVideoReplyIndicator({
    super.key,
    required this.replyVideoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (replyVideoUrl == null) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF5F3DC4).withValues(alpha: 0.50),
                      const Color(0xFFAE3EC9).withValues(alpha: 0.35),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.play_circle_fill, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    const Text(
                      'Ver respuesta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(CupertinoIcons.chevron_right, color: Colors.white.withValues(alpha: 0.5), size: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Complete bottom-left info panel combining all sub-widgets — TikTok style.
class ReelInfoPanel extends StatelessWidget {
  final NexUser author;
  final String postContent;
  final bool isLocked;
  final List<Map<String, dynamic>> mutualConnections;
  final String? replyVideoUrl;
  final VoidCallback onPlayReply;
  final int matchScore;
  final VoidCallback? onMatchTap;

  const ReelInfoPanel({
    super.key,
    required this.author,
    required this.postContent,
    required this.isLocked,
    required this.mutualConnections,
    required this.replyVideoUrl,
    required this.onPlayReply,
    this.matchScore = 0,
    this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayTags = author.tags.isNotEmpty ? author.tags.take(3).toList() : <String>[];

    // ── Panel blanco (estilo mockup: tarjeta clara debajo del video, en vez
    // del overlay transparente sobre el video) ──
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Tags (max 3, pills claros) ──
          if (displayTags.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: displayTags.map((tag) => _WhiteTagPill(tag: tag)).toList(),
            ),
            const SizedBox(height: 10),
          ],

          // ── Avatar/logo + Nombre + Subtítulo ──
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: author)));
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        width: 34, height: 34,
                        color: const Color(0xFFF2F2F7),
                        child: isLocked
                            ? const Icon(CupertinoIcons.eye_slash_fill, color: Color(0xFF6B7280), size: 16)
                            : (author.avatarUrl != null && author.avatarUrl!.isNotEmpty)
                                ? CachedNetworkImage(
                                    imageUrl: author.avatarUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const SizedBox.shrink(),
                                    errorWidget: (_, __, ___) => Center(child: Text(author.initials, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800, fontSize: 12))),
                                  )
                                : Center(child: Text(author.initials, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w800, fontSize: 12))),
                      ),
                    ),
                    if (author.isVerified && !isLocked)
                      Positioned(
                        right: -3, bottom: -3,
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(CupertinoIcons.checkmark_seal_fill, color: NexTheme.brandAccent, size: 13),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLocked ? author.name.split(' ').first : author.name,
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.none,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      GestureDetector(
                        onTap: () => _showDetailsSheet(context),
                        child: Text(
                          _buildSubtitle(),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (matchScore > 0) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onMatchTap,
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: NexTheme.brandAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ver detalles del match ($matchScore% - ${_matchTier(matchScore)})',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
                    ),
                    const SizedBox(width: 4),
                    const Icon(CupertinoIcons.chevron_right, color: Colors.white, size: 12),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _matchTier(int score) {
    if (score >= 70) return 'Altamente Compatible';
    if (score >= 40) return 'Buen Match';
    return 'Compatible';
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (author.headline.isNotEmpty) parts.add(author.headline);
    if (author.company != null && author.company!.isNotEmpty) parts.add(author.company!);
    if (parts.isEmpty && postContent.isNotEmpty) parts.add(postContent);
    return parts.join(' · ');
  }

  /// Shows full details on tap (tags, mutuals, reply, match) — keeps all functionality accessible
  void _showDetailsSheet(BuildContext context) {
    final displayTags = author.tags.isNotEmpty ? author.tags : <String>[];
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Name + Status
            Row(
              children: [
                Expanded(
                  child: Text(
                    author.name,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
                  ),
                ),
                if (author.isOpenToWork || author.isHiring)
                  ReelStatusBadge(author: author),
                if (matchScore > 0) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () { Navigator.pop(ctx); onMatchTap?.call(); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$matchScore% Match', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                    ),
                  ),
                ],
              ],
            ),
            if (postContent.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(postContent, style: const TextStyle(color: Colors.white70, fontSize: 14, decoration: TextDecoration.none)),
            ],
            if (author.company != null && author.company!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(author.company!, style: const TextStyle(color: Colors.white54, fontSize: 13, decoration: TextDecoration.none)),
            ],
            // Tags
            if (displayTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: displayTags.take(5).map((tag) => ReelTagPill(tag: tag)).toList(),
              ),
            ],
            // Mutuals
            if (mutualConnections.isNotEmpty) ...[
              const SizedBox(height: 12),
              ReelMutualConnections(mutualConnections: mutualConnections),
            ],
            // Reply button
            const SizedBox(height: 12),
            ReelVideoReplyButton(author: author),
            // Reply indicator
            ReelVideoReplyIndicator(replyVideoUrl: replyVideoUrl, onTap: () { Navigator.pop(ctx); onPlayReply(); }),
          ],
        ),
      ),
    );
  }
}
