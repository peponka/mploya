import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/chat_service.dart';
import 'agora_call_screen.dart';

class ChatInmailScreen extends StatefulWidget {
  final NexUser? targetUser;
  
  const ChatInmailScreen({super.key, this.targetUser});

  @override
  State<ChatInmailScreen> createState() => _ChatInmailScreenState();
}

class _ChatInmailScreenState extends State<ChatInmailScreen> {
  final TextEditingController _msgController = TextEditingController();
  final _supabase = Supabase.instance.client;
  late final Stream<List<Map<String, dynamic>>> _messagesStream;

  @override
  void initState() {
    super.initState();
    final myId = _supabase.auth.currentUser?.id;
    final otherId = widget.targetUser?.id;

    if (myId != null && otherId != null) {
      _messagesStream = _supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: true)
          .map((rows) => rows.where((row) => 
               (row['sender_id'] == myId && row['receiver_id'] == otherId) ||
               (row['sender_id'] == otherId && row['receiver_id'] == myId)
          ).toList());
    } else {
      _messagesStream = Stream.value([]);
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  void _startVideoCall(BuildContext context) async {
    final myId = _supabase.auth.currentUser?.id;
    final otherId = widget.targetUser?.id;
    if (myId == null || otherId == null) return;

    // Notificar en el chat que se inició videollamada
    await ChatService.instance.sendTextMessage(
      receiverId: otherId,
      text: '📹 Videollamada iniciada — únete desde la app',
    );

    if (!context.mounted) return;
    final channelName = '${[myId, otherId]..sort()}'.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').substring(0, 32);
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => AgoraCallScreen(
          channelName: channelName,
          displayName: _supabase.auth.currentUser?.userMetadata?['full_name']?.toString() ?? 'Usuario',
          otherName: widget.targetUser?.name ?? 'Talento',
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    
    final myId = _supabase.auth.currentUser?.id;
    final otherId = widget.targetUser?.id;
    if (myId == null || otherId == null) return;

    _msgController.clear();
    FocusScope.of(context).unfocus();

    try {
      await _supabase.from('messages').insert({
        'sender_id': myId,
        'receiver_id': otherId,
        'content': text,
        'text': text,
        'type': 'text',
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorName = widget.targetUser?.name ?? 'Talento Confidencial';
    final myId = _supabase.auth.currentUser?.id;
    
    return CupertinoPageScaffold(
      backgroundColor: context.bgColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: context.bgColor,
        middle: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(authorName, style: TextStyle(color: context.textPrimary)),
            const Text('Respuesta garantizada al 85%', style: TextStyle(color: MployaTheme.brandAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _startVideoCall(context),
          child: const Icon(CupertinoIcons.video_camera_solid, color: MployaTheme.brandAccent, size: 26),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CupertinoActivityIndicator());
                  }
                  final msgs = snapshot.data ?? [];
                  
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: msgs.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 24),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: MployaTheme.brandAccent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Estás usando un InMail Premium.\nEl candidato recibirá una notificación prioritaria.', textAlign: TextAlign.center, style: TextStyle(color: MployaTheme.brandAccent, fontSize: 12)),
                          ),
                        );
                      }
                      final m = msgs[index - 1];
                      final isMe = m['sender_id'] == myId;
                      return _buildMessageBubble(m['text']?.toString() ?? m['content']?.toString() ?? '', isMe: isMe);
                    },
                  );
                },
              ),
            ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, {required bool isMe}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? MployaTheme.brandAccent : CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(0) : null,
            bottomLeft: !isMe ? const Radius.circular(0) : null,
          ),
        ),
        child: Text(text, style: TextStyle(color: isMe ? Colors.white : context.textPrimary, fontSize: 15)),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: _msgController,
              placeholder: 'Escribe tu InMail directo...',
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MployaTheme.brandAccent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: MployaTheme.brandAccent.withValues(alpha: 0.3), blurRadius: 8)],
              ),
              child: const Icon(CupertinoIcons.paperplane_fill, color: Colors.white, size: 20),
            ),
          )
        ],
      ),
    );
  }
}