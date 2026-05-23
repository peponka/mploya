/// Pantalla de perfil de empresa con 3 tabs.
///
/// Header: logo, badges, stats.
/// Tabs: Empresa, Posiciones, Herramientas.
/// Diseño diferenciado del perfil de candidato.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/features/profile/models/company_profile_store.dart';

// ─── Perks icon mapping ──────────────────────────────────────────────

const _perkIcons = <String, IconData>{
  'Trabajo remoto': Icons.home_work_outlined,
  'Horario flexible': Icons.schedule_outlined,
  'Stock options': Icons.trending_up_rounded,
  'Capacitación': Icons.school_outlined,
  'Gym': Icons.fitness_center_outlined,
  'Almuerzo': Icons.restaurant_outlined,
  'Vacaciones extra': Icons.beach_access_outlined,
  'Bono anual': Icons.card_giftcard_outlined,
};

// ─── Mock job data ───────────────────────────────────────────────────

class _MockJob {
  const _MockJob({
    required this.title,
    required this.modality,
    required this.salaryRange,
    required this.applicants,
  });
  final String title;
  final String modality;
  final String salaryRange;
  final int applicants;
}

const _mockJobs = [
  _MockJob(
    title: 'Senior Flutter Developer',
    modality: 'Remoto',
    salaryRange: '\$3,000 - 5,000/mes',
    applicants: 12,
  ),
  _MockJob(
    title: 'Product Designer',
    modality: 'Híbrido',
    salaryRange: '\$2,500 - 4,000/mes',
    applicants: 8,
  ),
  _MockJob(
    title: 'Data Engineer',
    modality: 'Remoto',
    salaryRange: '\$4,000 - 6,500/mes',
    applicants: 5,
  ),
];

// ─── Company Profile Screen ──────────────────────────────────────────

class CompanyProfileScreen extends ConsumerStatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  ConsumerState<CompanyProfileScreen> createState() =>
      _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends ConsumerState<CompanyProfileScreen> {
  int _selectedTab = 0;

  static const _tabIcons = [
    Icons.business_outlined,
    Icons.work_outline,
    Icons.auto_awesome_outlined,
  ];

  static const _tabLabels = ['Empresa', 'Posiciones', 'Herramientas'];

  // ── Helpers ──

  String get _companyName {
    final name = CompanyProfileStore.companyName;
    return name.isNotEmpty ? name : 'Mi Empresa';
  }

  String get _companyInitial => _companyName.isNotEmpty ? _companyName[0] : 'M';

  String get _description {
    final desc = CompanyProfileStore.description;
    return desc.isNotEmpty
        ? desc
        : 'Empresa innovadora buscando talento excepcional';
  }

  List<String> get _activePerks => CompanyProfileStore.activePerks;

  List<String> get _industries => CompanyProfileStore.industries;

  List<String> get _cultureValues => CompanyProfileStore.cultureValues;

  List<String> get _techStack => CompanyProfileStore.techStack;

  // ═════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header section ──
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  _buildCompanyAvatar()
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(begin: const Offset(0.9, 0.9)),
                  const SizedBox(height: AppSpacing.md),
                  _buildCompanyName()
                      .animate()
                      .fadeIn(delay: 50.ms, duration: 400.ms),
                  const SizedBox(height: AppSpacing.sm),
                  _buildOrgTypeBadge()
                      .animate()
                      .fadeIn(delay: 80.ms, duration: 400.ms),
                  const SizedBox(height: AppSpacing.sm),
                  _buildIndustryChips()
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 400.ms),
                  const SizedBox(height: AppSpacing.md),
                  _buildBadgesRow()
                      .animate()
                      .fadeIn(delay: 120.ms, duration: 400.ms),
                  const SizedBox(height: AppSpacing.lg),
                  _buildStats()
                      .animate()
                      .fadeIn(delay: 150.ms, duration: 400.ms),
                  const SizedBox(height: AppSpacing.lg),
                  _buildTabs()
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 400.ms),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),

            // ── Tab content ──
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: AnimDurations.normal,
                child: _buildTabContent(),
              ),
            ),

            // ── Bottom padding ──
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.xxl),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // HEADER WIDGETS
  // ═════════════════════════════════════════════════════════════════════

  /// Large circle with company initial and gradient orange background.
  Widget _buildCompanyAvatar() {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          gradient: MployaColors.orangeGradientVertical,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: MployaColors.orange.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            _companyInitial,
            style: GoogleFonts.outfit(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: MployaColors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyName() {
    return Text(
      _companyName,
      style: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: MployaColors.textPrimary,
      ),
    );
  }

  /// Org type displayed as a subtle outlined pill.
  Widget _buildOrgTypeBadge() {
    final orgType = CompanyProfileStore.orgType;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        color: MployaColors.orangeSurface,
        border: Border.all(
          color: MployaColors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        orgType,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: MployaColors.orangeDark,
        ),
      ),
    );
  }

  /// Industry tags as horizontal chip row.
  Widget _buildIndustryChips() {
    if (_industries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        alignment: WrapAlignment.center,
        children: _industries.map((industry) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              color: MployaColors.surfaceVariant,
            ),
            child: Text(
              industry,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: MployaColors.textSecondary,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Verified + "Contratando ✅" badges.
  Widget _buildBadgesRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Verified badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: MployaColors.teal),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  color: MployaColors.teal, size: 14),
              const SizedBox(width: 4),
              Text(
                'Verificado',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MployaColors.teal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Contratando badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            color: MployaColors.tealLight,
            border: Border.all(color: MployaColors.teal),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✅', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                'Contratando',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MployaColors.teal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Stats row: Aplicantes | Vistas | Posiciones.
  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _CompanyStatColumn(value: '24', label: 'Aplicantes'),
            const VerticalDivider(
              color: MployaColors.borderLight,
              width: AppSpacing.xl,
              thickness: 1,
            ),
            _CompanyStatColumn(value: '156', label: 'Vistas'),
            const VerticalDivider(
              color: MployaColors.borderLight,
              width: AppSpacing.xl,
              thickness: 1,
            ),
            _CompanyStatColumn(value: '3', label: 'Posiciones'),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // TABS
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: List.generate(_tabLabels.length, (i) {
          final isSelected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(
                  right: i < _tabLabels.length - 1 ? AppSpacing.sm : 0,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? MployaColors.orange : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color:
                        isSelected ? MployaColors.orange : MployaColors.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _tabIcons[i],
                      size: 16,
                      color: isSelected
                          ? MployaColors.white
                          : MployaColors.textPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _tabLabels[i],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? MployaColors.white
                            : MployaColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildEmpresaTab();
      case 1:
        return _buildPosicionesTab();
      case 2:
        return _buildHerramientasTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // TAB 1: EMPRESA
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildEmpresaTab() {
    return Column(
      key: const ValueKey('empresa'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSobreNosotros()
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.03, end: 0),
        const SizedBox(height: AppSpacing.xl),
        _buildCulturaYValores()
            .animate()
            .fadeIn(delay: 100.ms, duration: 400.ms)
            .slideY(begin: 0.03, end: 0),
        const SizedBox(height: AppSpacing.xl),
        _buildBeneficiosYPerks()
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .slideY(begin: 0.03, end: 0),
        const SizedBox(height: AppSpacing.xl),
        _buildTechStackSection()
            .animate()
            .fadeIn(delay: 300.ms, duration: 400.ms)
            .slideY(begin: 0.03, end: 0),
        const SizedBox(height: AppSpacing.xl),
        _buildVideoCultura()
            .animate()
            .fadeIn(delay: 400.ms, duration: 400.ms)
            .slideY(begin: 0.03, end: 0),
      ],
    );
  }

  // ── Sobre Nosotros ──

  Widget _buildSobreNosotros() {
    final website = CompanyProfileStore.website;
    final teamSize = CompanyProfileStore.teamSize;
    final modality = CompanyProfileStore.modality;
    final foundingYear = CompanyProfileStore.foundingYear;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.info_outline, 'Sobre Nosotros'),
          const SizedBox(height: AppSpacing.md),

          // Description card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.6,
                    color: MployaColors.textSecondary,
                  ),
                ),
                if (website.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Icon(
                        Icons.language,
                        size: 16,
                        color: MployaColors.orange,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          website,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: MployaColors.orange,
                            decoration: TextDecoration.underline,
                            decorationColor:
                                MployaColors.orange.withValues(alpha: 0.4),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                // Info pills row
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (teamSize.isNotEmpty)
                      _infoPill(Icons.people_outline, teamSize),
                    _infoPill(Icons.location_on_outlined, modality),
                    if (foundingYear != null)
                      _infoPill(Icons.calendar_today_outlined,
                          'Fundada en $foundingYear'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Cultura y Valores ──

  Widget _buildCulturaYValores() {
    final cultureText = CompanyProfileStore.cultureText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.favorite_outline, 'Cultura y Valores'),
          const SizedBox(height: AppSpacing.md),
          if (_cultureValues.isNotEmpty) ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _cultureValues.asMap().entries.map((entry) {
                final index = entry.key;
                final value = entry.value;
                final colors = _cultureChipColors[
                    index % _cultureChipColors.length];
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.$1,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: colors.$2.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.$2,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (cultureText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: _cardDecoration(),
              child: Text(
                cultureText,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.6,
                  color: MployaColors.textSecondary,
                ),
              ),
            ),
          ],
          if (_cultureValues.isEmpty && cultureText.isEmpty)
            _emptySection(
              'Definí tu cultura',
              'Agregá los valores que representan a tu empresa',
            ),
        ],
      ),
    );
  }

  // Culture chip color palette
  static const _cultureChipColors = <(Color, Color)>[
    (Color(0xFFFFF7ED), Color(0xFFF97316)), // orange
    (Color(0xFFD1FAE5), Color(0xFF059669)), // green
    (Color(0xFFDBEAFE), Color(0xFF3B82F6)), // blue
    (Color(0xFFF3E8FF), Color(0xFF8B5CF6)), // purple
    (Color(0xFFFEE2E2), Color(0xFFEF4444)), // red
    (Color(0xFFFEF3C7), Color(0xFFD97706)), // amber
    (Color(0xFFCFFAFE), Color(0xFF0891B2)), // cyan
    (Color(0xFFF0FDF4), Color(0xFF16A34A)), // emerald
  ];

  // ── Beneficios y Perks ──

  Widget _buildBeneficiosYPerks() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.card_giftcard_outlined, 'Beneficios y Perks'),
          const SizedBox(height: AppSpacing.md),
          if (_activePerks.isNotEmpty)
            _buildPerksGrid()
          else
            _emptySection(
              'Sin beneficios configurados',
              'Agregá los perks que ofrecés a tu equipo',
            ),
        ],
      ),
    );
  }

  Widget _buildPerksGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2.8,
      ),
      itemCount: _activePerks.length,
      itemBuilder: (context, index) {
        final perk = _activePerks[index];
        final icon = _perkIcons[perk] ?? Icons.star_outline;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: MployaColors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: MployaColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: MployaColors.orangeSurface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: MployaColors.orange, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  perk,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: MployaColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tech Stack ──

  Widget _buildTechStackSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.code, 'Tech Stack'),
          const SizedBox(height: AppSpacing.md),
          if (_techStack.isNotEmpty)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _techStack.map((tech) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: MployaColors.border),
                    color: MployaColors.white,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle,
                          size: 6, color: MployaColors.orange),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        tech,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: MployaColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
          else
            _emptySection(
              'Sin tech stack',
              'Agregá las tecnologías que usa tu equipo',
            ),
        ],
      ),
    );
  }

  // ── Video Cultura ──

  Widget _buildVideoCultura() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle(Icons.videocam_outlined, 'Video Cultura'),
              GestureDetector(
                onTap: () => context.push('/onboarding/video'),
                child: Text(
                  'Grabar nuevo',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Dark video card
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A1A2E).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Center play button
                const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    size: 56,
                    color: Colors.white38,
                  ),
                ),
                // Top left: "Cultura" tag
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Cultura',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MployaColors.white,
                      ),
                    ),
                  ),
                ),
                // Top right: points badge
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: MployaColors.orangeGradient,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '85 pts',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: MployaColors.white,
                      ),
                    ),
                  ),
                ),
                // Bottom bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(AppRadius.lg),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(
                          '0:45',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.fullscreen,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // TAB 2: POSICIONES
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildPosicionesTab() {
    return Column(
      key: const ValueKey('posiciones'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Posiciones abiertas',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MployaColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: MployaColors.orangeSurface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${_mockJobs.length} activas',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.orange,
                  ),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.03, end: 0),

        const SizedBox(height: AppSpacing.md),

        // Job cards
        ...List.generate(_mockJobs.length, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                _buildJobCard(_mockJobs[index]),
                if (index < _mockJobs.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ),
          )
              .animate()
              .fadeIn(
                  delay: Duration(milliseconds: 100 + index * 100),
                  duration: 400.ms)
              .slideY(begin: 0.03, end: 0);
        }),

        const SizedBox(height: AppSpacing.lg),

        // Publicar nueva posición button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: GestureDetector(
            onTap: () => context.push('/jobs/new'),
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: MployaColors.orangeGradient,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: [
                  BoxShadow(
                    color: MployaColors.orange.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push('/jobs/new'),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add,
                            color: MployaColors.white, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Publicar nueva posición',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: MployaColors.white,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const Text(
                          '→',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 500.ms, duration: 400.ms)
            .slideY(begin: 0.05, end: 0),
      ],
    );
  }

  Widget _buildJobCard(_MockJob job) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: title + modality chip
          Row(
            children: [
              Expanded(
                child: Text(
                  job.title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: job.modality == 'Remoto'
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  job.modality,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: job.modality == 'Remoto'
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Salary + applicants
          Row(
            children: [
              Icon(Icons.attach_money,
                  size: 16, color: MployaColors.teal),
              const SizedBox(width: 2),
              Text(
                job.salaryRange,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: MployaColors.textSecondary,
                ),
              ),
              const Spacer(),
              Icon(Icons.people_outline,
                  size: 14, color: MployaColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                '${job.applicants} aplicantes',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MployaColors.textTertiary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Ver aplicantes button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/jobs/applicants'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: const BorderSide(color: MployaColors.orange),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              child: Text(
                'Ver aplicantes',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MployaColors.orange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // TAB 3: HERRAMIENTAS
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildHerramientasTab() {
    const profileCompletionPercent = 80;
    const profileCompletionCount = 4;
    const profileCompletionTotal = 5;

    return Column(
      key: const ValueKey('herramientas'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── SECTION 1: PROGRESO ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PROGRESO',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MployaColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Perfil completo',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: MployaColors.textPrimary,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$profileCompletionPercent',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: MployaColors.orange,
                        ),
                      ),
                      Text(
                        ' %',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: MployaColors.orange,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '$profileCompletionCount de $profileCompletionTotal',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MployaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: const LinearProgressIndicator(
                  value: profileCompletionPercent / 100,
                  minHeight: 8,
                  backgroundColor: Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    MployaColors.orange,
                  ),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.05, end: 0),

        const SizedBox(height: AppSpacing.xl),

        // ── SECTION 2: Crecimiento ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'Crecimiento',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MployaColors.textPrimary,
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 100.ms, duration: 400.ms)
            .slideY(begin: 0.05, end: 0),

        const SizedBox(height: AppSpacing.md),

        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              _buildCrecimientoItem(
                icon: Icons.rocket_launch,
                label: 'Boost',
                bgColor: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFF97316),
                onTap: () => context.push('/tools/boost'),
              ),
              const SizedBox(width: AppSpacing.md),
              _buildCrecimientoItem(
                icon: Icons.local_fire_department,
                label: 'Challenge',
                bgColor: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFEF4444),
                onTap: () => context.push('/tools/pitch-challenge'),
              ),
              const SizedBox(width: AppSpacing.md),
              _buildCrecimientoItem(
                icon: Icons.visibility,
                label: 'Vistas',
                bgColor: const Color(0xFFDBEAFE),
                iconColor: const Color(0xFF3B82F6),
                onTap: () => context.push('/tools/vistas'),
              ),
              const SizedBox(width: AppSpacing.md),
              _buildCrecimientoItem(
                icon: Icons.bar_chart,
                label: 'Analytics',
                bgColor: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF8B5CF6),
                onTap: () => context.push('/tools/analytics'),
              ),
              const SizedBox(width: AppSpacing.md),
              _buildCrecimientoItem(
                icon: Icons.people,
                label: 'Invita',
                bgColor: const Color(0xFFD1FAE5),
                iconColor: const Color(0xFF10B981),
                onTap: () => context.push('/tools/invite'),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .slideY(begin: 0.05, end: 0),

        const SizedBox(height: AppSpacing.xl),

        // ── SECTION 3: Cuenta ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cuenta',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MployaColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Configuración tile
              Container(
                decoration: BoxDecoration(
                  color: MployaColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: MployaColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: MployaColors.surfaceVariant,
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: MployaColors.textSecondary,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        'Configuración',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: MployaColors.textPrimary,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: MployaColors.textSecondary,
                        size: 22,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      onTap: () => context.push('/settings'),
                    ),
                    const Divider(height: 1, indent: 72),
                    // Cerrar sesión
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: MployaColors.redLight,
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.logout,
                          color: MployaColors.red,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        'Cerrar sesión',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: MployaColors.red,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: MployaColors.textSecondary,
                        size: 22,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                              '¿Cerrar sesión?',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            content: Text(
                              'Vas a salir de tu cuenta. Podés volver a iniciar sesión en cualquier momento.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: MployaColors.textSecondary,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  context.go('/auth/login');
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: MployaColors.red,
                                ),
                                child: const Text('Cerrar sesión'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 300.ms, duration: 400.ms)
            .slideY(begin: 0.05, end: 0),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ═════════════════════════════════════════════════════════════════════

  /// Section title with icon.
  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: MployaColors.orange, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MployaColors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Standard card decoration.
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: MployaColors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: MployaColors.borderLight),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Info pill (team size, modality, etc).
  Widget _infoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: MployaColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: MployaColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: MployaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Empty section placeholder.
  Widget _emptySection(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg, horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: MployaColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: MployaColors.borderLight,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 32,
            color: MployaColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: MployaColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MployaColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Growth tool item for horizontal list.
  Widget _buildCrecimientoItem({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: MployaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Column helper ──────────────────────────────────────────────

class _CompanyStatColumn extends StatelessWidget {
  const _CompanyStatColumn({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: MployaColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MployaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
