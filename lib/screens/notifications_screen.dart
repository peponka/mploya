import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../services/notification_service.dart';
import '../services/social_service.dart';
import '../services/error_handler.dart';
import '../widgets/skeleton_loader.dart';
import '../services/smart_notification_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // ── IA Insights Data ──
  int _profileViews = 0;
  int _totalMatches = 0;
  int _pitchesReceived = 0;
  bool _insightsLoaded = false;
  List<SmartNotification> _digests = [];

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    final insights = await NotificationService.instance.getInsights();
    final digests = await SmartNotificationService.instance.fetchUnread();
    if (mounted) {
      setState(() {
        _profileViews = insights.views;
        _totalMatches = insights.matches;
        _pitchesReceived = insights.pitches;
        _insightsLoaded = true;
        _digests = digests;
      });
    }
  }

  NotificationType _parseType(String typeStr) {
    switch (typeStr) {
      case 'like': return NotificationType.like;
      case 'comment': return NotificationType.comment;
      case 'connection': return NotificationType.connection;
      case 'jobAlert': return NotificationType.jobAlert;
      case 'profileView': return NotificationType.profileView;
      case 'mention': return NotificationType.mention;
      default: return NotificationType.like;
    }
  }

  void _markAllAsRead(List<Map<String, dynamic>> unreadNotifs) async {
    final ids = unreadNotifs
        .where((n) => n['is_read'] != true && n['id'] != null)
        .map((n) => n['id'].toString())
        .toList();
    if (ids.isEmpty) return;
    await NotificationService.instance.markAllAsRead(ids);
  }

  void _markAsRead(Map<String, dynamic> n) async {
    if (n['is_read'] == true) return;
    await NotificationService.instance.markAsRead(n['id'].toString());
  }

  /// Extrae el requester_id de una notificación de conexión.
  String? _extractRequesterId(Map<String, dynamic> n) {
    if (n['requester_id'] != null) return n['requester_id'].toString();
    if (n['data'] is Map) {
      final data = n['data'] as Map;
      if (data['requester_id'] != null) return data['requester_id'].toString();
      if (data['sender_id'] != null) return data['sender_id'].toString();
    }
    return null;
  }

  Future<void> _handleAccept(Map<String, dynamic> n) async {
    final requesterId = _extractRequesterId(n);
    if (requesterId == null) {
      _markAsRead(n);
      return;
    }
    final result = await MployaErrorHandler.instance.wrapAsync(
      context,
      () => SocialService.instance.respondConnection(requesterId, 'accept'),
      successMessage: 'Conexión aceptada ✅',
      errorMessage: 'No se pudo aceptar la solicitud',
    );
    if (result != null) _markAsRead(n);
  }

  Future<void> _handleReject(Map<String, dynamic> n) async {
    final requesterId = _extractRequesterId(n);
    if (requesterId == null) {
      _markAsRead(n);
      return;
    }
    final result = await MployaErrorHandler.instance.wrapAsync(
      context,
      () => SocialService.instance.respondConnection(requesterId, 'reject'),
      successMessage: 'Solicitud rechazada',
      errorMessage: 'No se pudo rechazar la solicitud',
    );
    if (result != null) _markAsRead(n);
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return CupertinoIcons.hand_thumbsup_fill;
      case NotificationType.comment:
        return CupertinoIcons.chat_bubble_fill;
      case NotificationType.connection:
        return CupertinoIcons.person_add_solid;
      case NotificationType.jobAlert:
        return CupertinoIcons.briefcase_fill;
      case NotificationType.profileView:
        return CupertinoIcons.eye_fill;
      case NotificationType.mention:
        return CupertinoIcons.at;
    }
  }

  Color _colorForType(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return MployaTheme.brandAccent;
      case NotificationType.comment:
        return const Color(0xFF057642);
      case NotificationType.connection:
        return const Color(0xFF5F3DC4);
      case NotificationType.jobAlert:
        return NexTheme.brandAccent;
      case NotificationType.profileView:
        return const Color(0xFF00838F);
      case NotificationType.mention:
        return const Color(0xFFC2185B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
      child: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: NotificationService.instance.notificationsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: CupertinoColors.destructiveRed)));
            }
            if (!snapshot.hasData) {
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: 6,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SkeletonLoader(width: 44, height: 44, borderRadius: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader(width: 180, height: 13),
                            SizedBox(height: 6),
                            SkeletonLoader(width: 120, height: 11),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final uid = Supabase.instance.client.auth.currentUser?.id;
            final allNotifs = snapshot.data!;
            final List<Map<String, dynamic>> myNotifs = allNotifs.where((n) => n['user_id']?.toString() == uid).toList();

            final currentUser = ref.watch(currentUserProvider).value;
            if (currentUser != null && currentUser.accountType == 'confidencial') {
              final stealthTip = NotificationService.instance.getStealthTip(currentUser);
              if (stealthTip != null) {
                myNotifs.insert(0, {
                   'id': 'stealth-tip-${DateTime.now().toIso8601String().substring(0, 10)}',
                   'type': 'profileView',
                   'description': stealthTip,
                   'is_read': false,
                   'created_at': DateTime.now().toIso8601String(),
                });
              }
            }

            final hasActivity = _profileViews > 0 || _totalMatches > 0 || _pitchesReceived > 0;
            final unreadCount = myNotifs.where((n) => n['is_read'] != true).length;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      children: [
                        Text(
                          'Notificaciones',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: context.textPrimary,
                            fontFamily: '.SF Pro Display',
                            letterSpacing: -0.8,
                          ),
                        ),
                        const Spacer(),
                        if (unreadCount > 0)
                          GestureDetector(
                            onTap: () => _markAllAsRead(myNotifs),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: MployaTheme.brandAccent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Leer todas ($unreadCount)',
                                style: const TextStyle(fontSize: 13, color: MployaTheme.brandAccent, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Weekly Summary (compact, only if there's data) ──
                if (_insightsLoaded && hasActivity)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: MployaTheme.brandAccent.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          _CompactMetric(value: '$_profileViews', label: 'Vistas', icon: CupertinoIcons.eye_fill),
                          Container(width: 1, height: 28, color: context.dividerColor),
                          _CompactMetric(value: '$_totalMatches', label: 'Matches', icon: CupertinoIcons.bolt_fill),
                          Container(width: 1, height: 28, color: context.dividerColor),
                          _CompactMetric(value: '$_pitchesReceived', label: 'Replies', icon: CupertinoIcons.chat_bubble_fill),
                        ],
                      ),
                    ),
                  ),

                // ── Tip (only if no activity yet) ──
                if (_insightsLoaded && !hasActivity)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.isDark ? const Color(0xFF2A2310) : const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFE082).withValues(alpha: context.isDark ? 0.2 : 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.lightbulb_fill, color: Color(0xFFFFB800), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _getInsightTip(),
                              style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.4, fontFamily: '.SF Pro Text'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Smart Digests ──
                if (_digests.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Column(
                        children: _digests.map((d) => GestureDetector(
                          onTap: () async {
                            await SmartNotificationService.instance.markRead(d.id);
                            if (mounted) setState(() => _digests.removeWhere((x) => x.id == d.id));
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: context.isDark ? const Color(0xFF1A1F33) : const Color(0xFFF0F4FF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: context.isDark ? const Color(0xFF2E3A5C) : const Color(0xFFD6E4FF)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(CupertinoIcons.sparkles, color: Color(0xFF5856D6), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary)),
                                      const SizedBox(height: 2),
                                      Text(d.body, style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.3)),
                                    ],
                                  ),
                                ),
                                const Icon(CupertinoIcons.xmark_circle, size: 16, color: Color(0xFFAEAEB2)),
                              ],
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ),

                // ── Notification list ──
                if (myNotifs.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(CupertinoIcons.bell, size: 32, color: context.textTertiary),
                          ),
                          const SizedBox(height: 16),
                          Text('Sin notificaciones', style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                            'Interacciones, matches y alertas\naparecerán aquí.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.textSecondary, fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Section header only when there are notifications
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                      child: Text(
                        'Recientes',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final n = myNotifs[index];
                        final type = _parseType(n['type']?.toString() ?? 'like');
                        final isConnection = type == NotificationType.connection;
                        return GestureDetector(
                          onTap: () => _markAsRead(n),
                          behavior: HitTestBehavior.opaque,
                          child: _NotificationTile(
                            isRead: n['is_read'] == true,
                            description: n['description']?.toString() ?? '',
                            timeAgo: NotificationService.instance.timeAgo(n['created_at']),
                            icon: _iconForType(type),
                            iconColor: _colorForType(type),
                            showQuickActions: isConnection && n['is_read'] != true,
                            onAccept: isConnection ? () => _handleAccept(n) : null,
                            onReject: isConnection ? () => _handleReject(n) : null,
                          ),
                        );
                      },
                      childCount: myNotifs.length,
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }

  String _getInsightTip() {
    return NotificationService.instance.getInsightTip(
      _pitchesReceived, _totalMatches, _profileViews,
    );
  }
}

// ── Compact Metric (inline row) ──
class _CompactMetric extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _CompactMetric({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: MployaTheme.brandAccent, size: 14),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary, fontFamily: '.SF Pro Display')),
              Text(label, style: TextStyle(color: context.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Notification Tile (clean) ──
class _NotificationTile extends StatelessWidget {
  final bool isRead;
  final String description;
  final String timeAgo;
  final IconData icon;
  final Color iconColor;
  final bool showQuickActions;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _NotificationTile({
    required this.isRead,
    required this.description,
    required this.timeAgo,
    required this.icon,
    required this.iconColor,
    this.showQuickActions = false,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isRead ? Colors.transparent : MployaTheme.brandAccent.withValues(alpha: context.isDark ? 0.08 : 0.03),
        border: Border(bottom: BorderSide(color: context.dividerColor.withValues(alpha: 0.6), width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textPrimary,
                    fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
                // ── Quick Actions para conexiones ──
                if (showQuickActions) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onAccept,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: context.isDark ? CupertinoColors.white : const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Aceptar',
                            style: TextStyle(
                              color: context.isDark ? CupertinoColors.black : CupertinoColors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onReject,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Rechazar',
                            style: TextStyle(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(
                color: MployaTheme.brandAccent,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}