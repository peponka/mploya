/// Shell principal con navegación adaptativa.
///
/// En mobile muestra [BottomNavigationBar].
/// En desktop muestra un sidebar lateral con [NavigationRail] estilizado.
/// Contiene [IndexedStack] para mantener el estado de cada tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';
import 'package:mploya/core/utils/responsive.dart';
import 'package:mploya/features/feed/screens/feed_screen.dart';
import 'package:mploya/features/explore/screens/explore_screen.dart';
import 'package:mploya/features/matches/screens/matches_screen.dart';
import 'package:mploya/features/notifications/screens/alerts_screen.dart';
import 'package:mploya/features/profile/models/company_profile_store.dart';
import 'package:mploya/features/profile/screens/company_profile_screen.dart';
import 'package:mploya/features/profile/screens/profile_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;

  List<Widget> get _screens => [
    const FeedScreen(),
    const ExploreScreen(),
    const MatchesScreen(),
    const AlertsScreen(),
    CompanyProfileStore.isCompany
        ? const CompanyProfileScreen()
        : const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    final tablet = isTablet(context);

    // ── Desktop / Tablet: sidebar + content ──
    if (desktop || tablet) {
      return Scaffold(
        body: Row(
          children: [
            _DesktopSidebar(
              currentIndex: _currentIndex,
              isExpanded: desktop, // expanded on desktop, collapsed on tablet
              onTabSelected: (i) => setState(() => _currentIndex = i),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: MployaColors.borderLight),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      );
    }

    // ── Mobile: bottom nav ──
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: MployaColors.white,
          border: Border(
            top: BorderSide(color: MployaColors.borderLight, width: 1),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(5, (i) {
                final isSelected = _currentIndex == i;
                return _NavItem(
                  icon: _unselectedIcons[i],
                  activeIcon: _selectedIcons[i],
                  label: _labels[i],
                  isSelected: isSelected,
                  onTap: () => setState(() => _currentIndex = i),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  static const _labels = ['Feed', 'Explorar', 'Matches', 'Alertas', 'Perfil'];

  static const _unselectedIcons = [
    Icons.play_arrow_outlined,
    Icons.explore_outlined,
    Icons.bolt_outlined,
    Icons.notifications_outlined,
    Icons.person_outline_rounded,
  ];

  static const _selectedIcons = [
    Icons.play_arrow_rounded,
    Icons.explore_rounded,
    Icons.bolt_rounded,
    Icons.notifications_rounded,
    Icons.person_rounded,
  ];
}

// ─── Desktop Sidebar ─────────────────────────────────────────────────

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.currentIndex,
    required this.isExpanded,
    required this.onTabSelected,
  });

  final int currentIndex;
  final bool isExpanded;
  final ValueChanged<int> onTabSelected;

  static const _labels = ['Feed', 'Explorar', 'Matches', 'Alertas', 'Perfil'];

  static const _unselectedIcons = [
    Icons.play_arrow_outlined,
    Icons.explore_outlined,
    Icons.bolt_outlined,
    Icons.notifications_outlined,
    Icons.person_outline_rounded,
  ];

  static const _selectedIcons = [
    Icons.play_arrow_rounded,
    Icons.explore_rounded,
    Icons.bolt_rounded,
    Icons.notifications_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final width = isExpanded ? 220.0 : 80.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      color: MployaColors.white,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          // ── Logo ──
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isExpanded ? AppSpacing.lg : AppSpacing.md,
            ),
            child: isExpanded
                ? Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SvgPicture.asset(
                          'assets/icons/mploya_logo.svg',
                          width: 36,
                          height: 36,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'mploya',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: MployaColors.textPrimary,
                        ),
                      ),
                      Text(
                        '.ai',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: MployaColors.orange,
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SvgPicture.asset(
                        'assets/icons/mploya_logo.svg',
                        width: 40,
                        height: 40,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          // ── Nav items ──
          ...List.generate(5, (i) {
            final selected = currentIndex == i;
            return _SidebarItem(
              icon: selected ? _selectedIcons[i] : _unselectedIcons[i],
              label: _labels[i],
              isSelected: selected,
              isExpanded: isExpanded,
              onTap: () => onTabSelected(i),
            );
          }),
          const Spacer(),
          // ── Bottom info ──
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                '© 2026 mploya.ai',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: MployaColors.textTertiary,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

// ─── Sidebar Item ────────────────────────────────────────────────────

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isSelected
        ? MployaColors.orange
        : _isHovered
            ? MployaColors.textPrimary
            : MployaColors.textTertiary;

    final bgColor = widget.isSelected
        ? MployaColors.orange.withValues(alpha: 0.08)
        : _isHovered
            ? MployaColors.orange.withValues(alpha: 0.04)
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.symmetric(
            horizontal: widget.isExpanded ? AppSpacing.md : AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isExpanded ? AppSpacing.md : 0,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisAlignment: widget.isExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              // Orange indicator bar
              if (widget.isSelected)
                Container(
                  width: 3,
                  height: 20,
                  margin: EdgeInsets.only(
                    right: widget.isExpanded ? AppSpacing.sm : 0,
                  ),
                  decoration: BoxDecoration(
                    color: MployaColors.orange,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                )
              else if (widget.isExpanded)
                const SizedBox(width: 3 + AppSpacing.sm),
              Icon(widget.icon, color: color, size: 24),
              if (widget.isExpanded) ...[
                const SizedBox(width: AppSpacing.md),
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight:
                        widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mobile Nav Item ─────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? MployaColors.orange : MployaColors.textTertiary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador naranja
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isSelected ? 24 : 0,
              decoration: BoxDecoration(
                color: isSelected ? MployaColors.orange : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
