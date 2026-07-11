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
import '../services/scheduling_service.dart';
import '../widgets/web_ui.dart';
import 'profile_screen.dart';
import 'ats_dashboard_screen.dart';
import 'scheduling_screen.dart';

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
  bool _bannerDismissed = false;

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
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width > 900 ? 720 : double.infinity,
            ),
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

            final isCompany = currentUser?.accountType == 'empresa' || currentUser?.accountType == 'headhunter';

            if (isWebWide(context)) {
              return isCompany
                  ? const _CompanyAlertsWeb()
                  : _buildWeb(context, myNotifs, hasActivity, unreadCount);
            }

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
                // SliverFillRemaining centra el estado vacío en el espacio que
                // sobra debajo del header/tip, en vez de quedar pegado arriba
                // con un padding fijo y dejar un vacío enorme más abajo.
                if (myNotifs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
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
        ),
      ),
    );
  }

  String _getInsightTip() {
    return NotificationService.instance.getInsightTip(
      _pitchesReceived, _totalMatches, _profileViews,
    );
  }

  // ── Layout web ────────────────────────────────────────────────────────────
  Widget _buildWeb(BuildContext context, List<Map<String, dynamic>> myNotifs, bool hasActivity, int unreadCount) {
    return WebPage(
      title: 'Notificaciones',
      subtitle: hasActivity ? '$_profileViews vistas · $_totalMatches matches · $_pitchesReceived respuestas' : null,
      actions: [
        if (unreadCount > 0)
          WebButton(label: 'Leer todas ($unreadCount)', filled: false, onTap: () => _markAllAsRead(myNotifs)),
      ],
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          if (_insightsLoaded && !hasActivity && !_bannerDismissed) _webTipBanner(context),
          ..._digests.map((d) => _webDigestCard(context, d)),
          if (myNotifs.isEmpty)
            WebEmptyState(
              icon: CupertinoIcons.bell,
              title: 'Tu centro de notificaciones está impecable',
              subtitle: 'Interacciones, matches y alertas aparecerán aquí.',
            )
          else ...[
            const WebSectionLabel('Recientes'),
            WebCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: myNotifs.map((n) {
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
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _webTipBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: WebCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const WebIconBadge(icon: CupertinoIcons.rocket_fill, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Impulsá tu visibilidad',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: context.textPrimary)),
                  const SizedBox(height: 3),
                  Text(_getInsightTip(), style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            WebButton(label: 'Completar ahora', onTap: () => Navigator.of(context).maybePop()),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => setState(() => _bannerDismissed = true),
              child: Icon(CupertinoIcons.xmark, size: 16, color: context.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _webDigestCard(BuildContext context, SmartNotification d) {
    return GestureDetector(
      onTap: () async {
        await SmartNotificationService.instance.markRead(d.id);
        if (mounted) setState(() => _digests.removeWhere((x) => x.id == d.id));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: WebCard(
          borderColor: const Color(0xFFD6E4FF),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WebIconBadge(icon: CupertinoIcons.sparkles, color: Color(0xFF5856D6), size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: context.textPrimary)),
                    const SizedBox(height: 3),
                    Text(d.body, style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.4)),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.xmark_circle, size: 18, color: Color(0xFFAEAEB2)),
            ],
          ),
        ),
      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Panel de Alertas para empresas — dark, con postulantes nuevos reales
// (get_company_candidates), próximas entrevistas reales (scheduled_interviews)
// y conexiones reales. Sin radar de skills ni "Premium Insight": esas partes
// del mockup no tienen una fuente de datos real detrás todavía.
// ─────────────────────────────────────────────────────────────────────────────
class _CompanyAlertsWeb extends StatefulWidget {
  const _CompanyAlertsWeb();

  @override
  State<_CompanyAlertsWeb> createState() => _CompanyAlertsWebState();
}

class _CompanyAlertsWebState extends State<_CompanyAlertsWeb> {
  final _supabase = Supabase.instance.client;
  Future<List<Map<String, dynamic>>>? _newCandidates;
  Future<List<ScheduledInterview>>? _interviews;
  Future<List<Map<String, dynamic>>>? _connections;

  @override
  void initState() {
    super.initState();
    _newCandidates = _fetchNewCandidates();
    _interviews = SchedulingService.instance.fetchMyInterviews();
    _connections = _fetchConnections();
  }

  Future<List<Map<String, dynamic>>> _fetchNewCandidates() async {
    try {
      final res = await _supabase.rpc('get_company_candidates', params: {'p_status': 'pending'});
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('Error get_company_candidates (alertas): $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchConnections() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];
    try {
      final rows = await _supabase
          .from('connections')
          .select('requester_id, addressee_id, created_at')
          .or('requester_id.eq.$uid,addressee_id.eq.$uid')
          .eq('status', 'accepted')
          .order('created_at', ascending: false)
          .limit(5);
      final otherIds = rows.map<String>((r) {
        final req = r['requester_id']?.toString() ?? '';
        final add = r['addressee_id']?.toString() ?? '';
        return req == uid ? add : req;
      }).where((id) => id.isNotEmpty).toList();
      if (otherIds.isEmpty) return [];
      final users = await _supabase.from('users').select('id, name, headline').inFilter('id', otherIds);
      return List<Map<String, dynamic>>.from(users);
    } catch (e) {
      debugPrint('Error connections (alertas): $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebPage(
      title: 'Panel de alertas de candidatos',
      subtitle: 'Novedades reales de tus vacantes, en un solo lugar.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _newCandidatesColumn()),
          const SizedBox(width: 16),
          SizedBox(width: 300, child: _sidebarColumn()),
        ],
      ),
    );
  }

  Widget _newCandidatesColumn() {
    return SingleChildScrollView(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _newCandidates,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CupertinoActivityIndicator()));
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return WebCard(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: WebEmptyState(
                icon: CupertinoIcons.bell,
                title: '¡Estás al día!',
                subtitle: 'Sin alertas nuevas.\n(Tip: revisá tus vacantes activas.)',
              ),
            );
          }
          return Column(
            children: rows.map((r) => _candidateAlertCard(r)).toList(),
          );
        },
      ),
    );
  }

  Widget _candidateAlertCard(Map<String, dynamic> r) {
    final name = r['candidate_name']?.toString() ?? 'Candidato';
    final headline = r['candidate_headline']?.toString() ?? '';
    final jobTitle = r['job_title']?.toString() ?? 'tu vacante';
    final avatarUrl = r['candidate_avatar_url']?.toString();
    final tags = (r['candidate_tags'] as List?)?.map((t) => t.toString()).toList() ?? [];
    return GestureDetector(
      onTap: () async {
        final data = await _supabase.from('users').select().eq('id', r['candidate_id']).maybeSingle();
        if (data != null && mounted) {
          Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: NexUser.fromJson(data))));
        }
      },
      child: WebCard(
        padding: const EdgeInsets.all(16),
        onTap: () async {
          final data = await _supabase.from('users').select().eq('id', r['candidate_id']).maybeSingle();
          if (data != null && mounted) {
            Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: NexUser.fromJson(data))));
          }
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MployaTheme.brandAccent.withValues(alpha: 0.12),
                image: (avatarUrl != null && avatarUrl.isNotEmpty) ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
              ),
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: MployaTheme.brandAccent, fontWeight: FontWeight.w800)))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary)),
                      ),
                      const WebBadge(label: 'Nuevo'),
                    ],
                  ),
                  if (headline.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(headline, style: TextStyle(fontSize: 12.5, color: context.textTertiary)),
                    ),
                  const SizedBox(height: 8),
                  Text('Postuló a "$jobTitle"',
                      style: TextStyle(fontSize: 12.5, color: context.textSecondary, fontWeight: FontWeight.w600)),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags.take(4).map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: context.dividerColor.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(999)),
                            child: Text('#$t', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: context.textSecondary)),
                          )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _sidebarColumn() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WebSectionLabel('Próximas entrevistas', color: kMployaBlue),
                FutureBuilder<List<ScheduledInterview>>(
                  future: _interviews,
                  builder: (context, snap) {
                    if (!snap.hasData) return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: CupertinoActivityIndicator()));
                    final list = snap.data!;
                    if (list.isEmpty) {
                      return Text('Sin entrevistas agendadas.\n(Tip: programá una nueva entrevista.)',
                          style: TextStyle(fontSize: 12.5, color: context.textTertiary, height: 1.4));
                    }
                    return Column(
                      children: list.take(4).map((i) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 30, height: 30,
                                  decoration: BoxDecoration(color: kMployaBlue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(CupertinoIcons.calendar, size: 14, color: kMployaBlue),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text('${i.date} · ${i.time}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
                                ),
                              ],
                            ),
                          )).toList(),
                    );
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: WebButton(
                    icon: CupertinoIcons.add,
                    label: 'Agregar Entrevista',
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SchedulingScreen(isCompany: true))),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WebCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WebSectionLabel('Conexiones recientes', color: kMployaPurple),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _connections,
                  builder: (context, snap) {
                    if (!snap.hasData) return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: CupertinoActivityIndicator()));
                    final list = snap.data!;
                    if (list.isEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(5, (i) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Container(
                                    width: 30, height: 30,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: i == 0 ? MployaTheme.brandAccent : context.dividerColor, width: 1.5),
                                    ),
                                  ),
                                )),
                          ),
                          const SizedBox(height: 10),
                          Text('Todavía no tenés conexiones.\n(Tip: conectá con candidatos destacados.)',
                              style: TextStyle(fontSize: 12.5, color: context.textTertiary, height: 1.4)),
                        ],
                      );
                    }
                    return Column(
                      children: list.map((u) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: kMployaPurple.withValues(alpha: 0.15)),
                                  child: Center(child: Text((u['name']?.toString() ?? '?')[0].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kMployaPurple))),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(u['name']?.toString() ?? '', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          )).toList(),
                    );
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: WebButton(
                    label: 'Ver Candidatos',
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const AtsDashboardScreen())),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}