import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../utils/headhunter_candidate_privacy.dart';
import '../../utils/user_columns.dart';
import '../profile_screen.dart';

class HeadhunterTalentPoolScreen extends StatefulWidget {
  const HeadhunterTalentPoolScreen({super.key, this.previewRows});

  final List<Map<String, dynamic>>? previewRows;

  @override
  State<HeadhunterTalentPoolScreen> createState() =>
      _HeadhunterTalentPoolScreenState();
}

class _HeadhunterTalentPoolScreenState
    extends State<HeadhunterTalentPoolScreen> {
  final _searchController = TextEditingController();
  bool _loading = true;
  bool _error = false;
  String _query = '';
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    final preview = widget.previewRows;
    if (preview != null) {
      _rows = _safeRows(preview);
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _safeRows(List<Map<String, dynamic>> rows) {
    return rows
        .where((row) {
          final type = (row['pin_type'] ?? row['account_type'] ?? 'candidato')
              .toString();
          return type != 'empresa' &&
              type != 'headhunter' &&
              !isConfidentialAccountType(type);
        })
        .toList(growable: false);
  }

  Future<void> _load() async {
    try {
      final result = await Supabase.instance.client.rpc(
        'get_explore_pins',
        params: {'p_lat': -25.2867, 'p_lng': -57.3333, 'p_radius_km': 500.0},
      );
      if (!mounted) return;
      setState(() {
        _rows = _safeRows(List<Map<String, dynamic>>.from(result ?? const []));
        _loading = false;
      });
    } catch (error) {
      debugPrint('Headhunter talent pool: $error');
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visibleRows {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _rows;
    return _rows.where((row) {
      final name = (row['pin_name'] ?? row['name'] ?? '')
          .toString()
          .toLowerCase();
      final headline = (row['pin_headline'] ?? row['headline'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(query) || headline.contains(query);
    }).toList();
  }

  Future<void> _openProfile(Map<String, dynamic> row) async {
    final id = (row['pin_id'] ?? row['id'])?.toString() ?? '';
    if (id.isEmpty) return;
    NexUser? candidate;
    if (widget.previewRows != null) {
      candidate = NexUser.fromJson({
        'id': id,
        'name': row['pin_name'] ?? row['name'] ?? 'Talento',
        'headline': row['pin_headline'] ?? row['headline'] ?? '',
        'avatar_url': row['avatar_url'],
        'account_type': row['pin_type'] ?? row['account_type'] ?? 'candidato',
      });
    } else {
      final data = await Supabase.instance.client
          .from('accessible_user_profiles')
          .select(kUserColumns)
          .eq('id', id)
          .maybeSingle();
      if (data != null) candidate = NexUser.fromJson(data);
    }
    if (candidate == null || !mounted) return;
    final visible = protectCandidateForHeadhunter(candidate, 'headhunter');
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) =>
            ProfileScreen(user: visible, viewerAccountType: 'headhunter'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visibleRows;
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 5),
              child: Text(
                'Talent Pool',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                  letterSpacing: -0.7,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Talento público disponible en Mploya',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B778C)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 17, 20, 14),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Buscar por nombre o especialidad',
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _error
                  ? _empty(
                      CupertinoIcons.exclamationmark_triangle,
                      'No pudimos cargar el Talent Pool',
                      'Revisá tu conexión y probá de nuevo.',
                    )
                  : rows.isEmpty
                  ? _empty(
                      CupertinoIcons.person_3,
                      _query.isEmpty
                          ? 'No hay talento público en esta zona'
                          : 'No encontramos coincidencias',
                      _query.isEmpty
                          ? 'Los perfiles confidenciales no aparecen en este listado.'
                          : 'Probá con otra búsqueda.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 112),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 11),
                      itemBuilder: (_, index) => _talentCard(rows[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(IconData icon, String title, String body) => Center(
    child: Padding(
      padding: const EdgeInsets.all(34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFF9AA7B8)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF263247),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Color(0xFF738095),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _talentCard(Map<String, dynamic> row) {
    final name = (row['pin_name'] ?? row['name'] ?? 'Talento').toString();
    final headline = (row['pin_headline'] ?? row['headline'] ?? '').toString();
    final avatar = row['avatar_url']?.toString() ?? '';
    final distance = row['distance_km'] as num?;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openProfile(row),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFE4E9F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FC),
                shape: BoxShape.circle,
                image: avatar.isEmpty
                    ? null
                    : DecorationImage(
                        image: NetworkImage(avatar),
                        fit: BoxFit.cover,
                      ),
              ),
              alignment: Alignment.center,
              child: avatar.isEmpty
                  ? Text(
                      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF185FA5),
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF263247),
                    ),
                  ),
                  if (headline.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6D798D),
                      ),
                    ),
                  ],
                  if (distance != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${distance.toDouble().toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF185FA5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 17,
              color: Color(0xFF9AA7B8),
            ),
          ],
        ),
      ),
    );
  }
}
