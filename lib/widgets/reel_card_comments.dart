import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../services/pitch_comment_service.dart';
import '../services/content_moderation_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// openReelCommentsSheet — Bottom sheet de comentarios para Video Pitches
// Extraído de tiktok_reel_card.dart para reducir el tamaño del god file.
// ─────────────────────────────────────────────────────────────────────────────

void openReelCommentsSheet(
  BuildContext parentContext,
  NexUser author, {
  bool Function(String)? contactInfoChecker,
}) {
  final commentController = TextEditingController();
  showCupertinoModalPopup(
    context: parentContext,
    builder: (_) => StatefulBuilder(
      builder: (context, setModalState) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: const BoxDecoration(
                color: Color(0xF2FFFFFF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFD1D1D6), borderRadius: BorderRadius.circular(2)))),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Comentarios para ${author.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E), decoration: TextDecoration.none, fontFamily: '.SF Pro Display')),
                  ),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: PitchCommentService.instance.getComments(author.id),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CupertinoActivityIndicator());
                        final comments = snap.data ?? [];
                        if (comments.isEmpty) return const Center(child: Text('Sé el primero en comentar 💬', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15, decoration: TextDecoration.none)));
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: comments.length,
                          itemBuilder: (context, i) => _CommentTile(comment: comments[i]),
                        );
                      },
                    ),
                  ),
                  _CommentInput(controller: commentController, authorId: author.id, contactInfoChecker: contactInfoChecker, onCommentAdded: () => setModalState(() {})),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final name = (comment['author_name'] ?? 'Usuario').toString();
    final text = (comment['text'] ?? '').toString();
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatarUrl = comment['author_avatar']?.toString();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: MployaTheme.brandAccent, image: hasAvatar ? DecorationImage(image: CachedNetworkImageProvider(avatarUrl), fit: BoxFit.cover) : null),
          child: !hasAvatar ? Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.none))) : null),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E), decoration: TextDecoration.none)),
          const SizedBox(height: 2),
          Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF3A3A3C), height: 1.3, decoration: TextDecoration.none)),
        ])),
      ]),
    );
  }
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final String authorId;
  final bool Function(String)? contactInfoChecker;
  final VoidCallback onCommentAdded;
  const _CommentInput({required this.controller, required this.authorId, this.contactInfoChecker, required this.onCommentAdded});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: const BoxDecoration(color: Color(0xFFF7F7F7), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Row(children: [
        Expanded(child: CupertinoTextField(controller: controller, placeholder: 'Escribe un comentario...', padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(20)))),
        const SizedBox(width: 8),
        CupertinoButton(padding: EdgeInsets.zero, onPressed: () => _submit(context), child: Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: MployaTheme.brandAccent, shape: BoxShape.circle), child: const Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 18))),
      ]),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    if (contactInfoChecker?.call(text) ?? false) {
      showCupertinoDialog(context: context, builder: (ctx) => CupertinoAlertDialog(title: const Text('Contenido no permitido'), content: const Text('Por seguridad, no se pueden compartir emails ni teléfonos en los comentarios.'), actions: [CupertinoDialogAction(child: const Text('Entendido'), onPressed: () => Navigator.pop(ctx))]));
      return;
    }
    final moderation = await ContentModerationService.instance.moderate(text, context: 'comment');
    if (moderation.isBlocked) {
      if (context.mounted) showCupertinoDialog(context: context, builder: (ctx) => CupertinoAlertDialog(title: const Text('Contenido no permitido'), content: Text(moderation.reason ?? 'Comentario no permitido.'), actions: [CupertinoDialogAction(child: const Text('Entendido'), onPressed: () => Navigator.pop(ctx))]));
      return;
    }
    if (moderation.isFlagged) ContentModerationService.instance.logFlaggedContent(text, moderation.category ?? 'unknown', 'comment');
    final ok = await PitchCommentService.instance.addComment(authorId, text);
    if (ok) { controller.clear(); onCommentAdded(); }
  }
}
