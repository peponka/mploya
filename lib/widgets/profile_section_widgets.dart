import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../screens/trending_hashtags_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Profile Section Widgets — Sub-widgets extraídos de profile_screen.dart
//
// Contiene:
//  • ProfileSection        — Card contenedor reutilizable para secciones
//  • ScoreChip             — Chip de puntuación IA (Claridad, Energía, etc.)
//  • EducationItem         — Item de formación académica
//  • SkillPill             — Pill de habilidad con endorsement interactivo
//  • ProfileCompletionBar  — Barra de completitud del perfil
//  • ProfileViewersCard    — Card de "Quién vio tu perfil"
//  • AiCoachCard           — Card de sugerencias del Coach IA
//  • PremiumUpsellBanner   — Banner de upgrade a Premium
//  • StealthVaultBanner    — Banner de configuración Stealth
// ─────────────────────────────────────────────────────────────────────────────

/// Card contenedor reutilizable con título para secciones del perfil.
class ProfileSection extends StatelessWidget {
  final String title;
  final Widget child;

  const ProfileSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(MployaTheme.radiusMD),
          boxShadow: context.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Chip de puntuación IA para video-pitch.
class ScoreChip extends StatelessWidget {
  final String label;
  final int value;
  const ScoreChip({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: MployaTheme.brandAccent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(MployaTheme.radiusSM),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: MployaTheme.brandAccent),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Item de formación académica.
class EducationItem extends StatelessWidget {
  final Education education;

  const EducationItem({super.key, required this.education});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF5F3DC4).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.book_fill,
                color: Color(0xFF5F3DC4),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  education.school,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${education.degree}${education.field != null ? ', ${education.field}' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  education.years,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill de habilidad/hashtag con endorsement interactivo.
///
/// - En perfil propio: navega al SearchScreen buscando ese tag.
/// - En perfil ajeno: tap para endorsar (validar competencia).
class SkillPill extends StatefulWidget {
  final String skill;
  final bool isOwnProfile;
  final String? targetUserId;

  const SkillPill({super.key, required this.skill, required this.isOwnProfile, this.targetUserId});

  @override
  State<SkillPill> createState() => _SkillPillState();
}

class _SkillPillState extends State<SkillPill> with SingleTickerProviderStateMixin {
  bool _isEndorsed = false;
  int _endorsements = 0;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _onTap() {
    if (widget.isOwnProfile) {
      // ── Hashtag interactivo: abrir TrendingHashtags con este tag ──
      _bounceController.forward().then((_) => _bounceController.reverse());
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => TrendingHashtagsScreen(initialTag: widget.skill),
        ),
      );
    } else {
      // ── Endorsement en perfil ajeno ──
      setState(() {
        _isEndorsed = !_isEndorsed;
        _isEndorsed ? _endorsements++ : _endorsements--;
      });
      _bounceController.forward().then((_) => _bounceController.reverse());
      
      // Persistir endorsement (fire-and-forget)
      if (_isEndorsed && widget.targetUserId != null) {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          Supabase.instance.client.rpc('create_system_notification', params: {
            'p_user_id': widget.targetUserId,
            'p_type': 'endorsement',
            'p_description': '⭐ Alguien validó tu habilidad "${widget.skill}"',
            'p_actor_id': uid,
          }).catchError((_) {});
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _bounceAnim,
      child: GestureDetector(
        onTap: _onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _isEndorsed
                ? const Color(0xFFFEF3C7)
                : widget.isOwnProfile
                    ? context.brandAccent.withValues(alpha: 0.06)
                    : context.brandAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
            border: Border.all(
              color: _isEndorsed
                  ? const Color(0xFFF59E0B)
                  : widget.isOwnProfile
                      ? context.brandAccent.withValues(alpha: 0.25)
                      : context.brandAccent.withValues(alpha: 0.2),
              width: _isEndorsed ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isOwnProfile)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    CupertinoIcons.search,
                    size: 12,
                    color: context.brandAccent.withValues(alpha: 0.6),
                  ),
                ),
              Text(
                widget.isOwnProfile ? '#${widget.skill}' : widget.skill,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: _isEndorsed ? FontWeight.w700 : FontWeight.w500,
                  color: _isEndorsed ? const Color(0xFFB45309) : context.brandAccent,
                ),
              ),
              if (_endorsements > 0) ...[
                const SizedBox(width: 6),
                const Icon(CupertinoIcons.star_fill, size: 12, color: Color(0xFFF59E0B)),
                const SizedBox(width: 2),
                Text(
                  '+$_endorsements',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD97706),
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

/// Barra de completitud del perfil propio (estilo clean).
class ProfileCompletionBar extends StatelessWidget {
  final NexUser profile;
  const ProfileCompletionBar({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    int total = 6;
    int filled = 0;
    if (profile.videoUrl != null && profile.videoUrl!.isNotEmpty) filled++;
    if (profile.tags.isNotEmpty) filled++;
    if (profile.headline.isNotEmpty && profile.headline != 'Directivo Stealth') filled++;
    if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) filled++;
    if (profile.about != null && profile.about!.isNotEmpty) filled++;
    if (profile.company != null && profile.company!.isNotEmpty) filled++;

    final pct = (filled / total * 100).round();
    final ratio = filled / total;

    if (pct >= 100) return const SizedBox.shrink();

    return Container(
      color: CupertinoColors.white,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROGRESO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Perfil completo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary),
              ),
              const Spacer(),
              Text(
                '$pct',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.textPrimary),
              ),
              Text(
                ' %',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary),
              ),
              const SizedBox(width: 8),
              Text(
                '$filled de $total',
                style: TextStyle(fontSize: 13, color: context.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card de "Quién vio tu perfil" (últimas 5 vistas).
class ProfileViewersCard extends StatelessWidget {
  const ProfileViewersCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', Supabase.instance.client.auth.currentUser?.id ?? '')
          .eq('type', 'profileView')
          .order('created_at', ascending: false)
          .limit(5),
      builder: (context, snap) {
        final viewers = snap.data ?? [];
        if (viewers.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(CupertinoIcons.eye_fill, size: 16, color: Color(0xFF00838F)),
                      SizedBox(width: 8),
                      Text(
                        'Quién vio tu perfil',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00838F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${viewers.length}',
                      style: const TextStyle(color: Color(0xFF00838F), fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...viewers.map((v) {
                final desc = v['description']?.toString() ?? 'Alguien vio tu perfil';
                final timeRaw = v['created_at'];
                String timeAgo = 'Reciente';
                if (timeRaw != null) {
                  final dt = DateTime.tryParse(timeRaw.toString());
                  if (dt != null) {
                    final diff = DateTime.now().difference(dt);
                    if (diff.inDays > 0) {
                      timeAgo = '${diff.inDays}d';
                    } else if (diff.inHours > 0) {
                      timeAgo = '${diff.inHours}h';
                    } else if (diff.inMinutes > 0) {
                      timeAgo = '${diff.inMinutes}m';
                    } else {
                      timeAgo = 'Ahora';
                    }
                  }
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00838F).withValues(alpha: 0.15),
                        ),
                        child: const Icon(CupertinoIcons.person_fill, size: 16, color: Color(0xFF00838F)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          desc,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF3C3C43), height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

/// Card de sugerencias del Coach IA (estilo clean).
class AiCoachCard extends StatelessWidget {
  final NexUser profile;
  const AiCoachCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final tips = <Map<String, dynamic>>[];

    if (profile.avatarUrl == null || profile.avatarUrl!.isEmpty) {
      tips.add({'tip': 'Agregá foto de perfil', 'mult': '+7×'});
    }
    if (profile.tags.length < 3) {
      tips.add({'tip': 'Sumá 2 skills clave', 'mult': '+2×'});
    }
    if (profile.videoUrl == null || profile.videoUrl!.isEmpty) {
      tips.add({'tip': 'Grabá tu Video Pitch', 'mult': '+5×'});
    }
    if (profile.about == null || profile.about!.isEmpty) {
      tips.add({'tip': 'Actualizá disponibilidad', 'mult': '+1.2×'});
    }
    if (profile.headline.isEmpty) {
      tips.add({'tip': 'Escribí un headline fuerte', 'mult': '+3×'});
    }

    if (tips.isEmpty) return const SizedBox.shrink();

    return Container(
      color: CupertinoColors.white,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUGERENCIAS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          // Coach IA header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9FB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      '+',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: MployaTheme.brandAccent),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'COACH IA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: MployaTheme.brandAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Tres pasos para duplicar tu alcance.',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                // Suggestion items
                ...tips.take(3).toList().asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value;
                  return Column(
                    children: [
                      if (i > 0)
                        const Divider(height: 1, color: Color(0xFFE5E5EA)),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: MployaTheme.brandAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MployaTheme.brandAccent),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                t['tip'] as String,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary),
                              ),
                            ),
                            Text(
                              t['mult'] as String,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: MployaTheme.brandAccent),
                            ),
                            const SizedBox(width: 6),
                            Icon(CupertinoIcons.chevron_right, size: 12, color: context.textTertiary),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
