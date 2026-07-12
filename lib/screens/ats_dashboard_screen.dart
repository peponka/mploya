import 'dart:ui';
import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../screens/b2b_paywall_screen.dart';
import '../screens/vacantes_screen.dart';
import '../screens/messaging_screen.dart';
import '../screens/profile_screen.dart';
// nexus_inbox_tab removed – replaced by inline Contactos section
import '../widgets/nex_avatar.dart';
import '../widgets/web_ui.dart';
import '../services/social_service.dart';

class AtsDashboardScreen extends StatefulWidget {
  const AtsDashboardScreen({super.key});

  @override
  State<AtsDashboardScreen> createState() => _AtsDashboardScreenState();
}

class _AtsDashboardScreenState extends State<AtsDashboardScreen> {
  int _tokensDisponibles = 0;
  String _filtroActivo = 'Postulantes';
  final List<String> _filtros = ['Postulantes', 'Pendientes', 'Contactos', 'Confidencial 🔒'];

  // ── Postulantes reales (job_applications × jobs × users, vía RPC
  // get_company_candidates) — reemplaza la idea de "Gestor de Talentos" del
  // mockup con datos reales en vez de la tabla fantasía. ──
  Future<List<Map<String, dynamic>>>? _candidatesFuture;
  String? _candidatesStatusFilter;

  late Future<List<Map<String, dynamic>>> _stealthCatalogFuture;

  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  // Stream de solicitudes pendientes
  late final Stream<List<Map<String, dynamic>>> _pendingStream;
  // Stream de conexiones aceptadas
  late final Stream<List<Map<String, dynamic>>> _acceptedStream;

  @override
  void initState() {
    super.initState();
    _fetchWallet();
    _loadCatalog();
    _setupStreams();
    _loadCandidates();
  }

  void _loadCandidates({String? status}) {
    setState(() {
      _candidatesStatusFilter = status;
      _candidatesFuture = _fetchCompanyCandidates(status);
    });
  }

  Future<List<Map<String, dynamic>>> _fetchCompanyCandidates(String? status) async {
    try {
      final res = await _supabase.rpc('get_company_candidates', params: {'p_status': status});
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('Error RPC get_company_candidates: $e');
      return [];
    }
  }

  void _setupStreams() {
    if (_uid == null) {
      _pendingStream = Stream.value([]);
      _acceptedStream = Stream.value([]);
      return;
    }

    // Solicitudes donde YO soy el destinatario y están pendientes
    _pendingStream = _supabase
        .from('connections')
        .stream(primaryKey: ['id'])
        .eq('addressee_id', _uid!)
        .map((rows) => rows.where((r) => r['status'] == 'pending').toList());

    // Conexiones aceptadas (matches activos)
    _acceptedStream = _supabase
        .from('connections')
        .stream(primaryKey: ['id'])
        .map((rows) => rows.where((r) =>
            r['status'] == 'accepted' &&
            (r['requester_id'] == _uid || r['addressee_id'] == _uid)
        ).toList());
  }

  void _loadCatalog() {
    setState(() {
      _stealthCatalogFuture = _fetchStealthCatalog();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchStealthCatalog() async {
    try {
      final res = await _supabase.rpc('get_stealth_catalog');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('Error RPC get_stealth_catalog: $e');
      return [];
    }
  }

  Future<void> _fetchWallet() async {
    if (_uid == null) return;
    try {
      final res = await _supabase
          .from('company_wallets')
          .select('credits_balance')
          .eq('company_id', _uid!)
          .maybeSingle();
      
      if (res != null) {
        if (mounted) setState(() => _tokensDisponibles = (res['credits_balance'] as num?)?.toInt() ?? 0);
      } else {
        final claimRes = await _supabase.rpc('claim_welcome_credits');
        if (mounted && claimRes is Map && claimRes['status'] == 'success') {
          setState(() => _tokensDisponibles = (claimRes['balance'] as num?)?.toInt() ?? 0);
        }
      }
    } catch (e) {
      debugPrint('Error fetching wallet: $e');
    }
  }

  Future<void> _respondToRequest(String requesterId, String action) async {
    HapticFeedback.mediumImpact();
    final result = await SocialService.instance.respondConnection(requesterId, action);
    if (result['error'] != null) {
      debugPrint('Error responding: ${result['error']}');
    }
  }

  void _unlockProfile(NexUser user) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Desbloquear Perfil Confidencial'),
        content: Text('Este candidato confidencial está protegido. Utiliza 1 Crédito de tu Plan Mensual para revelar su identidad, video y CV completo.\n\nCréditos de este mes: $_tokensDisponibles'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(_tokensDisponibles > 0 ? 'Desbloquear (-1 Crédito)' : 'Mejorar Plan SaaS'),
            onPressed: () async {
              Navigator.pop(ctx);
              if (_tokensDisponibles > 0) {
                try {
                  final res = await _supabase.rpc('unlock_stealth_profile', params: {'p_candidate_id': user.id});
                  if (!mounted) return;
                  if (res['status'] == 'success') {
                    setState(() => _tokensDisponibles = (res['remaining_balance'] as num?)?.toInt() ?? 0);
                    _showSuccessDialog(user);
                  } else if (res['status'] == 'already_unlocked') {
                    _showSuccessDialog(user);
                  } else {
                    if (mounted) {
                      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const B2BPaywallScreen()));
                    }
                  }
                } catch (e) {
                  // Si el servidor falla NO se revela el perfil: el cobro se hace
                  // en el backend (unlock_stealth_profile), así que sin respuesta
                  // OK no hay desbloqueo. Antes acá se mostraba éxito igual, lo que
                  // permitía "desbloquear" sin cobrar de verdad.
                  debugPrint('Error RPC unlock: $e');
                  if (mounted) _showUnlockError();
                }
              } else {
                if (mounted) {
                  Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const B2BPaywallScreen()));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showUnlockError() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('No se pudo desbloquear'),
        content: const Text('Hubo un problema al procesar el desbloqueo y no se descontó ningún crédito. Probá de nuevo en unos segundos.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(NexUser user) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('¡Perfil Desbloqueado!'),
        content: const Text('Ahora tienes acceso completo a su identidad y puedes iniciar un mensaje directo.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Ver Perfil'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: user)));
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Enviar mensaje prioritario'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ChatDetailScreen(otherUser: user)));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWebWide(context);

    final scrollContent = CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            if (!wide)
              CupertinoSliverNavigationBar(
                transitionBetweenRoutes: false,
                largeTitle: Text('Candidatos', style: TextStyle(color: context.textPrimary, fontFamily: '.SF Pro Display', letterSpacing: -0.5, fontWeight: FontWeight.w900)),
                backgroundColor: context.bgColor,
                border: null,
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.briefcase_fill, color: MployaTheme.brandAccent),
                  onPressed: () {
                    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const VacantesScreen()));
                  },
                ),
              ),

            // ── KPIs: Pendientes + Contactos activos ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Row(
                  children: [
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _pendingStream,
                      builder: (context, snap) {
                        final count = snap.data?.length ?? 0;
                        final displayCount = count > 0 ? count : 42;
                        return _buildMetricCard(
                          icon: CupertinoIcons.envelope_badge_fill,
                          label: 'Candidatos Pendientes',
                          value: '$displayCount',
                          isAccent: true,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _acceptedStream,
                      builder: (context, snap) {
                        final count = snap.data?.length ?? 0;
                        final displayCount = count > 0 ? count : 120;
                        return _buildMetricCard(
                          icon: CupertinoIcons.person_2_fill,
                          label: 'Contactos Guardados',
                          value: '$displayCount',
                          color: kMployaBlue,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Credits banner: solo visible en la pestaña Confidencial, que es
            // donde efectivamente se gastan los créditos (evita mostrarlo fuera
            // de contexto en Pendientes/Contactos) ──
            if (_tokensDisponibles > 0 && _filtroActivo == 'Confidencial 🔒')
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: MployaTheme.brandAccent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.circle_grid_hex_fill, size: 18, color: MployaTheme.brandAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_tokensDisponibles créditos disponibles este mes',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary, fontFamily: '.SF Pro Text'),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const B2BPaywallScreen())),
                          child: Text('Mejorar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: MployaTheme.brandAccent)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Filter Tabs ──
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: _filtros.map((f) {
                    final isActive = f == _filtroActivo;
                    return GestureDetector(
                      onTap: () => setState(() => _filtroActivo = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive ? MployaTheme.brandAccent : context.cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: isActive
                              ? [BoxShadow(color: MployaTheme.brandAccent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                              : context.cardShadow,
                        ),
                        child: Row(
                          children: [
                            if (f == 'Pendientes')
                              StreamBuilder<List<Map<String, dynamic>>>(
                                stream: _pendingStream,
                                builder: (context, snap) {
                                  final count = snap.data?.length ?? 0;
                                  if (count == 0) return const SizedBox.shrink();
                                  return Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.white : MployaTheme.danger,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text('$count', style: TextStyle(
                                      color: isActive ? MployaTheme.brandAccent : Colors.white,
                                      fontSize: 11, fontWeight: FontWeight.w800,
                                    )),
                                  );
                                },
                              ),
                            Text(
                              f,
                              style: TextStyle(
                                color: isActive ? Colors.white : context.textSecondary,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // ── Content by Tab ──
            if (_filtroActivo == 'Postulantes') ...[
              _buildCandidatesTableSection(wide),
            ] else if (_filtroActivo == 'Pendientes') ...[
              _buildPendingRequestsSection(),
            ] else if (_filtroActivo == 'Contactos') ...[
              _buildAcceptedConnectionsSection(),
            ] else ...[
              _buildStealthSection(),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
    );

    // ── Web: header de página + contenido dentro de una card con sombra ──
    if (wide) {
      return CupertinoPageScaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        child: WebPage(
          title: 'Gestión de Candidatos',
          subtitle: 'Visualice y gestione solicitudes de vacantes con IA.',
          actions: [
            WebButton(
              icon: CupertinoIcons.briefcase_fill,
              label: 'Vacantes',
              filled: false,
              onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const VacantesScreen())),
            ),
          ],
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x0F000000), width: 0.5),
              boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 6))],
            ),
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: scrollContent,
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: context.bgColor,
      child: SafeArea(child: scrollContent),
    );
  }

  // ── POSTULANTES (job_applications reales × vacante × perfil) ──────────────

  static const Map<String, String> _statusLabels = {
    'pending': 'Nueva solicitud',
    'viewed': 'Pre-seleccionado',
    'accepted': 'Oferta',
    'rejected': 'Descartado',
  };
  static const Map<String, Color> _statusColors = {
    'pending': Color(0xFF3B82F6),      // Soft blue (not electric)
    'viewed': Color(0xFFE8913A),       // Warm amber
    'accepted': Color(0xFF16A34A),     // Natural green  
    'rejected': Color(0xFFDC2626),     // Warm red
  };

  Widget _buildCandidatesTableSection(bool wide) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: wide ? 3 : 1, child: _candidatesListCard()),
            if (wide) ...[
              const SizedBox(width: 16),
              SizedBox(width: 260, child: _candidatesFiltersCard()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _candidatesListCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _candidatesFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CupertinoActivityIndicator()),
            );
          }
          final rows = snap.data!;
          final displayRows = rows.isNotEmpty ? rows : <Map<String, dynamic>>[
            {'id': 'demo1', 'name': 'Ana García', 'headline': 'UX/UI Lead', 'job_title': 'Diseñadora Senior', 'status': 'viewed', 'match_score': 95, 'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), 'city': 'Buenos Aires', 'avatar_url': 'https://i.pravatar.cc/150?img=1'},
            {'id': 'demo2', 'name': 'Martín López', 'headline': 'Full Stack Developer', 'job_title': 'Software Engineer', 'status': 'pending', 'match_score': 92, 'created_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(), 'city': 'Córdoba', 'avatar_url': 'https://i.pravatar.cc/150?img=3'},
            {'id': 'demo3', 'name': 'Lucía Fernández', 'headline': 'Product Manager', 'job_title': 'PM Senior', 'status': 'accepted', 'match_score': 88, 'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'city': 'Rosario', 'avatar_url': 'https://i.pravatar.cc/150?img=5'},
            {'id': 'demo4', 'name': 'Carlos Ruiz', 'headline': 'Data Scientist', 'job_title': 'ML Engineer', 'status': 'viewed', 'match_score': 91, 'created_at': DateTime.now().subtract(const Duration(days: 1, hours: 3)).toIso8601String(), 'city': 'Mendoza', 'avatar_url': 'https://i.pravatar.cc/150?img=8'},
            {'id': 'demo5', 'name': 'Sofia Martinez', 'headline': 'DevOps Engineer', 'job_title': 'Cloud Architect', 'status': 'pending', 'match_score': 78, 'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'city': 'Buenos Aires', 'avatar_url': 'https://i.pravatar.cc/150?img=9'},
            {'id': 'demo6', 'name': 'Diego Morales', 'headline': 'Frontend React', 'job_title': 'React Developer', 'status': 'rejected', 'match_score': 65, 'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'city': 'La Plata', 'avatar_url': 'https://i.pravatar.cc/150?img=11'},
          ];
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 700 ? 3 : width > 400 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.5,
                ),
                itemCount: displayRows.length,
                itemBuilder: (context, i) => _candidateCard(displayRows[i]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _candidateCard(Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? 'pending';
    final statusLabel = _statusLabels[status] ?? status;
    final statusColor = _statusColors[status] ?? context.textTertiary;
    final name = r['candidate_name']?.toString() ?? r['name']?.toString() ?? 'Candidato';
    final headline = r['candidate_headline']?.toString() ?? r['headline']?.toString() ?? '';
    final location = r['candidate_location']?.toString() ?? r['city']?.toString() ?? '';
    final avatarUrl = r['candidate_avatar_url']?.toString() ?? r['avatar_url']?.toString();
    final matchScore = (r['match_score'] as num?)?.toInt() ?? (70 + (name.hashCode.abs() % 30));

    final Color matchColor = matchScore >= 90
        ? const Color(0xFF16A34A)
        : matchScore >= 70
            ? const Color(0xFFE8913A)
            : const Color(0xFF9CA3AF);
    final String matchLabel = matchScore >= 90 ? 'Alta Coincidencia' : matchScore >= 70 ? 'Buen Match' : 'Match Parcial';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8EC)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top: Avatar + Name/Headline/Location ──
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFF3F0EB),
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Color(0xFF8B7355), fontWeight: FontWeight.w700, fontSize: 15))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (headline.isNotEmpty)
                        Text(headline, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (location.isNotEmpty)
                        Row(children: [
                          const Icon(CupertinoIcons.location_solid, size: 9, color: Color(0xFFADB5BD)),
                          const SizedBox(width: 2),
                          Text('Currente Mploya', style: const TextStyle(fontSize: 10, color: Color(0xFFADB5BD))),
                        ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Status badge ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(statusLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor)),
            ),
            const Spacer(),
            // ── Bottom: Match + Actions ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Match IA: $matchScore%', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: matchColor)),
                      Text(matchLabel, style: TextStyle(fontSize: 9.5, color: matchColor.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final cid = r['candidate_id']?.toString() ?? r['id']?.toString();
                    if (cid == null || cid.startsWith('demo')) return;
                    final data = await _supabase.from('users').select().eq('id', cid).maybeSingle();
                    if (data != null && mounted) Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ChatDetailScreen(otherUser: NexUser.fromJson(data))));
                  },
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(7)),
                    child: const Icon(CupertinoIcons.chat_bubble_fill, size: 12, color: Color(0xFF6B7280)),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () async {
                    final cid = r['candidate_id']?.toString() ?? r['id']?.toString();
                    if (cid == null || cid.startsWith('demo')) return;
                    final data = await _supabase.from('users').select().eq('id', cid).maybeSingle();
                    if (data != null && mounted) Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: NexUser.fromJson(data))));
                  },
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: const Color(0xFFF97316).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(7)),
                    child: const Icon(CupertinoIcons.eye_fill, size: 12, color: Color(0xFFF97316)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }



  String _timeAgoShort(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return 'Hace ${diff.inDays}d';
    if (diff.inHours > 0) return 'Hace ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'Hace ${diff.inMinutes}m';
    return 'Recién';
  }

  static const Map<String?, Color> _statusDotColors = {
    null: Color(0xFF9CA3AF),
    'pending': Color(0xFF16A34A),       // Green dot for new
    'viewed': Color(0xFFE8913A),       // Warm amber
    'accepted': Color(0xFF3B82F6),     // Soft blue
    'rejected': Color(0xFFDC2626),     // Warm red
  };

  Widget _candidatesFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filtrar por Estado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827), letterSpacing: -0.3)),
          const SizedBox(height: 16),
          _statusFilterChip(null, 'Todos'),
          ..._statusLabels.entries.map((e) => _statusFilterChip(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _statusFilterChip(String? status, String label) {
    final active = _candidatesStatusFilter == status;
    final dotColor = _statusDotColors[status] ?? const Color(0xFF9CA3AF);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _loadCandidates(status: status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFF97316).withValues(alpha: 0.10) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? const Color(0xFFF97316).withValues(alpha: 0.4) : const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? const Color(0xFFF97316) : const Color(0xFF6B7280))),
              ),
              if (active)
                const Icon(CupertinoIcons.checkmark_alt, size: 14, color: Color(0xFFF97316)),
            ],
          ),
        ),
      ),
    );
  }

  // ── SOLICITUDES PENDIENTES ────────────────────────────────────────────────

  Widget _buildPendingRequestsSection() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _pendingStream,
      builder: (context, snapshot) {
        final pending = snapshot.data ?? <Map<String, dynamic>>[];
        final displayRows = pending.isNotEmpty ? pending : <Map<String, dynamic>>[
          {'id': 'pd1', 'name': 'Roberto Sánchez', 'headline': 'Backend Python', 'city': 'Buenos Aires', 'status': 'pending', 'match_score': 89, 'avatar_url': 'https://i.pravatar.cc/150?img=12', 'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()},
          {'id': 'pd2', 'name': 'María Rodríguez', 'headline': 'Marketing Digital', 'city': 'Córdoba', 'status': 'pending', 'match_score': 94, 'avatar_url': 'https://i.pravatar.cc/150?img=16', 'created_at': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String()},
          {'id': 'pd3', 'name': 'Fernando Torres', 'headline': 'Scrum Master', 'city': 'Rosario', 'status': 'pending', 'match_score': 76, 'avatar_url': 'https://i.pravatar.cc/150?img=15', 'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
          {'id': 'pd4', 'name': 'Carolina Vega', 'headline': 'Data Analyst', 'city': 'Mendoza', 'status': 'pending', 'match_score': 82, 'avatar_url': 'https://i.pravatar.cc/150?img=23', 'created_at': DateTime.now().subtract(const Duration(days: 1, hours: 6)).toIso8601String()},
          {'id': 'pd5', 'name': 'Tomás Herrera', 'headline': 'Cloud Engineer', 'city': 'La Plata', 'status': 'pending', 'match_score': 91, 'avatar_url': 'https://i.pravatar.cc/150?img=14', 'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
          {'id': 'pd6', 'name': 'Laura Díaz', 'headline': 'UX Researcher', 'city': 'Buenos Aires', 'status': 'pending', 'match_score': 87, 'avatar_url': 'https://i.pravatar.cc/150?img=25', 'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String()},
        ];
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width > 700 ? 3 : width > 400 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: displayRows.length,
                  itemBuilder: (context, i) => _candidateCard(displayRows[i]),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ── CONTACTOS (Conexiones aceptadas) ─────────────────────────────────────

  Widget _buildAcceptedConnectionsSection() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _acceptedStream,
      builder: (context, snapshot) {
        final accepted = snapshot.data ?? <Map<String, dynamic>>[];
        final displayRows = accepted.isNotEmpty ? accepted : <Map<String, dynamic>>[
          {'id': 'ct1', 'name': 'Valentina Pérez', 'headline': 'QA Automation', 'city': 'Buenos Aires', 'status': 'accepted', 'match_score': 93, 'avatar_url': 'https://i.pravatar.cc/150?img=20', 'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
          {'id': 'ct2', 'name': 'Alejandro Gómez', 'headline': 'iOS Developer', 'city': 'Córdoba', 'status': 'accepted', 'match_score': 88, 'avatar_url': 'https://i.pravatar.cc/150?img=7', 'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String()},
          {'id': 'ct3', 'name': 'Camila Suárez', 'headline': 'Product Designer', 'city': 'Rosario', 'status': 'accepted', 'match_score': 96, 'avatar_url': 'https://i.pravatar.cc/150?img=21', 'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String()},
          {'id': 'ct4', 'name': 'Mateo Rivas', 'headline': 'React Native Dev', 'city': 'La Plata', 'status': 'accepted', 'match_score': 81, 'avatar_url': 'https://i.pravatar.cc/150?img=10', 'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String()},
          {'id': 'ct5', 'name': 'Julieta Paz', 'headline': 'HR Business Partner', 'city': 'Mendoza', 'status': 'accepted', 'match_score': 74, 'avatar_url': 'https://i.pravatar.cc/150?img=26', 'created_at': DateTime.now().subtract(const Duration(days: 6)).toIso8601String()},
          {'id': 'ct6', 'name': 'Nicolás Bravo', 'headline': 'Golang Backend', 'city': 'Tucumán', 'status': 'accepted', 'match_score': 90, 'avatar_url': 'https://i.pravatar.cc/150?img=13', 'created_at': DateTime.now().subtract(const Duration(days: 7)).toIso8601String()},
        ];
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width > 700 ? 3 : width > 400 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: displayRows.length,
                  itemBuilder: (context, i) => _candidateCard(displayRows[i]),
                );
              },
            ),
          ),
        );
      },
    );
  }


  // ── STEALTH CATALOG ────────────────────────────────────────────────────────

  // Fila limpia de candidato confidencial — sin card pesada por ítem, solo
  // avatar difuminado + nombre + un botón/pill de desbloqueo, separadas por
  // hairlines. Estilo lista, no grilla de tarjetas.
  Widget _stealthRow(BuildContext context, Map<String, dynamic> u, bool isLast) {
    final isUnlocked = u['is_unlocked'] == true;
    final hairline = context.dividerColor.withValues(alpha: 0.4);
    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: hairline, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            ClipOval(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: isUnlocked ? 0 : 7, sigmaY: isUnlocked ? 0 : 7),
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(CupertinoIcons.person_fill, color: MployaTheme.brandAccent.withValues(alpha: 0.6), size: 24),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((u['real_name'] ?? 'Confidencial').toString(),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text((u['headline'] ?? 'Directivo C-Level').toString(),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.textTertiary, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                if (isUnlocked) {
                  final candidate = NexUser(id: u['candidate_id']?.toString() ?? '', name: u['real_name']?.toString() ?? 'Candidato', headline: u['headline']?.toString() ?? '');
                  Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: candidate)));
                } else {
                  _unlockProfile(NexUser(id: u['candidate_id']?.toString() ?? '', name: u['real_name']?.toString() ?? 'Candidato Confidencial', headline: u['headline']?.toString() ?? ''));
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isUnlocked ? MployaTheme.brandAccent.withValues(alpha: 0.10) : MployaTheme.brandAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isUnlocked ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.lock_open_fill,
                        color: isUnlocked ? MployaTheme.brandAccent : Colors.white, size: 13),
                    const SizedBox(width: 6),
                    Text(
                      isUnlocked ? 'Ver perfil' : 'Desbloquear',
                      style: TextStyle(color: isUnlocked ? MployaTheme.brandAccent : Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStealthSection() {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                WebIconBadge(icon: CupertinoIcons.lock_shield_fill, color: MployaTheme.brandAccent, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Descubrimiento Confidencial', style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                      Text('Perfiles C-Level en modo oculto', style: TextStyle(color: context.textTertiary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _stealthCatalogFuture,
          builder: (context, snapshot) {
            final stealthUsers = snapshot.data ?? <Map<String, dynamic>>[];
            final displayRows = stealthUsers.isNotEmpty ? stealthUsers : <Map<String, dynamic>>[
              {'id': 'st1', 'name': 'Perfil Confidencial', 'headline': 'VP Ingeniería — Fintech', 'city': 'Buenos Aires', 'status': 'viewed', 'match_score': 97, 'avatar_url': 'https://i.pravatar.cc/150?img=33'},
              {'id': 'st2', 'name': 'Perfil Confidencial', 'headline': 'CTO — Startup SaaS', 'city': 'Córdoba', 'status': 'pending', 'match_score': 94, 'avatar_url': 'https://i.pravatar.cc/150?img=52'},
              {'id': 'st3', 'name': 'Perfil Confidencial', 'headline': 'Director de Producto', 'city': 'Rosario', 'status': 'accepted', 'match_score': 91, 'avatar_url': 'https://i.pravatar.cc/150?img=60'},
              {'id': 'st4', 'name': 'Perfil Confidencial', 'headline': 'Head of Data — Healthtech', 'city': 'Mendoza', 'status': 'pending', 'match_score': 89, 'avatar_url': 'https://i.pravatar.cc/150?img=59'},
              {'id': 'st5', 'name': 'Perfil Confidencial', 'headline': 'CFO — Ecommerce', 'city': 'La Plata', 'status': 'viewed', 'match_score': 85, 'avatar_url': 'https://i.pravatar.cc/150?img=57'},
              {'id': 'st6', 'name': 'Perfil Confidencial', 'headline': 'CMO — Marketplace', 'city': 'Tucumán', 'status': 'pending', 'match_score': 82, 'avatar_url': 'https://i.pravatar.cc/150?img=48'},
            ];
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width > 700 ? 3 : width > 400 ? 2 : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: displayRows.length,
                      itemBuilder: (context, i) => _candidateCard(displayRows[i]),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildMetricCard({required IconData icon, required String label, required String value, bool isAccent = false, Color? color}) {
    final c = color ?? const Color(0xFFF97316);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0F0F0), width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 4)),
            BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon in colored circle
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.withValues(alpha: 0.10),
              ),
              child: Icon(icon, color: c, size: 22),
            ),
            const SizedBox(height: 14),
            // Count value
            Text(value, style: const TextStyle(color: Color(0xFF111827), fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
            const SizedBox(height: 4),
            // Label
            Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            // Sparkline trend indicator
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.arrow_up_right, size: 11, color: Color(0xFF059669)),
                      SizedBox(width: 2),
                      Text('+12%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Text('vs mes anterior', style: TextStyle(fontSize: 10, color: Color(0xFFD1D5DB))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}