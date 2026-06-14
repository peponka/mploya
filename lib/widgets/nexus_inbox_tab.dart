import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/nex_avatar.dart';
import '../services/nexus_service.dart';
import '../widgets/nexus_match_overlay.dart';
import '../utils/time_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NexusInboxTab — Pestaña del ATS donde las empresas ven las señales recibidas
//
// Muestra:
//  • Lista de candidatos que enviaron ⚡ interés o 🎬 micro-pitch  
//  • Botones Aceptar (genera Nexus Match) / Pasar
//  • Preview de video para micro-pitches
//  • % de afinidad IA
// ─────────────────────────────────────────────────────────────────────────────

class NexusInboxTab extends StatefulWidget {
  const NexusInboxTab({super.key});

  @override
  State<NexusInboxTab> createState() => _NexusInboxTabState();
}

class _NexusInboxTabState extends State<NexusInboxTab> {
  String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  Future<NexUser?> _fetchCurrentUser() async {
    if (_uid == null) return null;
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', _uid!)
          .maybeSingle();
      if (res != null) return NexUser.fromJson(res);
    } catch (e) {
      debugPrint('⚠️ NexusInbox._fetchCurrentUser: $e');
    }
    return null;
  }

  Future<void> _handleAccept(Map<String, dynamic> signal) async {
    final success = await NexusService.instance.acceptSignal(signal['id']);
    if (!success || !mounted) return;

    // Buscar datos del sender para el overlay
    try {
      final senderData = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', signal['sender_id'])
          .maybeSingle();

      if (senderData == null || !mounted) return;

      final matchedUser = NexUser.fromJson(senderData);
      final currentUser = await _fetchCurrentUser();
      if (currentUser == null || !mounted) return;

      NexusMatchOverlay.show(
        context,
        currentUser: currentUser,
        matchedUser: matchedUser,
      );
    } catch (e) {
      debugPrint('Error en match overlay: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: NexusService.instance.pendingSignalsStream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CupertinoActivityIndicator(radius: 14));
        }

        final pending = snap.data!
            .where((s) => s['status'] == 'pending')
            .toList();

        if (pending.isEmpty) return _buildEmpty();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pending.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final signal = pending[index];
            return _NexusSignalCard(
              signal: signal,
              onAccept: () => _handleAccept(signal),
              onDecline: () => _confirmDecline(signal),
            );
          },
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
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
                  CupertinoIcons.bolt_fill,
                  size: 36,
                  color: MployaTheme.brandAccent.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sin señales pendientes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cuando un candidato muestre interés en tu empresa, aparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8E8E93),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDecline(Map<String, dynamic> signal) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('¿Pasar este candidato?'),
        content: const Text('No podrás deshacer esta acción.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Pasar'),
            onPressed: () {
              Navigator.pop(ctx);
              NexusService.instance.declineSignal(signal['id']);
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Signal Card
// ─────────────────────────────────────────────────────────────────────────────

class _NexusSignalCard extends StatefulWidget {
  final Map<String, dynamic> signal;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _NexusSignalCard({
    required this.signal,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_NexusSignalCard> createState() => _NexusSignalCardState();
}

class _NexusSignalCardState extends State<_NexusSignalCard> {
  NexUser? _senderUser;
  VideoPlayerController? _videoCtrl;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _fetchSender();
  }

  Future<void> _fetchSender() async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', widget.signal['sender_id'])
          .maybeSingle();
      if (res != null && mounted) {
        setState(() => _senderUser = NexUser.fromJson(res));
      }
    } catch (e) {
      debugPrint('⚠️ NexusSignalCard._fetchSender: $e');
    }
  }

  void _toggleVideo() {
    final url = widget.signal['video_url']?.toString();
    if (url == null) return;

    if (_videoCtrl == null) {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _isPlaying = true);
            _videoCtrl!.play();
          }
        });
    } else if (_isPlaying) {
      _videoCtrl!.pause();
      setState(() => _isPlaying = false);
    } else {
      _videoCtrl!.play();
      setState(() => _isPlaying = true);
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMicroPitch = widget.signal['signal_type'] == 'micro_pitch';
    final signalTimeAgo = timeAgo(widget.signal['created_at'], prefix: 'hace ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0C000000), blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: badge + sender info ──
            Row(
              children: [
                // Badge tipo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isMicroPitch
                          ? [const Color(0xFF5F3DC4), const Color(0xFFAE3EC9)]
                          : [MployaTheme.brandAccent, const Color(0xFF00C65E)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMicroPitch ? CupertinoIcons.videocam_fill : CupertinoIcons.bolt_fill,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMicroPitch ? 'Micro-Pitch' : 'Interesado',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  signalTimeAgo,
                  style: const TextStyle(
                    color: Color(0xFFAEAEB2),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Sender info ──
            Row(
              children: [
                if (_senderUser != null)
                  NexAvatar(user: _senderUser!, size: 48, showBadge: true, onTap: () {})
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEFEFEF),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _senderUser?.name ?? 'Cargando...',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _senderUser?.headline ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8E8E93),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Video preview (micro-pitch only) ──
            if (isMicroPitch && widget.signal['video_url'] != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _toggleVideo,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _videoCtrl != null && _videoCtrl!.value.isInitialized
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _videoCtrl!.value.size.width,
                                  height: _videoCtrl!.value.size.height,
                                  child: VideoPlayer(_videoCtrl!),
                                ),
                              ),
                              if (!_isPlaying)
                                Container(
                                  color: Colors.black26,
                                  child: const Center(
                                    child: Icon(CupertinoIcons.play_fill, color: Colors.white, size: 40),
                                  ),
                                ),
                            ],
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(CupertinoIcons.play_fill, color: Colors.white, size: 28),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Ver Micro-Pitch',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ── Action buttons ──
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: widget.onDecline,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text(
                          'Pasar',
                          style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: widget.onAccept,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [MployaTheme.brandAccent, Color(0xFF00C65E)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: MployaTheme.brandAccent.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '⚡ Aceptar Nexus',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
