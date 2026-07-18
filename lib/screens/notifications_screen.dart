import 'dart:math';
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

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> with TickerProviderStateMixin {
  // ── IA Insights Data ──
  int _profileViews = 0;
  int _totalMatches = 0;
  int _pitchesReceived = 0;
  bool _insightsLoaded = false;
  List<SmartNotification> _digests = [];
  bool _bannerDismissed = false;
  int _selectedCandidateIndex = 0;
  int _activeMobileTab = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    _loadInsights();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
    if (isWebWide(context)) {
      return _buildWeb(context);
    }
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E293B),
            elevation: 0,
            title: const Text(
              'Notificaciones',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tip Banner
                if (!_bannerDismissed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.lightbulb_fill, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            "Completá tu perfil y grabá un video pitch.",
                            style: TextStyle(color: Color(0xFF92400E), fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _bannerDismissed = true),
                          child: const Icon(CupertinoIcons.xmark, color: Color(0xFF92400E), size: 14),
                        ),
                      ],
                    ),
                  ),

                // Career Quantum Explorer Header Card
                const Text(
                  "Career Quantum Explorer",
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10),

                // Selected Candidate Details Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF475569).withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: NetworkImage("https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&h=100&fit=crop"),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -2, right: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF97316),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text("10K", style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Gale / Senior Engineering Lead",
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "(Latinaics)",
                              style: TextStyle(color: Color(0xFFF97316), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Tab Selector
                Row(
                  children: [
                    _buildTabButton("Quantum", 0),
                    const SizedBox(width: 6),
                    _buildTabButton("Mobility", 1),
                    const SizedBox(width: 6),
                    _buildTabButton("Suggestions", 2),
                  ],
                ),

                const SizedBox(height: 16),

                // Tab Contents
                if (_activeMobileTab == 0) ...[
                  // Quantum Nexus & Radar skills chart
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: QuantumNexusPainter(animationValue: _animationController.value),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text("Satinunics Skills", style: TextStyle(color: Color(0xFF1E293B), fontSize: 12, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        SizedBox(
                          width: 44, height: 44,
                          child: CustomPaint(
                            painter: RadarChartPainter(values: const [0.8, 0.75, 0.9, 0.65, 0.85, 0.7], labels: const []),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text("98%", style: TextStyle(color: Color(0xFFC2410C), fontSize: 14, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ] else if (_activeMobileTab == 1) ...[
                  // Mobility map
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Global Talent Mobility Map", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text("High demand detected in Santiago, Chile for Senior DevOps.", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 180,
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: TalentMobilityMapPainter(animationValue: _animationController.value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Network suggestions & Impact Score
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("YOUR GLOBAL IMPACT SCORE", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 150,
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: GlobalImpactScorePainter(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("NETWORK SUGGESTIONS", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        ..._suggestions.take(3).map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: DecorationImage(image: NetworkImage(s["avatar"]!), fit: BoxFit.cover),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(s["name"]!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 4),
                              Text(s["match"]!, style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF97316),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text("Conectar", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )).toList(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabButton(String text, int index) {
    final isSelected = _activeMobileTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeMobileTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF97316) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF475569).withOpacity(0.3)),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }


  // ── Layout web — Cards Grid ────────────────────────────────────────────────
  final List<Map<String, String>> _suggestions = const [
    {
      "name": "James Ehon",
      "match": "98%",
      "title": "Matching",
      "sub": "Skill stong",
      "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop"
    },
    {
      "name": "Poriard Threa",
      "match": "96%",
      "title": "Matching",
      "sub": "Skill stong",
      "avatar": "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop"
    },
    {
      "name": "Ronnad Jones",
      "match": "93%",
      "title": "Matching",
      "sub": "Skill stong",
      "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop"
    },
    {
      "name": "Partsla Sehan",
      "match": "58%",
      "title": "Matching",
      "sub": "Skill stong",
      "avatar": "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop"
    },
    {
      "name": "Harlard Staney",
      "match": "85%",
      "title": "Matching",
      "sub": "Skill stong",
      "avatar": "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop"
    },
  ];

  Widget _buildWeb(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return WebPage(
          title: 'Notificaciones',
          subtitle: 'Alertas y panel de control del Quantum Nexus',
          child: Container(
            width: double.infinity,
            height: 980,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tip Banner
                if (!_bannerDismissed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.lightbulb_fill, color: Color(0xFFD97706), size: 22),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            "Completá tu perfil y grabá un video pitch para aumentar tu visibilidad.",
                            style: TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _bannerDismissed = true),
                          child: const Icon(CupertinoIcons.xmark, color: Color(0xFF92400E), size: 18),
                        ),
                      ],
                    ),
                  ),

                // Main Dashboard Body
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Area: Quantum Nexus Graph & Mobility Map (flex 3.2)
                      Expanded(
                        flex: 32,
                        child: Stack(
                          children: [
                            // Background Canvas for Quantum Nexus Graph
                            Positioned.fill(
                              child: CustomPaint(
                                painter: QuantumNexusPainter(
                                  animationValue: _animationController.value,
                                ),
                              ),
                            ),

                            // Overlay: Profile & Skill Cards (Top Left)
                            Positioned(
                              top: 15,
                              left: 15,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Career Quantum Explorer",
                                    style: TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      // Profile Card
                                      Container(
                                        width: 230,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9).withOpacity(0.95),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.04),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    image: DecorationImage(
                                                      image: NetworkImage("https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&h=100&fit=crop"),
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  bottom: -2,
                                                  right: -2,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF97316),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      "10K",
                                                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 12),
                                            const Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "Gale / Senior Engineering Lead",
                                                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  SizedBox(height: 3),
                                                  Text(
                                                    "(Latinaics)",
                                                    style: TextStyle(color: Color(0xFFF97316), fontSize: 10, fontWeight: FontWeight.w800),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Skills Match Radar Card
                                      Container(
                                        width: 240,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.04),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    "Satinunics",
                                                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  SizedBox(
                                                    width: 72,
                                                    height: 72,
                                                    child: CustomPaint(
                                                      painter: RadarChartPainter(
                                                        values: const [0.8, 0.75, 0.9, 0.65, 0.85, 0.7],
                                                        labels: const [],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFF7ED),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFFFEDD5)),
                                              ),
                                              child: const Text(
                                                "98%",
                                                style: TextStyle(color: Color(0xFFC2410C), fontSize: 15, fontWeight: FontWeight.w900),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: 484,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC).withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Text(
                                      "CURATED PREMIUM MATCH\n\nA new role with a skill factor has been curated for your ore-cur view. View detailed profile analysis.",
                                      style: TextStyle(color: Color(0xFF475569), fontSize: 10, height: 1.4, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Overlay: Global Talent Mobility Alert Map (Bottom Left)
                            Positioned(
                              bottom: 15,
                              left: 15,
                              child: Container(
                                width: 340,
                                height: 290,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC).withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Global Talent mobility alert",
                                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      "High demand detected in Santiago, Chile for Senior DevOps with LATAM expertise.",
                                      style: TextStyle(color: Color(0xFF475569), fontSize: 10, height: 1.4),
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          // South America custom vector map
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: CustomPaint(
                                                size: Size.infinite,
                                                painter: TalentMobilityMapPainter(
                                                  animationValue: _animationController.value,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Map Legend Scale
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Text("High", style: TextStyle(color: Color(0xFFEF4444), fontSize: 8, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 5),
                                              Container(
                                                width: 8,
                                                height: 110,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(4),
                                                  gradient: const LinearGradient(
                                                    colors: [Color(0xFFEF4444), Color(0xFFF97316), Color(0xFFCBD5E1)],
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              const Text("Low", style: TextStyle(color: Color(0xFF64748B), fontSize: 8, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Orbital Stage indicator overlay (Bottom center-ish)
                            Positioned(
                              bottom: 140,
                              right: 210,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF97316),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  "Stage 3",
                                  style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 28),

                      // Right Area: Impact Score & Network suggestions (flex 1.0)
                      Expanded(
                        flex: 10,
                        child: Column(
                          children: [
                            // Card 1: YOUR GLOBAL IMPACT SCORE
                            Container(
                              height: 310,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "YOUR GLOBAL IMPACT SCORE",
                                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: CustomPaint(
                                      size: Size.infinite,
                                      painter: GlobalImpactScorePainter(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: const Text(
                                      "Interactive Contribution",
                                      style: TextStyle(color: Color(0xFF334155), fontSize: 11.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Card 2: IMMEDIATE NETWORK SUGGESTIONS
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "IMMEDIATE NETWORK SUGGESTIONS",
                                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                    ),
                                    const SizedBox(height: 12),

                                    // Suggestions list
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: _suggestions.length,
                                        itemBuilder: (context, index) {
                                          final s = _suggestions[index];
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 10.0),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    image: DecorationImage(image: NetworkImage(s["avatar"]!), fit: BoxFit.cover),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        s["name"]!,
                                                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold),
                                                      ),
                                                      Text(
                                                        "${s["title"]!} - ${s["sub"]!}",
                                                        style: const TextStyle(color: Color(0xFF475569), fontSize: 9.5),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  s["match"]!,
                                                  style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(width: 10),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF97316),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    "Conectar",
                                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),

                                    // Video Prep widgets
                                    Container(
                                      height: 70,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 54,
                                            height: 54,
                                            decoration: BoxDecoration(
                                              color: Colors.black26,
                                              borderRadius: BorderRadius.circular(8),
                                              image: const DecorationImage(
                                                image: NetworkImage("https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=100&h=100&fit=crop"),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 16),
                                          ),
                                          const SizedBox(width: 10),
                                          const Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  "Quantum Senior Engineering",
                                                  style: TextStyle(color: Color(0xFF0F172A), fontSize: 10, fontWeight: FontWeight.bold),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 3),
                                                Text(
                                                  "Learn more",
                                                  style: TextStyle(color: Color(0xFFF97316), fontSize: 9, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

// ── Models and Custom widgets for the Premium Presentation Layout ──

class AlertCandidate {
  final String name;
  final String role;
  final String location;
  final String avatarUrl;
  final String views;
  final List<String> tags;
  final List<double> radarValues;
  final List<String> radarLabels;
  final List<Map<String, String>> timeline;
  final String matchPercentage;

  const AlertCandidate({
    required this.name,
    required this.role,
    required this.location,
    required this.avatarUrl,
    required this.views,
    required this.tags,
    required this.radarValues,
    required this.radarLabels,
    required this.timeline,
    required this.matchPercentage,
  });
}

final List<AlertCandidate> _alertCandidates = [
  const AlertCandidate(
    name: "Galo",
    role: "Senior Engineering Lead",
    location: "Match mator",
    avatarUrl: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=120&h=120&fit=crop",
    views: "10K",
    tags: ["LATINAMCS", "SCALABLE SYSTEMS", "GLOBAL SCOPE"],
    radarValues: [0.90, 0.85, 0.75, 0.80, 0.85],
    radarLabels: ["System Design", "Coding", "Velocity", "Teamwork", "Security"],
    timeline: [
      {"year": "2015", "title": "Standing", "desc": "Started career at MercadoLibre leading core platform services."},
      {"year": "2020", "title": "Experience", "desc": "Architected high-throughput infrastructure at Globant."},
      {"year": "2025", "title": "Education", "desc": "Stanford MSc in Distributed Systems & AI Cloud architectures."},
      {"year": "2026", "title": "Digestive Timeline", "desc": "Liderando plataforma de escala masiva en Mploya."},
    ],
    matchPercentage: "15",
  ),
  const AlertCandidate(
    name: "mploya",
    role: "Ingeniero de Software Senior",
    location: "Buenos Aires, AR",
    avatarUrl: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=120&h=120&fit=crop",
    views: "1.2K",
    tags: ["FLUTTER", "DART", "SUPABASE", "RIVERPOD"],
    radarValues: [0.75, 0.95, 0.90, 0.80, 0.70],
    radarLabels: ["Frontend", "Coding", "Velocity", "API Design", "Testing"],
    timeline: [
      {"year": "2018", "title": "Junior Dev", "desc": "Construcción de apps móviles nativas en Android."},
      {"year": "2021", "title": "Flutter Dev", "desc": "Migración completa de plataformas a Flutter Web."},
      {"year": "2025", "title": "Senior Lead", "desc": "Liderando la arquitectura móvil multiplataforma."},
    ],
    matchPercentage: "16",
  ),
  const AlertCandidate(
    name: "Questica Resas",
    role: "Senior Product Designer",
    location: "San Pablo, BR",
    avatarUrl: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120&h=120&fit=crop",
    views: "2.3K",
    tags: ["FIGMA", "DESIGN SYSTEMS", "UX RESEARCH"],
    radarValues: [0.95, 0.70, 0.85, 0.90, 0.95],
    radarLabels: ["UX Research", "UI Craft", "Systems", "Product", "User Flow"],
    timeline: [
      {"year": "2017", "title": "UI Designer", "desc": "Creación de interfaces y micro-interacciones."},
      {"year": "2022", "title": "Product Lead", "desc": "Rediseño completo del flujo B2B SaaS corporativo."},
      {"year": "2026", "title": "UX Principal", "desc": "Estrategia de diseño global centrado en el usuario."},
    ],
    matchPercentage: "18",
  ),
  const AlertCandidate(
    name: "Sulo",
    role: "Senior Recruiter Lead",
    location: "Bogotá, CO",
    avatarUrl: "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=120&h=120&fit=crop",
    views: "1.5K",
    tags: ["TALENT ACQUISITION", "SOURCING", "LATAM TECH"],
    radarValues: [0.60, 0.50, 0.85, 0.95, 0.80],
    radarLabels: ["Sourcing", "Interviewing", "Velocity", "HR Tech", "Negotiation"],
    timeline: [
      {"year": "2016", "title": "HR Associate", "desc": "Reclutamiento de perfiles IT junior en LATAM."},
      {"year": "2021", "title": "Talent Lead", "desc": "Escalabilidad de equipos de ingeniería de 50 a 200 devs."},
      {"year": "2026", "title": "Director", "desc": "Estrategia integral de contratación y marca empleadora."},
    ],
    matchPercentage: "14",
  ),
];

class RadarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;

  RadarChartPainter({required this.values, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.7;
    final int count = values.length;

    final paintLine = Paint()
      ..color = const Color(0xFFE2E8F0).withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final paintGrid = Paint()
      ..color = const Color(0xFFCBD5E1).withOpacity(0.2)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final paintFill = Paint()
      ..color = const Color(0xFFF97316).withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = const Color(0xFFF97316)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Concentric polygons
    for (int step = 1; step <= 3; step++) {
      final r = radius * (step / 3);
      final path = Path();
      for (int i = 0; i < count; i++) {
        final angle = (i * 2 * pi / count) - pi / 2;
        final pt = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, paintGrid);
    }

    // Axes
    for (int i = 0; i < count; i++) {
      final angle = (i * 2 * pi / count) - pi / 2;
      final pt = Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
      canvas.drawLine(center, pt, paintLine);

      // Draw axis labels
      if (labels.isNotEmpty && i < labels.length) {
        final labelAngle = angle;
        // Place labels slightly outside the radius
        final labelPt = Offset(
          center.dx + (radius + 12) * cos(labelAngle),
          center.dy + (radius + 6) * sin(labelAngle),
        );
        final textPainter = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 7, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        
        textPainter.paint(
          canvas,
          Offset(labelPt.dx - textPainter.width / 2, labelPt.dy - textPainter.height / 2),
        );
      }
    }

    // Value shape
    final pathValue = Path();
    for (int i = 0; i < count; i++) {
      final angle = (i * 2 * pi / count) - pi / 2;
      final val = values[i].clamp(0.0, 1.0);
      final pt = Offset(center.dx + radius * val * cos(angle), center.dy + radius * val * sin(angle));
      if (i == 0) {
        pathValue.moveTo(pt.dx, pt.dy);
      } else {
        pathValue.lineTo(pt.dx, pt.dy);
      }
    }
    pathValue.close();
    canvas.drawPath(pathValue, paintFill);
    canvas.drawPath(pathValue, paintBorder);
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) => true;
}

class QuantumNexusPainter extends CustomPainter {
  final double animationValue;
  QuantumNexusPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.52, size.height * 0.48);
    final paint = Paint()
      ..color = const Color(0xFFFDBA74).withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // 1. Draw tilted orbits (ellipses)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.12);
    canvas.translate(-center.dx, -center.dy);
    
    final rect1 = Rect.fromCenter(center: center, width: size.width * 0.88, height: size.height * 0.72);
    final rect2 = Rect.fromCenter(center: center, width: size.width * 0.65, height: size.height * 0.54);
    final rect3 = Rect.fromCenter(center: center, width: size.width * 0.42, height: size.height * 0.35);
    
    canvas.drawOval(rect1, paint);
    canvas.drawOval(rect2, paint..color = const Color(0xFF94A3B8).withOpacity(0.2));
    canvas.drawOval(rect3, paint..color = const Color(0xFF94A3B8).withOpacity(0.15));
    canvas.restore();

    // 2. Define wider satellite positions
    final satellitePositions = [
      Offset(center.dx - 180, center.dy - 70), // Company 3
      Offset(center.dx - 80, center.dy - 120), // Jobs
      Offset(center.dx + 50, center.dy - 130), // Company 2
      Offset(center.dx + 170, center.dy - 50), // Company
      Offset(center.dx - 150, center.dy + 65), // Company
      Offset(center.dx - 50, center.dy + 110), // Skills
      Offset(center.dx + 80, center.dy + 100), // Staffs
      Offset(center.dx + 180, center.dy + 50), // Senior Company
    ];

    // Connection curved lines
    final linePaint = Paint()
      ..color = const Color(0xFFF97316).withOpacity(0.22)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var pos in satellitePositions) {
      final path = Path();
      path.moveTo(center.dx, center.dy);
      final ctrlX = (center.dx + pos.dx) / 2 + 12 * sin(animationValue * 2 * pi);
      final ctrlY = (center.dy + pos.dy) / 2 - 12 * cos(animationValue * 2 * pi);
      path.quadraticBezierTo(ctrlX, ctrlY, pos.dx, pos.dy);
      canvas.drawPath(path, linePaint);

      // Moving particle along the connection line
      final t = (animationValue + pos.hashCode % 10 / 10.0) % 1.0;
      final dotX = (1 - t) * (1 - t) * center.dx + 2 * (1 - t) * t * ctrlX + t * t * pos.dx;
      final dotY = (1 - t) * (1 - t) * center.dy + 2 * (1 - t) * t * ctrlY + t * t * pos.dy;
      canvas.drawCircle(Offset(dotX, dotY), 3.0, Paint()..color = const Color(0xFFF97316));
    }

    // 3. Draw Center Node (Dark orange fill with text on light theme)
    final centerGlow = Paint()
      ..color = const Color(0xFFFFF7ED)
      ..style = PaintingStyle.fill;
    
    final glowRadius = 42.0 + 3.0 * sin(animationValue * 2 * pi);
    canvas.drawCircle(center, glowRadius, Paint()..color = const Color(0xFFF97316).withOpacity(0.2));
    canvas.drawCircle(center, 37.0, Paint()..color = const Color(0xFFF97316));
    canvas.drawCircle(center, 33.5, centerGlow);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.text = const TextSpan(
      children: [
        TextSpan(
          text: "QUANTUM\n",
          style: TextStyle(color: Color(0xFF0F172A), fontSize: 8.5, fontWeight: FontWeight.bold, height: 1.1),
        ),
        TextSpan(
          text: "NEXUS",
          style: TextStyle(color: Color(0xFFC2410C), fontSize: 9.5, fontWeight: FontWeight.w900),
        ),
      ],
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));

    // 4. Draw satellite nodes
    final nodeLabels = [
      "COMPANY 3",
      "JOBS",
      "COMPANY 2",
      "COMPANY",
      "COMPANY",
      "SKILLS",
      "STAFFS",
      "SENIOR COMPANY",
    ];

    for (int i = 0; i < satellitePositions.length; i++) {
      final pos = satellitePositions[i];
      final label = nodeLabels[i];

      canvas.drawCircle(pos, 16.0, Paint()..color = const Color(0xFFF97316).withOpacity(0.12));
      canvas.drawCircle(pos, 12.0, Paint()..color = const Color(0xFFCBD5E1));
      canvas.drawCircle(pos, 10.5, centerGlow);

      final iconPaint = Paint()
        ..color = const Color(0xFFF97316)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      
      if (label == "JOBS" || label == "SKILLS") {
        canvas.drawCircle(pos, 3.0, iconPaint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: pos, width: 6, height: 6), iconPaint);
      }

      final labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Color(0xFF334155), fontSize: 8.5, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(pos.dx - labelPainter.width / 2, pos.dy - 18));
    }
  }

  @override
  bool shouldRepaint(covariant QuantumNexusPainter oldDelegate) => true;
}

class TalentMobilityMapPainter extends CustomPainter {
  final double animationValue;
  TalentMobilityMapPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Stylized South America Map
    final path = Path();
    path.moveTo(size.width * 0.28, size.height * 0.15);
    path.quadraticBezierTo(size.width * 0.45, size.height * 0.08, size.width * 0.65, size.height * 0.12);
    path.quadraticBezierTo(size.width * 0.90, size.height * 0.25, size.width * 0.75, size.height * 0.52);
    path.quadraticBezierTo(size.width * 0.60, size.height * 0.78, size.width * 0.52, size.height * 0.86);
    path.lineTo(size.width * 0.48, size.height * 0.96);
    path.lineTo(size.width * 0.45, size.height * 0.96);
    path.quadraticBezierTo(size.width * 0.35, size.height * 0.68, size.width * 0.26, size.height * 0.48);
    path.quadraticBezierTo(size.width * 0.18, size.height * 0.26, size.width * 0.28, size.height * 0.15);
    path.close();

    final mapPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, mapPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);

    // Active flight paths/flows to Santiago
    final santiago = Offset(size.width * 0.38, size.height * 0.78);
    final buenosAires = Offset(size.width * 0.52, size.height * 0.80);
    final bogota = Offset(size.width * 0.32, size.height * 0.24);

    final flowPaint = Paint()
      ..color = const Color(0xFFF97316).withOpacity(0.65)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    void drawFlow(Offset from, Offset to) {
      final flowPath = Path();
      flowPath.moveTo(from.dx, from.dy);
      final ctrlX = (from.dx + to.dx) / 2 - 15;
      final ctrlY = (from.dy + to.dy) / 2 - 20;
      flowPath.quadraticBezierTo(ctrlX, ctrlY, to.dx, to.dy);
      canvas.drawPath(flowPath, flowPaint);

      final t = (animationValue + from.hashCode % 10 / 10.0) % 1.0;
      final dotX = (1 - t) * (1 - t) * from.dx + 2 * (1 - t) * t * ctrlX + t * t * to.dx;
      final dotY = (1 - t) * (1 - t) * from.dy + 2 * (1 - t) * t * ctrlY + t * t * to.dy;
      canvas.drawCircle(Offset(dotX, dotY), 2.5, Paint()..color = const Color(0xFFEF4444));
    }

    drawFlow(buenosAires, santiago);
    drawFlow(bogota, santiago);

    // Pin markers
    canvas.drawCircle(santiago, 5.0, Paint()..color = const Color(0xFFEF4444));
    canvas.drawCircle(santiago, 9.0, Paint()..color = const Color(0xFFEF4444).withOpacity(0.35)..style = PaintingStyle.stroke..strokeWidth = 1.8);
    
    canvas.drawCircle(buenosAires, 4.0, Paint()..color = const Color(0xFF64748B));
    canvas.drawCircle(bogota, 4.0, Paint()..color = const Color(0xFF64748B));
  }

  @override
  bool shouldRepaint(covariant TalentMobilityMapPainter oldDelegate) => true;
}

class GlobalImpactScorePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;

    final bgPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawCircle(center, radius * 0.66, bgPaint);
    canvas.drawCircle(center, radius * 0.33, bgPaint);

    // Cross axes
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), bgPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), bgPaint);

    // Blue Polygon (Flow Reach)
    final bluePoints = [
      Offset(center.dx, center.dy - radius * 0.75), // Top
      Offset(center.dx + radius * 0.4, center.dy), // Right
      Offset(center.dx, center.dy + radius * 0.55), // Bottom
      Offset(center.dx - radius * 0.65, center.dy), // Left
    ];

    // Orange Polygon (Career Reach)
    final orangePoints = [
      Offset(center.dx, center.dy - radius * 0.45), // Top
      Offset(center.dx + radius * 0.8, center.dy), // Right
      Offset(center.dx, center.dy + radius * 0.7), // Bottom
      Offset(center.dx - radius * 0.35, center.dy), // Left
    ];

    void drawPolygon(List<Offset> points, Color color) {
      final path = Path()..moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      path.close();

      canvas.drawPath(path, Paint()..color = color.withOpacity(0.22)..style = PaintingStyle.fill);
      canvas.drawPath(path, Paint()..color = color..strokeWidth = 2.0..style = PaintingStyle.stroke);
      
      for (var pt in points) {
        canvas.drawCircle(pt, 3.5, Paint()..color = color);
      }
    }

    drawPolygon(bluePoints, const Color(0xFF2563EB));
    drawPolygon(orangePoints, const Color(0xFFF97316));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
