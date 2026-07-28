import 'dart:math';
import '../utils/user_columns.dart';
import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import '../services/social_service.dart';
import '../services/error_handler.dart';
import '../services/smart_notification_service.dart';
import '../services/scheduling_service.dart';
import '../widgets/web_ui.dart';
import 'profile_screen.dart';
import 'ats_dashboard_screen.dart';
import 'scheduling_screen.dart';
import '../navigation/main_navigation.dart';

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
  // Filtro activo de la lista de alertas (all/candidates/interviews/connections)
  String _alertFilter = 'all';
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

  @override
  Widget build(BuildContext context) {
    if (isWebWide(context)) {
      return _buildWeb(context);
    }
    
    return _buildMobileAlerts(context);
  }

  // Alertas mobile — panel enmarcado con header, filtros y filas agrupadas por
  // tiempo. Con notificaciones reales las muestra; si no hay, muestra contenido
  // DEMO (intencional mientras no haya usuarios reales) para que se vea vivo.
  Widget _buildMobileAlerts(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
          children: [_alertsPanel(context, webMode: false)],
        ),
      ),
    );
  }

  // ── Panel enmarcado compartido móvil/web ──
  Widget _alertsPanel(BuildContext context, {required bool webMode}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: NotificationService.instance.notificationsStream,
      builder: (context, snapshot) {
        final notifs = snapshot.data ?? const <Map<String, dynamic>>[];
        final loading =
            snapshot.connectionState == ConnectionState.waiting && notifs.isEmpty;
        final useDemo = !loading && notifs.isEmpty;
        final realUnread = notifs.where((n) => n['is_read'] != true).length;
        final unread = useDemo ? 3 : realUnread;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9EEF4)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _panelHeader(unread, notifs, webMode: webMode, demo: useDemo),
              _panelFilters(),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CupertinoActivityIndicator()),
                )
              else
                ..._renderGrouped(useDemo ? _demoRows() : _realRows(notifs)),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Widget _panelHeader(int unread, List<Map<String, dynamic>> notifs,
      {required bool webMode, required bool demo}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEAF3FC), Color(0xFFF7FBFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(bottom: BorderSide(color: Color(0xFFE9EEF4))),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF185FA5), Color(0xFF378ADD)]),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(CupertinoIcons.bell_fill, size: 21, color: Colors.white),
              ),
              if (unread > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD85A30),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text('$unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!webMode)
                  const Text('Novedades',
                      style: TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                Text(unread > 0 ? 'Tenés $unread sin leer' : 'Estás al día',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3A6EA5))),
              ],
            ),
          ),
          if (unread > 0)
            GestureDetector(
              onTap: demo ? null : () => _markAllAsRead(notifs),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFCFE0F2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.checkmark_alt, size: 14, color: Color(0xFF185FA5)),
                    SizedBox(width: 4),
                    Text('Marcar leídas',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF185FA5))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _panelFilters() {
    const filters = <String, String>{
      'all': 'Todas',
      'candidates': 'Candidatos',
      'interviews': 'Entrevistas',
      'connections': 'Conexiones',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F3F7))),
      ),
      child: SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: filters.entries.map((e) {
            final active = _alertFilter == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _alertFilter = e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF185FA5) : const Color(0xFFF4F6F9),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: active ? const Color(0xFF185FA5) : const Color(0xFFE8ECF1)),
                  ),
                  child: Text(e.value,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : const Color(0xFF64748B))),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Inserta labels de grupo + divisores entre filas (mismo render para demo y real).
  List<Widget> _renderGrouped(List<({String group, String cat, Widget row})> items) {
    final visible = items.where((i) => _alertFilter == 'all' || i.cat == _alertFilter).toList();
    if (visible.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 44),
          child: Center(
            child: Text('Nada por acá con este filtro.',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          ),
        ),
      ];
    }
    final widgets = <Widget>[];
    String? current;
    var firstInGroup = true;
    for (final it in visible) {
      if (it.group != current) {
        current = it.group;
        firstInGroup = true;
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Text(it.group.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Color(0xFF9AA6B5))),
        ));
      }
      if (!firstInGroup) {
        widgets.add(const Divider(height: 1, thickness: 0.5, indent: 18, endIndent: 18, color: Color(0xFFF0F3F7)));
      }
      widgets.add(it.row);
      firstInGroup = false;
    }
    return widgets;
  }

  // Fila "glam": acento lateral en no leídas, avatar temático, título con badge de
  // match opcional, subtítulo con parte en azul, acciones inline y hora.
  Widget _glamRow({
    required Color color,
    IconData? icon,
    String? initials,
    bool circle = false,
    required String title,
    String? subtitle,
    String? linkText,
    String? matchPct,
    List<Widget>? actions,
    required String time,
    required bool unread,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: unread ? const Color(0xFFF6FAFE) : Colors.white,
          border: Border(
            left: BorderSide(color: unread ? color : Colors.transparent, width: 3),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: circle ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: circle ? null : BorderRadius.circular(12),
              ),
              child: initials != null
                  ? Center(
                      child: Text(initials,
                          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)))
                  : Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                      ),
                      if (matchPct != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE1F5EE), borderRadius: BorderRadius.circular(999)),
                          child: Text('$matchPct match',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F6E56))),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null || linkText != null) ...[
                    const SizedBox(height: 3),
                    Text.rich(TextSpan(
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.3),
                      children: [
                        if (subtitle != null) TextSpan(text: subtitle),
                        if (linkText != null)
                          TextSpan(
                              text: linkText,
                              style: const TextStyle(
                                  color: Color(0xFF185FA5), fontWeight: FontWeight.w600)),
                      ],
                    )),
                  ],
                  if (actions != null) ...[
                    const SizedBox(height: 10),
                    Row(children: actions),
                  ],
                  const SizedBox(height: 7),
                  Text(time, style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
            if (unread)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  // Contenido de muestra (mientras no haya notificaciones reales).
  List<({String group, String cat, Widget row})> _demoRows() {
    return [
      (
        group: 'Hoy',
        cat: 'candidates',
        row: _glamRow(
          color: const Color(0xFF639922),
          initials: 'ML',
          circle: true,
          title: 'María López',
          matchPct: '92%',
          subtitle: 'Se postuló a ',
          linkText: 'Senior UX Lead',
          time: 'Hace 20 min',
          unread: true,
          actions: [
            _miniBtn('Ver perfil', const Color(0xFF1C1C1E), Colors.white, () => currentMainTabNotifier.value = 2),
            const SizedBox(width: 8),
            _miniBtn('Guardar', const Color(0xFFF1F5F9), const Color(0xFF64748B), () {}),
          ],
        ),
      ),
      (
        group: 'Hoy',
        cat: 'interviews',
        row: _glamRow(
          color: const Color(0xFF534AB7),
          icon: CupertinoIcons.calendar,
          title: 'Entrevista confirmada',
          subtitle: 'Carlos M. · mañana 15:00 · videollamada',
          time: 'Hace 2 h',
          unread: true,
        ),
      ),
      (
        group: 'Hoy',
        cat: 'candidates',
        row: _glamRow(
          color: const Color(0xFFBA7517),
          icon: CupertinoIcons.flame_fill,
          title: 'Tu vacante está en llamas',
          subtitle: 'Senior UX Lead recibió 8 vistas nuevas hoy',
          time: 'Hace 4 h',
          unread: true,
        ),
      ),
      (
        group: 'Esta semana',
        cat: 'connections',
        row: _glamRow(
          color: const Color(0xFF185FA5),
          initials: 'AR',
          circle: true,
          title: 'Ana R. quiere conectar',
          subtitle: 'Product Designer en Globant',
          time: 'Lun',
          unread: false,
          actions: [
            _miniBtn('Aceptar', const Color(0xFF1C1C1E), Colors.white, () {}),
            const SizedBox(width: 8),
            _miniBtn('Rechazar', const Color(0xFFF1F5F9), const Color(0xFF64748B), () {}),
          ],
        ),
      ),
    ];
  }

  // Notificaciones reales → filas glam agrupadas por tiempo.
  List<({String group, String cat, Widget row})> _realRows(List<Map<String, dynamic>> notifs) {
    String catOf(String t) {
      if (t.startsWith('connection')) return 'connections';
      if (t.contains('interview') || t.contains('schedul')) return 'interviews';
      if (t.contains('job') || t == 'jobAlert' || t == 'profileView' || t.contains('application')) {
        return 'candidates';
      }
      return 'other';
    }

    String groupOf(String? iso) {
      final dt = DateTime.tryParse(iso ?? '')?.toLocal();
      if (dt == null) return 'Antes';
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) return 'Hoy';
      if (now.difference(dt).inDays < 7) return 'Esta semana';
      return 'Antes';
    }

    // Ordena por grupo (Hoy → Esta semana → Antes) para que _renderGrouped agrupe bien.
    const order = {'Hoy': 0, 'Esta semana': 1, 'Antes': 2};
    final sorted = [...notifs]..sort((a, b) {
        final ga = order[groupOf(a['created_at']?.toString())] ?? 3;
        final gb = order[groupOf(b['created_at']?.toString())] ?? 3;
        return ga.compareTo(gb);
      });

    return sorted.map((n) {
      final type = (n['type'] ?? '').toString();
      final isRead = n['is_read'] == true;
      final isConnection = type.startsWith('connection');
      // La tabla real usa title/body (el schema.sql del repo está desactualizado
      // y menciona `description`: no existe). Si el título viniera vacío, se cae
      // a uno legible según el tipo.
      final rawTitle = (n['title'] ?? '').toString();
      final rawBody = (n['body'] ?? '').toString();
      final title = rawTitle.isNotEmpty ? rawTitle : _titleForType(type);
      final subtitle = rawBody;
      return (
        group: groupOf(n['created_at']?.toString()),
        cat: catOf(type),
        row: _glamRow(
          color: _alertIconColor(type),
          icon: _alertIconData(type),
          circle: isConnection,
          title: title,
          subtitle: subtitle.isEmpty ? null : subtitle,
          time: _relativeTime(n['created_at']?.toString()),
          unread: !isRead,
          onTap: () => _markAsRead(n),
          actions: (isConnection && !isRead)
              ? [
                  _miniBtn('Aceptar', const Color(0xFF1C1C1E), Colors.white, () => _handleAccept(n)),
                  const SizedBox(width: 8),
                  _miniBtn('Rechazar', const Color(0xFFF1F5F9), const Color(0xFF64748B),
                      () => _handleReject(n)),
                ]
              : null,
        ),
      );
    }).toList();
  }

  /// Título legible para cada `type` de la tabla `notifications`
  /// Fallback para cuando la fila no trae `title`.
  String _titleForType(String type) {
    switch (type) {
      case 'connection':
      case 'connection_request':
        return 'Nueva solicitud de conexión';
      case 'connection_accepted':
        return 'Conexión aceptada';
      case 'message':
        return 'Mensaje nuevo';
      case 'like':
        return 'Le interesó tu perfil';
      case 'comment':
        return 'Nuevo comentario';
      case 'mention':
        return 'Te mencionaron';
      case 'profileView':
        return 'Vieron tu perfil';
      case 'jobAlert':
        return 'Vacante que te puede interesar';
      case 'job_application':
        return 'Nueva postulación';
      case 'interview':
      case 'interview_scheduled':
        return 'Entrevista agendada';
      case 'nexus':
        return 'Sugerencia de Nexus';
      default:
        return 'Novedad';
    }
  }

  Widget _miniBtn(String label, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
        child: Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
      ),
    );
  }

  IconData _alertIconData(String type) {
    switch (type) {
      case 'connection':
      case 'connection_request':
      case 'connection_accepted':
        return CupertinoIcons.person_2_fill;
      case 'message':
        return CupertinoIcons.chat_bubble_2_fill;
      case 'like':
        return CupertinoIcons.heart_fill;
      case 'jobAlert':
      case 'job_application':
        return CupertinoIcons.briefcase_fill;
      case 'nexus':
        return CupertinoIcons.sparkles;
      default:
        return CupertinoIcons.bell_fill;
    }
  }

  Color _alertIconColor(String type) {
    switch (type) {
      case 'connection':
      case 'connection_request':
      case 'connection_accepted':
        return const Color(0xFF3B82F6);
      case 'message':
        return const Color(0xFF10B981);
      case 'like':
        return const Color(0xFFEF4444);
      case 'jobAlert':
      case 'job_application':
        return const Color(0xFF185FA5);
      case 'nexus':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _relativeTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ── VIEJO layout mobile (mockup Quantum Nexus). Ya no se usa; se deja como
  //    referencia y para no romper los painters. No llamar. ──
  // ignore: unused_element
  Widget _deadOldMobileAlerts(BuildContext context) {
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
                                color: const Color(0xFF185FA5),
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
                              style: TextStyle(color: Color(0xFF185FA5), fontSize: 10, fontWeight: FontWeight.bold),
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
                                  color: const Color(0xFF185FA5),
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
            color: isSelected ? const Color(0xFF185FA5) : const Color(0xFF1E293B),
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
    // Columna centrada (maxWidth 620) — misma lección de ancho que Perfil/Feed:
    // en web ancha una lista tipo "columna" no se debe estirar a 1400px.
    return WebPage(
      title: 'Novedades',
      subtitle: 'Alertas y actividad de tu cuenta',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: _alertsPanel(context, webMode: true),
        ),
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
        final data = await _supabase.from('users').select(kUserColumns).eq('id', r['candidate_id']).maybeSingle();
        if (data != null && mounted) {
          Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: NexUser.fromJson(data))));
        }
      },
      child: WebCard(
        padding: const EdgeInsets.all(16),
        onTap: () async {
          final data = await _supabase.from('users').select(kUserColumns).eq('id', r['candidate_id']).maybeSingle();
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


// ─────────────────────────────────────────────────────────────────────────────
// Alert Card Widget — renders each card type with proper visuals
// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// Mobile Alert Card — compact card for 2-column grid
// ─────────────────────────────────────────────────────────────────────────────


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
      ..color = const Color(0xFF185FA5).withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = const Color(0xFF185FA5)
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
      ..color = const Color(0xFF85B7EB).withOpacity(0.25)
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
      ..color = const Color(0xFF185FA5).withOpacity(0.22)
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
      canvas.drawCircle(Offset(dotX, dotY), 3.0, Paint()..color = const Color(0xFF185FA5));
    }

    // 3. Draw Center Node (Dark orange fill with text on light theme)
    final centerGlow = Paint()
      ..color = const Color(0xFFE6F1FB)
      ..style = PaintingStyle.fill;
    
    final glowRadius = 42.0 + 3.0 * sin(animationValue * 2 * pi);
    canvas.drawCircle(center, glowRadius, Paint()..color = const Color(0xFF185FA5).withOpacity(0.2));
    canvas.drawCircle(center, 37.0, Paint()..color = const Color(0xFF185FA5));
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

      canvas.drawCircle(pos, 16.0, Paint()..color = const Color(0xFF185FA5).withOpacity(0.12));
      canvas.drawCircle(pos, 12.0, Paint()..color = const Color(0xFFCBD5E1));
      canvas.drawCircle(pos, 10.5, centerGlow);

      final iconPaint = Paint()
        ..color = const Color(0xFF185FA5)
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
      ..color = const Color(0xFF185FA5).withOpacity(0.65)
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
    drawPolygon(orangePoints, const Color(0xFF185FA5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

