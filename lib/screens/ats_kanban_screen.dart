import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'messaging_screen.dart';
import 'profile_screen.dart';

class AtsKanbanScreen extends StatefulWidget {
  const AtsKanbanScreen({super.key});

  @override
  State<AtsKanbanScreen> createState() => _AtsKanbanScreenState();
}

class _AtsKanbanScreenState extends State<AtsKanbanScreen> {
  // Lista temporal para el Kanban
  final Map<String, List<Map<String, dynamic>>> _columns = {
    'new': [],
    'interviewing': [],
    'hired': [],
    'rejected': [],
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    setState(() => _isLoading = true);
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final res = await Supabase.instance.client.rpc('get_my_pipeline');
      final List dynamicList = res as List;

      final cols = {
        'new': <Map<String, dynamic>>[],
        'interviewing': <Map<String, dynamic>>[],
        'hired': <Map<String, dynamic>>[],
        'rejected': <Map<String, dynamic>>[],
      };

      for (var row in dynamicList) {
        final sts = row['ats_status'] as String? ?? 'new';
        
        final partialMap = {
          'id': row['user_id'],
          'name': row['user_name'],
          'headline': row['user_headline'],
          'avatar_url': row['user_avatar_url'],
          'account_type': row['user_account_type'],
          'video_url': row['user_video_url'],
          // Forzar la lista en blanco para no errar mapping de DTO
          'tags': [], 
        };

        // Inject is_confidential
        partialMap['account_type'] = row['is_confidential'] == true ? 'confidencial' : row['user_account_type'];

        final combined = {
          'connection_id': row['connection_id'],
          'ats_status': sts,
          'user': NexUser.fromJson(partialMap),
        };

        if (cols.containsKey(sts)) {
          cols[sts]!.add(combined);
        } else {
          cols['new']!.add(combined);
        }
      }

      if (mounted) {
        setState(() {
          _columns['new'] = cols['new']!;
          _columns['interviewing'] = cols['interviewing']!;
          _columns['hired'] = cols['hired']!;
          _columns['rejected'] = cols['rejected']!;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching ATS: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeAtsStatus(String connectionId, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('connections')
          .update({'ats_status': newStatus})
          .eq('id', connectionId);
      _fetchMatches();
    } catch (e) {
      debugPrint('Error ATS update $e');
    }
  }

  Widget _buildKanbanCard(Map<String, dynamic> item) {
    final NexUser user = item['user'] as NexUser;
    final cId = item['connection_id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              CircleAvatar(
                radius: 20,
                backgroundColor: MployaTheme.brandAccent,
                backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty && !user.isConfidential) // FIXED: empty string check
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.isConfidential
                    ? const Icon(CupertinoIcons.eye_slash_fill, color: Colors.white, size: 20)
                    : ((user.avatarUrl == null || user.avatarUrl!.isEmpty) ? Text(user.initials, style: const TextStyle(color: Colors.white)) : null),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.isConfidential ? '${user.name.split(' ').first} (Confidencial)' : user.name,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.textPrimary, letterSpacing: -0.3),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.headline,
                      style: TextStyle(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    onPressed: () {
                      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ProfileScreen(user: user)));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: MployaTheme.brandAccent,
                        borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
                      ),
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.play_arrow_solid, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Ver Pitch', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    onPressed: () {
                      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => ChatDetailScreen(otherUser: user)));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: MployaTheme.brandAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
                      ),
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.chat_bubble_fill, size: 14, color: MployaTheme.brandAccent),
                          SizedBox(width: 4),
                          Text('Chat', style: TextStyle(fontSize: 13, color: MployaTheme.brandAccent, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              CupertinoButton(
                 padding: EdgeInsets.zero,
                 minimumSize: const Size(0, 0),
                 onPressed: () {
                   _showActionMenu(cId, (item['ats_status'] ?? 'new').toString());
                 },
                 child: Icon(CupertinoIcons.ellipsis_circle, color: context.textTertiary, size: 24),
              )
            ],
          )
        ],
      ),
    );
  }

  void _showActionMenu(String connectionId, String currentStatus) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Mover Candidato a...'),
        actions: [
          if (currentStatus != 'new')
            CupertinoActionSheetAction(
              child: const Text('Nuevos'),
              onPressed: () { Navigator.pop(context); _changeAtsStatus(connectionId, 'new'); },
            ),
          if (currentStatus != 'interviewing')
            CupertinoActionSheetAction(
              child: const Text('En Entrevista'),
              onPressed: () { Navigator.pop(context); _changeAtsStatus(connectionId, 'interviewing'); },
            ),
          if (currentStatus != 'hired')
            CupertinoActionSheetAction(
              child: const Text('Contratado'),
              onPressed: () { Navigator.pop(context); _changeAtsStatus(connectionId, 'hired'); },
            ),
          if (currentStatus != 'rejected')
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: const Text('Descartar'),
              onPressed: () { Navigator.pop(context); _changeAtsStatus(connectionId, 'rejected'); },
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  String _selectedTab = 'new';

  final Map<String, String> _tabLabels = {
    'new': 'Nuevos',
    'interviewing': 'Entrevista',
    'hired': 'Contratados',
    'rejected': 'Descartados',
  };

  final Map<String, Color> _tabColors = {
    'new': CupertinoColors.activeBlue,
    'interviewing': CupertinoColors.systemOrange,
    'hired': CupertinoColors.activeGreen,
    'rejected': CupertinoColors.systemRed,
  };

  @override
  Widget build(BuildContext context) {
    final list = _columns[_selectedTab] ?? [];

    return CupertinoPageScaffold(
      backgroundColor: context.bgColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Pipeline', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: context.cardColor.withValues(alpha: 0.8),
        border: null,
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : Column(
                children: [
                      // ── Tab Chips ──
                      SizedBox(
                        height: 48,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: _tabLabels.entries.map((e) {
                            final isActive = _selectedTab == e.key;
                            final color = _tabColors[e.key]!;
                            final count = _columns[e.key]?.length ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedTab = e.key),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isActive ? color : color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: isActive ? null : Border.all(color: color.withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        e.value,
                                        style: TextStyle(
                                          color: isActive ? Colors.white : color,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isActive ? Colors.white.withValues(alpha: 0.3) : color.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$count',
                                          style: TextStyle(
                                            color: isActive ? Colors.white : color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // ── Card List ──
                      Expanded(
                        child: list.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(CupertinoIcons.tray, size: 40, color: Colors.grey[300]),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Sin candidatos en esta etapa',
                                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                                physics: const BouncingScrollPhysics(),
                                itemCount: list.length,
                                itemBuilder: (context, index) {
                                  return _buildKanbanCard(list[index]);
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}