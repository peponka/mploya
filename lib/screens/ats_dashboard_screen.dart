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
import '../screens/chat_inmail_screen.dart';
import '../screens/profile_screen.dart';
// nexus_inbox_tab removed – replaced by inline Contactos section
import '../widgets/nex_avatar.dart';
import '../services/social_service.dart';

class AtsDashboardScreen extends StatefulWidget {
  const AtsDashboardScreen({super.key});

  @override
  State<AtsDashboardScreen> createState() => _AtsDashboardScreenState();
}

class _AtsDashboardScreenState extends State<AtsDashboardScreen> {
  int _tokensDisponibles = 0;
  String _filtroActivo = 'Pendientes';
  final List<String> _filtros = ['Pendientes', 'Contactos', 'Confidencial 🔒'];
  
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
                  debugPrint('Error RPC unlock: $e');
                  if (context.mounted) setState(() => _tokensDisponibles -= 1);
                  _showSuccessDialog(user);
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
              Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ChatInmailScreen(targetUser: user)));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.bgColor,
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            CupertinoSliverNavigationBar(
              transitionBetweenRoutes: false,
              largeTitle: Text('Conexiones', style: TextStyle(color: context.textPrimary, fontFamily: '.SF Pro Display', letterSpacing: -0.5, fontWeight: FontWeight.w900)),
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
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Credits banner (subtle, for companies only) ──
            if (_tokensDisponibles > 0)
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
            if (_filtroActivo == 'Pendientes') ...[
              _buildPendingRequestsSection(),
            ] else if (_filtroActivo == 'Contactos') ...[
              _buildAcceptedConnectionsSection(),
            ] else ...[
              _buildStealthSection(),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
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
                              CupertinoPageRoute(builder: (_) => ChatInmailScreen(targetUser: user)),
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

  Widget _buildStealthSection() {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Descubrimiento Confidencial', style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const Icon(CupertinoIcons.lock_shield_fill, color: MployaTheme.brandAccent, size: 20),
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

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final u = stealthUsers[index];
                  final isUnlocked = u['is_unlocked'] == true;
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: context.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipOval(
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(sigmaX: isUnlocked ? 0 : 8, sigmaY: isUnlocked ? 0 : 8),
                                child: Container(
                                  width: 56, height: 56,
                                  decoration: BoxDecoration(
                                    color: MployaTheme.brandAccent.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(CupertinoIcons.person_fill, color: MployaTheme.brandAccent.withValues(alpha: 0.6), size: 32),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text((u['real_name'] ?? 'Confidencial').toString(), style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text((u['headline'] ?? 'Directivo C-Level').toString(), style: const TextStyle(color: MployaTheme.brandAccent, fontSize: 14, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          (u['about'] ?? 'Logros clave no disponibles.').toString(),
                          style: TextStyle(color: context.textPrimary, fontSize: 14, height: 1.4),
                          maxLines: 3, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
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
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isUnlocked ? context.cardColor : MployaTheme.brandAccent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isUnlocked ? [] : [BoxShadow(color: MployaTheme.brandAccent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(isUnlocked ? Icons.verified : Icons.lock_open_rounded, color: isUnlocked ? MployaTheme.brandAccent : Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  isUnlocked ? 'Ver Perfil y CV' : 'Desbloquear (1 Crédito)',
                                  style: TextStyle(color: isUnlocked ? MployaTheme.brandAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                childCount: stealthUsers.length,
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildMetricCard({required IconData icon, required String label, required String value, bool isAccent = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isAccent ? MployaTheme.brandAccent.withValues(alpha: 0.08) : context.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: context.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Icon(icon, color: MployaTheme.brandAccent, size: 24),
                const SizedBox(width: 8),
                Text(value, style: TextStyle(color: context.textPrimary, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: '.SF Pro Display')),
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