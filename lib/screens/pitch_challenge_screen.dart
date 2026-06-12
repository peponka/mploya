import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/pitch_challenge_service.dart';
import 'camera_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PitchChallengeScreen — Challenge semanal de Video-Pitch
//
// Muestra el desafío activo + entries de otros usuarios + opción de participar
// ─────────────────────────────────────────────────────────────────────────────

class PitchChallengeScreen extends StatefulWidget {
  const PitchChallengeScreen({super.key});

  @override
  State<PitchChallengeScreen> createState() => _PitchChallengeScreenState();
}

class _PitchChallengeScreenState extends State<PitchChallengeScreen> {
  final _service = PitchChallengeService.instance;
  PitchChallenge? _challenge;
  List<ChallengeEntry> _entries = [];
  bool _isLoading = true;
  bool _hasParticipated = false;

  @override
  void initState() {
    super.initState();
    _loadChallenge();
  }

  Future<void> _loadChallenge() async {
    setState(() => _isLoading = true);
    final challenge = await _service.getCurrentChallenge();

    if (challenge != null) {
      final entries = await _service.getEntries(challenge.id);
      final participated = await _service.hasParticipated(challenge.id);

      if (mounted) {
        setState(() {
          _challenge = challenge;
          _entries = entries;
          _hasParticipated = participated;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _participate() async {
    if (_challenge == null) return;

    // Abrir cámara para grabar el challenge
    final result = await Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const CameraScreen()),
    );

    if (result == true && _challenge != null) {
      // El video ya fue subido por CameraScreen, buscar la URL del pitch
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final userData = await Supabase.instance.client
          .from('users')
          .select('video_url')
          .eq('id', uid)
          .maybeSingle();

      final videoUrl = userData?['video_url']?.toString();
      if (videoUrl != null && videoUrl.isNotEmpty) {
        final error = await _service.submitEntry(
          challengeId: _challenge!.id,
          videoUrl: videoUrl,
        );

        if (mounted) {
          if (error == null) {
            showCupertinoDialog(
              context: context,
              builder: (ctx) => CupertinoAlertDialog(
                title: const Text('¡Participación Enviada! 🎉'),
                content: const Text('Tu video ya forma parte del challenge. '
                    'Compartilo para conseguir más likes y ganar visibilidad.'),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('Genial'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _loadChallenge(); // Refresh
                    },
                  ),
                ],
              ),
            );
          } else {
            showCupertinoDialog(
              context: context,
              builder: (ctx) => CupertinoAlertDialog(
                title: const Text('Aviso'),
                content: Text(error),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('OK'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Pitch Challenge'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _loadChallenge,
          child: Icon(CupertinoIcons.refresh, size: 20, color: context.brandAccent),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 14))
            : _challenge == null
                ? _buildNoChallenge()
                : _buildChallengeContent(),
      ),
    );
  }

  Widget _buildNoChallenge() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Próximamente',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'El próximo challenge se publicará pronto. ¡Mantené tu perfil listo!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: context.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeContent() {
    final c = _challenge!;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        // ── Challenge Card ──
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5F3DC4), Color(0xFFAE3EC9)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5F3DC4).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(c.emoji, style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'CHALLENGE SEMANAL',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          c.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                c.description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              // Stats row
              Row(
                children: [
                  _ChallengeStatChip(
                    icon: CupertinoIcons.person_2_fill,
                    label: '${c.participantCount} participantes',
                  ),
                  const SizedBox(width: 10),
                  _ChallengeStatChip(
                    icon: CupertinoIcons.clock,
                    label: c.isOngoing ? '${c.daysRemaining}d restantes' : 'Finalizado',
                  ),
                  const SizedBox(width: 10),
                  _ChallengeStatChip(
                    icon: CupertinoIcons.timer,
                    label: '${c.maxDurationSeconds}s máx',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Participate button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  onPressed: _hasParticipated ? null : _participate,
                  child: Text(
                    _hasParticipated ? '✓ Ya Participaste' : '🎬 Participar Ahora',
                    style: TextStyle(
                      color: _hasParticipated
                          ? const Color(0xFF5F3DC4).withValues(alpha: 0.5)
                          : const Color(0xFF5F3DC4),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── Leaderboard ──
        if (_entries.isNotEmpty) ...[
          Row(
            children: [
              const Text('🏅', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Ranking',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._entries.asMap().entries.map((entry) {
            final index = entry.key;
            final e = entry.value;
            return _LeaderboardCard(
              entry: e,
              position: index + 1,
              onLike: () async {
                await _service.likeEntry(e.id);
                _loadChallenge();
              },
            );
          }),
        ] else ...[
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                const Text('🎤', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  '¡Sé el primero en participar!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Grabá tu respuesta al challenge y liderá el ranking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 80),
      ],
    );
  }
}

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _ChallengeStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ChallengeStatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  final ChallengeEntry entry;
  final int position;
  final VoidCallback onLike;

  const _LeaderboardCard({
    required this.entry,
    required this.position,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final isTop3 = position <= 3;
    final medal = position == 1 ? '🥇' : position == 2 ? '🥈' : position == 3 ? '🥉' : '#$position';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isTop3
            ? Border.all(color: const Color(0xFFFACC15).withValues(alpha: 0.3))
            : null,
        boxShadow: context.cardShadow,
      ),
      child: Row(
        children: [
          // Position
          SizedBox(
            width: 36,
            child: Text(
              medal,
              style: TextStyle(
                fontSize: isTop3 ? 22 : 16,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
          ),
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: MployaTheme.brandAccent.withValues(alpha: 0.1),
            backgroundImage: entry.userAvatar != null
                ? NetworkImage(entry.userAvatar!)
                : null,
            child: entry.userAvatar == null
                ? Text(
                    entry.userName.isNotEmpty ? entry.userName[0] : '?',
                    style: const TextStyle(
                      color: MployaTheme.brandAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.userName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  '${entry.views} views',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // Like button
          GestureDetector(
            onTap: onLike,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.heart_fill, size: 14, color: Color(0xFFEF4444)),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.likes}',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}