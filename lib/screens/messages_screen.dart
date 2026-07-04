import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/nex_avatar.dart';
import '../utils/time_utils.dart';
import 'chat_inmail_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  late final Stream<List<Map<String, dynamic>>> _messagesStream;

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      _messagesStream = _supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false);
    } else {
      _messagesStream = Stream.value([]);
    }
  }

  // Agrupa los mensajes por conversación (partner_id) y queda con el último
  List<_Conversation> _buildConversations(List<Map<String, dynamic>> allMsgs) {
    final Map<String, _Conversation> convMap = {};

    for (final msg in allMsgs) {
      final senderId = msg['sender_id']?.toString() ?? '';
      final receiverId = msg['receiver_id']?.toString() ?? '';
      if (senderId != _uid && receiverId != _uid) continue;

      final partnerId = senderId == _uid ? receiverId : senderId;
      if (partnerId.isEmpty) continue;

      if (!convMap.containsKey(partnerId)) {
        final unread = (senderId != _uid && msg['is_read'] == false) ? 1 : 0;
        convMap[partnerId] = _Conversation(
          partnerId: partnerId,
          lastMessage: msg['text']?.toString() ?? msg['content']?.toString() ?? '',
          lastAt: msg['created_at']?.toString() ?? '',
          unreadCount: unread,
        );
      } else {
        if (senderId != _uid && msg['is_read'] == false) {
          convMap[partnerId]!.unreadCount++;
        }
      }
    }

    final list = convMap.values.toList()
      ..sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.bgColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: context.bgColor,
        middle: Text('Mensajes', style: TextStyle(color: context.textPrimary)),
      ),
      child: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _messagesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final all = snapshot.data ?? [];
            final convs = _buildConversations(all);

            if (convs.isEmpty) return _buildEmpty();

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: convs.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 80,
                color: context.dividerColor.withValues(alpha: 0.2),
              ),
              itemBuilder: (context, index) =>
                  _ConversationTile(conv: convs[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MployaTheme.brandAccent.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Icon(
                CupertinoIcons.chat_bubble_2_fill,
                size: 36,
                color: MployaTheme.brandAccent.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Sin mensajes aún',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuando hagas match con alguien\naparecerá aquí tu conversación.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ─── Conversation tile ───────────────────────────────────────────────────────

class _ConversationTile extends StatefulWidget {
  final _Conversation conv;
  const _ConversationTile({required this.conv});

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  final _supabase = Supabase.instance.client;
  NexUser? _partner;

  @override
  void initState() {
    super.initState();
    _fetchPartner();
  }

  Future<void> _fetchPartner() async {
    try {
      final res = await _supabase
          .from('users')
          .select()
          .eq('id', widget.conv.partnerId)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() => _partner = NexUser.fromJson(res));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = widget.conv.unreadCount > 0;
    final timeStr = widget.conv.lastAt.isNotEmpty
        ? timeAgo(widget.conv.lastAt, prefix: '')
        : '';

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _partner == null ? null : () => Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => ChatInmailScreen(targetUser: _partner),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            if (_partner != null)
              NexAvatar(user: _partner!, size: 52, showBadge: false, onTap: () {})
            else
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.dividerColor.withValues(alpha: 0.3),
                ),
              ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _partner?.name ?? '...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                            color: context.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread
                              ? MployaTheme.brandAccent
                              : context.textTertiary,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.conv.lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: hasUnread
                                ? context.textPrimary
                                : context.textSecondary,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: MployaTheme.brandAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${widget.conv.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Model interno ───────────────────────────────────────────────────────────

class _Conversation {
  final String partnerId;
  final String lastMessage;
  final String lastAt;
  int unreadCount;

  _Conversation({
    required this.partnerId,
    required this.lastMessage,
    required this.lastAt,
    required this.unreadCount,
  });
}
