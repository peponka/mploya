library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

// =============================================================================
// Conversations List Screen
// =============================================================================
// Left-hand panel for the desktop master-detail chat layout.
// Shows a searchable list of conversations with avatars, online/unread
// indicators, and selection highlighting.
// =============================================================================

/// Mock conversation data used for the conversations list.
const _mockConversations = [
  (
    id: 'c1',
    name: 'Sofía Castro',
    lastMsg: 'Me interesa tu perfil ✨',
    time: '2m',
    unread: true,
    online: true,
    color: Color(0xFFE91E63),
  ),
  (
    id: 'c2',
    name: 'TechCorp HR',
    lastMsg: '¿Podemos coordinar entrevista?',
    time: '15m',
    unread: true,
    online: false,
    color: Color(0xFF2196F3),
  ),
  (
    id: 'c3',
    name: 'Valentina R.',
    lastMsg: '¡Gracias por el match!',
    time: '1h',
    unread: false,
    online: true,
    color: Color(0xFF4CAF50),
  ),
  (
    id: 'c4',
    name: 'Globant',
    lastMsg: 'Revisamos tu video pitch',
    time: '3h',
    unread: false,
    online: false,
    color: Color(0xFF9C27B0),
  ),
  (
    id: 'c5',
    name: 'Tomás A.',
    lastMsg: '¿Conocés Flutter Web?',
    time: '1d',
    unread: false,
    online: false,
    color: Color(0xFFFF9800),
  ),
  (
    id: 'c6',
    name: 'Ana Martínez',
    lastMsg: 'Perfecto, nos vemos!',
    time: '2d',
    unread: false,
    online: true,
    color: Color(0xFF00BCD4),
  ),
];

/// Conversations list widget for the desktop master-detail layout.
///
/// Displays a header with title + search icon, a decorative search bar,
/// and a scrollable list of mock conversations.  Tapping an item calls
/// [onSelectChat] with the conversation id.  The currently-selected
/// conversation (if any) is highlighted with an orange background.
class ConversationsListScreen extends StatelessWidget {
  const ConversationsListScreen({
    required this.onSelectChat,
    this.selectedId,
    super.key,
  });

  /// Called when the user taps a conversation row.
  final Function(String) onSelectChat;

  /// The currently-selected conversation id (highlighted).
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surface,
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Mensajes',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.search_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Buscar',
                ),
              ],
            ),
          ),

          // ── Search bar (decorative) ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
            ),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Buscar conversaciones…',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Conversation List ──────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              itemCount: _mockConversations.length,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              itemBuilder: (context, index) {
                final conv = _mockConversations[index];
                final isSelected = conv.id == selectedId;

                return _ConversationTile(
                  id: conv.id,
                  name: conv.name,
                  lastMsg: conv.lastMsg,
                  time: conv.time,
                  unread: conv.unread,
                  online: conv.online,
                  avatarColor: conv.color,
                  isSelected: isSelected,
                  onTap: () => onSelectChat(conv.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Conversation Tile
// =============================================================================

class _ConversationTile extends StatefulWidget {
  const _ConversationTile({
    required this.id,
    required this.name,
    required this.lastMsg,
    required this.time,
    required this.unread,
    required this.online,
    required this.avatarColor,
    required this.isSelected,
    required this.onTap,
  });

  final String id;
  final String name;
  final String lastMsg;
  final String time;
  final bool unread;
  final bool online;
  final Color avatarColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final initial = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';

    // Background colour: selected > hovered > default.
    Color tileBackground;
    if (widget.isSelected) {
      tileBackground = MployaColors.orange.withValues(alpha: 0.10);
    } else if (_isHovered) {
      tileBackground = colorScheme.onSurface.withValues(alpha: 0.04);
    } else {
      tileBackground = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: tileBackground,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: widget.isSelected
                ? Border.all(
                    color: MployaColors.orange.withValues(alpha: 0.25),
                  )
                : null,
          ),
          child: Row(
            children: [
              // ── Avatar with online dot ────────────────────────────────
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          widget.avatarColor.withValues(alpha: 0.15),
                      child: Text(
                        initial,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: widget.avatarColor,
                        ),
                      ),
                    ),
                    if (widget.online)
                      Positioned(
                        bottom: 1,
                        right: 1,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C853),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              // ── Name + last message ───────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight:
                            widget.unread ? FontWeight.w700 : FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.lastMsg,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            widget.unread ? FontWeight.w500 : FontWeight.w400,
                        color: widget.unread
                            ? colorScheme.onSurface.withValues(alpha: 0.8)
                            : colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              // ── Time + unread dot ─────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.time,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight:
                          widget.unread ? FontWeight.w600 : FontWeight.w400,
                      color: widget.unread
                          ? MployaColors.orange
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (widget.unread) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: MployaColors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
