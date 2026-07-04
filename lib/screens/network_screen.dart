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
