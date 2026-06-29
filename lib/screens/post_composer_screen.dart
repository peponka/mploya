import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'camera_screen.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/nex_avatar.dart';

class PostComposerScreen extends StatefulWidget {
  const PostComposerScreen({super.key});

  @override
  State<PostComposerScreen> createState() => _PostComposerScreenState();
}

class _PostComposerScreenState extends State<PostComposerScreen> {
  final TextEditingController _controller = TextEditingController();
  String _audience = 'Público General';
  int _charCount = 0;
  bool _isPublishing = false;
  static const int _maxChars = 3000;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _charCount = _controller.text.length);
    });
  }

  Future<void> _publishPost() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isPublishing) return;
    
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    setState(() => _isPublishing = true);

    try {
      await Supabase.instance.client.from('posts').insert({
        'user_id': currentUserId,
        'content': text,
        'audience': _audience,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error publicando: $e');
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Error DB'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(ctx),
              )
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(MployaTheme.radiusXXL),
        ),
      ),
      child: Column(
        children: [
          // ── Handle ──
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: context.dividerColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
            child: Row(
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.all(10),
                  minimumSize: Size.zero,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 20,
                    color: context.textPrimary,
                  ),
                ),
                const Spacer(),
                // Clock/schedule button (pendiente implementar programación)
                CupertinoButton(
                  padding: const EdgeInsets.all(10),
                  minimumSize: Size.zero,
                  onPressed: null,
                  child: Icon(
                    CupertinoIcons.clock,
                    size: 22,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                // Post button
                Opacity(
                  opacity: _charCount > 0 ? 1.0 : 0.5,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    color: MployaTheme.brandAccent,
                    borderRadius:
                        BorderRadius.circular(MployaTheme.radiusPill),
                    minimumSize: Size.zero,
                    onPressed: (_charCount > 0 && !_isPublishing) ? _publishPost : null,
                    child: _isPublishing 
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white, radius: 10)
                      : const Text(
                          'Publicar',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white,
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),

// ── User + Audience ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client.auth.currentUser != null ? Supabase.instance.client.from('users').stream(primaryKey: ['id']).eq('id', Supabase.instance.client.auth.currentUser!.id) : null,
              builder: (context, snapshot) {
                final user = (snapshot.hasData && snapshot.data!.isNotEmpty) ? NexUser.fromJson(snapshot.data!.first) : const NexUser(id: 'guest', name: 'Usuario', headline: '');
                return Row(
                  children: [
                    NexAvatar(user: user, size: 44),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        _showAudiencePicker(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(MployaTheme.radiusPill),
                          
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.globe,
                              size: 13,
                              color: context.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _audience,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: context.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              CupertinoIcons.chevron_down,
                              size: 11,
                              color: context.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                  ],
                );
              },
            ),
          ),

          // ── Text Field ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoTextField(
                controller: _controller,
                placeholder: 'Graba tu Pitch o escribe una actualización...',
                placeholderStyle: TextStyle(
                  fontSize: 18,
                  color: context.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
                style: TextStyle(
                  fontSize: 17,
                  color: context.textPrimary,
                  height: 1.5,
                ),
                padding: EdgeInsets.zero,
                decoration: const BoxDecoration(),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ),

          // ── Character Count ──
          if (_charCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$_charCount / $_maxChars',
                  style: TextStyle(
                    fontSize: 12,
                    color: _charCount > _maxChars
                        ? MployaTheme.danger
                        : context.textTertiary,
                  ),
                ),
              ),
            ),

          // ── Media bar ──
          Container(
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              top: 8,
              bottom: bottomInset > 0 ? 8 : 16,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: context.dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  const _MediaButton(
                    icon: CupertinoIcons.photo,
                    label: 'Foto',
                    color: Color(0xFF057642),
                  ),
                  _MediaButton(
                    icon: CupertinoIcons.videocam,
                    label: 'Pitch',
                    color: const Color(0xFFC2185B),
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(builder: (_) => const CameraScreen()),
                      );
                    },
                  ),
                  const _MediaButton(
                    icon: CupertinoIcons.doc,
                    label: 'Portfolio',
                    color: MployaTheme.brandAccent,
                  ),
                  const _MediaButton(
                    icon: CupertinoIcons.calendar,
                    label: 'Evento',
                    color: Color(0xFF5F3DC4),
                  ),
                  const _MediaButton(
                    icon: CupertinoIcons.text_quote,
                    label: 'Artículo',
                    color: MployaTheme.brandAccent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAudiencePicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('¿Quién puede ver esto?'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _audience = 'Público General');
              Navigator.pop(ctx);
            },
            child: const Text('Público General'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _audience = 'Solo Mis Matches');
              Navigator.pop(ctx);
            },
            child: const Text('Solo Mis Matches'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _MediaButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 8),
        minimumSize: Size.zero,
        onPressed: onTap ?? () {},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: context.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
