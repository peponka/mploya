import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
                   'body': stealthTip,
                   'is_read': false,
                   'created_at': DateTime.now().toIso8601String(),
                });
              }
            }

            final hasActivity = _profileViews > 0 || _totalMatches > 0 || _pitchesReceived > 0;
            final unreadCount = myNotifs.where((n) => n['is_read'] != true).length;

            if (isWebWide(context)) {
              return _buildWeb(context, myNotifs, hasActivity, unreadCount);
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
                          'Alertas',
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

                // ── Banner de visibilidad (mobile) ──
                if (_insightsLoaded && !hasActivity && !_bannerDismissed)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFB923C)]),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(CupertinoIcons.rocket_fill, color: CupertinoColors.white, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('Aumentá tu visibilidad',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary)),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _bannerDismissed = true),
                                child: Icon(CupertinoIcons.xmark, size: 14, color: context.textTertiary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Completá tu perfil y grabá un video pitch para destacarte ante los reclutadores.',
                              style: TextStyle(fontSize: 12.5, color: context.textSecondary, height: 1.4)),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => Navigator.of(context).maybePop(),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: MployaTheme.brandAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('Grabar Video Pitch', textAlign: TextAlign.center,
                                  style: TextStyle(color: CupertinoColors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
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

                // ── Cards Grid (2 columns on mobile) ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: _buildMobileCardsGrid(context, myNotifs),
                  ),
                ),

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

  // ── Mobile Cards Grid (2 columns) ──────────────────────────────────────────
  Widget _buildMobileCardsGrid(BuildContext context, List<Map<String, dynamic>> myNotifs) {
    final List<_AlertCardData> alertCards = myNotifs.map((n) {
      final type = _parseType(n['type']?.toString() ?? 'like');
      final isConnection = type == NotificationType.connection;
      return _AlertCardData(
        type: type,
        title: n['body']?.toString() ?? n['title']?.toString() ?? '',
        timeAgo: NotificationService.instance.timeAgo(n['created_at']),
        isRead: n['is_read'] == true,
        avatarUrl: n['avatar_url']?.toString(),
        name: n['sender_name']?.toString(),
        headline: n['sender_headline']?.toString(),
        companyName: n['company_name']?.toString(),
        onTap: () => _markAsRead(n),
        onAccept: isConnection ? () => _handleAccept(n) : null,
        onReject: isConnection ? () => _handleReject(n) : null,
      );
    }).toList();

    final showDemo = alertCards.isEmpty;
    final displayCards = showDemo ? _demoAlertCards() : alertCards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDemo)
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MployaTheme.brandAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.sparkles, size: 11, color: MployaTheme.brandAccent),
                      SizedBox(width: 4),
                      Text('Preview', style: TextStyle(color: MployaTheme.brandAccent, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: displayCards.map((card) => SizedBox(
            width: (MediaQuery.of(context).size.width - 42) / 2,
            child: _MobileAlertCard(data: card),
          )).toList(),
        ),
      ],
    );
  }

  String _getInsightTip() {
    return NotificationService.instance.getInsightTip(
      _pitchesReceived, _totalMatches, _profileViews,
    );
  }

  // ── Layout web — Cards Grid ────────────────────────────────────────────────
  Widget _buildWeb(BuildContext context, List<Map<String, dynamic>> myNotifs, bool hasActivity, int unreadCount) {
    // Convertir notificaciones reales a alert cards
    final List<_AlertCardData> alertCards = myNotifs.map((n) {
      final type = _parseType(n['type']?.toString() ?? 'like');
      final isConnection = type == NotificationType.connection;
      return _AlertCardData(
        type: type,
        title: n['body']?.toString() ?? n['title']?.toString() ?? '',
        timeAgo: NotificationService.instance.timeAgo(n['created_at']),
        isRead: n['is_read'] == true,
        avatarUrl: n['avatar_url']?.toString(),
        name: n['sender_name']?.toString(),
        headline: n['sender_headline']?.toString(),
        companyName: n['company_name']?.toString(),
        onTap: () => _markAsRead(n),
        onAccept: isConnection ? () => _handleAccept(n) : null,
        onReject: isConnection ? () => _handleReject(n) : null,
      );
    }).toList();

    // Si no hay notifs reales, mostrar demo cards
    final showDemo = alertCards.isEmpty;
    final displayCards = showDemo ? _demoAlertCards() : alertCards;

    return WebPage(
      title: 'Alertas',
      subtitle: hasActivity
          ? '$_profileViews vistas · $_totalMatches matches · $_pitchesReceived respuestas'
          : 'Coincidencias, vistas de perfil y oportunidades',
      actions: [
        if (unreadCount > 0)
          WebButton(label: 'Leer todas ($unreadCount)', filled: false, onTap: () => _markAllAsRead(myNotifs)),
      ],
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // ── Banner de visibilidad ──
          if (_insightsLoaded && !hasActivity && !_bannerDismissed) _webVisibilityBanner(context),
          // ── Smart Digests ──
          ..._digests.map((d) => _webDigestCard(context, d)),
          // ── Grid de Alert Cards ──
          if (showDemo)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: MployaTheme.brandAccent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.sparkles, size: 13, color: MployaTheme.brandAccent),
                        const SizedBox(width: 5),
                        Text('Vista previa', style: TextStyle(color: MployaTheme.brandAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Así se verán tus alertas cuando tengas actividad',
                      style: TextStyle(color: context.textTertiary, fontSize: 13)),
                ],
              ),
            ),
          WebGrid(
            children: displayCards.map((card) => _AlertCardWidget(data: card)).toList(),
          ),
        ],
      ),
    );
  }

  /// Banner de visibilidad rediseñado con gradient y CTA prominente
  Widget _webVisibilityBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFB923C)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(CupertinoIcons.rocket_fill, color: CupertinoColors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aumentá tu visibilidad',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
                  const SizedBox(height: 3),
                  Text('Completá tu perfil y grabá un video pitch para destacarte ante los reclutadores.',
                      style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            WebButton(label: 'Grabar Video Pitch', onTap: () => Navigator.of(context).maybePop()),
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

  /// Demo alert cards para cuando no hay notificaciones reales
  List<_AlertCardData> _demoAlertCards() {
    return [
      _AlertCardData(
        type: NotificationType.jobAlert,
        cardKind: _AlertKind.talentMatch,
        title: 'Senior UX Lead',
        name: 'María López',
        headline: 'HR Manager',
        companyName: 'Google',
        compatibilityScore: 0.87,
        skillTags: ['Figma', 'Sketch', 'Research', 'UX', 'Strategy'],
        timeAgo: 'Hace 2h',
      ),
      _AlertCardData(
        type: NotificationType.profileView,
        cardKind: _AlertKind.premiumView,
        title: 'Vista de perfil',
        name: 'Sarah J.',
        headline: 'Senior Recruiter',
        companyName: 'Google',
        timeAgo: 'Hace 1 h',
      ),
      _AlertCardData(
        type: NotificationType.like,
        cardKind: _AlertKind.marketInfo,
        title: 'Salarios de UX en auge',
        subtitle: 'El mercado UX creció 23% en LatAm. Los salarios promedio subieron a USD 4.500/mes.',
        timeAgo: 'Hace 3h',
      ),
      _AlertCardData(
        type: NotificationType.like,
        cardKind: _AlertKind.marketInfo,
        title: 'Demanda de Flutter +40%',
        subtitle: 'Las búsquedas de desarrolladores Flutter aumentaron significativamente este trimestre.',
        timeAgo: 'Hace 5h',
      ),
      _AlertCardData(
        type: NotificationType.connection,
        cardKind: _AlertKind.connectionRequest,
        title: 'Solicitud de conexión',
        name: 'Carlos M.',
        headline: 'Tech Lead en Mercado Libre',
        timeAgo: 'Hace 30 min',
      ),
      _AlertCardData(
        type: NotificationType.connection,
        cardKind: _AlertKind.connectionRequest,
        title: 'Solicitud de conexión',
        name: 'Ana R.',
        headline: 'Product Designer en Globant',
        timeAgo: 'Hace 45 min',
      ),
    ];
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

// ─────────────────────────────────────────────────────────────────────────────
// Alert Card Data Model & Types
// ─────────────────────────────────────────────────────────────────────────────

enum _AlertKind { talentMatch, premiumView, marketInfo, connectionRequest, generic }

class _AlertCardData {
  final NotificationType type;
  final _AlertKind cardKind;
  final String title;
  final String? subtitle;
  final String? name;
  final String? headline;
  final String? companyName;
  final String? avatarUrl;
  final String timeAgo;
  final bool isRead;
  final double? compatibilityScore;
  final List<String>? skillTags;
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  _AlertCardData({
    required this.type,
    _AlertKind? cardKind,
    required this.title,
    this.subtitle,
    this.name,
    this.headline,
    this.companyName,
    this.avatarUrl,
    this.timeAgo = '',
    this.isRead = false,
    this.compatibilityScore,
    this.skillTags,
    this.onTap,
    this.onAccept,
    this.onReject,
  }) : cardKind = cardKind ?? _inferKind(type);

  static _AlertKind _inferKind(NotificationType type) {
    switch (type) {
      case NotificationType.jobAlert:
        return _AlertKind.talentMatch;
      case NotificationType.profileView:
        return _AlertKind.premiumView;
      case NotificationType.connection:
        return _AlertKind.connectionRequest;
      default:
        return _AlertKind.generic;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alert Card Widget — renders each card type with proper visuals
// ─────────────────────────────────────────────────────────────────────────────

class _AlertCardWidget extends StatelessWidget {
  final _AlertCardData data;
  const _AlertCardWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    switch (data.cardKind) {
      case _AlertKind.talentMatch:
        return _buildTalentMatchCard(context);
      case _AlertKind.premiumView:
        return _buildPremiumViewCard(context);
      case _AlertKind.marketInfo:
        return _buildMarketInfoCard(context);
      case _AlertKind.connectionRequest:
        return _buildConnectionCard(context);
      case _AlertKind.generic:
        return _buildGenericCard(context);
    }
  }

  // ── Coincidencia de Talento ──
  Widget _buildTalentMatchCard(BuildContext context) {
    return WebCard(
      onTap: data.onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('COINCIDENCIA DE TALENTO',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: MployaTheme.brandAccent, letterSpacing: 0.8)),
          const SizedBox(height: 14),
          Row(
            children: [
              _avatar(data.name, data.avatarUrl, 52),
              const SizedBox(width: 12),
              if (data.companyName != null)
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(data.companyName![0], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(data.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary)),
          const SizedBox(height: 14),
          Text('Skills compatibilidad', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondary)),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                data.skillTags?.length ?? 5,
                (i) {
                  final heights = [0.85, 0.45, 0.65, 0.90, 0.55];
                  final h = i < heights.length ? heights[i] : 0.5;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        height: 48 * h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [MployaTheme.brandAccent.withValues(alpha: 0.6), MployaTheme.brandAccent],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (data.skillTags != null)
            Row(
              children: data.skillTags!.map((t) => Expanded(
                    child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 8.5, color: context.textTertiary, fontWeight: FontWeight.w600)),
                  )).toList(),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: MployaTheme.brandAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Ver Coincidencia', textAlign: TextAlign.center,
                  style: TextStyle(color: CupertinoColors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Vista de Perfil Premium ──
  Widget _buildPremiumViewCard(BuildContext context) {
    return WebCard(
      onTap: data.onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VISTA DE PERFIL PREMIUM',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF00838F), letterSpacing: 0.8)),
          const SizedBox(height: 14),
          Row(
            children: [
              _avatar(data.name, data.avatarUrl, 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.name ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary)),
                    Text(data.headline ?? '', style: TextStyle(fontSize: 12.5, color: context.textSecondary)),
                  ],
                ),
              ),
              if (data.companyName != null)
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(data.companyName![0], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: context.dividerColor.withValues(alpha: 0.4), height: 1),
          const SizedBox(height: 10),
          Text('Completá tu perfil: ${data.headline ?? "Recruiter"} con sempetaante aquí el argentino.',
              style: TextStyle(fontSize: 12.5, color: context.textSecondary, height: 1.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              Text('Visto ${data.timeAgo}', style: TextStyle(fontSize: 11.5, color: context.textTertiary, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Información de Mercado ──
  Widget _buildMarketInfoCard(BuildContext context) {
    return WebCard(
      onTap: data.onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INFORMACIÓN DE MERCADO',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF057642), letterSpacing: 0.8)),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF057642).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.chart_bar_fill, color: Color(0xFF057642), size: 18),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('G', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(data.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary)),
          if (data.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(data.subtitle!, style: TextStyle(fontSize: 12.5, color: context.textSecondary, height: 1.4)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: MployaTheme.brandAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Explorar Datos', textAlign: TextAlign.center,
                  style: TextStyle(color: CupertinoColors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Solicitud de Conexión ──
  Widget _buildConnectionCard(BuildContext context) {
    return WebCard(
      onTap: data.onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SOLICITUD DE CONEXIÓN',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF5F3DC4), letterSpacing: 0.8)),
          const SizedBox(height: 14),
          Center(child: _avatar(data.name, data.avatarUrl, 56)),
          const SizedBox(height: 10),
          Center(
            child: Text(data.name ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary)),
          ),
          if (data.headline != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(data.headline!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: MployaTheme.brandAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Aceptar', textAlign: TextAlign.center,
                  style: TextStyle(color: CupertinoColors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Genérica ──
  Widget _buildGenericCard(BuildContext context) {
    return WebCard(
      onTap: data.onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WebIconBadge(
                icon: _iconForKind(data.type),
                color: _colorForKind(data.type),
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(data.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(data.timeAgo, style: TextStyle(fontSize: 11.5, color: context.textTertiary)),
        ],
      ),
    );
  }

  // ── Helpers ──
  Widget _avatar(String? name, String? url, double size) {
    final initial = (name != null && name.isNotEmpty) ? name[0].toUpperCase() : '?';
    final colors = _gradientForInitial(initial);
    final fallback = Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: colors[0].withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Center(child: Text(initial, style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w800, fontSize: size * 0.38))),
    );
    if (url == null || url.isEmpty) return fallback;
    return ClipOval(
      child: SizedBox(
        width: size, height: size,
        child: Image.network(
          url,
          width: size, height: size,
          fit: BoxFit.cover,
          webHtmlElementStrategy: kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }

  List<Color> _gradientForInitial(String initial) {
    switch (initial) {
      case 'M': return [const Color(0xFFE91E63), const Color(0xFFFF6090)];
      case 'S': return [const Color(0xFF00838F), const Color(0xFF4DD0E1)];
      case 'C': return [const Color(0xFF5F3DC4), const Color(0xFF9775FA)];
      case 'A': return [const Color(0xFF057642), const Color(0xFF38D9A9)];
      default:  return [MployaTheme.brandAccent, const Color(0xFFFB923C)];
    }
  }

  IconData _iconForKind(NotificationType type) {
    switch (type) {
      case NotificationType.like: return CupertinoIcons.hand_thumbsup_fill;
      case NotificationType.comment: return CupertinoIcons.chat_bubble_fill;
      case NotificationType.connection: return CupertinoIcons.person_add_solid;
      case NotificationType.jobAlert: return CupertinoIcons.briefcase_fill;
      case NotificationType.profileView: return CupertinoIcons.eye_fill;
      case NotificationType.mention: return CupertinoIcons.at;
    }
  }

  Color _colorForKind(NotificationType type) {
    switch (type) {
      case NotificationType.like: return MployaTheme.brandAccent;
      case NotificationType.comment: return const Color(0xFF057642);
      case NotificationType.connection: return const Color(0xFF5F3DC4);
      case NotificationType.jobAlert: return NexTheme.brandAccent;
      case NotificationType.profileView: return const Color(0xFF00838F);
      case NotificationType.mention: return const Color(0xFFC2185B);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile Alert Card — compact card for 2-column grid
// ─────────────────────────────────────────────────────────────────────────────

class _MobileAlertCard extends StatelessWidget {
  final _AlertCardData data;
  const _MobileAlertCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = _cardColor();
    final label = _cardLabel();
    final icon = _cardIcon();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark ? NexTheme.darkCard : CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: context.isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header badge ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
          ),
          const SizedBox(height: 10),

          // ── Icon / Avatar ──
          Row(
            children: [
              if (data.name != null && data.name!.isNotEmpty)
                _buildAvatar(data.name, data.avatarUrl, 36)
              else
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
              if (data.companyName != null) ...[
                const SizedBox(width: 6),
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(data.companyName![0], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // ── Title ──
          Text(
            data.cardKind == _AlertKind.connectionRequest ? (data.name ?? data.title) : data.title,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textPrimary, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // ── Subtitle ──
          if (data.headline != null || data.subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                data.subtitle ?? data.headline ?? '',
                style: TextStyle(fontSize: 10.5, color: context.textSecondary, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          const SizedBox(height: 10),

          // ── CTA Buttons ──
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: data.onTap ?? data.onAccept,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: MployaTheme.brandAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_ctaLabel(), textAlign: TextAlign.center,
                        style: const TextStyle(color: CupertinoColors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              if (data.cardKind == _AlertKind.talentMatch) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
                    decoration: BoxDecoration(
                      color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Guardar', style: TextStyle(color: context.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? name, String? url, double size) {
    final initial = (name != null && name.isNotEmpty) ? name[0].toUpperCase() : '?';
    final colors = _gradientColors(initial);
    final fallback = Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(child: Text(initial, style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w800, fontSize: size * 0.38))),
    );
    if (url == null || url.isEmpty) return fallback;
    return ClipOval(
      child: SizedBox(
        width: size, height: size,
        child: Image.network(url, width: size, height: size, fit: BoxFit.cover, webHtmlElementStrategy: kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never, errorBuilder: (_, __, ___) => fallback),
      ),
    );
  }

  List<Color> _gradientColors(String initial) {
    switch (initial) {
      case 'M': return [const Color(0xFFE91E63), const Color(0xFFFF6090)];
      case 'S': return [const Color(0xFF00838F), const Color(0xFF4DD0E1)];
      case 'C': return [const Color(0xFF5F3DC4), const Color(0xFF9775FA)];
      case 'A': return [const Color(0xFF057642), const Color(0xFF38D9A9)];
      default:  return [MployaTheme.brandAccent, const Color(0xFFFB923C)];
    }
  }

  Color _cardColor() {
    switch (data.cardKind) {
      case _AlertKind.talentMatch: return MployaTheme.brandAccent;
      case _AlertKind.premiumView: return const Color(0xFF00838F);
      case _AlertKind.marketInfo: return const Color(0xFF057642);
      case _AlertKind.connectionRequest: return const Color(0xFF5F3DC4);
      case _AlertKind.generic: return MployaTheme.brandAccent;
    }
  }

  String _cardLabel() {
    switch (data.cardKind) {
      case _AlertKind.talentMatch: return 'NUEVO MATCH';
      case _AlertKind.premiumView: return 'VISTA PREMIUM';
      case _AlertKind.marketInfo: return 'INFO MERCADO';
      case _AlertKind.connectionRequest: return 'CONEXIÓN';
      case _AlertKind.generic: return 'ALERTA';
    }
  }

  IconData _cardIcon() {
    switch (data.cardKind) {
      case _AlertKind.talentMatch: return CupertinoIcons.briefcase_fill;
      case _AlertKind.premiumView: return CupertinoIcons.eye_fill;
      case _AlertKind.marketInfo: return CupertinoIcons.chart_bar_fill;
      case _AlertKind.connectionRequest: return CupertinoIcons.person_add_solid;
      case _AlertKind.generic: return CupertinoIcons.bell_fill;
    }
  }

  String _ctaLabel() {
    switch (data.cardKind) {
      case _AlertKind.talentMatch: return 'Ver Detalles';
      case _AlertKind.premiumView: return 'Ver Perfil';
      case _AlertKind.marketInfo: return 'Explorar Datos';
      case _AlertKind.connectionRequest: return 'Aceptar';
      case _AlertKind.generic: return 'Ver';
    }
  }
}
