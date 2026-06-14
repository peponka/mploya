import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'spring_interaction.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Profile Helper Widgets — Extraídos de profile_screen.dart para modularidad
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScoreChip extends StatelessWidget {
  final String label;
  final int value;
  const ProfileScoreChip({super.key, required this.label, required this.value});

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

class VideoExperienceItem extends StatelessWidget {
  final Experience experience;
  final int index;

  const VideoExperienceItem({super.key, required this.experience, required this.index});

  @override
  Widget build(BuildContext context) {
    return SpringInteraction(
      onTap: () {
        showCupertinoModalPopup<void>(
          context: context,
          builder: (_) => const ProfileVideoPlayerModal(
            videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
            index: 0,
          ),
        );
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF2E1A10), Color(0xFF141414)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 2))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.6,
                child: Container(color: Colors.black),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.play_arrow_solid, color: Colors.white, size: 14),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withValues(alpha: 0.95), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      experience.role,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      experience.company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: MployaTheme.brandAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        experience.duration,
                        style: const TextStyle(fontSize: 10, color: MployaTheme.brandAccent, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileEducationItem extends StatelessWidget {
  final Education education;

  const ProfileEducationItem({super.key, required this.education});

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
              child: Icon(CupertinoIcons.book_fill, color: Color(0xFF5F3DC4), size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  education.school,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${education.degree}${education.field != null ? ', ${education.field}' : ''}',
                  style: TextStyle(fontSize: 14, color: context.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  education.years,
                  style: TextStyle(fontSize: 13, color: context.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSkillPill extends StatefulWidget {
  final String skill;
  final bool isOwnProfile;
  final String? targetUserId;

  const ProfileSkillPill({super.key, required this.skill, required this.isOwnProfile, this.targetUserId});

  @override
  State<ProfileSkillPill> createState() => _ProfileSkillPillState();
}

class _ProfileSkillPillState extends State<ProfileSkillPill> {
  bool _isEndorsed = false;
  int _endorsements = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.isOwnProfile) return;
        setState(() {
          _isEndorsed = !_isEndorsed;
          _isEndorsed ? _endorsements++ : _endorsements--;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _isEndorsed
              ? const Color(0xFFFEF3C7)
              : context.brandAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.skill,
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
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Portfolio thumbnail constants and widget
// ─────────────────────────────────────────────────────────────────────────────

const kSampleVideoUrls = [
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
];

const kThumbnailGradients = [
  [Color(0xFFD4E4FF), Color(0xFFB8C8E8)],
  [Color(0xFFFFE0CC), Color(0xFFFFBD99)],
  [Color(0xFFD8F5E8), Color(0xFFAADEC5)],
  [Color(0xFFF0D8FF), Color(0xFFD8AAEE)],
  [Color(0xFFFFF3D0), Color(0xFFFFD97A)],
  [Color(0xFFD0F0FF), Color(0xFF9ED8F0)],
  [Color(0xFFFFD6D6), Color(0xFFFFAAAA)],
  [Color(0xFFE8FFD8), Color(0xFFC0EEA0)],
  [Color(0xFFD8EEFF), Color(0xFFAAC8EE)],
  [Color(0xFFFFEED8), Color(0xFFFFCC88)],
  [Color(0xFFEED8FF), Color(0xFFCC88EE)],
  [Color(0xFFD8FFE8), Color(0xFF88EECC)],
  [Color(0xFFFFD8EE), Color(0xFFEE88CC)],
  [Color(0xFFD8F0FF), Color(0xFF88CCEE)],
  [Color(0xFFF0FFD8), Color(0xFFCCEE88)],
];

const kFakeDurations = [
  '0:42', '1:15', '0:58', '2:03', '0:34',
  '1:47', '0:22', '3:10', '0:51', '1:28',
  '0:39', '2:44', '1:02', '0:17', '1:55',
];

const kFakeViews = [
  '2.1k', '845', '5.3k', '1.2k', '320',
  '9.8k', '412', '3.6k', '780', '14k',
  '520', '2.7k', '1.1k', '6.4k', '290',
];

class ProfileVideoThumb extends StatelessWidget {
  const ProfileVideoThumb({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = kThumbnailGradients[index % kThumbnailGradients.length];
    final videoUrl = kSampleVideoUrls[index % kSampleVideoUrls.length];

    return GestureDetector(
      onTap: () => showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => ProfileVideoPlayerModal(videoUrl: videoUrl, index: index),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors[0], colors[1]],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Center(
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.play_fill, color: Color(0xFF1C1C1E), size: 14),
              ),
            ),
            Positioned(
              bottom: 5, right: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  kFakeDurations[index % kFakeDurations.length],
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              bottom: 5, left: 5,
              child: Row(
                children: [
                  const Icon(CupertinoIcons.play_arrow_solid, color: Colors.white, size: 9),
                  const SizedBox(width: 2),
                  Text(
                    kFakeViews[index % kFakeViews.length],
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Video Player Modal (portrait sheet, iOS-style)
// ─────────────────────────────────────────────────────────────────────────────

class ProfileVideoPlayerModal extends StatefulWidget {
  const ProfileVideoPlayerModal({super.key, required this.videoUrl, required this.index});

  final String videoUrl;
  final int index;

  @override
  State<ProfileVideoPlayerModal> createState() => _ProfileVideoPlayerModalState();
}

class _ProfileVideoPlayerModalState extends State<ProfileVideoPlayerModal> {
  late final VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() => _isInitialized = true);
        _controller.play();
        _controller.setLooping(true);
      }
    }).catchError((_) {
      if (mounted) setState(() => _hasError = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final colors = kThumbnailGradients[widget.index % kThumbnailGradients.length];

    return Material(
      color: Colors.transparent,
      child: Container(
        height: screenH * 0.82,
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _hasError
                    ? ProfileErrorPlaceholder(colors: colors)
                    : !_isInitialized
                        ? ProfileLoadingPlaceholder(colors: colors)
                        : ValueListenableBuilder(
                            valueListenable: _controller,
                            builder: (_, VideoPlayerValue value, __) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  AspectRatio(
                                    aspectRatio: _controller.value.aspectRatio,
                                    child: VideoPlayer(_controller),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      _controller.value.isPlaying
                                          ? _controller.pause()
                                          : _controller.play();
                                    },
                                    child: AnimatedOpacity(
                                      opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                                      duration: const Duration(milliseconds: 200),
                                      child: Container(
                                        width: 64, height: 64,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 28),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
              ),
            ),
            if (_isInitialized && !_hasError)
              ValueListenableBuilder(
                valueListenable: _controller,
                builder: (_, VideoPlayerValue value, __) {
                  final position = value.position;
                  final duration = value.duration;
                  final progress = duration.inMilliseconds > 0
                      ? position.inMilliseconds / duration.inMilliseconds
                      : 0.0;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: MployaTheme.brandAccent,
                            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                            thumbColor: MployaTheme.brandAccent,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            trackHeight: 3,
                            overlayShape: SliderComponentShape.noOverlay,
                          ),
                          child: Slider(
                            value: progress.clamp(0.0, 1.0),
                            onChanged: (v) {
                              final newPos = Duration(
                                milliseconds: (v * duration.inMilliseconds).round(),
                              );
                              _controller.seekTo(newPos);
                            },
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _formatDuration(position),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                            ),
                            const Spacer(),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size.square(36),
                              onPressed: () {
                                value.isPlaying ? _controller.pause() : _controller.play();
                              },
                              child: Icon(
                                value.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                                color: Colors.white, size: 28,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatDuration(duration),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
          ],
        ),
      ),
    );
  }
}

class ProfileLoadingPlaceholder extends StatelessWidget {
  const ProfileLoadingPlaceholder({super.key, required this.colors});
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors[0], colors[1]],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(child: CupertinoActivityIndicator(radius: 16)),
    );
  }
}

class ProfileErrorPlaceholder extends StatelessWidget {
  const ProfileErrorPlaceholder({super.key, required this.colors});
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors[0], colors[1]],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.wifi_slash, color: Color(0xFF8E8E93), size: 36),
            SizedBox(height: 8),
            Text('Video no disponible', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class VideoTestimonialCard extends StatelessWidget {
  final int index;
  const VideoTestimonialCard({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  index % 2 == 0 ? const Color(0xFF2C1045) : const Color(0xFF0F3B2E),
                  Colors.black,
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),
          const Center(
            child: Icon(CupertinoIcons.play_circle_fill, color: Colors.white60, size: 36),
          ),
          Positioned(
            bottom: 8, left: 8, right: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white38, width: 1),
                      ),
                      child: const Icon(CupertinoIcons.person_fill, size: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'CEO',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('15s', style: TextStyle(color: Colors.white70, fontSize: 9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
