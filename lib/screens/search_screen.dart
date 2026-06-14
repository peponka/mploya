import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/nex_avatar.dart';
import '../widgets/job_card.dart';
import 'profile_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedFilter = 0;
  bool _hasQuery = false;

  // ── Cache del future para no re-lanzar la query en cada rebuild ──
  Future<List<dynamic>>? _searchFuture;
  String _lastSearchQuery = '';
  int _lastSearchFilter = -1;

  // ── Filtros avanzados para vacantes ──
  String? _filterModality;
  String? _filterSeniority;
  static const _modalityOptions = {'remote': '🏠 Remoto', 'hybrid': '🔄 Híbrido', 'onsite': '🏢 Presencial'};
  static const _seniorityOptions = {'junior': 'Junior', 'mid': 'Mid', 'senior': 'Senior', 'lead': 'Lead', 'clevel': 'C-Level'};

  final _filters = ['Todos', 'Candidatos', 'Ofertas', 'Empresas', 'Vídeos', 'GPS'];

  final _trending = [
    'Remoto Senior',
    'Finanzas Madrid',
    'Flutter Development',
    'Diseñadores UI/UX',
    'Sector Hostelería',
  ];

  final List<String> _recentSearches = [
    'Chef Mediterráneo',
    'Desarrollador React',
    'Marketing B2B',
    'Startup Fintech',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _hasQuery = true;
      _lastSearchQuery = widget.initialQuery!;
      _lastSearchFilter = 0;
      // Lanzar búsqueda inicial con el tag recibido
      _searchFuture = _performSearch();
    }
    _searchController.addListener(() {
      final text = _searchController.text;
      setState(() {
        _hasQuery = text.isNotEmpty;
        // Solo relanzar la búsqueda si el texto realmente cambió
        if (text != _lastSearchQuery || _selectedFilter != _lastSearchFilter) {
          _lastSearchQuery = text;
          _lastSearchFilter = _selectedFilter;
          _searchFuture = _performSearch();
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: CupertinoSearchTextField(
          controller: _searchController,
          placeholder: 'Buscar talento, ofertas, empresas...',
          backgroundColor: context.isDark ? NexTheme.darkSurface : CupertinoColors.white,
          borderRadius: BorderRadius.circular(20),
          autofocus: true,
          style: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 15,
            color: context.textPrimary,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: TextStyle(
              fontSize: 15,
              color: context.brandAccent,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: _hasQuery ? _buildResults(context) : _buildSuggestions(context),
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // ── Recent Searches ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Búsquedas recientes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () {
                  setState(() {
                    _recentSearches.clear();
                  });
                },
                child: Text(
                  'Limpiar',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.brandAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((search) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = search;
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius:
                        BorderRadius.circular(MployaTheme.radiusPill),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.clock,
                        size: 14,
                        color: context.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        search,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── Trending ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 10),
          child: Text(
            'Trending en tu Sector',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ),
        ...List.generate(_trending.length, (index) {
          return _TrendingItem(
            rank: index + 1,
            topic: _trending[index],
            onTap: (topic) {
              _searchController.text = topic;
            },
          );
        }),

        // ── People in your industry ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 10),
          child: Text(
            'Sugerencias de la Red',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: Supabase.instance.client.from('users').select().limit(4),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(padding: EdgeInsets.all(20), child: Center(child: CupertinoActivityIndicator()));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: CupertinoColors.destructiveRed)));
            }
            if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
              return const Center(child: Text('Nada que sugerir'));
            }
            
            final List rows = snapshot.data as List;
            final users = rows.map((m) => NexUser.fromJson(m as Map<String, dynamic>)).toList();
            return Column(
              children: users.map((u) => _SuggestedPerson(user: u)).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<List<dynamic>> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return [];

    final client = Supabase.instance.client;
    List<dynamic> combinedResults = [];

    try {
      // Usar _selectedFilter: 0=Todos, 1=Candidatos, 2=Ofertas, 3=Empresas, 4=Vídeos, 5=GPS
      bool searchUsers = _selectedFilter != 2; // Buscar usuarios en todos lados excepto en solo "Ofertas"
      bool searchJobs = _selectedFilter == 0 || _selectedFilter == 2 || _selectedFilter == 3 || _selectedFilter == 5; // Buscar jobs en Todos, Ofertas, Empresas y GPS

      if (searchUsers) {
        // Buscar por nombre/headline con texto libre
        var queryBuilder = client.from('users').select().or('name.ilike.%$query%,headline.ilike.%$query%');
        
        // Si el filtro es Empresas, forzamos que traiga empresas
        if (_selectedFilter == 3) {
          queryBuilder = queryBuilder.eq('account_type', 'empresa');
        }
        
        final List userRows = await queryBuilder;

        // Buscar por tag exacto (array contains) 
        // Como Supabase text[] es sensible a mayúsculas, buscamos variaciones comunes
        final List tagRows = [];
        final qLower = query.toLowerCase();
        final qUpper = query.toUpperCase();
        final qCapital = query.isNotEmpty ? '${query[0].toUpperCase()}${query.substring(1).toLowerCase()}' : query;
        
        for (final q in {query, qLower, qUpper, qCapital}) {
          final rows = await client
              .from('users')
              .select()
              .contains('tags', [q]);
          tagRows.addAll(rows);
        }

        // Unir resultados deduplicando por id
        final Map<String, Map<String, dynamic>> seen = {};
        for (final r in [...userRows, ...tagRows]) {
          final id = r['id']?.toString() ?? '';
          if (id.isNotEmpty) seen[id] = r as Map<String, dynamic>;
        }
        final users = seen.values
            .map((m) => NexUser.fromJson(m))
            .toList();
        combinedResults.addAll(users);
      }

      if (searchJobs) {
        var jobQuery = client
            .from('jobs')
            .select('*, users!jobs_company_id_fkey(name, avatar_url)')
            .eq('is_active', true);

        if (query.isNotEmpty) {
          jobQuery = jobQuery.or('title.ilike.%$query%,location.ilike.%$query%,description.ilike.%$query%');
        }

        // Aplicar filtros avanzados
        if (_filterModality != null) {
          jobQuery = jobQuery.eq('modality', _filterModality!);
        }
        if (_filterSeniority != null) {
          jobQuery = jobQuery.eq('seniority', _filterSeniority!);
        }

        final List jobRows = await jobQuery.order('created_at', ascending: false).limit(30);

        final jobs = jobRows.map((r) {
          final companyData = r['users'] as Map<String, dynamic>?;
          return Job(
            id: r['id']?.toString() ?? '',
            title: r['title']?.toString() ?? 'Puesto',
            company: companyData?['name']?.toString() ?? 'Empresa',
            companyLogoUrl: companyData?['avatar_url']?.toString(),
            location: r['location']?.toString() ?? 'Ubicación',
            salaryRange: r['salary_range']?.toString(),
            postedAgo: 'Reciente',
            isRemote: r['modality'] == 'remote',
          );
        }).toList();
        combinedResults.addAll(jobs);
      }
    } catch (e) {
      debugPrint('Search error: $e');
      rethrow;
    }

    return combinedResults;
  }

  void _toggleAdvancedFilter(String type, String? value) {
    setState(() {
      if (type == 'modality') {
        _filterModality = _filterModality == value ? null : value;
      } else {
        _filterSeniority = _filterSeniority == value ? null : value;
      }
      _searchFuture = _performSearch();
    });
  }

  Widget _buildResults(BuildContext context) {
    return Column(
      children: [
        // ── Filter tabs ──
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            itemCount: _filters.length,
            itemBuilder: (context, index) {
              final isActive = _selectedFilter == index;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedFilter = index;
                    _lastSearchFilter = index;
                    // Reset advanced filters when switching tabs
                    _filterModality = null;
                    _filterSeniority = null;
                    _searchFuture = _performSearch();
                  }),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? MployaTheme.brandAccent
                          : context.cardColor,
                      borderRadius:
                          BorderRadius.circular(MployaTheme.radiusPill),
                      boxShadow: isActive
                          ? null
                          : const [
                              BoxShadow(
                                color: Color(0x0A000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              )
                            ],
                    ),
                    child: Center(
                      child: Text(
                        _filters[index],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? CupertinoColors.white
                              : context.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ── Advanced filters (Ofertas tab or Todos) ──
        if (_selectedFilter == 0 || _selectedFilter == 2)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ..._modalityOptions.entries.map((e) => _AdvancedFilterChip(
                      label: e.value,
                      isActive: _filterModality == e.key,
                      onTap: () => _toggleAdvancedFilter('modality', e.key),
                    )),
                Container(
                  width: 1,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  color: context.dividerColor,
                ),
                ..._seniorityOptions.entries.map((e) => _AdvancedFilterChip(
                      label: e.value,
                      isActive: _filterSeniority == e.key,
                      onTap: () => _toggleAdvancedFilter('seniority', e.key),
                    )),
              ],
            ),
          ),

        // ── Results List ──
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _searchFuture ??= _performSearch(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: CupertinoColors.destructiveRed)));
              }
              final results = snapshot.data!;
              
              if (results.isEmpty) {
                return Center(child: Text('No hay resultados', style: TextStyle(color: context.textTertiary)));
              }
              
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(top: 8),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final item = results[index];
                  if (item is NexUser) {
                    return _SearchResult(user: item);
                  } else if (item is Job) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: JobCard(job: item, index: index),
                    );
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrendingItem extends StatelessWidget {
  final int rank;
  final String topic;
  final ValueChanged<String>? onTap;

  const _TrendingItem({required this.rank, required this.topic, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap?.call(topic),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.textTertiary,
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.arrow_up_right,
              size: 14,
              color: MployaTheme.openToWork,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                topic,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: context.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestedPerson extends StatelessWidget {
  final NexUser user;

  const _SuggestedPerson({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          NexAvatar(user: user, size: 44, showBadge: true),
          const SizedBox(width: 12),
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
                Text(
                  user.headline,
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
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
            color: context.brandAccent.withValues(alpha: 0.10),
            onPressed: () {
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => ProfileScreen(user: user)),
              );
            },
            child: Text(
              'Contactar',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.brandAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResult extends StatelessWidget {
  final NexUser user;

  const _SearchResult({required this.user});

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            NexAvatar(user: user, size: 48, showBadge: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isPremium)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            CupertinoIcons.star_circle_fill,
                            size: 14,
                            color: MployaTheme.premiumGold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.headline,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.location != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        user.location!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 16, color: context.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ─── Advanced Filter Chip ─────────────────────────────────────────────────────

class _AdvancedFilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _AdvancedFilterChip({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(colors: [NexTheme.brandAccent, NexTheme.premiumEnd])
                : null,
            color: isActive ? null : context.cardColor,
            borderRadius: BorderRadius.circular(16),
            
            boxShadow: isActive
                ? [BoxShadow(color: NexTheme.brandAccent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? CupertinoColors.white : context.textSecondary,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
