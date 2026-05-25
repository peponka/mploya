import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mploya/core/widgets/platform_video_player.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/features/messaging/models/message_model.dart';
import 'package:mploya/features/messaging/models/video_reply_store.dart';

// =============================================================================
// Message Bubble Widget
// =============================================================================
// Renders an individual chat message with different styles for sent vs received
// messages. Supports text, images, files, and system messages. Includes read
// receipts, timestamps, and long-press context menus.
// =============================================================================

/// A chat message bubble with adaptive styling for sent and received messages.
///
/// Features:
/// - Asymmetric rounded corners distinguishing sent (right) from received (left)
/// - Read receipt indicators (double check marks) for sent messages
/// - Timestamp display
/// - Media attachment support (images, files, GIFs)
/// - Long-press context menu (copy, delete)
/// - Entrance animation
///
/// ```dart
/// MessageBubble(
///   message: message,
///   isSent: true,
///   showTail: true,
/// )
/// ```
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.isSent,
    this.showTail = true,
    this.onLongPress,
    super.key,
  });

  /// The message data to render.
  final Message message;

  /// Whether this message was sent by the current user.
  final bool isSent;

  /// Whether to show the tail (pointer) on the bubble.
  /// Typically `true` for the last message in a consecutive group.
  final bool showTail;

  /// Optional callback for long-press actions.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    // System messages get a centered, muted style.
    if (message.isSystem) {
      return _SystemMessageBubble(message: message);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Sent messages align right; received align left.
    final alignment = isSent ? Alignment.centerRight : Alignment.centerLeft;

    // Color scheme for sent vs received.
    final bubbleColor = isSent
        ? colorScheme.primary
        : colorScheme.surfaceContainerHigh;
    final textColor = isSent
        ? colorScheme.onPrimary
        : colorScheme.onSurface;
    final metaColor = isSent
        ? colorScheme.onPrimary.withValues(alpha: 0.7)
        : colorScheme.onSurfaceVariant;

    // Asymmetric corners: tail side gets a smaller radius.
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.lg),
      topRight: const Radius.circular(AppRadius.lg),
      bottomLeft: Radius.circular(
        isSent ? AppRadius.lg : (showTail ? AppRadius.xs : AppRadius.lg),
      ),
      bottomRight: Radius.circular(
        isSent ? (showTail ? AppRadius.xs : AppRadius.lg) : AppRadius.lg,
      ),
    );

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onLongPress: () => _showContextMenu(context),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Container(
            margin: EdgeInsets.only(
              left: isSent ? AppSpacing.xxl : AppSpacing.sm,
              right: isSent ? AppSpacing.sm : AppSpacing.xxl,
              bottom: showTail ? AppSpacing.sm : AppSpacing.xxs,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Media Content ──
                if (message.hasMedia) _buildMediaContent(context, textColor),

                // ── Text Content ──
                if (message.content.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                      top: message.hasMedia ? AppSpacing.xs : 0,
                    ),
                    child: message.content.startsWith('🎬')
                        ? _buildVideoReplyContent(context, textColor)
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              message.content,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: textColor,
                                height: 1.4,
                              ),
                            ),
                          ),
                  ),

                const SizedBox(height: AppSpacing.xxs),

                // ── Timestamp + Read Receipt ──
                _buildMeta(metaColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the media preview for image/GIF/file messages.
  Widget _buildMediaContent(BuildContext context, Color textColor) {
    switch (message.type) {
      case MessageType.image:
      case MessageType.gif:
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            constraints: const BoxConstraints(
              maxHeight: 200,
              maxWidth: double.infinity,
            ),
            color: Colors.black.withValues(alpha: 0.1),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    message.type == MessageType.gif
                        ? Icons.gif_box_rounded
                        : Icons.image_rounded,
                    size: 48,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message.type == MessageType.gif ? 'GIF' : 'Imagen',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case MessageType.file:
        return Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file_rounded,
                size: AppIconSize.md,
                color: textColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  message.mediaUrl?.split('/').last ?? 'Archivo adjunto',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.download_rounded,
                size: AppIconSize.sm,
                color: textColor.withValues(alpha: 0.5),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  /// Builds a special video reply card inside the message bubble.
  Widget _buildVideoReplyContent(BuildContext context, Color textColor) {
    return GestureDetector(
      onTap: () {
        final blobUrl = VideoReplyStore.lastRecordedBlobUrl;
        if (blobUrl != null) {
          _showVideoPlayer(context, blobUrl);
        }
      },
      child: Container(
      width: 220,
      height: 140,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1033), Color(0xFF0D0D0D)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Play icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          // Label
          Positioned(
            bottom: 10,
            left: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.videocam_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  'Video Reply',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // Duration badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                '0:08',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
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

  /// Opens a fullscreen video player dialog for the recorded video reply.
  void _showVideoPlayer(BuildContext context, String blobUrl) {
    final viewId = 'chat-video-player-${DateTime.now().millisecondsSinceEpoch}';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: SizedBox(
            width: MediaQuery.of(ctx).size.width * 0.9,
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: Stack(
              children: [
                PlatformVideoPlayer(
                  viewId: viewId,
                  url: blobUrl,
                  objectFit: 'contain',
                  loop: true,
                  autoplay: true,
                  controls: true,
                  background: '#000',
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the timestamp and read-receipt row.
  Widget _buildMeta(Color metaColor) {
    final timeStr = DateFormat('HH:mm').format(message.createdAt);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeStr,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: metaColor,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (isSent) ...[
          const SizedBox(width: AppSpacing.xxs + 1),
          Icon(
            message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
            size: 14,
            color: message.isRead
                ? (isSent ? Colors.white.withValues(alpha: 0.9) : Colors.blue)
                : metaColor,
          ),
        ],
      ],
    );
  }

  /// Shows a context menu on long press with copy/delete options.
  void _showContextMenu(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    HapticFeedback.mediumImpact();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),

              // Copy option
              ListTile(
                leading: Icon(
                  Icons.copy_rounded,
                  color: colorScheme.onSurface,
                ),
                title: Text(
                  'Copiar mensaje',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Mensaje copiado',
                        style: GoogleFonts.inter(),
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),

              // Forward option
              ListTile(
                leading: Icon(
                  Icons.forward_rounded,
                  color: colorScheme.onSurface,
                ),
                title: Text(
                  'Reenviar',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () => Navigator.pop(context),
              ),

              // Delete option (only for sent messages)
              if (isSent)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: colorScheme.error,
                  ),
                  title: Text(
                    'Eliminar mensaje',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onLongPress?.call();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// System Message Bubble
// =============================================================================

/// Renders a system-generated message with centered, muted styling.
class _SystemMessageBubble extends StatelessWidget {
  const _SystemMessageBubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xl,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          message.content,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// =============================================================================
// Typing Indicator Widget
// =============================================================================

/// Animated "typing..." indicator shown when the other participant is typing.
///
/// Displays three animated dots in a received-message-styled bubble.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.xxl,
          bottom: AppSpacing.sm,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.lg),
            topRight: Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(AppRadius.xs),
            bottomRight: Radius.circular(AppRadius.lg),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            )
                .animate(
                  onPlay: (controller) => controller.repeat(),
                )
                .scaleXY(
                  begin: 0.6,
                  end: 1.0,
                  duration: 600.ms,
                  delay: (index * 200).ms,
                  curve: Curves.easeInOut,
                )
                .then()
                .scaleXY(
                  begin: 1.0,
                  end: 0.6,
                  duration: 600.ms,
                  curve: Curves.easeInOut,
                );
          }),
        ),
      ),
    );
  }
}
