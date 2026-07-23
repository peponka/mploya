import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/skill_assessment_service.dart';
import '../screens/skill_assessment_screen.dart';

/// Widget que muestra los badges verificados de un usuario en su perfil.
/// Si es perfil propio, incluye un botón para tomar nuevos assessments.
class SkillBadgesSection extends StatefulWidget {
  final String userId;
  final bool isOwnProfile;
  const SkillBadgesSection({super.key, required this.userId, required this.isOwnProfile});

  @override
  State<SkillBadgesSection> createState() => _SkillBadgesSectionState();
}

class _SkillBadgesSectionState extends State<SkillBadgesSection> {
  List<SkillBadge> _badges = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final badges = widget.isOwnProfile
        ? await SkillAssessmentService.instance.fetchMyBadges()
        : await SkillAssessmentService.instance.fetchUserBadges(widget.userId);
    if (mounted) setState(() { _badges = badges; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    // No mostrar si no hay badges y es perfil ajeno
    if (_loaded && _badges.isEmpty && !widget.isOwnProfile) return const SizedBox.shrink();

    return Container(
      color: CupertinoColors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              const Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFFFFD700), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Insignias de habilidades', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
              ),
              if (widget.isOwnProfile)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () {
                    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SkillAssessmentScreen()))
                        .then((_) => _load()); // Refresh on return
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: MployaTheme.brandAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(CupertinoIcons.add, size: 14, color: MployaTheme.brandAccent),
                      SizedBox(width: 4),
                      Text('Tomar Test', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MployaTheme.brandAccent)),
                    ]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Badges Grid ──
          if (!_loaded)
            const Center(child: CupertinoActivityIndicator(radius: 10))
          else if (_badges.isEmpty)
            GestureDetector(
              onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SkillAssessmentScreen())).then((_) => _load()),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
                ),
                child: const Column(children: [
                  Icon(CupertinoIcons.checkmark_seal, size: 32, color: Color(0xFFAEAEB2)),
                  SizedBox(height: 8),
                  Text('Validá tus skills', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E))),
                  SizedBox(height: 2),
                  Text('Tomá un test rápido de 5 preguntas', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                ]),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _badges.map((b) {
                final c = b.badgeLevel == 'gold' ? const Color(0xFFFFD700) : b.badgeLevel == 'silver' ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.withValues(alpha: 0.3), width: 0.5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(CupertinoIcons.checkmark_seal_fill, color: c, size: 14),
                    const SizedBox(width: 5),
                    Text(b.skillName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.withValues(alpha: 1.0))),
                    const SizedBox(width: 4),
                    Text('${b.score}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.withValues(alpha: 0.7))),
                  ]),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
