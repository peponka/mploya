import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/nex_avatar.dart';
import 'profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SavedProfilesScreen — "Mis Guardados" (Bookmarks)
//
// Muestra una lista de perfiles que el usuario guardó desde el feed.
// Cada tarjeta permite:
//  • Ver el perfil completo (tap)
//  • Eliminar el bookmark (swipe o botón)
// ─────────────────────────────────────────────────────────────────────────────

class SavedProfilesScreen extends StatefulWidget {
  const SavedProfilesScreen({super.key});

  @override
  State<SavedProfilesScreen> createState() => _SavedProfilesScreenState();
}

class _SavedProfilesScreenState extends State<SavedProfilesScreen> {
  List<Map<String, dynamic>> _savedProfiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedProfiles();
  }

  Future<void> _loadSavedProfiles() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      // Obtener IDs guardados
      final savedRows = await Supabase.instance.client
          .from('saved_profiles')
          .select('saved_user_id, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      if (savedRows.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final savedIds = (savedRows as List)
          .map((r) => r['saved_user_id'].toString())
          .toList();

      // Obtener datos de los usuarios guardados
      final users = await Supabase.instance.client
          .from('users')
          .select()
          .inFilter('id', savedIds);

      if (mounted) {
        setState(() {
          _savedProfiles = List<Map<String, dynamic>>.from(users);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading saved profiles: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeBookmark(String savedUserId) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await Supabase.instance.client
          .from('saved_profiles')
          .delete()
          .eq('user_id', uid)
          .eq('saved_user_id', savedUserId);
      setState(() {
        _savedProfiles.removeWhere((p) => p['id'] == savedUserId);
      });
    } catch (e) {
      debugPrint('❌ Error removing bookmark: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Guardados'),
        trailing: _savedProfiles.isNotEmpty
            ? Text(
                '${_savedProfiles.length}',
                style: TextStyle(
                  color: context.brandAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : _savedProfiles.isEmpty
                ? _buildEmptyState(context)
                : _buildProfileList(context),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.brandAccent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.bookmark,
                size: 48,
                color: context.brandAccent.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin perfiles guardados',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Guardá perfiles desde el feed\npara verlos después aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileList(BuildContext context) {
    return RefreshIndicator(
      color: MployaTheme.brandAccent,
      onRefresh: _loadSavedProfiles,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _savedProfiles.length,
        itemBuilder: (context, index) {
          final data = _savedProfiles[index];
          final user = NexUser.fromJson(data);
          return Dismissible(
            key: Key(user.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.destructiveRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                CupertinoIcons.trash,
                color: CupertinoColors.destructiveRed,
                size: 24,
              ),
            ),
            onDismissed: (_) => _removeBookmark(user.id),
            child: _SavedProfileCard(
              user: user,
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => ProfileScreen(user: user)),
                );
              },
              onRemove: () => _removeBookmark(user.id),
            ),
          );
        },
      ),
    );
  }
}

class _SavedProfileCard extends StatelessWidget {
  final NexUser user;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedProfileCard({
    required this.user,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Role label
    String roleLabel;
    Color roleColor;
    switch (user.accountType) {
      case 'empresa':
        roleLabel = 'Empresa';
        roleColor = MployaTheme.brandAccent;
        break;
      case 'headhunter':
        roleLabel = 'Hunter';
        roleColor = NexTheme.accentDark;
        break;
      case 'confidencial':
        roleLabel = 'Stealth';
        roleColor = const Color(0xFF5F3DC4);
        break;
      default:
        roleLabel = 'Candidato';
        roleColor = const Color(0xFF00838F);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            NexAvatar(user: user, size: 52, showBadge: true),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: roleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.headline.isNotEmpty ? user.headline : 'Sin descripción',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: user.tags.take(3).map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.brandAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.brandAccent,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: onRemove,
              child: const Icon(
                CupertinoIcons.bookmark_fill,
                color: Color(0xFFFFD60A),
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}