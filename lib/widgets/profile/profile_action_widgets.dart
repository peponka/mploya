import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

/// Spotlight Card — Full-width gradient card for premium AI features
class SpotlightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String? tag;
  final VoidCallback onTap;
  const SpotlightCard({super.key, required this.title, required this.subtitle, required this.icon, required this.gradient, this.tag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.mediumImpact(); onTap(); },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: gradient.first.withValues(alpha: 0.30), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(14)), child: Icon(icon, size: 24, color: Colors.white)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2)),
              if (tag != null) ...[
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(6)),
                  child: Text(tag!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white))),
              ],
            ]),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.85)), maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), shape: BoxShape.circle), child: const Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.white)),
        ]),
      ),
    );
  }
}

/// Spotlight Card Compact — Half-width gradient card
class SpotlightCardCompact extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  const SpotlightCardCompact({super.key, required this.title, required this.icon, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.mediumImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: gradient.first.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: Colors.white)),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.2)),
          const SizedBox(height: 4),
          Row(children: [
            Text('Empezar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.80))),
            const SizedBox(width: 4),
            Icon(CupertinoIcons.chevron_right, size: 10, color: Colors.white.withValues(alpha: 0.80)),
          ]),
        ]),
      ),
    );
  }
}

/// Quick Action Chip — Vertical icon chip for horizontal scroll
class QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const QuickActionChip({super.key, required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        width: 72, margin: const EdgeInsets.only(right: 10),
        child: Column(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.15), width: 1)),
            child: Icon(icon, size: 22, color: color)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

/// Profile Tab Button — Custom tab with icon + label + optional badge
class ProfileTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final String? badge;
  final VoidCallback onTap;
  const ProfileTabButton({super.key, required this.icon, required this.label, required this.isSelected, this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? MployaTheme.brandAccent.withValues(alpha: 0.10) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? MployaTheme.brandAccent.withValues(alpha: 0.30) : Colors.transparent, width: 1.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(icon, size: 18, color: isSelected ? MployaTheme.brandAccent : const Color(0xFF8E8E93)),
              if (badge != null) Positioned(top: -6, right: -10, child: Text(badge!, style: const TextStyle(fontSize: 10))),
            ]),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? MployaTheme.brandAccent : const Color(0xFF8E8E93))),
          ]),
        ),
      ),
    );
  }
}
