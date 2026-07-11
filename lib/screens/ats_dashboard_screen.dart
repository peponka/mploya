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
                        return _buildMetricCard(
                          icon: CupertinoIcons.envelope_badge_fill,
                          label: 'Pendientes',
                          value: '$count',
                          isAccent: count > 0,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _acceptedStream,
                      builder: (context, snap) {
                        final count = snap.data?.length ?? 0;
                        return _buildMetricCard(
                          icon: CupertinoIcons.person_2_fill,
                          label: 'Contactos',
                          value: '$count',
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
        backgroundColor: const Color(0xFFF1F1F4),
        child: WebPage(
          title: 'Candidatos',
          subtitle: 'Gestioná solicitudes, contactos y el radar confidencial.',
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
              color: context.cardColor,
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
    'pending': kMployaBlue,
    'viewed': Color(0xFFD97706),
    'accepted': Color(0xFF059669),
    'rejected': MployaTheme.danger,
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
          if (rows.isEmpty) {
            return WebEmptyState(
              icon: CupertinoIcons.person_3,
              title: 'Todavía no tenés postulantes',
              subtitle: 'Cuando alguien aplique a una de tus vacantes con video, va a aparecer acá.',
            );
          }
          return Column(
            children: [
              for (int i = 0; i < rows.length; i++)
                _candidateRow(rows[i], isLast: i == rows.length - 1),
            ],
          );
        },
      ),
    );
  }

  Widget _candidateRow(Map<String, dynamic> r, {required bool isLast}) {
    final status = r['status']?.toString() ?? 'pending';
    final statusLabel = _statusLabels[status] ?? status;
    final statusColor = _statusColors[status] ?? context.textTertiary;
    final name = r['candidate_name']?.toString() ?? 'Candidato';
    final headline = r['candidate_headline']?.toString() ?? '';
    final jobTitle = r['job_title']?.toString() ?? 'Vacante';
    final avatarUrl = r['candidate_avatar_url']?.toString();
    final appliedAt = DateTime.tryParse(r['applied_at']?.toString() ?? '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: context.dividerColor.withValues(alpha: 0.5), width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MployaTheme.brandAccent.withValues(alpha: 0.12),
              image: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: MployaTheme.brandAccent, fontWeight: FontWeight.w800)))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (headline.isNotEmpty)
                  Text(headline, style: TextStyle(fontSize: 12, color: context.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(jobTitle, style: TextStyle(fontSize: 13, color: context.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Text(statusLabel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ),
          ),
          if (appliedAt != null)
            SizedBox(
              width: 90,
              child: Text(_timeAgoShort(appliedAt), style: TextStyle(fontSize: 12, color: context.textTertiary)),
            ),
          SizedBox(
            width: 90,
            child: GestureDetector(
              onTap: () async {
                final data = await _supabase.from('users').select().eq('id', r['candidate_id']).maybeSingle();
                if (data != null && mounted) {
                  Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: NexUser.fromJson(data))));
                }
              },
              child: Text('Ver perfil', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: MployaTheme.brandAccent)),
            ),
          ),
        ],
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

  Widget _candidatesFiltersCard() {
    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WebSectionLabel('Filtrar por estado'),
          _statusFilterChip(null, 'Todos'),
          ..._statusLabels.entries.map((e) => _statusFilterChip(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _statusFilterChip(String? status, String label) {
    final active = _candidatesStatusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _loadCandidates(status: status),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? MployaTheme.brandAccent.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? MployaTheme.brandAccent : context.dividerColor),
          ),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? MployaTheme.brandAccent : context.textSecondary)),
        ),
      ),
    );
  }

  // ── SOLICITUDES PENDIENTES ────────────────────────────────────────────────

  Widget _buildPendingRequestsSection() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _pendingStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(child: Center(child: CupertinoActivityIndicator()));
        }

        final pending = snapshot.data!;

        if (pending.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
              child: Column(
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: MployaTheme.brandAccent.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CupertinoIcons.person_2, size: 32, color: MployaTheme.brandAccent.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 16),
                  Text('Todo al día', style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'Las solicitudes de conexión aparecerán aquí.\nCompartí tu perfil para recibir más.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.textTertiary, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => HapticFeedback.selectionClick(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: MployaTheme.brandAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Compartir perfil', style: TextStyle(color: MployaTheme.brandAccent, fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Para cada solicitud, necesitamos info del requester
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final conn = pending[index];
              final requesterId = conn['requester_id']?.toString() ?? '';
              
              return FutureBuilder<Map<String, dynamic>?>(
                future: _supabase.from('users').select('id, name, headline, avatar_url, account_type').eq('id', requesterId).maybeSingle(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || userSnap.data == null) {
                    return const SizedBox.shrink();
                  }
                  final userData = userSnap.data!;
                  final user = NexUser.fromJson(userData);
                  final createdAt = DateTime.tryParse(conn['created_at']?.toString() ?? '');
                  final timeAgo = createdAt != null ? _timeAgo(createdAt) : '';

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: context.cardShadow,
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            CupertinoPageRoute(builder: (_) => ProfileScreen(user: user)),
                          ),
                          child: NexAvatar(user: user, size: 52),
                        ),
                        const SizedBox(width: 16),
                        // Info
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              CupertinoPageRoute(builder: (_) => ProfileScreen(user: user)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.name, style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  user.headline.isNotEmpty ? user.headline : 'Candidato',
                                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                                if (timeAgo.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(timeAgo, style: TextStyle(color: context.textTertiary, fontSize: 11)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Action buttons
                        Column(
                          children: [
                            // Accept
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _respondToRequest(requesterId, 'accept'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: MployaTheme.brandAccent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Aceptar', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Reject
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _respondToRequest(requesterId, 'reject'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('Ignorar', style: TextStyle(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            childCount: pending.length,
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
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(child: Center(child: CupertinoActivityIndicator()));
        }

        final accepted = snapshot.data!;

        if (accepted.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
              child: Column(
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CupertinoIcons.hand_thumbsup, size: 32, color: const Color(0xFF34C759).withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 16),
                  Text('Sin contactos aún', style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'Cuando aceptes una solicitud,\nel contacto aparecerá aquí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.textTertiary, fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final conn = accepted[index];
              // Determinar quién es el otro usuario
              final otherId = conn['requester_id'] == _uid
                  ? conn['addressee_id']?.toString() ?? ''
                  : conn['requester_id']?.toString() ?? '';

              return FutureBuilder<Map<String, dynamic>?>(
                future: _supabase.from('users').select('id, name, headline, avatar_url, account_type').eq('id', otherId).maybeSingle(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || userSnap.data == null) {
                    return const SizedBox.shrink();
                  }
                  final userData = userSnap.data!;
                  final user = NexUser.fromJson(userData);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: context.cardShadow,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            CupertinoPageRoute(builder: (_) => ProfileScreen(user: user)),
                          ),
                          child: NexAvatar(user: user, size: 48),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              CupertinoPageRoute(builder: (_) => ProfileScreen(user: user)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.name, style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  user.headline.isNotEmpty ? user.headline : 'Contacto',
                                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).push(
                              CupertinoPageRoute(builder: (_) => ChatDetailScreen(otherUser: user)),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: MployaTheme.brandAccent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.chat_bubble_fill, size: 14, color: Colors.white),
                                const SizedBox(width: 5),
                                const Text('Chat', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            childCount: accepted.length,
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
            if (!snapshot.hasData) {
              return const SliverToBoxAdapter(child: Center(child: CupertinoActivityIndicator()));
            }

            final stealthUsers = snapshot.data!;

            if (stealthUsers.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('No hay perfiles confidenciales disponibles.', textAlign: TextAlign.center, style: TextStyle(color: context.textTertiary)),
                ),
              );
            }

            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: Column(
                  children: [
                    for (int i = 0; i < stealthUsers.length; i++)
                      _stealthRow(context, stealthUsers[i], i == stealthUsers.length - 1),
                  ],
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
    final c = color ?? MployaTheme.brandAccent;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isAccent ? c.withValues(alpha: 0.06) : context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAccent ? c.withValues(alpha: 0.18) : context.dividerColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WebIconBadge(icon: icon, color: c, size: 34),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(color: context.textPrimary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: context.textTertiary, fontSize: 12.5)),
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