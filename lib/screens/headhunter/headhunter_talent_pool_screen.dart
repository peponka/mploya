import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../utils/headhunter_candidate_privacy.dart';
import '../../utils/user_columns.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../profile_screen.dart';

/// Talent Pool de Headhunter.
///
/// Migrada al sistema de diseño (18/8/2026), 3ª pantalla — mismo patrón de
/// `headhunter_dashboard_screen.dart` / `headhunter_pipeline_screen.dart`.
///
/// SIN mockup 1:1, mismo motivo que Pipeline: `Headhunter_Talent_Pool.png`
/// describe una base de talento propia con categorías por skill, 5 stat
/// tiles agregados, match IA y video-thumbnails por candidato — nada de
/// eso existe. El dato real sale de `get_explore_pins` (candidatos
/// públicos cerca de una ubicación fija): nombre, headline, avatar,
/// distancia. Se migró el patrón de tarjeta, no la composición del
/// mockup:
///
///   · Buscador          → `CupertinoSearchTextField` sin cambios (widget
///     nativo, sin color hardcodeado que migrar).
///   · Tarjeta de talento → [MpListRow], leading [MpAvatar], `trailingText`
///     con la distancia (reemplaza el chevron+distancia manual: mostrar
///     ambos requeriría `trailing` custom, y la distancia sola ya
///     transmite lo mismo con menos ruido).
///   · Estado vacío       → mismo patrón compacto de Dashboard/Pipeline
///     ([MpCard] + [MpIconTile] circular + texto).
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
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MpTokens.screenPadding,
                MpTokens.space20,
                MpTokens.screenPadding,
                MpTokens.space4,
              ),
              child: _header(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MpTokens.screenPadding,
                MpTokens.space16,
                MpTokens.screenPadding,
                MpTokens.space12,
              ),
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
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        MpTokens.screenPadding,
                        0,
                        MpTokens.screenPadding,
                        MpTokens.space32,
                      ),
                      children: [
                        MpRowGroup(
                          rows: [for (final row in rows) _talentRow(row)],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final s = context.mp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Talent Pool', style: MpTokens.h2.copyWith(color: s.text, fontSize: 24)),
        const SizedBox(height: MpTokens.space4),
        Text(
          'Talento público disponible en Mploya',
          style: MpTokens.body.copyWith(color: s.textSecondary),
        ),
      ],
    );
  }

  Widget _talentRow(Map<String, dynamic> row) {
    final name = (row['pin_name'] ?? row['name'] ?? 'Talento').toString();
    final headline = (row['pin_headline'] ?? row['headline'] ?? '').toString();
    final avatar = row['avatar_url']?.toString() ?? '';
    final distance = row['distance_km'] as num?;

    return MpListRow(
      leading: MpAvatar(
        image: avatar.isEmpty ? null : NetworkImage(avatar),
        name: name,
        size: 50,
      ),
      title: name,
      subtitle: headline.trim().isEmpty ? null : headline,
      trailingText: distance == null
          ? null
          : '${distance.toDouble().toStringAsFixed(1)} km',
      onTap: () => _openProfile(row),
    );
  }

  Widget _empty(IconData icon, String title, String body) {
    final s = context.mp;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MpTokens.space32),
        child: MpCard(
          padding: const EdgeInsets.symmetric(
            horizontal: MpTokens.space16,
            vertical: MpTokens.space24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MpIconTile(icon: icon, color: s.textTertiary, size: 44, circular: true),
              const SizedBox(height: MpTokens.space12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: MpTokens.title.copyWith(color: s.text),
              ),
              const SizedBox(height: MpTokens.space4),
              Text(
                body,
                textAlign: TextAlign.center,
                style: MpTokens.caption.copyWith(color: s.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
