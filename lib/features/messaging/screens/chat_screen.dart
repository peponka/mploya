library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/features/auth/providers/auth_provider.dart';
import 'package:mploya/features/messaging/models/message_model.dart';
import 'package:mploya/features/messaging/providers/messaging_provider.dart';
import 'package:mploya/features/messaging/widgets/message_bubble.dart';

// =============================================================================
// Chat Screen
// =============================================================================
// Individual 1-on-1 chat view with message bubbles, input bar, attachment
// actions, date separators, read receipts, typing indicator, and scroll-to-
// bottom FAB. Connected to real Riverpod providers for messages and
// conversation data.
// =============================================================================

/// Individual chat screen for a specific conversation.
///
/// Features:
/// - AppBar with avatar, name, and online status
/// - Video call action button
/// - Reverse-scrollable message list with date separators
/// - Message bubbles with read receipts
/// - Animated typing indicator
/// - Chat input bar with attachment options
/// - Scroll-to-bottom floating action button
/// - Welcome/first-connection screen with AI-suggested messages
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    required this.conversationId,
    super.key,
  });

  /// The conversation ID to load messages for.
  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  bool _showScrollToBottom = false;
  bool _isTyping = false;
  bool _showAttachmentMenu = false;
  late AnimationController _sendButtonController;

  /// Whether the welcome screen has been dismissed (e.g. by sending a suggestion).
  bool _welcomeDismissed = false;

  // ── Demo mode state ────────────────────────────────────────────────────────
  static const _demoUserId = 'demo-user';
  static const _demoPartnerId = 'demo-partner';
  final List<Message> _demoMessages = [];
  int _demoMessageCounter = 0;

  /// Whether this chat was opened from a video reply flow.
  bool get _isVideoReplyChat => widget.conversationId.startsWith('reply-');

  static const _demoReplies = [
    '¡Gracias por tu mensaje! Te respondo pronto.',
    'Interesante, contame más sobre tu experiencia.',
    '¡Perfecto! ¿Podemos coordinar una entrevista?',
    'Me parece genial tu perfil. Revisemos tu CV.',
    '¿Cuándo estarías disponible para una videollamada?',
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _sendButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTextChanged);

    // Mark messages as read when opening the chat.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref
            .read(messagesProvider(widget.conversationId).notifier)
            .markAsRead(user.id);
      }
    });

    // Simulate partner typing after 3 seconds.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isTyping = true);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _isTyping = false);
      });
    });

    // If opened from Video Reply, inject the video message automatically.
    if (_isVideoReplyChat) {
      _demoMessageCounter++;
      _demoMessages.add(Message(
        id: 'demo-video-reply-$_demoMessageCounter',
        conversationId: widget.conversationId,
        senderId: _demoUserId,
        content: '🎬 Video Reply enviado',
        createdAt: DateTime.now(),
      ));
      _welcomeDismissed = true;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _sendButtonController.dispose();
    super.dispose();
  }

  // ── Event Handlers ─────────────────────────────────────────────────────────

  void _onScroll() {
    final shouldShow = _scrollController.offset > 200;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  void _onTextChanged() {
    if (_messageController.text.isNotEmpty) {
      _sendButtonController.forward();
    } else {
      _sendButtonController.reverse();
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleSend() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _sendMessageText(text);
  }

  /// Sends a message string (from input bar or suggestion tap).
  void _sendMessageText(String text) {
    final user = ref.read(currentUserProvider);

    if (user == null) {
      // ── Demo mode: store messages locally ──
      _demoMessageCounter++;
      final sentMessage = Message(
        id: 'demo-sent-$_demoMessageCounter',
        conversationId: widget.conversationId,
        senderId: _demoUserId,
        content: text,
        createdAt: DateTime.now(),
      );
      setState(() {
        _demoMessages.add(sentMessage);
        _welcomeDismissed = true;
      });
      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

      // Simulate a reply after 2 seconds.
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        _demoMessageCounter++;
        final reply = _demoReplies[Random().nextInt(_demoReplies.length)];
        final replyMessage = Message(
          id: 'demo-recv-$_demoMessageCounter',
          conversationId: widget.conversationId,
          senderId: _demoPartnerId,
          content: reply,
          createdAt: DateTime.now(),
        );
        setState(() => _demoMessages.add(replyMessage));
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      });
      return;
    }

    ref.read(messagesProvider(widget.conversationId).notifier).sendMessage(
          senderId: user.id,
          content: text,
        );

    _messageController.clear();
    setState(() => _welcomeDismissed = true);

    // Scroll to the new message.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _toggleAttachmentMenu() {
    setState(() => _showAttachmentMenu = !_showAttachmentMenu);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Finds the current conversation from the loaded conversations list.
  Conversation? _findConversation() {
    final convState = ref.watch(conversationsProvider);
    if (convState is ConversationsLoaded) {
      try {
        return convState.conversations.firstWhere(
          (c) => c.id == widget.conversationId,
        );
      } catch (e) {
        debugPrint('Error finding conversation: $e');
        return null;
      }
    }
    return null;
  }

  /// Whether the welcome screen should be shown.
  bool _shouldShowWelcome(List<Message> messages) {
    return !_welcomeDismissed && messages.isEmpty;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final messagesState = ref.watch(messagesProvider(widget.conversationId));
    final conversation = _findConversation();
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: _buildAppBar(colorScheme, conversation),
      body: currentUser == null
          ? _buildDemoBody(colorScheme)
          : _buildBody(colorScheme, messagesState, currentUser.id),
    );
  }

  // ── Demo Mode Body ──────────────────────────────────────────────────────────

  Widget _buildDemoBody(ColorScheme colorScheme) {
    return Column(
      children: [
        Expanded(
          child: _shouldShowWelcome(_demoMessages)
              ? _buildWelcomeScreen(colorScheme)
              : _demoMessages.isEmpty
                  ? _buildEmptyState(colorScheme)
                  : Stack(
                      children: [
                        _buildMessageList(
                            colorScheme, _demoMessages, _demoUserId),
                        if (_showScrollToBottom)
                          Positioned(
                            bottom: AppSpacing.md,
                            right: AppSpacing.md,
                            child: _buildScrollToBottomFab(colorScheme)
                                .animate()
                                .fadeIn(duration: 200.ms)
                                .scaleXY(
                                    begin: 0.8, end: 1, duration: 200.ms),
                          ),
                      ],
                    ),
        ),
        if (_showAttachmentMenu)
          _buildAttachmentMenu(colorScheme)
              .animate()
              .fadeIn(duration: 200.ms)
              .slideY(begin: 0.3, end: 0, duration: 250.ms),
        _buildInputBar(colorScheme),
      ],
    );
  }

  Widget _buildBody(
    ColorScheme colorScheme,
    MessagesState messagesState,
    String currentUserId,
  ) {
    return Column(
      children: [
        // ── Message Area ──
        Expanded(
          child: switch (messagesState) {
            MessagesInitial() || MessagesLoading() =>
              _buildLoadingState(colorScheme),
            MessagesError(:final message) =>
              _buildErrorState(colorScheme, message),
            MessagesLoaded(:final messages) => _shouldShowWelcome(messages)
                ? _buildWelcomeScreen(colorScheme)
                : messages.isEmpty
                    ? _buildEmptyState(colorScheme)
                    : Stack(
                        children: [
                          _buildMessageList(
                              colorScheme, messages, currentUserId),

                          // Scroll-to-bottom FAB
                          if (_showScrollToBottom)
                            Positioned(
                              bottom: AppSpacing.md,
                              right: AppSpacing.md,
                              child: _buildScrollToBottomFab(colorScheme)
                                  .animate()
                                  .fadeIn(duration: 200.ms)
                                  .scaleXY(
                                      begin: 0.8, end: 1, duration: 200.ms),
                            ),
                        ],
                      ),
          },
        ),

        // ── Attachment Menu (expandable) ──
        if (_showAttachmentMenu)
          _buildAttachmentMenu(colorScheme)
              .animate()
              .fadeIn(duration: 200.ms)
              .slideY(begin: 0.3, end: 0, duration: 250.ms),

        // ── Input Bar ──
        _buildInputBar(colorScheme),
      ],
    );
  }

  // ── Welcome / First-Connection Screen ──────────────────────────────────────

  Widget _buildWelcomeScreen(ColorScheme colorScheme) {
    final conversation = _findConversation();
    final partnerName = conversation?.participantName ?? 'esta persona';
    final partnerInitials = conversation?.participantInitials ?? '?';
    final partnerTitle = 'CTO'; // Placeholder role

    final suggestions = [
      'Hola $partnerName, vi tu perfil de "$partnerTitle". ¡Muy interesante!',
      'Vi que trabajás con liderar y fintech. ¡Tenemos mucho en común!',
      'Hola $partnerName, me gustaría conectar y explorar sinergias. ¿Cómo estás?',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xxl),

          // Large circular avatar with purple border ring
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF8B5CF6),
                width: 3,
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              backgroundImage: conversation?.participantAvatarUrl != null
                  ? NetworkImage(conversation!.participantAvatarUrl!)
                  : null,
              child: conversation?.participantAvatarUrl == null
                  ? Text(
                      partnerInitials,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8B5CF6),
                      ),
                    )
                  : null,
            ),
          ).animate().fadeIn(duration: 500.ms).scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                duration: 500.ms,
                curve: Curves.easeOutBack,
              ),

          const SizedBox(height: AppSpacing.md),

          // 'Has conectado con [name]'
          Text(
            'Has conectado con $partnerName',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 400.ms, delay: 150.ms),

          const SizedBox(height: AppSpacing.lg),

          // Purple pill badge: ✨ IA sugiere empezar con...
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✨', style: TextStyle(fontSize: 16)),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'IA sugiere empezar con…',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

          const SizedBox(height: AppSpacing.lg),

          // 3 suggested message cards
          ...suggestions.asMap().entries.map((entry) {
            final index = entry.key;
            final suggestion = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildSuggestionCard(
                colorScheme: colorScheme,
                text: suggestion,
                delay: 400 + index * 100,
              ),
            );
          }),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard({
    required ColorScheme colorScheme,
    required String text,
    required int delay,
  }) {
    return GestureDetector(
      onTap: () => _sendMessageText(text),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 💡 icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Center(
                child: Text('💡', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Message text
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Orange arrow button
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: MployaColors.orange,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: delay.ms).slideY(begin: 0.1, end: 0);
  }

  // ── Loading State ──────────────────────────────────────────────────────────

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Cargando mensajes…',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── Error State ────────────────────────────────────────────────────────────

  Widget _buildErrorState(ColorScheme colorScheme, String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Error al cargar mensajes',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              errorMessage,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () {
                ref
                    .read(messagesProvider(widget.conversationId).notifier)
                    .loadMessages();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Reintentar',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sin mensajes aún',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '¡Envía el primer mensaje para iniciar la conversación!',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
    ColorScheme colorScheme,
    Conversation? conversation,
  ) {
    final participantName = conversation?.participantName ?? 'Chat';
    final isOnline = conversation?.isOnline ?? false;
    final initials = conversation?.participantInitials ?? '?';

    return AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          // Participant avatar
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: conversation?.participantAvatarUrl != null
                      ? NetworkImage(conversation!.participantAvatarUrl!)
                      : null,
                  child: conversation?.participantAvatarUrl == null
                      ? Text(
                          initials,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        )
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
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

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participantName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _isTyping
                      ? 'Escribiendo…'
                      : (isOnline ? 'En línea' : 'Desconectado'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _isTyping
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight:
                        _isTyping ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // '🎬 Entrevista' orange prominent button - bigger and more visible
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: FilledButton.icon(
            onPressed: () {
              final name = _findConversation()?.participantName ?? 'Entrevista Mploya';
              context.push('/video-call/lobby?title=${Uri.encodeComponent('Entrevista con $name')}');
            },
            style: FilledButton.styleFrom(
              backgroundColor: MployaColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              minimumSize: const Size(48, 48),
              elevation: 3,
              shadowColor: MployaColors.orange.withValues(alpha: 0.5),
            ),
            icon: const Icon(Icons.videocam_rounded, size: 22),
            label: Text(
              'Entrevista',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Message List ───────────────────────────────────────────────────────────

  Widget _buildMessageList(
    ColorScheme colorScheme,
    List<Message> messages,
    String currentUserId,
  ) {
    // Sort messages oldest-first, then reverse the ListView for chat behavior.
    final sortedMessages = List<Message>.from(messages)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      itemCount: sortedMessages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        // Typing indicator at index 0 (bottom) when active.
        if (_isTyping && index == 0) {
          return const TypingIndicator();
        }

        final messageIndex = _isTyping
            ? sortedMessages.length - index
            : sortedMessages.length - 1 - index;

        if (messageIndex < 0 || messageIndex >= sortedMessages.length) {
          return const SizedBox.shrink();
        }

        final message = sortedMessages[messageIndex];
        final isSent = message.senderId == currentUserId;

        // Determine if this is the last message in a consecutive group
        // from the same sender, to show the tail.
        final isLastInGroup = messageIndex == sortedMessages.length - 1 ||
            sortedMessages[messageIndex + 1].senderId != message.senderId;

        // Date separator logic.
        Widget? dateSeparator;
        if (messageIndex == 0 ||
            !_isSameDay(
              sortedMessages[messageIndex - 1].createdAt,
              message.createdAt,
            )) {
          dateSeparator = _buildDateSeparator(message.createdAt, colorScheme);
        }

        return Column(
          children: [
            ?dateSeparator,
            MessageBubble(
              message: message,
              isSent: isSent,
              showTail: isLastInGroup,
            ),
          ],
        );
      },
    );
  }

  /// Whether two dates fall on the same calendar day.
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Builds a centered date separator label ('Hoy', 'Ayer', or full date).
  Widget _buildDateSeparator(DateTime date, ColorScheme colorScheme) {
    final now = DateTime.now();
    String label;

    if (_isSameDay(date, now)) {
      label = 'Hoy';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Ayer';
    } else {
      label = DateFormat('d \'de\' MMMM, yyyy', 'es').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  // ── Scroll-to-Bottom FAB ───────────────────────────────────────────────────

  Widget _buildScrollToBottomFab(ColorScheme colorScheme) {
    return FloatingActionButton.small(
      heroTag: 'scroll_to_bottom',
      onPressed: _scrollToBottom,
      backgroundColor: colorScheme.surfaceContainer,
      foregroundColor: colorScheme.onSurface,
      elevation: AppElevation.md,
      child: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
    );
  }

  // ── Attachment Menu ────────────────────────────────────────────────────────

  Widget _buildAttachmentMenu(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _AttachmentOption(
            icon: Icons.camera_alt_rounded,
            label: 'Cámara',
            color: const Color(0xFFE17055),
            onTap: () => _toggleAttachmentMenu(),
          ),
          _AttachmentOption(
            icon: Icons.photo_rounded,
            label: 'Galería',
            color: const Color(0xFF6C5CE7),
            onTap: () => _toggleAttachmentMenu(),
          ),
          _AttachmentOption(
            icon: Icons.insert_drive_file_rounded,
            label: 'Archivo',
            color: const Color(0xFF00B894),
            onTap: () => _toggleAttachmentMenu(),
          ),
          _AttachmentOption(
            icon: Icons.gif_box_rounded,
            label: 'GIF',
            color: const Color(0xFF0984E3),
            onTap: () => _toggleAttachmentMenu(),
          ),
        ],
      ),
    );
  }

  // ── Input Bar ──────────────────────────────────────────────────────────────

  Widget _buildInputBar(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewPadding.bottom + AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // '+' dark circle button
          GestureDetector(
            onTap: _toggleAttachmentMenu,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: MployaColors.textPrimary,
                shape: BoxShape.circle,
              ),
              child: AnimatedRotation(
                turns: _showAttachmentMenu ? 0.125 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _showAttachmentMenu
                      ? Icons.close_rounded
                      : Icons.add_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Text input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje…',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 15,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  filled: false,
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.xs),

          // Orange circle send button with arrow up
          ListenableBuilder(
            listenable: _sendButtonController,
            builder: (context, child) {
              final hasText = _messageController.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: hasText ? _handleSend : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hasText
                        ? MployaColors.orange
                        : MployaColors.textTertiary.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      key: ValueKey(hasText),
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Attachment Option Widget
// =============================================================================

/// A single attachment option button in the expandable attachment menu.
class _AttachmentOption extends StatelessWidget {
  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: AppIconSize.md),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
