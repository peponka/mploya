import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/connection_card.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/nex_avatar.dart';
import '../services/social_service.dart';
import '../services/error_handler.dart';
import 'profile_screen.dart';
import 'messaging_screen.dart';
import '../navigation/main_navigation.dart';
import '../widgets/web_ui.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  List<Map<String, dynamic>>? _recommended;
  List<NexUser>? _connections;
  bool _loadingConnections = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadRecommended(), _loadConnections()]);
  }

  Future<void> _loadRecommended() async {
    final results = await SocialService.instance.getRecommendedUsers(limit: 20);
    if (mounted) setState(() => _recommended = results);
  }

  Future<void> _loadConnections() async {
    setState(() => _loadingConnections = true);
    try {
      final uid = _uid;
      if (uid == null) return;

      final rows = await _supabase
          .from('connections')
          .select('requester_id, addressee_id')
          .or('requester_id.eq.$uid,addressee_id.eq.$uid')
          .eq('status', 'accepted');

      final otherIds = rows
          .map<String>((r) {
            final req = r['requester_id']?.toString() ?? '';
            final add = r['addressee_id']?.toString() ?? '';
            return req == uid ? add : req;
          })
          .where((id) => id.isNotEmpty)
          .toList();

      if (otherIds.isEmpty) {
        if (mounted) setState(() { _connections = []; _loadingConnections = false; });
        return;
      }

      final users = await _supabase.from('users').select().inFilter('id', otherIds);
      if (mounted) setState(() {
        _connections = users.map((r) => NexUser.fromJson(r)).toList();
        _loadingConnections = false;
      });
    } catch (e) {
      debugPrint('❌ _loadConnections: $e');
      if (mounted) setState(() { _connections = []; _loadingConnections = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SocialService.instance.pendingRequestsStream,
        builder: (context, pendingSnap) {
          final pending = pendingSnap.data ?? [];
          if (isWebWide(context)) return _buildWeb(context, pending);
          return CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // ── Nav bar ──
              CupertinoSliverNavigationBar(
                backgroundColor: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
                border: null,
                transitionBetweenRoutes: false,
                largeTitle: Text(
                  'Matches',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: context.textPrimary,
                  ),
                ),
              ),

              // ── Subtítulo explicativo ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MployaTheme.brandAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(CupertinoIcons.bolt_fill, color: MployaTheme.brandAccent, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cuando ambos se conectan, aparecen acá. Explorá el feed para encontrar tu próxima oportunidad.',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Solicitudes pendientes ──
              if (pending.isNotEmpty) ...[
                _sectionHeader(
                  context,
                  'SOLICITUDES PENDIENTES',
                  trailing: pending.length > 2
                      ? GestureDetector(
                          onTap: () => _showAllPending(context, pending),
                          child: Text(
                            'Ver todas (${pending.length})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: MployaTheme.brandAccent,
                            ),
                          ),
                        )
                      : null,
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: pending.take(2).map((req) {
                      final requesterId = req['requester_id']?.toString() ?? '';
                      return FutureBuilder<Map<String, dynamic>?>(
                        future: _supabase
                            .from('users')
                            .select('name, avatar_url, headline')
                            .eq('id', requesterId)
                            .maybeSingle(),
                        builder: (context, snap) {
                          final name = snap.data?['name']?.toString() ?? '...';
                          final headline = snap.data?['headline']?.toString() ?? '';
                          final avatar = snap.data?['avatar_url']?.toString();
                          return _PendingInlineTile(
                            name: name,
                            headline: headline,
                            avatarUrl: avatar,
                            requesterId: requesterId,
                            onDone: _loadConnections,
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 8)),
              ],

              // ── Para conectar (carrusel recomendados) ──
              _sectionHeader(context, 'PARA CONECTAR'),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 260,
                  child: _buildRecommendedCarousel(context),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Container(height: 0.5, color: context.dividerColor),
                ),
              ),

              // ── Tus conexiones ──
              _sectionHeader(
                context,
                'TUS CONEXIONES',
                trailing: _connections != null && _connections!.isNotEmpty
                    ? Text(
                        '${_connections!.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.textSecondary,
                        ),
                      )
                    : null,
              ),
              _buildConnectionsList(context),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  // ── Layout web: Primeros Pasos + solicitudes + para conectar + conexiones ──
  Widget _buildWeb(BuildContext context, List<Map<String, dynamic>> pending) {
    return WebPage(
      title: 'Matches',
      subtitle: 'Tu viaje profesional empieza acá',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _webExplainerCard(context)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _webFirstStepsCard(context)),
              ],
            ),
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 24),
            const WebSectionLabel('Solicitudes pendientes'),
            WebCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: pending.map((req) {
                  final requesterId = req['requester_id']?.toString() ?? '';
                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _supabase
                        .from('users')
                        .select('name, avatar_url, headline')
                        .eq('id', requesterId)
                        .maybeSingle(),
                    builder: (context, snap) {
                      final name = snap.data?['name']?.toString() ?? '...';
                      final headline = snap.data?['headline']?.toString() ?? '';
                      final avatar = snap.data?['avatar_url']?.toString();
                      return _PendingInlineTile(
                        name: name,
                        headline: headline,
                        avatarUrl: avatar,
                        requesterId: requesterId,
                        onDone: _loadConnections,
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const WebSectionLabel('Tus matches recientes'),
          _buildMatchesGrid(context),
          const SizedBox(height: 24),
          Row(
            children: [
              const WebSectionLabel('Tus conexiones'),
              const Spacer(),
              if (_connections != null && _connections!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('${_connections!.length}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textSecondary)),
                ),
            ],
          ),
          _webConnectionsCard(context),
        ],
      ),
    );
  }

  Widget _webExplainerCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: context.cardShadow,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: CupertinoColors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.play_fill, color: CupertinoColors.white, size: 22),
          ),
          const SizedBox(height: 44),
          const Text('Cómo encontrar tus Matches ideales',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CupertinoColors.white)),
          const SizedBox(height: 6),
          Text('Explorá el feed, conectá con empresas que buscan tu perfil y respondé a tiempo.',
              style: TextStyle(fontSize: 13, color: CupertinoColors.white.withValues(alpha: 0.7), height: 1.4)),
        ],
      ),
    );
  }

  Widget _webFirstStepsCard(BuildContext context) {
    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Primeros pasos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              WebIconBadge(icon: CupertinoIcons.person_fill, color: kMployaBlue, size: 34),
              const SizedBox(width: 8),
              WebIconBadge(icon: CupertinoIcons.heart_fill, color: MployaTheme.brandAccent, size: 34),
              const SizedBox(width: 8),
              WebIconBadge(icon: CupertinoIcons.compass_fill, color: kMployaPurple, size: 34),
              const SizedBox(width: 8),
              const WebIconBadge(icon: CupertinoIcons.person_2_fill, color: Color(0xFF1E293B), size: 34),
            ],
          ),
          const SizedBox(height: 12),
          Text('Tu red profesional empieza acá',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
          const SizedBox(height: 3),
          Text('Explorá el feed y conectá con empresas que buscan tu perfil.',
              style: TextStyle(fontSize: 12, color: context.textTertiary, height: 1.4)),
          const SizedBox(height: 16),
          _firstStepButton(context, icon: CupertinoIcons.person_fill, color: const Color(0xFF64748B), label: 'Completá tu perfil',
              onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: null)))),
          const SizedBox(height: 8),
          _firstStepButton(context, icon: CupertinoIcons.heart_fill, color: MployaTheme.brandAccent, label: 'Definí tus intereses',
              onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: null)))),
          const SizedBox(height: 8),
          _firstStepButton(context, icon: CupertinoIcons.compass_fill, color: kMployaBlue, label: 'Explorá el feed',
              onTap: () => currentMainTabNotifier.value = 0),
          const SizedBox(height: 8),
          _firstStepButton(context, icon: CupertinoIcons.paperplane_fill, color: const Color(0xFF1E293B), label: 'Enviá solicitudes',
              onTap: () {}),
        ],
      ),
    );
  }

  Widget _firstStepButton(BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 16, color: CupertinoColors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: CupertinoColors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grilla de matches recientes: foto real + % de afinidad real (RPC) +
  // skills reales + acciones. Si no hay recomendados todavía, cae al grid
  // fantasma (no inventa gente). ──
  Widget _buildMatchesGrid(BuildContext context) {
    if (_recommended == null) {
      return WebGrid(children: List.generate(3, (_) => const WebCard(child: SizedBox(height: 220))));
    }
    if (_recommended!.isEmpty) {
      return _ghostProfileGrid(context, caption: 'Perfil sugerido');
    }
    return WebGrid(
      children: _recommended!.map((r) {
        final userId = r['user_id']?.toString() ?? r['id']?.toString() ?? '';
        final affinity = (r['affinity_score'] as num?)?.toDouble() ?? 0;
        return FutureBuilder<Map<String, dynamic>?>(
          future: _supabase.from('users').select().eq('id', userId).maybeSingle(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data == null) {
              return const WebCard(child: SizedBox(height: 220));
            }
            final user = NexUser.fromJson(snap.data!);
            return _MatchGridCard(user: user, matchScore: affinity.round());
          },
        );
      }).toList(),
    );
  }

  // Grilla de placeholders "Perfil sugerido" — mismo rol que un skeleton: no
  // inventa datos falsos, solo indica dónde van a aparecer las sugerencias.
  Widget _ghostProfileGrid(BuildContext context, {required String caption}) {
    return WebGrid(
      gap: 12,
      children: List.generate(6, (i) {
        final pending = i.isEven;
        return WebCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.person_fill, size: 22, color: context.textTertiary.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 10),
              Text(pending ? 'Invitación pendiente' : caption,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textTertiary)),
            ],
          ),
        );
      }),
    );
  }

  Widget _webConnectionsCard(BuildContext context) {
    if (_loadingConnections) {
      return const WebCard(child: SizedBox(height: 120, child: Center(child: CupertinoActivityIndicator())));
    }
    final conns = _connections ?? [];
    if (conns.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ghostProfileGrid(context, caption: 'Perfil sugerido'),
          const SizedBox(height: 16),
          Text('Todavía no tenés conexiones activas. Enviá solicitudes para verlas acá.',
              style: TextStyle(fontSize: 13, color: context.textTertiary)),
        ],
      );
    }
    return WebCard(
      padding: EdgeInsets.zero,
      child: Column(children: conns.map((u) => _ConnectionListItem(user: u)).toList()),
    );
  }

  // ── Section header helper ──
  Widget _sectionHeader(BuildContext context, String title, {Widget? trailing}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: context.textSecondary,
              ),
            ),
            const Spacer(),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  // ── Carrusel de recomendados ──
  Widget _buildRecommendedCarousel(BuildContext context) {
    if (_recommended == null) {
      return ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 4,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(right: 12),
          child: ConnectionCardSkeleton(),
        ),
      );
    }

    // Usamos todos los recomendados (cross-type ya viene filtrado del RPC)
    final users = _recommended!;

    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.person_2, size: 44, color: context.textTertiary),
              const SizedBox(height: 12),
              Text(
                'Tu red profesional empieza acá',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Explorá el feed y conectá con empresas que buscan tu perfil.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final r = users[index];
        final userId = r['user_id']?.toString() ?? r['id']?.toString() ?? '';
        final mutualCount = (r['mutual_count'] as num?)?.toInt() ?? 0;
        final affinity = (r['affinity_score'] as num?)?.toDouble() ?? 0;

        return FutureBuilder<Map<String, dynamic>?>(
          future: _supabase.from('users').select().eq('id', userId).maybeSingle(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data == null) {
              return const Padding(
                padding: EdgeInsets.only(right: 12),
                child: ConnectionCardSkeleton(),
              );
            }
            final user = NexUser.fromJson(snap.data!);
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ConnectionCard(
                user: user,
                mutualConnections: mutualCount,
                affinityScore: affinity,
              ),
            );
          },
        );
      },
    );
  }

  // ── Lista de conexiones aceptadas ──
  Widget _buildConnectionsList(BuildContext context) {
    if (_loadingConnections) {
      return const NetworkListSkeleton();
    }

    final conns = _connections ?? [];
    if (conns.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            children: [
              Icon(CupertinoIcons.person_2, size: 44, color: context.textTertiary.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(
                'Todavía no tenés conexiones',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cuando alguien acepte tu solicitud, aparecerá acá.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _ConnectionListItem(user: conns[index]),
        childCount: conns.length,
      ),
    );
  }

  // ── Modal "Ver todas las solicitudes" ──
  void _showAllPending(BuildContext context, List<Map<String, dynamic>> pending) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: ctx.isDark ? NexTheme.darkCard : CupertinoColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: ctx.dividerColor, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Solicitudes (${pending.length})',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ctx.textPrimary)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () => Navigator.pop(ctx),
                      child: Icon(CupertinoIcons.xmark_circle_fill, color: ctx.textTertiary, size: 28),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: pending.length,
                  separatorBuilder: (_, __) => Container(height: 0.5, color: ctx.dividerColor),
                  itemBuilder: (context, index) {
                    final req = pending[index];
                    final requesterId = req['requester_id']?.toString() ?? '';
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _supabase.from('users').select('name, avatar_url, headline').eq('id', requesterId).maybeSingle(),
                      builder: (context, snap) {
                        final name = snap.data?['name']?.toString() ?? 'Usuario';
                        final headline = snap.data?['headline']?.toString() ?? '';
                        final avatar = snap.data?['avatar_url']?.toString();
                        return _PendingInlineTile(
                          name: name,
                          headline: headline,
                          avatarUrl: avatar,
                          requesterId: requesterId,
                          onDone: () { _loadConnections(); if (ctx.mounted) Navigator.pop(ctx); },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Solicitud pendiente inline ──
class _PendingInlineTile extends StatefulWidget {
  final String name;
  final String headline;
  final String? avatarUrl;
  final String requesterId;
  final VoidCallback onDone;

  const _PendingInlineTile({
    required this.name,
    required this.headline,
    this.avatarUrl,
    required this.requesterId,
    required this.onDone,
  });

  @override
  State<_PendingInlineTile> createState() => _PendingInlineTileState();
}

class _PendingInlineTileState extends State<_PendingInlineTile> {
  bool _loading = false;

  Future<void> _respond(String action) async {
    setState(() => _loading = true);
    await MployaErrorHandler.instance.wrapAsync(
      context,
      () => SocialService.instance.respondConnection(widget.requesterId, action),
      successMessage: action == 'accept' ? 'Conexión aceptada ✅' : 'Solicitud rechazada',
      errorMessage: 'No se pudo procesar',
    );
    if (mounted) widget.onDone();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MployaTheme.brandAccent.withValues(alpha: 0.1),
              image: (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty)
                  ? DecorationImage(image: NetworkImage(widget.avatarUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: (widget.avatarUrl == null || widget.avatarUrl!.isEmpty)
                ? Center(
                    child: Text(
                      widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: MployaTheme.brandAccent, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary)),
                if (widget.headline.isNotEmpty)
                  Text(widget.headline,
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_loading)
            const CupertinoActivityIndicator()
          else ...[
            GestureDetector(
              onTap: () => _respond('accept'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: context.isDark ? CupertinoColors.white : const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Aceptar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.isDark ? CupertinoColors.black : CupertinoColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _respond('reject'),
              child: Icon(CupertinoIcons.xmark, size: 18, color: context.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Connection List Item ──
// ── Card de match recomendado (estilo mockup): foto + badge de % real +
// skills reales + Conectar/Ver Perfil. ──
class _MatchGridCard extends StatefulWidget {
  final NexUser user;
  final int matchScore;
  const _MatchGridCard({required this.user, required this.matchScore});

  @override
  State<_MatchGridCard> createState() => _MatchGridCardState();
}

class _MatchGridCardState extends State<_MatchGridCard> {
  String _status = 'none';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    final res = await SocialService.instance.getConnectionStatus(widget.user.id);
    if (res['status'] != null && mounted) setState(() => _status = res['status'] as String);
  }

  Future<void> _connect() async {
    setState(() { _loading = true; _status = 'pending'; });
    await SocialService.instance.sendConnectionRequest(widget.user.id);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final skills = widget.user.tags.isNotEmpty ? widget.user.tags : widget.user.skills;
    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              NexAvatar(user: widget.user, size: 52),
              if (widget.matchScore > 0)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: MployaTheme.brandAccent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: CupertinoColors.white, width: 2),
                    ),
                    child: Text('${widget.matchScore}%',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: CupertinoColors.white)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(widget.user.name,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(widget.user.headline.isNotEmpty ? widget.user.headline : 'Sin descripción',
              style: TextStyle(fontSize: 12.5, color: context.textTertiary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: skills.take(3).map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: kMployaBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                    child: Text('#$t', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: kMployaBlue)),
                  )).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _status == 'none'
                    ? GestureDetector(
                        onTap: _loading ? null : _connect,
                        child: Container(
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: MployaTheme.brandAccent, borderRadius: BorderRadius.circular(10)),
                          child: _loading
                              ? const CupertinoActivityIndicator(color: CupertinoColors.white, radius: 8)
                              : const Text('Conectar', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: CupertinoColors.white)),
                        ),
                      )
                    : Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_status == 'pending' ? 'Pendiente' : 'Conectado',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textSecondary)),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: widget.user))),
                  child: Container(
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.dividerColor),
                    ),
                    child: Text('Ver Perfil', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectionListItem extends StatelessWidget {
  final NexUser user;
  const _ConnectionListItem({required this.user});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => ProfileScreen(user: user)),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.dividerColor.withValues(alpha: 0.6), width: 0.5)),
        ),
        child: Row(
          children: [
            NexAvatar(user: user, size: 48, showBadge: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    user.headline.isNotEmpty ? user.headline : 'Sin descripción',
                    style: TextStyle(fontSize: 13, color: context.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Tipo de cuenta
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (user.accountType == 'empresa' || user.accountType == 'headhunter')
                      ? MployaTheme.brandAccent.withValues(alpha: 0.3)
                      : context.dividerColor,
                ),
              ),
              child: Text(
                user.accountType == 'empresa' ? 'Empresa'
                    : user.accountType == 'headhunter' ? 'Hunter'
                    : 'Candidato',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: (user.accountType == 'empresa' || user.accountType == 'headhunter')
                      ? MployaTheme.brandAccent
                      : context.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Botón mensaje
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => ChatDetailScreen(otherUser: user)),
              ),
              child: Icon(CupertinoIcons.chat_bubble, size: 20, color: context.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
