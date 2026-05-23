/// Pantalla de matches con dos vistas.
///
/// Vista A: 3 secciones horizontales (Empresas, Profesionales, Talentos).
/// Vista B: Lista de conexiones con filtros (Activos, Conectados, Pendientes).
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

// ─── Modelos mock ────────────────────────────────────────────────────

class _CompanyMatch {
  const _CompanyMatch({
    required this.name,
    required this.role,
    required this.initial,
    required this.color,
    required this.actionLabel,
    this.isRequested = false,
  });

  final String name;
  final String role;
  final String initial;
  final Color color;
  final String actionLabel;
  final bool isRequested;
}

class _ProfessionalMatch {
  const _ProfessionalMatch({
    required this.name,
    required this.role,
    required this.initial,
    required this.color,
  });

  final String name;
  final String role;
  final String initial;
  final Color color;
}

class _TopTalent {
  const _TopTalent({
    required this.name,
    required this.role,
    required this.initial,
    required this.color,
    required this.views,
  });

  final String name;
  final String role;
  final String initial;
  final Color color;
  final int views;
}

class _ConnectionItem {
  const _ConnectionItem({
    required this.name,
    required this.role,
    required this.initial,
    required this.color,
    required this.type,
    this.isVerified = false,
    this.isConnected = false,
    this.isPending = false,
  });

  final String name;
  final String role;
  final String initial;
  final Color color;
  final String type; // 'Empresa' or 'Candidato'
  final bool isVerified;
  final bool isConnected;
  final bool isPending;
}

const _companies = [
  _CompanyMatch(
    name: 'Tagua',
    role: 'Buscan Flutter Dev',
    initial: 'T',
    color: Color(0xFF8B6914),
    actionLabel: 'Contactar',
  ),
  _CompanyMatch(
    name: 'Claude',
    role: 'Buscan UX Designer',
    initial: 'C',
    color: Color(0xFFF97316),
    actionLabel: 'Match Solicitado',
    isRequested: true,
  ),
  _CompanyMatch(
    name: 'Lenovo',
    role: 'Product Manager',
    initial: 'L',
    color: Color(0xFF3B82F6),
    actionLabel: 'Contactar',
  ),
  _CompanyMatch(
    name: 'Meta',
    role: 'Backend Engineer',
    initial: 'M',
    color: Color(0xFF8B5CF6),
    actionLabel: 'Contactar',
  ),
];

const _professionals = [
  _ProfessionalMatch(
    name: 'Ana García',
    role: 'Frontend Dev',
    initial: 'A',
    color: Color(0xFFEC4899),
  ),
  _ProfessionalMatch(
    name: 'Pedro Ruiz',
    role: 'Data Analyst',
    initial: 'P',
    color: Color(0xFF06B6D4),
  ),
  _ProfessionalMatch(
    name: 'María Torres',
    role: 'Scrum Master',
    initial: 'M',
    color: Color(0xFFF97316),
  ),
  _ProfessionalMatch(
    name: 'Diego Vargas',
    role: 'iOS Developer',
    initial: 'D',
    color: Color(0xFF10B981),
  ),
  _ProfessionalMatch(
    name: 'Laura Paz',
    role: 'QA Engineer',
    initial: 'L',
    color: Color(0xFF8B5CF6),
  ),
];

const _talents = [
  _TopTalent(
    name: 'Camila Soto',
    role: 'Full Stack Dev',
    initial: 'C',
    color: Color(0xFF3B82F6),
    views: 0,
  ),
  _TopTalent(
    name: 'Andrés Mora',
    role: 'ML Engineer',
    initial: 'A',
    color: Color(0xFFF97316),
    views: 0,
  ),
  _TopTalent(
    name: 'Julieta Ríos',
    role: 'UI Designer',
    initial: 'J',
    color: Color(0xFFEC4899),
    views: 0,
  ),
];

const _connections = [
  _ConnectionItem(
    name: 'Tagua',
    role: 'Buscan Flutter Dev',
    initial: 'T',
    color: Color(0xFF8B6914),
    type: 'Empresa',
    isVerified: true,
    isConnected: true,
  ),
  _ConnectionItem(
    name: 'claude',
    role: 'Buscan UX Designer',
    initial: 'C',
    color: Color(0xFFF97316),
    type: 'Empresa',
    isVerified: true,
    isPending: true,
  ),
  _ConnectionItem(
    name: 'lenovo',
    role: 'Product Manager',
    initial: 'L',
    color: Color(0xFF3B82F6),
    type: 'Empresa',
    isVerified: true,
    isConnected: true,
  ),
  _ConnectionItem(
    name: 'meta',
    role: 'Backend Engineer',
    initial: 'M',
    color: Color(0xFF8B5CF6),
    type: 'Empresa',
    isVerified: true,
    isPending: true,
  ),
  _ConnectionItem(
    name: 'facebook',
    role: 'Social Media Mgr',
    initial: 'F',
    color: Color(0xFF3B82F6),
    type: 'Empresa',
    isVerified: true,
    isConnected: true,
  ),
  _ConnectionItem(
    name: 'Pedro',
    role: 'Data Analyst',
    initial: 'P',
    color: Color(0xFF06B6D4),
    type: 'Candidato',
    isPending: true,
  ),
  _ConnectionItem(
    name: 'Juan Gabriel',
    role: 'Flutter Dev',
    initial: 'J',
    color: Color(0xFF10B981),
    type: 'Candidato',
    isConnected: true,
  ),
];

const _top28Talents = [
  _TopTalent(name: 'Camila Soto', role: 'Full Stack Dev', initial: 'C', color: Color(0xFF3B82F6), views: 342),
  _TopTalent(name: 'Andrés Mora', role: 'ML Engineer', initial: 'A', color: Color(0xFFF97316), views: 318),
  _TopTalent(name: 'Julieta Ríos', role: 'UI Designer', initial: 'J', color: Color(0xFFEC4899), views: 295),
  _TopTalent(name: 'Sebastián Cruz', role: 'DevOps Engineer', initial: 'S', color: Color(0xFF10B981), views: 278),
  _TopTalent(name: 'Valentina López', role: 'Product Manager', initial: 'V', color: Color(0xFF8B5CF6), views: 261),
  _TopTalent(name: 'Mateo Herrera', role: 'Backend Dev', initial: 'M', color: Color(0xFF06B6D4), views: 244),
  _TopTalent(name: 'Isabella Ruiz', role: 'Data Scientist', initial: 'I', color: Color(0xFF8B6914), views: 230),
  _TopTalent(name: 'Lucas Fernández', role: 'iOS Developer', initial: 'L', color: Color(0xFFEF4444), views: 215),
  _TopTalent(name: 'Sofía Martínez', role: 'Scrum Master', initial: 'S', color: Color(0xFFF59E0B), views: 198),
  _TopTalent(name: 'Diego Paredes', role: 'Cloud Architect', initial: 'D', color: Color(0xFF6366F1), views: 185),
];

// ─── Matches Screen ──────────────────────────────────────────────────

class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> {
  bool _showListView = false;
  int _selectedFilter = 0;
  final Set<int> _connectedIndices = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.white,
      body: SafeArea(
        child: _showListView ? _buildListView() : _buildSectionsView(),
      ),
    );
  }

  // ─── View A: Three horizontal sections ─────────────────────────────

  Widget _buildSectionsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Matches',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: MployaColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showListView = true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MployaColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.list_rounded,
                      color: MployaColors.textSecondary,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          // Section 1: Empresas para vos
          _SectionHeader(title: 'EMPRESAS PARA VOS'),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 195,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _companies.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) =>
                  _CompanyCard(company: _companies[i]),
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

          const SizedBox(height: AppSpacing.xl),

          // Section 2: Profesionales como vos
          _SectionHeader(title: 'PROFESIONALES COMO VOS'),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _professionals.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) =>
                  _ProfessionalCard(professional: _professionals[i]),
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

          const SizedBox(height: AppSpacing.xl),

          // Section 3: Talentos destacados
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🏆  TALENTOS DESTACADOS',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MployaColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showTop28BottomSheet(context),
                  child: Text(
                    'Top 28',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MployaColors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _talents.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) =>
                  _TalentCard(talent: _talents[i]),
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
        ],
      ),
    );
  }

  // ─── View B: Connection list ───────────────────────────────────────

  List<_ConnectionItem> get _filteredConnections {
    switch (_selectedFilter) {
      case 1: // Conectados
        return _connections.where((c) => c.isConnected).toList();
      case 2: // Pendientes
        return _connections.where((c) => c.isPending).toList();
      default: // Activos = todos
        return _connections;
    }
  }

  void _showTop28BottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MployaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MployaColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    '🏆  Top 28 Talentos Destacados',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: MployaColors.textPrimary,
                    ),
                  ),
                ),
                const Divider(color: MployaColors.borderLight, height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: _top28Talents.length,
                    separatorBuilder: (_, _) => const Divider(
                      color: MployaColors.borderLight,
                      height: 1,
                    ),
                    itemBuilder: (ctx, i) {
                      final t = _top28Talents[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                '#${i + 1}',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: i < 3
                                      ? MployaColors.orange
                                      : MployaColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: t.color,
                              child: Text(
                                t.initial,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: MployaColors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: MployaColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    t.role,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: MployaColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.visibility_outlined,
                                    size: 14, color: MployaColors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  '${t.views}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: MployaColors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildListView() {
    final filters = ['Activos', 'Conectados', 'Pendientes'];
    final filteredList = _filteredConnections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back + Title
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _showListView = false),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20),
              ),
              Text(
                'Matches',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: MployaColors.textPrimary,
                ),
              ),
            ],
          ),
        ),

        // Top horizontal cards
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: _talents.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final t = _talents[i];
              return Container(
                width: 110,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: MployaColors.surfaceVariant,
                  borderRadius:
                      BorderRadius.circular(AppRadius.lg),
                  border:
                      Border.all(color: MployaColors.borderLight),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: t.color,
                      child: Text(
                        t.initial,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MployaColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MployaColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.visibility_outlined,
                            size: 12, color: MployaColors.orange),
                        const SizedBox(width: 3),
                        Text(
                          '${t.views} vistas',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: MployaColors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Filter tabs
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: List.generate(filters.length, (i) {
              final isSelected = _selectedFilter == i;
              return Padding(
                padding: EdgeInsets.only(
                    right: i < filters.length - 1 ? AppSpacing.sm : 0),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _selectedFilter = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? MployaColors.textPrimary
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: isSelected
                            ? MployaColors.textPrimary
                            : MployaColors.border,
                      ),
                    ),
                    child: Text(
                      filters[i],
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? MployaColors.white
                            : MployaColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Connection list (filtered)
        Expanded(
          child: filteredList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'No hay conexiones en esta categoría',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: MployaColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: filteredList.length,
                  separatorBuilder: (_, _) => const Divider(
                    color: MployaColors.borderLight,
                    height: 1,
                  ),
                  itemBuilder: (context, i) {
                    final conn = filteredList[i];
                    // Find original index for connected-state tracking
                    final originalIndex = _connections.indexOf(conn);
                    return _ConnectionTile(
                      connection: conn,
                      isConnectedState: _connectedIndices.contains(originalIndex),
                      onToggleConnect: () {
                        setState(() {
                          if (_connectedIndices.contains(originalIndex)) {
                            _connectedIndices.remove(originalIndex);
                          } else {
                            _connectedIndices.add(originalIndex);
                          }
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Section header ──────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: MployaColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Company Card ────────────────────────────────────────────────────

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.company});
  final _CompanyMatch company;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MployaColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: MployaColors.borderLight),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar with green verified badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: company.color,
                child: Text(
                  company.initial,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: MployaColors.white,
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: MployaColors.teal,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MployaColors.surfaceVariant,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: MployaColors.white,
                    size: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            company.name,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MployaColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            company.role,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MployaColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Action button
          SizedBox(
            width: double.infinity,
            height: 32,
            child: company.isRequested
                ? OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Match con ${company.name} pendiente ⏳'),
                          backgroundColor: MployaColors.textSecondary,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: MployaColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    child: Text(
                      company.actionLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: MployaColors.textSecondary,
                      ),
                    ),
                  )
                : OutlinedButton(
                    onPressed: () {
                      final id = company.name.toLowerCase().replaceAll(' ', '-');
                      context.push('/chat/match-$id');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: MployaColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    child: Text(
                      company.actionLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MployaColors.textPrimary,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Professional Card ───────────────────────────────────────────────

class _ProfessionalCard extends StatefulWidget {
  const _ProfessionalCard({required this.professional});
  final _ProfessionalMatch professional;

  @override
  State<_ProfessionalCard> createState() => _ProfessionalCardState();
}

class _ProfessionalCardState extends State<_ProfessionalCard> {
  bool _connected = false;

  @override
  Widget build(BuildContext context) {
    final professional = widget.professional;
    return Container(
      width: 130,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MployaColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: MployaColors.borderLight),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: professional.color,
            child: Text(
              professional.initial,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MployaColors.white,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            professional.name,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MployaColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            professional.role,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MployaColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 30,
            child: _connected
                ? OutlinedButton(
                    onPressed: () => setState(() => _connected = false),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: MployaColors.teal),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    child: Text(
                      'Conectado ✓',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MployaColors.teal,
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: () => setState(() => _connected = true),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: MployaColors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Conectar',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MployaColors.white,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Talent Card ─────────────────────────────────────────────────────

class _TalentCard extends StatelessWidget {
  const _TalentCard({required this.talent});
  final _TopTalent talent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MployaColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: MployaColors.borderLight),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: talent.color,
            child: Text(
              talent.initial,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MployaColors.white,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            talent.name,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MployaColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            talent.role,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MployaColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.visibility_outlined,
                size: 14,
                color: MployaColors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                '${talent.views} vistas',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MployaColors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Connection list tile ────────────────────────────────────────────

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({
    required this.connection,
    required this.isConnectedState,
    required this.onToggleConnect,
  });

  final _ConnectionItem connection;
  final bool isConnectedState;
  final VoidCallback onToggleConnect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Avatar with green badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: connection.color,
                child: Text(
                  connection.initial,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: MployaColors.white,
                  ),
                ),
              ),
              if (connection.isVerified)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: MployaColors.teal,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MployaColors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: MployaColors.white,
                      size: 8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),

          // Name + role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connection.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  connection.role,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MployaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Connect / Connected toggle button
          GestureDetector(
            onTap: onToggleConnect,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: isConnectedState
                    ? MployaColors.teal.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: isConnectedState
                      ? MployaColors.teal
                      : MployaColors.orange,
                ),
              ),
              child: Text(
                isConnectedState ? 'Conectado ✓' : 'Conectar',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isConnectedState
                      ? MployaColors.teal
                      : MployaColors.orange,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Chat icon
          GestureDetector(
            onTap: () {
              final id = connection.name.toLowerCase().replaceAll(' ', '-');
              context.push('/chat/match-$id');
            },
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: MployaColors.textTertiary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}
