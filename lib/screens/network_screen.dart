import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
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
  final _usersStream = Supabase.instance.client
      .from('users')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(80);

  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  // ── Tabs funcionales ──
  int _selectedTab = 0; // 0=Activos, 1=Conectados, 2=Pendientes

  // ── Recomendados con score real ──
  List<Map<String, dynamic>>? _recommendedUsers;

  @override
  void initState() {
    super.initState();
    _loadRecommended();
  }

  Future<void> _loadRecommended() async {
    final results = await SocialService.instance.getRecommendedUsers(limit: 30);
    if (mounted) {
      setState(() {
        _recommendedUsers = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _usersStream,
        builder: (context, snapshot) {
          final myData = (snapshot.data ?? [])
              .firstWhere((r) => r['id'] == _currentUserId, orElse: () => {});
          final myType = myData['account_type']?.toString() ?? 'candidato';

          final allOthers = (snapshot.data ?? [])
              .where((row) => row['id'] != _currentUserId)
              .map((row) => NexUser.fromJson(row))
              .toList();

          // Separar por tipo
          final crossUsers = allOthers.where((u) {
            if (myType == 'empresa' || myType == 'headhunter') {
              return u.accountType == 'candidato' || u.accountType == 'confidencial';
            }
            return u.accountType == 'empresa' || u.accountType == 'headhunter';
          }).toList();

          // Peers = mismo tipo
          final peerUsers = allOthers.where((u) {
            final t = u.accountType;
            if (myType == 'candidato' || myType == 'confidencial') {
              return t == 'candidato' || t == 'confidencial';
            }
            return t == 'empresa' || t == 'headhunter';
          }).toList();

          final filteredUsers = _filterByTab(allOthers);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // ── Clean nav bar ──
              CupertinoSliverNavigationBar(
                backgroundColor: context.isDark
                    ? NexTheme.darkBg
                    : CupertinoColors.white,
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

              // ── Solicitudes Pendientes (clean) ──
              SliverToBoxAdapter(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SocialService.instance.pendingRequestsStream,
                  builder: (context, pendingSnap) {
                    final pending = pendingSnap.data ?? [];
                    if (pending.isEmpty) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: () => _showPendingRequests(context, pending),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.dividerColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: MployaTheme.brandAccent.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(CupertinoIcons.person_2_fill, color: MployaTheme.brandAccent, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Solicitudes pendientes',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${pending.length} persona${pending.length == 1 ? '' : 's'} quiere${pending.length == 1 ? '' : 'n'} conectar',
                                    style: TextStyle(fontSize: 12, color: context.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: MployaTheme.brandAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${pending.length}',
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(CupertinoIcons.chevron_right, size: 14, color: context.textTertiary),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Section label: Afinidad IA ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Text(
                    myType == 'empresa'
                        ? 'TALENTO PARA VOS'
                        : 'EMPRESAS PARA VOS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ),

              // ── Carrusel Cross con afinidad real ──
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 260,
                  child: _buildCarousel(context, crossUsers, snapshot),
                ),
              ),

              // ── Divider ──
              SliverToBoxAdapter(child: Divider(height: 32, indent: 20, endIndent: 20, color: context.dividerColor)),

              // ── Section: Peers ──
              if (peerUsers.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      myType == 'empresa'
                          ? 'OTRAS EMPRESAS'
                          : 'PROFESIONALES COMO VOS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      itemCount: peerUsers.length,
                      itemBuilder: (context, index) {
                        final peer = peerUsers[index];
                        return _PeerChip(user: peer);
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: Divider(height: 24, indent: 20, endIndent: 20, color: context.dividerColor)),
              ],

              // ── Talentos Destacados ──
              if (allOthers.where((u) => u.profileViews > 10 || u.isVerified).isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(
                      children: [
                        Text(
                          '🏆 TALENTOS DESTACADOS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: context.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Top ${allOthers.where((u) => u.profileViews > 10 || u.isVerified).length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: MployaTheme.brandAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      itemCount: allOthers
                          .where((u) => u.profileViews > 10 || u.isVerified)
                          .take(10)
                          .length,
                      itemBuilder: (context, index) {
                        final featured = allOthers
                            .where((u) => u.profileViews > 10 || u.isVerified)
                            .toList()
                          ..sort((a, b) => b.profileViews.compareTo(a.profileViews));
                        final user = featured[index];
                        return _FeaturedTalentChip(user: user);
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: Divider(height: 24, indent: 20, endIndent: 20, color: context.dividerColor)),
              ],

              // ── Tab pills (clean outline style) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      _TabChip(
                        label: 'Activos',
                        isActive: _selectedTab == 0,
                        onTap: () => setState(() => _selectedTab = 0),
                      ),
                      const SizedBox(width: 8),
                      _TabChip(
                        label: 'Conectados',
                        isActive: _selectedTab == 1,
                        onTap: () => setState(() => _selectedTab = 1),
                      ),
                      const SizedBox(width: 8),
                      _TabChip(
                        label: 'Pendientes',
                        isActive: _selectedTab == 2,
                        onTap: () => setState(() => _selectedTab = 2),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Lista vertical filtrada por tab ──
              _buildList(filteredUsers, snapshot),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  /// Filtra usuarios según el tab seleccionado usando datos reales de conexiones
  List<NexUser> _filterByTab(List<NexUser> allOthers) {
    switch (_selectedTab) {
      case 1: // Conectados
        return allOthers.where((u) => u.connections > 0).toList();
      case 2: // Pendientes
        return allOthers;
      default: // Activos — todos
        return allOthers;
    }
  }

  void _showPendingRequests(BuildContext context, List<Map<String, dynamic>> pending) {
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
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ctx.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Solicitudes (${pending.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: ctx.textPrimary,
                      ),
                    ),
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
                  separatorBuilder: (_, __) => Divider(height: 1, color: ctx.dividerColor),
                  itemBuilder: (context, index) {
                    final req = pending[index];
                    final requesterId = req['requester_id']?.toString() ?? '';
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: Supabase.instance.client
                          .from('users')
                          .select('name, avatar_url, headline')
                          .eq('id', requesterId)
                          .maybeSingle(),
                      builder: (context, userSnap) {
                        final name = userSnap.data?['name']?.toString() ?? 'Usuario';
                        final headline = userSnap.data?['headline']?.toString() ?? '';
                        final avatar = userSnap.data?['avatar_url']?.toString();
                        return _PendingRequestTile(
                          name: name,
                          headline: headline,
                          avatarUrl: avatar,
                          onAccept: () async {
                            await MployaErrorHandler.instance.wrapAsync(
                              context,
                              () => SocialService.instance.respondConnection(requesterId, 'accept'),
                              successMessage: 'Conexión aceptada ✅',
                              errorMessage: 'No se pudo aceptar',
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          onDecline: () async {
                            await MployaErrorHandler.instance.wrapAsync(
                              context,
                              () => SocialService.instance.respondConnection(requesterId, 'reject'),
                              successMessage: 'Solicitud rechazada',
                              errorMessage: 'No se pudo rechazar',
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
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

  Widget _buildCarousel(
    BuildContext context,
    List<NexUser> users,
    AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
  ) {
    if (!snapshot.hasData) {
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
                style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Explorá el feed y conectá con empresas que buscan tu perfil.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary, fontSize: 13),
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
        final user = users[index];

        int realMutualCount = 0;
        double realAffinity = 0;
        if (_recommendedUsers != null) {
          final match = _recommendedUsers!.where(
            (r) => r['user_id']?.toString() == user.id,
          );
          if (match.isNotEmpty) {
            realMutualCount = (match.first['mutual_count'] as num?)?.toInt() ?? 0;
            realAffinity = (match.first['affinity_score'] as num?)?.toDouble() ?? 0;
          }
        }

        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ConnectionCard(
            user: user,
            mutualConnections: realMutualCount,
            affinityScore: realAffinity,
          ),
        );
      },
    );
  }

  Widget _buildList(
    List<NexUser> users,
    AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
  ) {
    if (!snapshot.hasData) {
      return const NetworkListSkeleton();
    }
    if (users.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            children: [
              Icon(
                _selectedTab == 1 ? CupertinoIcons.person_2 : CupertinoIcons.clock,
                size: 44,
                color: context.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                _selectedTab == 1
                    ? 'Aún no tenés conexiones.\n¡Empezá a conectar!'
                    : _selectedTab == 2
                        ? 'No hay solicitudes pendientes.'
                        : 'La red está vacía por ahora.\n¡Invita a tus contactos a Mploya!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: context.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _ConnectionListItem(user: users[index]),
        childCount: users.length,
      ),
    );
  }
}

// ── Peer Chip (clean, minimal) ──
class _PeerChip extends StatefulWidget {
  final NexUser user;
  const _PeerChip({required this.user});

  @override
  State<_PeerChip> createState() => _PeerChipState();
}

class _PeerChipState extends State<_PeerChip> {
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.dividerColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => ProfileScreen(user: widget.user)),
              );
            },
            child: NexAvatar(user: widget.user, size: 42, showBadge: false),
          ),
          const SizedBox(height: 8),
          Text(
            widget.user.name.split(' ').first,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            widget.user.headline.isNotEmpty
                ? widget.user.headline
                : widget.user.accountType,
            style: TextStyle(fontSize: 10, color: context.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          GestureDetector(
            onTap: _sent ? null : () async {
              setState(() => _sent = true);
              await SocialService.instance.sendConnectionRequest(widget.user.id);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _sent
                    ? (context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7))
                    : (context.isDark ? CupertinoColors.white : const Color(0xFF1C1C1E)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _sent ? 'Enviado' : 'Conectar',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _sent
                      ? context.textSecondary
                      : (context.isDark ? CupertinoColors.black : CupertinoColors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pending Request Tile (clean) ──
class _PendingRequestTile extends StatelessWidget {
  final String name;
  final String headline;
  final String? avatarUrl;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _PendingRequestTile({
    required this.name,
    required this.headline,
    this.avatarUrl,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MployaTheme.brandAccent.withValues(alpha: 0.1),
              image: (avatarUrl != null && avatarUrl!.isNotEmpty)
                  ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: (avatarUrl == null || avatarUrl!.isEmpty)
                ? Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: MployaTheme.brandAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary)),
                if (headline.isNotEmpty)
                  Text(headline, style: TextStyle(fontSize: 13, color: context.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
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
            onTap: onDecline,
            child: Icon(CupertinoIcons.xmark, size: 18, color: context.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ── Tab Chip (clean outline style) ──
class _TabChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _TabChip({required this.label, this.isActive = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (context.isDark ? CupertinoColors.white : const Color(0xFF1C1C1E))
              : context.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? (context.isDark ? CupertinoColors.white : const Color(0xFF1C1C1E))
                : context.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive
                ? (context.isDark ? CupertinoColors.black : CupertinoColors.white)
                : context.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Connection List Item (clean) ──
class _ConnectionListItem extends StatelessWidget {
  final NexUser user;

  const _ConnectionListItem({required this.user});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => ProfileScreen(user: user)),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.dividerColor.withValues(alpha: 0.6), width: 0.5)),
        ),
        child: Row(
          children: [
            NexAvatar(user: user, size: 48, showBadge: true),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.headline.isNotEmpty
                        ? user.headline
                        : 'Sin descripción aún',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Role badge (outline style)
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
                (user.accountType == 'empresa')
                    ? 'Empresa'
                    : (user.accountType == 'headhunter')
                        ? 'Hunter'
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
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => ChatDetailScreen(otherUser: user),
                  ),
                );
              },
              child: Icon(
                CupertinoIcons.chat_bubble,
                size: 20,
                color: context.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Featured Talent Chip (premium style with gold highlight) ──
class _FeaturedTalentChip extends StatelessWidget {
  final NexUser user;
  const _FeaturedTalentChip({required this.user});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => ProfileScreen(user: user)),
        );
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: context.isDark
                ? [const Color(0xFF2A2310), NexTheme.darkCard]
                : [const Color(0xFFFFF8E1), CupertinoColors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFDAA520),
                  width: 2,
                ),
              ),
              child: NexAvatar(user: user, size: 40, showBadge: false),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name.split(' ').first,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.headline,
                    style: TextStyle(fontSize: 10, color: context.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.eye, size: 10, color: Color(0xFFDAA520)),
                      const SizedBox(width: 3),
                      Text(
                        '${user.profileViews} vistas',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDAA520),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}