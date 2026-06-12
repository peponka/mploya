import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../screens/story_viewer_screen.dart';
import '../screens/create_story_screen.dart';
import 'nex_avatar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StoryRow — Historias circulares estilo Instagram/LinkedIn
//
// Muestra:
//  • "Tu Historia" (primer círculo con +) → abre CreateStoryScreen
//  • Usuarios con stories activas (no expiradas, últimas 24h)
//  • Anillo gradient si tiene story activa
// ─────────────────────────────────────────────────────────────────────────────

class StoryRow extends StatefulWidget {
  final List<NexUser> users;
  final bool isDarkOverlay;
  final String currentAccountType;

  const StoryRow({super.key, required this.users, this.isDarkOverlay = false, this.currentAccountType = 'candidato'});

  @override
  State<StoryRow> createState() => _StoryRowState();
}

class _StoryRowState extends State<StoryRow> {
  List<NexUser> _storyUsers = [];
  Set<String> _activeStoryUserIds = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadActiveStories();
  }

  Future<void> _loadActiveStories() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final myAccountType = widget.currentAccountType;

      // Ley de Cruce: candidatos ven empresas, empresas ven candidatos
      final rows = await Supabase.instance.client
          .from('active_story_users')
          .select()
          .order('latest_story_at', ascending: false)
          .limit(20);

      final activeIds = <String>{};
      for (final r in rows) {
        activeIds.add(r['user_id'].toString());
      }

      if (mounted) {
        setState(() {
          _activeStoryUserIds = activeIds;

          // Filtrar por Ley de Cruce: solo mostrar el tipo opuesto
          // + incluir stealth/confidencial si somos empresa
          final crossFiltered = widget.users.where((u) {
            if (u.id == uid) return false; // No mostrarse a sí mismo
            if (myAccountType == 'empresa') {
              // Empresa ve candidatos y stealth
              return u.accountType != 'empresa';
            } else {
              // Candidato ve empresas
              return u.accountType == 'empresa';
            }
          }).toList();

          // Priorizar los que tienen story activa
          final withStory = crossFiltered.where((u) => activeIds.contains(u.id)).toList();
          final withoutStory = crossFiltered.where((u) => !activeIds.contains(u.id)).toList();

          // Si hay stories activas, solo mostrar esos. Si no, mostrar cross-filtered como fallback
          if (withStory.isNotEmpty) {
            _storyUsers = [...withStory, ...withoutStory].take(15).toList();
          } else {
            _storyUsers = crossFiltered.take(15).toList();
          }
          _loaded = true;
        });
      }
    } catch (e) {
      debugPrint('⚠️ StoryRow: Error loading stories: $e');
      if (mounted) {
        setState(() {
          // Fallback: aplicar filtro cruzado básico
          final uid = Supabase.instance.client.auth.currentUser?.id;
          _storyUsers = widget.users.where((u) => u.id != uid).take(15).toList();
          _loaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayUsers = _loaded ? _storyUsers : widget.users;

    return Container(
      height: 68,
      color: Colors.transparent,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
        itemCount: displayUsers.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _YourStory(isDarkOverlay: widget.isDarkOverlay);
          }
          final user = displayUsers[index - 1];
          final hasActiveStory = _activeStoryUserIds.contains(user.id);
          return _StoryItem(
            user: user,
            users: displayUsers,
            index: index - 1,
            isDarkOverlay: widget.isDarkOverlay,
            hasActiveStory: hasActiveStory,
          );
        },
      ),
    );
  }
}

class _YourStory extends StatefulWidget {
  final bool isDarkOverlay;
  const _YourStory({this.isDarkOverlay = false});

  @override
  State<_YourStory> createState() => _YourStoryState();
}

class _YourStoryState extends State<_YourStory> {
  String _initials = 'ME';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('name, avatar_url')
          .eq('id', uid)
          .maybeSingle();
      if (mounted && row != null) {
        final name = row['name']?.toString() ?? '';
        setState(() {
          _avatarUrl = row['avatar_url']?.toString();
          _initials = name.isNotEmpty
              ? name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
              : 'ME';
        });
      }
    } catch (e) {
      debugPrint('⚠️ StoryRow._loadAvatar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            CupertinoPageRoute(
              fullscreenDialog: true,
              builder: (_) => const CreateStoryScreen(),
            ),
          );
        },
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [NexTheme.brandAccent, NexTheme.premiumEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: NexTheme.brandAccent.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: widget.isDarkOverlay ? Colors.black : const Color(0xFFF9F9FA),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.isDark ? const Color(0xFF3A3A3A) : const Color(0xFFEFEFEF),
                        image: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(_avatarUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                          ? Center(
                              child: Text(
                                _initials,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: widget.isDarkOverlay ? Colors.black : const Color(0xFFF9F9FA),
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: MployaTheme.brandAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.add,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Tu Historia',
              style: TextStyle(
                fontSize: 10,
                color: widget.isDarkOverlay ? Colors.white : context.textSecondary,
                fontWeight: FontWeight.w600,
                shadows: widget.isDarkOverlay ? [const Shadow(color: Colors.black54, blurRadius: 4)] : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final NexUser user;
  final List<NexUser> users;
  final int index;
  final bool isDarkOverlay;
  final bool hasActiveStory;

  const _StoryItem({
    required this.user,
    required this.users,
    required this.index,
    this.isDarkOverlay = false,
    this.hasActiveStory = false,
  });

  @override
  Widget build(BuildContext context) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        children: [
          NexAvatar(
            user: user,
            size: 34,
            showStoryRing: hasActiveStory,
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => StoryViewerScreen(
                    users: users,
                    initialIndex: index,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 3),
          Text(
            initial,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDarkOverlay ? Colors.white70 : context.textSecondary,
              shadows: isDarkOverlay ? [const Shadow(color: Colors.black54, blurRadius: 4)] : null,
            ),
          ),
        ],
      ),
    );
  }
}
