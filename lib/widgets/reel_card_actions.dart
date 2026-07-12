import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reel Card Actions — Right-side action bar del TikTokReelCard
//
// Incluye: Avatar + Smart Connect, Like/Reactions, Comments, Bookmark,
// Share, Nexus (⚡), y More Options (⋯).
// Extraído de tiktok_reel_card.dart para reducir el tamaño del god file.
// ─────────────────────────────────────────────────────────────────────────────

/// Right-side action bar with all interaction buttons.
class ReelActionsBar extends StatelessWidget {
  final NexUser author;
  final NexUser? currentUser;
  final bool isLocked;
  // State values
  final String connectionStatus;
  final bool isMatched;
  final int matchCount;
  final bool isBookmarked;
  final bool nexusSent;
  final bool showReactions;
  final String? activeReaction;
  final Map<String, int> reactionCounts;
  // Callbacks
  final VoidCallback onAvatarTap;
  final VoidCallback onConnectTap;
  final VoidCallback onMatchToggle;
  final VoidCallback onReactionsToggle;
  final void Function(String?) onReactionSelected;
  final VoidCallback onCommentsTap;
  final VoidCallback onBookmarkTap;
  final VoidCallback onShareTap;
  final VoidCallback onNexusTap;
  final VoidCallback onMoreTap;

  /// Estilo "claro" para web: íconos oscuros sobre fondo blanco (TikTok web).
  final bool lightMode;

  const ReelActionsBar({
    super.key,
    required this.author,
    required this.currentUser,
    required this.isLocked,
    required this.connectionStatus,
    required this.isMatched,
    required this.matchCount,
    required this.isBookmarked,
    required this.nexusSent,
    required this.showReactions,
    required this.activeReaction,
    required this.reactionCounts,
    required this.onAvatarTap,
    required this.onConnectTap,
    required this.onMatchToggle,
    required this.onReactionsToggle,
    required this.onReactionSelected,
    required this.onCommentsTap,
    required this.onBookmarkTap,
    required this.onShareTap,
    required this.onNexusTap,
    required this.onMoreTap,
    this.lightMode = false,
  });

  // ── Colores según modo (dark overlay vs light web) ──
  Color get _fg => lightMode ? const Color(0xFF161823) : Colors.white;
  List<Shadow> get _sh =>
      lightMode ? const [] : const [Shadow(color: Colors.black54, blurRadius: 6)];

  Widget _buildActionButton({
    required VoidCallback onTap,
    required Widget icon,
    String? countText,
    String? semanticLabel,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (countText != null) ...[
              const SizedBox(height: 2),
              Text(
                countText,
                style: TextStyle(
                  color: _fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: _sh,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Avatar + Smart Connect ──
        _buildAvatarSection(context),
        const SizedBox(height: 18),

        // ── Like / Match (with reactions) ──
        _buildReactionsSection(),
        _buildLabel('Interesado'),
        const SizedBox(height: 14),

        // ── Video Reply ──
        _buildGlassButton(
          onTap: onCommentsTap,
          semanticLabel: 'Responder con video a ${author.name}',
          icon: CupertinoIcons.videocam_fill,
          color: _fg,
        ),
        _buildLabel('Video'),
        const SizedBox(height: 14),

        // ── Bookmark ──
        _buildGlassButton(
          onTap: () {
            HapticFeedback.selectionClick();
            onBookmarkTap();
          },
          semanticLabel: isBookmarked ? 'Quitar de guardados' : 'Guardar perfil',
          icon: isBookmarked ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
          color: isBookmarked ? const Color(0xFFFFD60A) : _fg,
        ),
        _buildLabel('Guardar'),
        const SizedBox(height: 14),

        // ── Share (long-press → Nexus ⚡, includes More) ──
        Semantics(
          button: true,
          label: nexusSent ? 'Interés ya enviado' : 'Compartir perfil. Mantené presionado para enviar Nexus',
          child: GestureDetector(
            onTap: onShareTap,
            onLongPress: () {
              if (nexusSent) return;
              HapticFeedback.heavyImpact();
              onNexusTap();
            },
            onDoubleTap: onMoreTap,
            child: _glassCircle(
              child: Icon(
                nexusSent ? CupertinoIcons.bolt_circle_fill : CupertinoIcons.arrow_turn_up_right,
                color: nexusSent ? const Color(0xFFFFD60A) : _fg,
                size: 24,
                shadows: _sh,
              ),
            ),
          ),
        ),
        _buildLabel('Compartir'),
      ],
    );
  }

  Widget _buildAvatarSection(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: connectionStatus == 'accepted'
                      ? NexTheme.brandAccent
                      : (lightMode ? const Color(0xFFD1D5DB) : Colors.white),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  color: const Color(0xFF2C2C2E),
                  child: isLocked
                      ? const Icon(CupertinoIcons.eye_slash_fill, color: Colors.white, size: 20)
                      : (author.avatarUrl != null
                          ? CachedNetworkImage(
                              imageUrl: author.avatarUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const SizedBox.shrink(),
                              errorWidget: (_, __, ___) => Center(child: Text(author.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))),
                            )
                          : Center(child: Text(author.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)))),
                ),
              ),
            ),
          ),
          // Smart Connect Button
          Positioned(
            bottom: 0,
            child: GestureDetector(
              onTap: onConnectTap,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: connectionStatus == 'accepted'
                      ? NexTheme.brandAccent
                      : connectionStatus == 'pending'
                          ? const Color(0xFF5F3DC4)
                          : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2C2C2E), width: 1.5),
                ),
                child: Icon(
                  connectionStatus == 'accepted'
                      ? CupertinoIcons.checkmark_alt
                      : connectionStatus == 'pending'
                          ? CupertinoIcons.clock
                          : CupertinoIcons.add,
                  color: connectionStatus == 'none'
                      ? const Color(0xFF2C2C2E)
                      : Colors.white,
                  size: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionsSection() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Reactions panel
        if (showReactions)
          Positioned(
            right: 42,
            top: -8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['🔥', '💯', '👏', '🚀', '🤝'].map((emoji) {
                      final isActive = activeReaction == emoji;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onReactionSelected(isActive ? null : emoji);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.white24 : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(emoji, style: TextStyle(fontSize: isActive ? 22 : 18)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        // Main like button
        GestureDetector(
          onTap: () {
            if (showReactions) {
              onReactionsToggle();
            } else {
              onMatchToggle();
            }
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            onReactionsToggle();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              activeReaction != null
                  ? Text(activeReaction!, style: const TextStyle(fontSize: 26, shadows: [Shadow(color: Colors.black54, blurRadius: 6)]))
                  : Icon(
                      isMatched ? CupertinoIcons.star_fill : CupertinoIcons.star,
                      color: isMatched ? NexTheme.brandAccent : _fg,
                      size: 30,
                      shadows: _sh,
                    ),
              if (matchCount > 0 || reactionCounts.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  reactionCounts.isNotEmpty
                      ? reactionCounts.values.fold(0, (a, b) => a + b).toString()
                      : '$matchCount',
                  style: TextStyle(
                    color: _fg,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    shadows: _sh,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildGlassButton({required VoidCallback onTap, required String semanticLabel, required IconData icon, required Color color}) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: _glassCircle(
          child: Icon(icon, color: color, size: 24, shadows: _sh),
        ),
      ),
    );
  }

  Widget _glassCircle({required Widget child}) {
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(
          color: _fg.withValues(alpha: 0.8),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          shadows: _sh,
        ),
      ),
    );
  }
}
