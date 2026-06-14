import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import '../services/profile_view_service.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';
import '../models/models.dart';
import '../utils/time_utils.dart';

class ProfileViewersScreen extends StatefulWidget {
  const ProfileViewersScreen({super.key});

  @override
  State<ProfileViewersScreen> createState() => _ProfileViewersScreenState();
}

class _ProfileViewersScreenState extends State<ProfileViewersScreen> {
  late Future<List<Map<String, dynamic>>> _viewersFuture;

  @override
  void initState() {
    super.initState();
    _viewersFuture = ProfileViewService.instance.getMyViewers();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Quién vio tu perfil'),
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _viewersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator(radius: 16));
          }

          final viewers = snapshot.data ?? [];

          if (viewers.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.eye_slash,
                      size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'Aún nadie vio tu perfil',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Graba un Video-Pitch increíble\npara atraer más vistas 🎬',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFAEAEB2),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 16),
            itemCount: viewers.length + 1, // +1 for header
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1DB954), Color(0xFF0D9B40)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.eye_fill,
                            color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${viewers.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'personas vieron tu perfil',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              final viewer = viewers[index - 1];
              final name = viewer['name']?.toString() ?? 'Usuario';
              final headline = viewer['headline']?.toString() ?? '';
              final avatarUrl = viewer['avatar_url']?.toString();
              final viewedAt = timeAgo(viewer['viewed_at'], prefix: 'Hace ');
              final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

              return GestureDetector(
                onTap: () {
                  final user = NexUser.fromJson(viewer);
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                        builder: (_) => ProfileScreen(user: user)),
                  );
                },
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 8,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: MployaTheme.brandAccent,
                          image: (avatarUrl != null && avatarUrl.isNotEmpty) // FIXED: empty string check
                              ? DecorationImage(
                                  image: NetworkImage(avatarUrl),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: (avatarUrl == null || avatarUrl.isEmpty) // FIXED: empty string check
                            ? Center(
                                child: Text(initials,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1C1C1E),
                              ),
                            ),
                            if (headline.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                headline,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8E8E93),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Time
                      Text(
                        viewedAt,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFAEAEB2),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(CupertinoIcons.chevron_right,
                          size: 14, color: Color(0xFFD1D1D6)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}