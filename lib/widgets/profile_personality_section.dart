import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, LinearProgressIndicator;
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/video_personality_service.dart';
import '../screens/personality_result_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Profile Personality Section — Análisis de personalidad IA
//
// Extraído de profile_screen.dart para reducir el god file.
// ─────────────────────────────────────────────────────────────────────────────

class ProfilePersonalitySection extends StatefulWidget {
  final String userId;
  final bool isOwnProfile;
  final String headline;
  final List<String> skills;

  const ProfilePersonalitySection({
    super.key,
    required this.userId,
    required this.isOwnProfile,
    required this.headline,
    required this.skills,
  });

  @override
  State<ProfilePersonalitySection> createState() => _ProfilePersonalitySectionState();
}

class _ProfilePersonalitySectionState extends State<ProfilePersonalitySection> {
  PersonalityAnalysis? _saved;
  bool _loading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await VideoPersonalityService.instance
        .getSavedAnalysis(widget.userId);
    if (mounted) {
      setState(() {
        _saved = saved;
        _loaded = true;
      });
    }
  }

  Future<void> _runAnalysis() async {
    setState(() => _loading = true);
    try {
      final result = await VideoPersonalityService.instance.analyzePersonality(
        userId: widget.userId,
        headline: widget.headline,
        skills: widget.skills,
      );
      if (mounted) {
        setState(() {
          _saved = result;
          _loading = false;
        });
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => PersonalityResultScreen(
              analysis: result,
              onReAnalyze: _runAnalysis,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint('❌ Personality analysis error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    return Container(
      color: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C3FC8), Color(0xFF9B6FE8)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Análisis de Personalidad IA',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E)),
                    ),
                    Text(
                      'Soft skills analizadas por Gemini',
                      style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_saved != null) ...[
            // ── Mini preview of results ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F5FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6C3FC8).withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  // Personality type badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF6C3FC8), Color(0xFF9B6FE8)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _saved!.personalityType,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_saved!.overallScore}/100',
                        style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900,
                          color: Color(0xFF6C3FC8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Mini skill bars
                  ...(_saved!.allScores.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(s.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 80,
                          child: Text(s.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E))),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: s.score / 100.0,
                              backgroundColor: const Color(0xFFE5E5EA),
                              valueColor: AlwaysStoppedAnimation(
                                s.score >= 75 ? MployaTheme.brandAccent : const Color(0xFF6C3FC8),
                              ),
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${s.score}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF6C3FC8))),
                      ],
                    ),
                  ))),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => PersonalityResultScreen(
                      analysis: _saved!,
                      onReAnalyze: widget.isOwnProfile ? _runAnalysis : null,
                    ),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C3FC8), Color(0xFF9B6FE8)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C3FC8).withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Ver análisis completo',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ] else if (widget.isOwnProfile) ...[
            // ── CTA compacta (no full-width) ──
            GestureDetector(
              onTap: _loading ? null : _runAnalysis,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F0FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF6C3FC8).withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6C3FC8), Color(0xFF9B6FE8)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(CupertinoIcons.wand_stars, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Analizar Personalidad IA',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
                          Text('Detecta tus soft skills desde tu video-pitch',
                            style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_loading)
                      const CupertinoActivityIndicator()
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF6C3FC8), Color(0xFF9B6FE8)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Analizar',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
