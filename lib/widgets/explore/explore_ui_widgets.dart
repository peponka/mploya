import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import '../../theme/app_theme.dart';

/// Zoom Button — Glassmorphic circle button for map controls
class ExploreZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const ExploreZoomButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF1C1C1E)),
          ),
        ),
      ),
    );
  }
}

/// GPS Banner — Shows when GPS permission is denied
class ExploreGpsBanner extends StatelessWidget {
  final bool permissionDenied;
  final bool gpsActivating;
  final VoidCallback onActivateGps;
  final VoidCallback onChooseCity;

  const ExploreGpsBanner({
    super.key,
    required this.permissionDenied,
    required this.gpsActivating,
    required this.onActivateGps,
    required this.onChooseCity,
  });

  @override
  Widget build(BuildContext context) {
    if (!permissionDenied) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(children: [
                Icon(CupertinoIcons.location_slash_fill, size: 16, color: Color(0xFFFF9500)),
                SizedBox(width: 8),
                Expanded(child: Text('Ubicación GPS no disponible',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: MployaTheme.brandAccent,
                  borderRadius: BorderRadius.circular(10),
                  minSize: 0,
                  onPressed: gpsActivating ? null : onActivateGps,
                  child: gpsActivating
                    ? const CupertinoActivityIndicator(color: CupertinoColors.white, radius: 8)
                    : const Text('Activar GPS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                )),
                const SizedBox(width: 8),
                Expanded(child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(10),
                  minSize: 0,
                  onPressed: onChooseCity,
                  child: const Text('Elegir Ciudad',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E))),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filter Chip for explore search bar
class ExploreFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const ExploreFilterChip({super.key, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? MployaTheme.brandAccent : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
            ? [BoxShadow(color: MployaTheme.brandAccent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
            : const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF1C1C1E),
        )),
      ),
    );
  }
}
