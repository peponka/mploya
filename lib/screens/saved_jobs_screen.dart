import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../services/saved_jobs_service.dart';
import '../widgets/mploya_toast.dart';
import '../widgets/mploya_shimmer.dart';
import '../widgets/nex_avatar.dart';
import '../models/models.dart';
import '../providers/user_provider.dart';
import 'job_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SavedJobsScreen — Pantalla unificada de Guardados (Perfiles + Vacantes)
//
// Tab 1: Perfiles guardados desde el feed (tabla saved_profiles)
// Tab 2: Vacantes guardadas desde Jobs (tabla saved_jobs)
//
// Accesible desde: ExploreScreen (bookmark button), JobsScreen, ProfileScreen
// ─────────────────────────────────────────────────────────────────────────────

class SavedJobsScreen extends ConsumerStatefulWidget {
  const SavedJobsScreen({super.key});

  @override
  ConsumerState<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends ConsumerState<SavedJobsScreen> {
  int _selectedTab = 0;

  /// Role detection — loaded from DB on init
  bool _isCompany = false;
  bool _roleLoaded = false;

  /// Label for the first tab based on role
  String get _profilesTabLabel => _isCompany ? 'Candidatos' : 'Empresas';

  // ── Perfiles guardados ──
  bool _loadingProfiles = true;
  List<NexUser> _savedProfiles = [];

  // ── Vacantes guardadas ──
  bool _loadingJobs = true;
  List<Map<String, dynamic>> _savedJobs = [];

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _detectRole();
    _loadSavedProfiles();
    _loadSavedJobs();
  }

  Future<void> _detectRole() async {
    try {
      NexUser? currentUserData;
      try {
        currentUserData = ref.read(currentUserProvider).value;
        currentUserData ??= await ref.read(manualUserRefreshProvider.future);
      } catch (e) {
        debugPrint('⚠️ SavedScreen: no se pudo leer currentUser ($e)');
      }
      final type = currentUserData?.accountType?.toLowerCase() ?? '';
      debugPrint('🔍 SavedScreen: accountType="$type", name="${currentUserData?.name}"');
      if (mounted) {
        setState(() {
          _isCompany = type == 'empresa' || type == 'headhunter';
          _roleLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error detecting role: $e');
      if (mounted) setState(() => _roleLoaded = true);
    }
  }

  // ─── Load Saved Profiles ─────────────────────────────────────────────────
  Future<void> _loadSavedProfiles() async {
    if (!mounted) return;
    setState(() => _loadingProfiles = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final rows = await Supabase.instance.client
          .from('saved_profiles')
          .select('saved_user_id, created_at, users!saved_profiles_saved_user_id_fkey(id, name, headline, avatar_url, account_type, video_url)')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      final profiles = <NexUser>[];
      final seenIds = <String>{};
      for (final row in rows) {
        final userData = row['users'] as Map<String, dynamic>?;
        if (userData != null) {
          final profile = NexUser.fromJson(userData);
          if (seenIds.contains(profile.id)) continue; // dedup
          // ── Ley de cruce: empresa ve candidatos, candidato ve empresas ──
          final savedType = profile.accountType.toLowerCase();
          if (_isCompany) {
            if (savedType == 'candidato' || savedType == 'confidencial') {
              profiles.add(profile);
              seenIds.add(profile.id);
            }
          } else {
            if (savedType == 'empresa' || savedType == 'headhunter') {
              profiles.add(profile);
              seenIds.add(profile.id);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _savedProfiles = profiles;
          _loadingProfiles = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved profiles: $e');
      // Fallback: try without join
      try {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid == null) return;
        final rows = await Supabase.instance.client
            .from('saved_profiles')
            .select('saved_user_id')
            .eq('user_id', uid)
            .order('created_at', ascending: false);

        final ids = rows.map<String>((r) => r['saved_user_id'].toString()).toList();
        if (ids.isEmpty) {
          if (mounted) setState(() { _savedProfiles = []; _loadingProfiles = false; });
          return;
        }

        final users = await Supabase.instance.client
            .from('users')
            .select()
            .inFilter('id', ids);

        final profiles = users.map<NexUser>((u) => NexUser.fromJson(u)).toList();

        // Preserve saved order
        final ordered = <NexUser>[];
        for (final id in ids) {
          final match = profiles.where((p) => p.id == id);
          if (match.isNotEmpty) ordered.add(match.first);
        }

        if (mounted) {
          setState(() {
            _savedProfiles = ordered;
            _loadingProfiles = false;
          });
        }
      } catch (e2) {
        debugPrint('Fallback also failed: $e2');
        if (mounted) setState(() { _savedProfiles = []; _loadingProfiles = false; });
      }
    }
  }

  // ─── Load Saved Jobs ──────────────────────────────────────────────────────
  Future<void> _loadSavedJobs() async {
    if (!mounted) return;
    setState(() => _loadingJobs = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final rows = await Supabase.instance.client
          .from('saved_jobs')
          .select('*, jobs(id, title, salary_range, modality, tags, created_at, company_id, users!jobs_company_id_fkey(name, avatar_url))')
          .eq('user_id', uid)
          .order('saved_at', ascending: false);

      if (mounted) {
        setState(() {
          _savedJobs = List<Map<String, dynamic>>.from(rows);
          _loadingJobs = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved jobs: $e');
      final jobs = await SavedJobsService.instance.fetchSavedJobs();
      if (mounted) {
        setState(() {
          _savedJobs = jobs;
          _loadingJobs = false;
        });
      }
    }
  }

  // ─── Remove Saved Profile ─────────────────────────────────────────────────
  Future<void> _removeProfile(String userId, int index) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _savedProfiles.removeAt(index));
    try {
      await Supabase.instance.client
          .from('saved_profiles')
          .delete()
          .eq('user_id', uid)
          .eq('saved_user_id', userId);
      if (mounted) MployaToast.removed(context, 'Perfil eliminado de guardados');
    } catch (e) {
      debugPrint('Error removing saved profile: $e');
      _loadSavedProfiles(); // Reload on error
    }
  }

  // ─── Remove Saved Job ─────────────────────────────────────────────────────
  Future<void> _removeSavedJob(String jobId, int index) async {
    setState(() => _savedJobs.removeAt(index));
    await SavedJobsService.instance.toggleSave(jobId);
    if (mounted) MployaToast.removed(context, 'Vacante eliminada de guardados');
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          backgroundColor: context.bgColor.withValues(alpha: 0.9),
          middle: const Text('Guardados'),
        ),
        child: SafeArea(child: MployaShimmer.listTile(count: 4)),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: context.bgColor.withValues(alpha: 0.9),
        middle: Text(_isCompany ? 'Candidatos Guardados' : 'Guardados'),
      ),
      child: SafeArea(
        child: _isCompany
            // Empresas: solo lista de candidatos guardados, sin tabs
            ? _buildProfilesTab()
            // Candidatos: tabs Empresas + Vacantes
            : Column(
                children: [
                  // ── Tab Selector ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildTab(_profilesTabLabel, 0, _savedProfiles.length),
                          _buildTab('Vacantes', 1, _savedJobs.length),
                        ],
                      ),
                    ),
                  ),

                  // ── Tab Content ──
                  Expanded(
                    child: _selectedTab == 0
                        ? _buildProfilesTab()
                        : _buildJobsTab(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTab(String label, int index, int count) {
    final active = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: active ? context.brandAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [BoxShadow(color: context.brandAccent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? CupertinoColors.white : context.textSecondary,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: active ? CupertinoColors.white.withValues(alpha: 0.25) : context.brandAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: active ? CupertinoColors.white : context.brandAccent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: Perfiles Guardados
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProfilesTab() {
    if (_loadingProfiles) return MployaShimmer.listTile(count: 6);

    if (_savedProfiles.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.person_2,
        title: 'Sin perfiles guardados',
        subtitle: 'Tocá el ícono 🔖 en los videos del feed para guardar candidatos o empresas.',
        actionLabel: 'Ir al Feed',
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await _loadSavedProfiles();
          },
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final user = _savedProfiles[index];
                return _SavedProfileCard(
                  user: user,
                  onRemove: () => _removeProfile(user.id, index),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => ProfileScreen(user: user)),
                  ),
                );
              },
              childCount: _savedProfiles.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: Vacantes Guardadas
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildJobsTab() {
    if (_loadingJobs) return MployaShimmer.listTile(count: 6);

    if (_savedJobs.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.briefcase,
        title: 'Sin vacantes guardadas',
        subtitle: 'Guardá vacantes desde la sección de empleos para verlas aquí.',
        actionLabel: 'Explorar vacantes',
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await _loadSavedJobs();
          },
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final saved = _savedJobs[index];
                final job = saved['jobs'] as Map<String, dynamic>? ?? saved;
                final jobId = job['id']?.toString() ?? saved['job_id']?.toString() ?? '';
                return _SavedJobCard(
                  job: job,
                  onRemove: () => _removeSavedJob(jobId, index),
                );
              },
              childCount: _savedJobs.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Empty State
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.brandAccent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: context.brandAccent.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: context.textTertiary, height: 1.4),
            ),
            const SizedBox(height: 28),
            CupertinoButton(
              color: MployaTheme.brandAccent,
              borderRadius: BorderRadius.circular(14),
              onPressed: () => Navigator.pop(context),
              child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Saved Profile Card
// ─────────────────────────────────────────────────────────────────────────────

class _SavedProfileCard extends StatelessWidget {
  final NexUser user;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _SavedProfileCard({required this.user, required this.onRemove, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.cardShadow,
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              NexAvatar(user: user, size: 52, showBadge: true),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.headline.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        user.headline,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Remove button
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onRemove();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MployaTheme.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    CupertinoIcons.bookmark_fill,
                    size: 18,
                    color: MployaTheme.brandAccent,
                  ),
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
// Saved Job Card
// ─────────────────────────────────────────────────────────────────────────────

class _SavedJobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onRemove;

  const _SavedJobCard({required this.job, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final title = job['title']?.toString() ?? 'Sin título';
    final salary = job['salary_range']?.toString();
    final modality = job['modality']?.toString() ?? '';
    final companyData = job['users'] as Map<String, dynamic>?;
    final companyName = companyData?['name']?.toString() ?? 'Empresa';
    final tagsRaw = job['tags'];
    final tags = tagsRaw is List ? tagsRaw.map((t) => t.toString()).toList() : <String>[];

    String modalityLabel = '';
    if (modality == 'remote') modalityLabel = '🏠 Remoto';
    if (modality == 'onsite') modalityLabel = '🏢 Presencial';
    if (modality == 'hybrid') modalityLabel = '🔄 Híbrido';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.cardShadow,
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => JobDetailScreen(job: job)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.brandAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    companyName.isNotEmpty ? companyName[0].toUpperCase() : '?',
                    style: TextStyle(color: context.brandAccent, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary, letterSpacing: -0.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(companyName, style: TextStyle(fontSize: 13, color: context.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (salary != null && salary.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(color: context.brandAccent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                            child: Text('\$ $salary', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.brandAccent)),
                          ),
                        if (modalityLabel.isNotEmpty)
                          Text(modalityLabel, style: TextStyle(fontSize: 11, color: context.textTertiary)),
                      ],
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        children: tags.take(3).map((t) => Text(
                          t.startsWith('#') ? t : '#$t',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF5F3DC4), fontWeight: FontWeight.w500),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onRemove();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: MployaTheme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(CupertinoIcons.bookmark_fill, size: 18, color: MployaTheme.brandAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
