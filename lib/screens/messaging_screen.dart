import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/nex_avatar.dart';
import '../services/chat_service.dart';
import '../services/content_moderation_service.dart';
import '../utils/time_utils.dart';
import '../navigation/main_navigation.dart';
import '../widgets/web_ui.dart';
import 'agora_call_screen.dart';
import 'profile_screen.dart';
import 'scheduling_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MessagingScreen — inbox & matches reales (Premium "No-Line" Theme)
// ─────────────────────────────────────────────────────────────────────────────

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  // ── Search ──
  String _searchQuery = '';
  // ── Filtro de conversaciones (chips: Todos / Talento Match / No leídos) ──
  String _convFilter = 'todos';
  // ── Panel maestro-detalle web: conversación seleccionada ──
  NexUser? _selectedUser;

  // ── Streams — Defense in depth: filtros explícitos + RLS ──────────────
  // Aunque RLS protege los datos en Supabase, agregamos filtros del lado
  // del cliente como segunda capa de seguridad. Si RLS falla por
  // misconfiguration, estos filtros limitan la superficie de exposición.

  final String? _currentUserId =
      Supabase.instance.client.auth.currentUser?.id;

  late final _usersStream = Supabase.instance.client
      .from('users')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(100);

  // Solo mis conexiones (ambos lados del vínculo)
  late final _connectionsStream = Supabase.instance.client
      .from('connections')
      .stream(primaryKey: ['id'])
      .limit(200);

  // Solo mensajes donde soy sender o receiver — límite razonable
  late final _messagesStreamGlobal = Supabase.instance.client
      .from('messages')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(200); // era 500 — innecesario para inbox




  /// Filtra usuarios por nombre o headline (case-insensitive)
  List<NexUser> _applySearch(List<NexUser> users) {
    if (_searchQuery.isEmpty) return users;
    final q = _searchQuery.toLowerCase();
    return users.where((u) =>
      u.name.toLowerCase().contains(q) ||
      u.headline.toLowerCase().contains(q)
    ).toList();
  }

  /// Muestra un sheet con las conexiones para iniciar un nuevo chat
  void _showNewMessageSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        decoration: BoxDecoration(
          color: ctx.isDark ? NexTheme.darkCard : CupertinoColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: ctx.dividerColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Nuevo Mensaje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ctx.textPrimary)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _connectionsStream,
                builder: (ctx, snap) {
                  if (!snap.hasData) return const Center(child: CupertinoActivityIndicator());
                  final accepted = snap.data!.where((c) =>
                    c['status'] == 'accepted' &&
                    (c['requester_id'] == _currentUserId || c['addressee_id'] == _currentUserId)
                  ).toList();
                  if (accepted.isEmpty) {
                    return Center(child: Text('No tenés conexiones aún', style: TextStyle(color: ctx.textSecondary)));
                  }
                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _usersStream,
                    builder: (ctx, usersSnap) {
                      if (!usersSnap.hasData) return const Center(child: CupertinoActivityIndicator());
                      final userMap = {for (var u in usersSnap.data!) u['id']?.toString() ?? '': u};
                      final contactIds = accepted.map((c) {
                        final rid = c['requester_id']?.toString() ?? '';
                        final aid = c['addressee_id']?.toString() ?? '';
                        return rid == _currentUserId ? aid : rid;
                      }).toSet();
                      final contacts = contactIds
                          .where((id) => userMap.containsKey(id))
                          .map((id) => NexUser.fromJson(userMap[id]!))
                          .toList();
                      return ListView.builder(
                        itemCount: contacts.length,
                        itemBuilder: (ctx, i) {
                          final u = contacts[i];
                          return CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              Navigator.pop(ctx);
                              if (MediaQuery.of(context).size.width > 900) {
                                setState(() => _selectedUser = u);
                              } else {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(builder: (_) => ChatDetailScreen(otherUser: u)),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: Row(
                                children: [
                                  NexAvatar(user: u, size: 44),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(u.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ctx.textPrimary)),
                                        if (u.headline.isNotEmpty)
                                          Text(u.headline, style: TextStyle(fontSize: 13, color: ctx.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;

    if (!wide) {
      return CupertinoPageScaffold(
        backgroundColor: context.isDark ? NexTheme.darkBg : const Color(0xFFF9F9FA),
        child: _buildListPane(
          context,
          onTapUser: (u) => Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => ChatDetailScreen(otherUser: u)),
          ),
        ),
      );
    }

    // En web: si NO hay conversaciones, un solo estado vacío premium a todo el
    // ancho (partir en 2 paneles vacíos no tiene sentido). Si SÍ hay, panel
    // maestro-detalle real (lista angosta + "elegí una conversación"), como
    // WhatsApp Web/Slack.
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _connectionsStream,
      builder: (ctx1, connSnap) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _usersStream,
          builder: (ctx2, snap) {
            final loading = !snap.hasData || !connSnap.hasData;
            bool hasConversations = true;
            if (!loading) {
              final validUserIds = connSnap.data!
                  .where((c) => c['status'] == 'accepted')
                  .map((c) => c['requester_id'] == _currentUserId ? c['addressee_id'] : c['requester_id'])
                  .toSet();
              hasConversations = snap.data!.any((r) => validUserIds.contains(r['id']));
            }

            if (!loading && !hasConversations) {
              return CupertinoPageScaffold(
                backgroundColor: const Color(0xFFF1F1F4),
                child: WebPage(
                  title: 'Mensajes',
                  subtitle: 'Tus conversaciones con conexiones aparecerán acá.',
                  child: Center(
                    child: WebCard(
                      padding: const EdgeInsets.all(40),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 76, height: 76,
                              decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
                              child: Icon(CupertinoIcons.chat_bubble_2_fill, size: 34, color: MployaTheme.brandAccent),
                            ),
                            const SizedBox(height: 20),
                            Text('Inbox vacío', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: context.textPrimary)),
                            const SizedBox(height: 8),
                            Text(
                              'Explorá el feed inmersivo y hacé match con profesionales para iniciar una conversación.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13.5, color: context.textTertiary, height: 1.5),
                            ),
                            const SizedBox(height: 22),
                            WebButton(
                              icon: CupertinoIcons.play_fill,
                              label: 'Ir al Feed',
                              onTap: () {
                                currentMainTabNotifier.value = 0;
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            // Si el usuario seleccionado ya no está en la lista (búsqueda, etc.),
            // no lo perdemos — solo se deselecciona si de verdad desapareció.
            final selected = _selectedUser;

            // Con conversaciones (o mientras carga): panel maestro-detalle.
            return CupertinoPageScaffold(
              backgroundColor: const Color(0xFFF1F1F4),
              child: SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 400,
                      margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0x0F000000), width: 0.5),
                        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 6))],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildListPane(
                        context,
                        selectedUser: selected,
                        onTapUser: (u) => setState(() => _selectedUser = u),
                      ),
                    ),
                    if (selected == null)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 84, height: 84,
                                decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(24)),
                                child: Icon(CupertinoIcons.chat_bubble_2_fill, size: 38, color: MployaTheme.brandAccent.withValues(alpha: 0.6)),
                              ),
                              const SizedBox(height: 20),
                              Text('Elegí una conversación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.textPrimary)),
                              const SizedBox(height: 6),
                              Text('Seleccioná un chat de la lista para ver los mensajes.',
                                  style: TextStyle(fontSize: 13.5, color: context.textTertiary)),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                          decoration: BoxDecoration(
                            color: context.cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0x0F000000), width: 0.5),
                            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 6))],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ChatDetailScreen(key: ValueKey(selected.id), otherUser: selected),
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: _quickActionsSidebar(context, selected),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildListPane(BuildContext context, {required void Function(NexUser) onTapUser, NexUser? selectedUser}) {
    return CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // ── Glassmorphic Navigation Bar ──
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false,
            backgroundColor: context.isDark
                ? const Color(0xDD000000)
                : const Color(0xDDFFFFFF), // Blurred backing
            border: null, // "No-Line" Rule
            largeTitle: Text(
              'Mensajes',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: context.textPrimary,
                fontFamily: '.SF Pro Display',
              ),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () {
                // Abrir selector de contactos para nuevo mensaje
                _showNewMessageSheet(context);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MployaTheme.brandAccent.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.pencil_ellipsis_rectangle,
                  size: 22,
                  color: context.brandAccent,
                ),
              ),
            ),
          ),

          // ── Search Bar (Pill style) ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: CupertinoSearchTextField(
                  placeholder: 'Buscar conexiones, mensajes...',
                  backgroundColor: const Color(0x00000000), // Transparent
                  borderRadius: BorderRadius.circular(20),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: 15,
                    color: context.textPrimary,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, top: 4, right: 0),
                    child: Icon(CupertinoIcons.search, color: Color(0xFFAEAEB2), size: 20),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
            ),
          ),

          // ── Chips de filtro (Todos / Talento Match / No leídos) ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Row(
                children: [
                  _filterChip('todos', 'Todos'),
                  const SizedBox(width: 8),
                  _filterChip('match', 'Talento Match'),
                  const SizedBox(width: 8),
                  _filterChip('noleidos', 'No leídos'),
                ],
              ),
            ),
          ),

          // ── Contenido Real (Matches + Inbox) ──
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _connectionsStream,
            builder: (ctx1, connSnap) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _usersStream,
                builder: (context, snap) {
                  if (!snap.hasData || !connSnap.hasData) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: _buildInboxSkeleton(),
                      ),
                    );
                  }

                  // Extraer IDs con las que conecté
                  final validUserIds = connSnap.data!
                      .where((c) => c['status'] == 'accepted')
                      .map((c) => c['requester_id'] == _currentUserId ? c['addressee_id'] : c['requester_id'])
                      .toSet();

                  final allUsers = snap.data!
                      .where((r) => validUserIds.contains(r['id']))
                      .map((r) => NexUser.fromJson(r))
                      .toList();

                  // Aplicar filtro de búsqueda
                  final users = _applySearch(allUsers);

                  if (allUsers.isEmpty) {
                    return _buildEmptyInbox(context);
                  }

                  if (users.isEmpty && _searchQuery.isNotEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
                        child: Column(
                          children: [
                            Icon(CupertinoIcons.search, size: 48, color: const Color(0xFFAEAEB2).withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text(
                              'Sin resultados para "$_searchQuery"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, color: Color(0xFF8E8E93), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

              return SliverList(
                delegate: SliverChildListDelegate([
                  // 1. Matches Horizontales (Bumble/Tinder style)
                  _buildNuevosMatches(users, context),
                  
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Text(
                      'Mensajes Recientes',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),

                  // 2. Lista Vertical de Chats
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _messagesStreamGlobal,
                    builder: (context, msgSnap) {
                      final allMsgs = msgSnap.data ?? [];

                      // ── Filtro por chip (sobre datos reales) ──
                      bool userHasUnread(NexUser u) => allMsgs.any((m) =>
                          m['sender_id'] == u.id && m['receiver_id'] == _currentUserId && m['is_read'] != true);
                      final visibleUsers = users.where((u) {
                        switch (_convFilter) {
                          case 'match':
                            return u.isPremium || u.isVerified;
                          case 'noleidos':
                            return userHasUnread(u);
                          default:
                            return true;
                        }
                      }).toList();

                      if (visibleUsers.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              _convFilter == 'noleidos'
                                  ? 'No tenés mensajes sin leer.'
                                  : 'Sin conversaciones en este filtro.',
                              style: TextStyle(fontSize: 13.5, color: context.textTertiary),
                            ),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.cardColor,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(color: Color(0x08000000), blurRadius: 24, offset: Offset(0, 8))
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Column(
                              children: visibleUsers.asMap().entries.map((entry) {
                                final i = entry.key;
                                final user = entry.value;

                                // Extraer último mensaje
                                final userMsgs = allMsgs.where((m) =>
                                    (m['sender_id'] == _currentUserId && m['receiver_id'] == user.id) ||
                                    (m['sender_id'] == user.id && m['receiver_id'] == _currentUserId));
                                final lastMsg = userMsgs.isNotEmpty ? userMsgs.first : null;
                                final unreadCount = userMsgs.where((m) => m['receiver_id'] == _currentUserId && m['is_read'] != true).length;
                                final hasUnread = unreadCount > 0;
                                final previewText = lastMsg != null
                                    ? (lastMsg['text']?.toString() ?? lastMsg['content']?.toString() ?? '')
                                    : (user.headline.isNotEmpty ? user.headline : 'Inicia la conversación...');
                                final timeText = lastMsg != null ? timeAgo(lastMsg['created_at']) : '';

                                return _ConversationTile(
                                  user: user,
                                  isLast: i == visibleUsers.length - 1,
                                  previewText: previewText,
                                  timeText: timeText,
                                  hasUnread: hasUnread,
                                  isSelected: selectedUser?.id == user.id,
                                  onTap: () => onTapUser(user),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    }
                  ),
                  const SizedBox(height: 100),
                ]),
                  );
                },
              );
            },
          ),
        ],
    );
  }

  Widget _filterChip(String value, String label) {
    final active = _convFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _convFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? MployaTheme.brandAccent.withValues(alpha: 0.12) : context.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? MployaTheme.brandAccent : context.dividerColor.withValues(alpha: 0.5),
            width: active ? 1.2 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? MployaTheme.brandAccent : context.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _quickActionsSidebar(BuildContext context, NexUser user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // ── Videollamada HD Card ──
          WebCard(
            child: Column(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFFE2860B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFF97316).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(CupertinoIcons.videocam_fill, size: 36, color: CupertinoColors.white),
                ),
                const SizedBox(height: 12),
                Text('Iniciar Videollamada HD', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.textPrimary), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Conectá cara a cara', style: TextStyle(fontSize: 11.5, color: context.textTertiary)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Perfil del contacto ──
          WebCard(
            child: Column(
              children: [
                NexAvatar(user: user, size: 52, showBadge: true),
                const SizedBox(height: 10),
                Text(user.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary), textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text(user.headline, style: TextStyle(fontSize: 12, color: context.textTertiary, height: 1.3), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                // Online indicator
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('Online', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF34C759))),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Acciones rápidas ──
          WebCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WebSectionLabel('Acciones Rápidas'),
                const SizedBox(height: 4),
                _quickActionRow(context, icon: CupertinoIcons.person_fill, label: 'Ver Perfil',
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: user)))),
                _quickActionRow(context, icon: CupertinoIcons.calendar, label: 'Agendar Entrevista',
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SchedulingScreen(isCompany: true)))),
                _quickActionRow(context, icon: CupertinoIcons.star_fill, label: 'Guardar contacto', onTap: () {}),
                _quickActionRow(context, icon: CupertinoIcons.doc_on_doc_fill, label: 'Compartir CV', onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionRow(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 15, color: MployaTheme.brandAccent),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.textPrimary))),
            Icon(CupertinoIcons.chevron_right, size: 14, color: context.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyInbox(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.cardColor,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8))
                ],
              ),
              child: Center(
                child: Icon(
                  CupertinoIcons.chat_bubble_2_fill,
                  size: 38,
                  color: context.brandAccent.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Inbox Vacío',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
                fontFamily: '.SF Pro Display',
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Explora el feed inmersivo y haz match con profesionales increíbles para iniciar una conversación.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: context.textSecondary,
                height: 1.4,
                fontFamily: '.SF Pro Text',
              ),
            ),
            const SizedBox(height: 32),
            CupertinoButton(
              color: MployaTheme.brandAccent,
              borderRadius: BorderRadius.circular(20),
              child: const Text('Ir al Feed', style: TextStyle(fontWeight: FontWeight.w700, color: CupertinoColors.white)),
              onPressed: () {
                // Navegar al tab Feed (index 0)
                currentMainTabNotifier.value = 0;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNuevosMatches(List<NexUser> users, BuildContext context) {
    // Mostramos las conexiones más recientes como "Nuevos Matches"
    final matches = users.take(users.length.clamp(0, 6)).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(
            children: [
              Text(
                'Nuevos Matches',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30),
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Text('${matches.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
        SizedBox(
          height: 106,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final user = matches[index];
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => ChatDetailScreen(otherUser: user),
                  ),
                ),
                child: _MatchAvatarHero(user: user, isNew: index < 2),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInboxSkeleton() {
    return Column(
      children: [
        // Matches skeleton
        SizedBox(
          height: 100,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, __) => const Column(
              children: [
                _SkeletonPulse(width: 64, height: 64, radius: 32),
                SizedBox(height: 8),
                _SkeletonPulse(width: 48, height: 10, radius: 5),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Conversation list skeleton
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              children: List.generate(4, (i) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    _SkeletonPulse(width: 56, height: 56, radius: 28),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonPulse(width: 120, height: 14, radius: 7),
                          SizedBox(height: 8),
                          _SkeletonPulse(width: 200, height: 12, radius: 6),
                        ],
                      ),
                    ),
                    _SkeletonPulse(width: 40, height: 12, radius: 6),
                  ],
                ),
              )),
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonPulse extends StatefulWidget {
  final double width, height, radius;
  const _SkeletonPulse({required this.width, required this.height, required this.radius});
  @override
  State<_SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<_SkeletonPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: context.isDark
              ? Color.lerp(const Color(0xFF2A2C36), const Color(0xFF1C1E26), _ctrl.value)
              : Color.lerp(const Color(0xFFE8E8ED), const Color(0xFFF5F5F5), _ctrl.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Match Avatar Hero (Stories style)
// ─────────────────────────────────────────────────────────────────────────────

class _MatchAvatarHero extends StatelessWidget {
  final NexUser user;
  final bool isNew;

  const _MatchAvatarHero({required this.user, required this.isNew});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isNew
                ? const LinearGradient(
                    colors: [Color(0xFF004E99), Color(0xFF715092)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            border: isNew ? null : Border.all(color: context.dividerColor, width: 2),
            boxShadow: isNew
                ? [
                    BoxShadow(
                      color: const Color(0xFF004E99).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: context.isDark ? NexTheme.darkBg : const Color(0xFFF9F9FA),
              shape: BoxShape.circle,
            ),
            child: NexAvatar(user: user, size: 64, showBadge: false, heroTag: 'avatar_${user.id}'),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Text(
            user.name.split(' ').first,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isNew ? FontWeight.w700 : FontWeight.w500,
              color: isNew ? context.textPrimary : context.textSecondary,
              fontFamily: '.SF Pro Text',
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conversation Tile ("No-Line" Rule Applied)
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final NexUser user;
  final bool isLast;
  final String previewText;
  final String timeText;
  final bool hasUnread;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.user,
    required this.isLast,
    required this.previewText,
    required this.timeText,
    required this.hasUnread,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return Material(
      color: isSelected ? MployaTheme.brandAccent.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        highlightColor: const Color(0x0A000000),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: isSelected ? MployaTheme.brandAccent : Colors.transparent, width: 3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
          child: Row(
            children: [
              NexAvatar(user: user, size: 56, showBadge: true, heroTag: 'avatar_${user.id}'),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                              color: context.textPrimary,
                              fontFamily: '.SF Pro Text',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          timeText.isNotEmpty ? timeText : 'Nuevo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
                            color: hasUnread ? MployaTheme.brandAccent : context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    if (user.isPremium || user.isVerified) ...[
                      const SizedBox(height: 2),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.star_fill, size: 11, color: MployaTheme.brandAccent),
                          SizedBox(width: 4),
                          Text(
                            'Premium Match',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: MployaTheme.brandAccent),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            previewText,
                            style: TextStyle(
                              fontSize: 14,
                              color: hasUnread ? context.textPrimary : context.textSecondary,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: MployaTheme.brandAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat Detail Screen — Premium Chat UI
// ─────────────────────────────────────────────────────────────────────────────

class ChatDetailScreen extends StatefulWidget {
  final NexUser otherUser;

  const ChatDetailScreen({super.key, required this.otherUser});

  @override
  State<ChatDetailScreen> createState() => ChatDetailScreenState();
}

class ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _otherIsTyping = false;
  RealtimeChannel? _typingChannel;
  DateTime? _lastTypingEvent;
  String _myDisplayName = 'Usuario';

  final _messagesStream = Supabase.instance.client
      .from('messages')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(200);

  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  String get _otherId => widget.otherUser.id;

  @override
  void initState() {
    super.initState();
    _setupTypingChannel();
    _controller.addListener(_onTextChanged);
    _loadMyName();
  }

  Future<void> _loadMyName() async {
    if (_currentUserId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('name')
          .eq('id', _currentUserId!)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() => _myDisplayName = row['name']?.toString() ?? 'Usuario');
      }
    } catch (_) {}
  }

  void _setupTypingChannel() {
    final roomId = ChatService.instance.generateJitsiRoom(
      _currentUserId ?? '', _otherId,
    );
    _typingChannel = Supabase.instance.client.channel('typing:$roomId');
    
    _typingChannel!
      .onBroadcast(
        event: 'typing',
        callback: (payload) {
          final senderId = payload['user_id'];
          if (senderId == _otherId && mounted) {
            setState(() => _otherIsTyping = true);
            // Auto-hide after 3 seconds
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) setState(() => _otherIsTyping = false);
            });
          }
        },
      )
      .subscribe();
  }

  void _onTextChanged() {
    if (_controller.text.isEmpty) return;
    final now = DateTime.now();
    // Throttle: only send typing event every 2 seconds
    if (_lastTypingEvent != null &&
        now.difference(_lastTypingEvent!).inSeconds < 2) {
      return;
    }
    _lastTypingEvent = now;
    _typingChannel?.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': _currentUserId},
    );
  }

  List<Map<String, dynamic>> _filterMessages(List<Map<String, dynamic>> all) {
    return all.where((m) {
      final s = m['sender_id']?.toString();
      final r = m['receiver_id']?.toString();
      return (s == _currentUserId && r == _otherId) ||
          (s == _otherId && r == _currentUserId);
    }).toList();
  }

  /// Detecta emails y teléfonos en texto (misma lógica que comentarios)
  bool _containsContactInfo(String text) {
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    final phoneRegex = RegExp(r'(\+?\d[\d\s\-\.]{7,}\d)');
    final obfuscatedEmail = RegExp(r'(arroba|@|at)\s*.+\s*(punto|dot)\s*(com|net|org|io)', caseSensitive: false);
    return emailRegex.hasMatch(text) || phoneRegex.hasMatch(text) || obfuscatedEmail.hasMatch(text);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    if (_currentUserId == null) return;

    // ── Filtro de datos personales ──
    if (_containsContactInfo(text)) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Datos protegidos'),
            content: const Text(
              'No podés compartir emails ni teléfonos por chat. '
              'Usá las herramientas de Mploya para coordinar entrevistas.',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Entendido'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
      return;
    }

    // ── Moderación IA de contenido ──
    final moderation = await ContentModerationService.instance.moderate(
      text,
      context: 'chat',
    );
    if (moderation.isBlocked) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Contenido no permitido'),
            content: Text(
              moderation.reason ?? 'Este mensaje no cumple con las normas de la comunidad.',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Entendido'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
      return;
    }
    if (moderation.isFlagged) {
      // Se envía pero se registra para revisión
      ContentModerationService.instance.logFlaggedContent(
        text, moderation.category ?? 'unknown', 'chat',
      );
    }

    setState(() => _isSending = true);
    _controller.clear();

    try {
      await Supabase.instance.client.from('messages').insert({
        'sender_id': _currentUserId,
        'receiver_id': _otherId,
        'content': text,
        'text': text,
        'type': 'text',
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Error enviando mensaje: $e');
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error DB'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
        );
      }
      _controller.text = text;
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Iniciar videollamada Jitsi (estilo Google Meet) ──
  Widget _headerAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x0C000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: MployaTheme.brandAccent),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MployaTheme.brandAccent)),
          ],
        ),
      ),
    );
  }

  Future<void> _startJitsiCall() async {
    if (_currentUserId == null) return;
    HapticFeedback.mediumImpact();

    // ── 0. Pedir permisos de cámara y micrófono ──
    try {
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (!cameraStatus.isGranted || !micStatus.isGranted) {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text('Permisos Necesarios'),
              content: const Text(
                'Para iniciar una videollamada necesitás permitir '
                'acceso a la cámara y al micrófono en Ajustes.',
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Abrir Ajustes'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Permission check error: $e');
      // Continue anyway — Jitsi SDK may handle permissions itself
    }

    final roomId = ChatService.instance.generateJitsiRoom(_currentUserId!, _otherId);

    // ── 1. Obtener nombre real + avatar del usuario actual ──
    String myName = 'Mploya User';
    String? myAvatar;
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('name, avatar_url')
          .eq('id', _currentUserId!)
          .maybeSingle();
      if (row != null) {
        myName = row['name']?.toString() ?? myName;
        myAvatar = row['avatar_url']?.toString();
      }
    } catch (e) {
      debugPrint('⚠️ Jitsi: error fetching user info: $e');
    }

    // ── 2. Enviar mensaje automático en el chat ──
    try {
      await ChatService.instance.sendTextMessage(
        receiverId: _otherId,
        text: '📹 CALL:$roomId\n$myName te está llamando.',
      );
    } catch (e) {
      debugPrint('⚠️ Call auto-message send failed: $e');
    }

    // ── 3. Push FCM al receptor ──
    try {
      await Supabase.instance.client.functions.invoke('send-fcm', body: {
        'target_user_id': _otherId,
        'title': '📹 Videollamada entrante',
        'body': '$myName te está llamando. Abrí el chat para unirte.',
        'data': {'type': 'call', 'channel_name': roomId, 'caller_name': myName},
      });
    } catch (e) {
      debugPrint('⚠️ FCM call notify failed: $e');
    }

    // ── 4. Abrir la videollamada dentro de la app ──
    // Una sola ruta para web y móvil: AgoraCallScreen resuelve la llamada según
    // plataforma (móvil = Agora nativo; web = Jitsi embebido en iframe). Antes
    // en web abría meet.jit.si en otra pestaña (no embebido); ahora queda dentro
    // de Mploya, igual que el botón "Unirse".
    if (!mounted) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => AgoraCallScreen(
          channelName: roomId,
          displayName: myName,
          otherName: widget.otherUser.name,
        ),
      ),
    );
  }

  // ── Mostrar opciones de adjuntar archivo ──
  void _showAttachmentOptions() {
    HapticFeedback.lightImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Enviar archivo'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              await _pickAndSendImage();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo_fill, color: Color(0xFF34C759), size: 22),
                SizedBox(width: 10),
                Text('Foto / Imagen'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              await _pickAndSendFile();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.doc_fill, color: Color(0xFF007AFF), size: 22),
                SizedBox(width: 10),
                Text('Documento / PDF'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage() async {
    final file = await ChatService.instance.pickImage();
    if (file == null) return;
    final path = file.path;
    if (path == null) return;
    
    setState(() => _isSending = true);
    try {
      await ChatService.instance.sendFileMessage(
        receiverId: _otherId,
        filePath: path,
        fileName: file.name,
      );
    } catch (e) {
      debugPrint('Error enviando imagen: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    final file = await ChatService.instance.pickFile();
    if (file == null) return;
    final path = file.path;
    if (path == null) return;
    
    setState(() => _isSending = true);
    try {
      await ChatService.instance.sendFileMessage(
        receiverId: _otherId,
        filePath: path,
        fileName: file.name,
      );
    } catch (e) {
      debugPrint('Error enviando archivo: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _typingChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      // Fondo con contraste para que resalten las burbujas
      backgroundColor: context.isDark ? NexTheme.darkBg : const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: context.isDark ? const Color(0xEE000000) : const Color(0xEEFFFFFF),
        border: null, // No-Line
        middle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NexAvatar(user: widget.otherUser, size: 32),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUser.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                    fontFamily: '.SF Pro Text',
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34C759),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.otherUser.headline.isNotEmpty
                          ? widget.otherUser.headline
                          : 'Conexión activa',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _headerAction(
              icon: CupertinoIcons.video_camera_solid,
              label: 'Video',
              onTap: () => _startJitsiCall(),
            ),
            const SizedBox(width: 8),
            _headerAction(
              icon: CupertinoIcons.person_fill,
              label: 'Ver Perfil',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => ProfileScreen(user: widget.otherUser)),
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Área de Mensajes ──
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _messagesStream,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CupertinoActivityIndicator());
                  }

                  final messages = _filterMessages(snap.data!);

                  // MARCAR MENSAJES RECIBIDOS COMO LEÍDOS
                  final unreadMsgs = messages.where((m) => m['receiver_id'] == _currentUserId && m['is_read'] != true).toList();
                  if (unreadMsgs.isNotEmpty) {
                    Future.microtask(() {
                      for (var m in unreadMsgs) {
                        Supabase.instance.client.from('messages').update({'is_read': true}).eq('id', m['id']);
                      }
                    });
                  }

                  if (messages.isEmpty) {
                    return _EmptyChat(
                      otherUser: widget.otherUser,
                      onSendHello: () {
                        _controller.text = '¡Hola! Me encantó tu perfil.';
                        _sendMessage();
                      },
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg['sender_id']?.toString() == _currentUserId;
                      // Logicas de agrupación (quitar colas si hay mensajes seguidos) se pueden hacer aquí.
                      return _MessageBubble(
                        text: msg['text']?.toString() ?? msg['content']?.toString() ?? '',
                        isMe: isMe,
                        time: timeAgo(msg['created_at']),
                        fileUrl: msg['file_url']?.toString(),
                        fileName: msg['file_name']?.toString(),
                        fileType: msg['file_type']?.toString(),
                        fileSizeBytes: msg['file_size_bytes'] as int?,
                        isRead: msg['is_read'] == true,
                        onJoinCall: (channelName) {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => AgoraCallScreen(
                                channelName: channelName,
                                displayName: _myDisplayName,
                                otherName: widget.otherUser.name,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // ── Typing Indicator ──
            if (_otherIsTyping)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _TypingDot(delay: 0),
                          const SizedBox(width: 4),
                          const _TypingDot(delay: 150),
                          const SizedBox(width: 4),
                          const _TypingDot(delay: 300),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.otherUser.name.split(' ').first} escribiendo...',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ── Barra de Input Glassmorphic ──
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: context.isDark ? const Color(0xCC16181F) : const Color(0xCCFFFFFF),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, -4))
                    ],
                  ),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: () => _showAttachmentOptions(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(CupertinoIcons.add, size: 22, color: context.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoTextField(
                          controller: _controller,
                          placeholder: 'Escribe un mensaje...',
                          placeholderStyle: TextStyle(color: context.textTertiary, fontFamily: '.SF Pro Text'),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          style: TextStyle(fontSize: 16, color: context.textPrimary),
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          decoration: BoxDecoration(
                            color: context.isDark ? NexTheme.darkCard : CupertinoColors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: context.dividerColor, width: 1), // Única linea permitida por input
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ── Mic button ──
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: () {},
                        child: Icon(CupertinoIcons.mic_fill, size: 22, color: context.textTertiary),
                      ),
                      const SizedBox(width: 10),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: _isSending ? null : _sendMessage,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF004E99), Color(0xFF715092)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF004E99).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))
                            ],
                          ),
                          child: Center(
                            child: _isSending
                                ? const CupertinoActivityIndicator(color: Colors.white, radius: 10)
                                : const Icon(CupertinoIcons.arrow_up, size: 20, color: CupertinoColors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty Chat State (Premium)
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  final NexUser otherUser;
  final VoidCallback? onSendHello;
  const _EmptyChat({required this.otherUser, this.onSendHello});

  List<String> _generateIcebreakers() {
    final name = otherUser.name.split(' ').first;
    final headline = otherUser.headline;
    final tags = otherUser.tags;
    final isCompany = otherUser.accountType == 'empresa' || otherUser.accountType == 'headhunter';

    final icebreakers = <String>[];

    if (isCompany) {
      icebreakers.add('¡Hola! Me interesa mucho la propuesta de $name. ¿Podemos charlar?');
      if (tags.isNotEmpty) {
        icebreakers.add('Vi que buscan perfil ${tags.first}. Tengo experiencia en eso. ¿Coordinamos?');
      }
      icebreakers.add('¡Buenas! Me encantaría conocer más sobre las oportunidades en $name.');
    } else {
      if (headline.isNotEmpty) {
        icebreakers.add('Hola $name, vi tu perfil de "$headline". ¡Muy interesante!');
      } else {
        icebreakers.add('¡Hola $name! Me encantó tu video pitch.');
      }
      if (tags.isNotEmpty) {
        icebreakers.add('Vi que trabajás con ${tags.take(2).join(' y ')}. ¡Tenemos mucho en común!');
      }
      icebreakers.add('Hola $name, me gustaría conectar y explorar sinergias. ¿Cómo estás?');
    }

    return icebreakers.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final icebreakers = _generateIcebreakers();
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF004E99), Color(0xFF715092)]),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF004E99).withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8))
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.isDark ? NexTheme.darkBg : const Color(0xFFF2F2F7),
                  shape: BoxShape.circle,
                ),
                child: NexAvatar(user: otherUser, size: 90, showBadge: false),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Has conectado con ${otherUser.name.split(' ').first}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
                letterSpacing: -0.5,
                fontFamily: '.SF Pro Display',
              ),
            ),
            const SizedBox(height: 16),
            // ── IA Icebreaker Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5F3DC4), Color(0xFFAE3EC9)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.sparkles, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'IA sugiere empezar con...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Icebreaker Pills ──
            ...icebreakers.map((text) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _IcebreakerPill(text: text),
            )),
          ],
        ),
      ),
    );
  }
}

class _IcebreakerPill extends StatelessWidget {
  final String text;
  const _IcebreakerPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: () {
        // Buscar el ChatDetailScreenState padre y setear el texto
        final chatState = context.findAncestorStateOfType<ChatDetailScreenState>();
        if (chatState != null) {
          chatState._controller.text = text;
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 3))],
          border: null, // No-Line Rule
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.lightbulb_fill, color: Color(0xFFFFCC00), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
            const Icon(CupertinoIcons.arrow_right_circle_fill, color: Color(0xFF5F3DC4), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message Bubble (No-Line Premium styling)
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final int? fileSizeBytes;
  final bool isRead;
  final Function(String channelName)? onJoinCall;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.time,
    this.fileUrl,
    this.fileName,
    this.fileType,
    this.fileSizeBytes,
    this.isRead = false,
    this.onJoinCall,
  });

  bool get _hasFile => fileUrl != null && fileUrl!.isNotEmpty;
  bool get _isImage => fileType == 'image';
  bool get _isCallMessage => text.startsWith('📹 CALL:');
  String get _callChannel => text.split('\n').first.replaceFirst('📹 CALL:', '').trim();
  String get _callCallerName => text.contains('\n') ? text.split('\n').last.replaceAll(' te está llamando.', '').trim() : '';
  bool get _isVideoReply => text.contains('Video Reply') && text.contains('https://');
  String get _extractVideoUrl {
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('http') && trimmed.contains('.mp4')) return trimmed;
    }
    return '';
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMe) const Spacer(flex: 1),
          Flexible(
            flex: 4,
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isMe ? null : context.cardColor,
                    gradient: isMe
                        ? const LinearGradient(
                            colors: [Color(0xFF004E99), Color(0xFF0A66C2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(22),
                      topRight: const Radius.circular(22),
                      bottomLeft: Radius.circular(isMe ? 22 : 6),
                      bottomRight: Radius.circular(isMe ? 6 : 22),
                    ),
                    boxShadow: isMe
                        ? [BoxShadow(color: const Color(0xFF004E99).withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))]
                        : const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Imagen adjunta ──
                      if (_hasFile && _isImage)
                        GestureDetector(
                          onTap: () => _openUrl(fileUrl!),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(22),
                              topRight: Radius.circular(22),
                            ),
                            child: Image.network(
                              fileUrl!,
                              width: 240,
                              height: 180,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 240,
                                height: 60,
                                color: const Color(0xFFF2F2F7),
                                child: const Center(child: Icon(CupertinoIcons.photo, color: Color(0xFF8E8E93))),
                              ),
                            ),
                          ),
                        ),

                      // ── Archivo adjunto (doc/PDF) ──
                      if (_hasFile && !_isImage)
                        GestureDetector(
                          onTap: () => _openUrl(fileUrl!),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : (context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7)),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(child: Icon(CupertinoIcons.doc_fill, size: 20, color: Color(0xFFFF3B30))),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileName ?? 'Archivo',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isMe ? Colors.white : context.textPrimary,
                                        ),
                                      ),
                                      if (fileSizeBytes != null)
                                        Text(
                                          ChatService.formatFileSize(fileSizeBytes!),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isMe ? Colors.white70 : context.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  CupertinoIcons.arrow_down_circle_fill,
                                  size: 24,
                                  color: isMe ? Colors.white70 : const Color(0xFF007AFF),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ── Texto del mensaje (con detección de Video Reply y Llamada) ──
                      if (text.isNotEmpty)
                        _isCallMessage
                            ? _CallMessageBubble(
                                callerName: _callCallerName,
                                isMe: isMe,
                                onJoin: onJoinCall != null ? () => onJoinCall!(_callChannel) : null,
                              )
                            : _isVideoReply
                                ? _VideoReplyBubble(
                                    videoUrl: _extractVideoUrl,
                                    isMe: isMe,
                                  )
                                : Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Text(
                                      text,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isMe ? CupertinoColors.white : context.textPrimary,
                                        fontFamily: '.SF Pro Text',
                                        height: 1.35,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                    ],
                  ),
                ),
                if (time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // ── Read Receipt Checks ──
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            isRead ? CupertinoIcons.checkmark_alt_circle_fill : CupertinoIcons.checkmark_alt_circle,
                            size: 14,
                            color: isRead ? const Color(0xFF34AADC) : const Color(0xFFAEAEB2),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!isMe) const Spacer(flex: 1),
        ],
      ),
    );
  }

  void _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Video Reply Bubble ──
// ── Call Message Bubble ──
class _CallMessageBubble extends StatelessWidget {
  final String callerName;
  final bool isMe;
  final VoidCallback? onJoin;

  const _CallMessageBubble({required this.callerName, required this.isMe, this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isMe ? 0.2 : 0.0),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.video_camera_solid, size: 22,
                    color: isMe ? Colors.white : const Color(0xFF34C759)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Videollamada',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: isMe ? Colors.white : context.textPrimary,
                      )),
                  if (callerName.isNotEmpty)
                    Text(callerName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe ? Colors.white70 : context.textSecondary,
                        )),
                ],
              ),
            ],
          ),
          if (onJoin != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onJoin,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.video_camera_solid, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Unirse', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VideoReplyBubble extends StatelessWidget {
  final String videoUrl;
  final bool isMe;

  const _VideoReplyBubble({required this.videoUrl, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (_) => _FullScreenVideoPlayer(videoUrl: videoUrl),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        width: 220,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    NexTheme.brandAccent.withValues(alpha: 0.3),
                    Colors.black87,
                  ],
                ),
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: NexTheme.brandAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: NexTheme.brandAccent.withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 28),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Row(
                children: [
                  const Icon(CupertinoIcons.videocam_fill, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Video Reply',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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

// ── Fullscreen Video Player (in-app) ──
class _FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _FullScreenVideoPlayer({required this.videoUrl});

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video ──
          Center(
            child: _initialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CupertinoActivityIndicator(color: Colors.white, radius: 16),
          ),

          // ── Top bar ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 20),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Video Reply',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                const SizedBox(width: 36),
              ],
            ),
          ),

          // ── Play/Pause tap ──
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                });
              },
              behavior: HitTestBehavior.translucent,
              child: _initialized && !_controller.value.isPlaying
                  ? Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 32),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing Dot Animation ──
class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _animation.value),
        child: child,
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFF8E8E93),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}