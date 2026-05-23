/// Shell principal con navegación inferior de 5 tabs.
///
/// Contiene [IndexedStack] para mantener el estado de cada tab
/// y [BottomNavigationBar] con indicador naranja debajo del ícono activo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';
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
