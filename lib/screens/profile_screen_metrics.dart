part of 'profile_screen.dart';

class _TimelineRailItem extends StatelessWidget {
  final _TimelineNode item;

  const _TimelineRailItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              item.leftLabel,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: context.textSecondary,
              ),
            ),
          ),
        ),
        Container(
          width: 16,
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.accent,
                ),
              ),
              Container(width: 2, height: 140, color: const Color(0xFFE7EBF4)),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFE),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: item.accent,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.55,
                    color: context.textSecondary,
                  ),
                ),
                if (item.tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item.tags
                        .map(
                          (tag) => MployaPill(label: tag, color: item.accent),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PortfolioProjectCard extends StatelessWidget {
  final PortfolioVideo video;
  final List<String> tags;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _PortfolioProjectCard({
    required this.video,
    required this.tags,
    required this.canEdit,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: context.cardShadow,
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 220,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF151C30),
                    Color(0xFF29304C),
                    Color(0xFF101624),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      CupertinoIcons.play_circle,
                      color: Colors.white,
                      size: 54,
                    ),
                  ),
                  if (canEdit)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          showCupertinoModalPopup<void>(
                            context: context,
                            builder: (sheetContext) => CupertinoActionSheet(
                              actions: [
                                CupertinoActionSheetAction(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    onEdit?.call();
                                  },
                                  child: const Text('Editar proyecto'),
                                ),
                                CupertinoActionSheetAction(
                                  isDestructiveAction: true,
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    onDelete?.call();
                                  },
                                  child: const Text('Eliminar proyecto'),
                                ),
                              ],
                              cancelButton: CupertinoActionSheetAction(
                                onPressed: () => Navigator.pop(sheetContext),
                                child: const Text('Cerrar'),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            CupertinoIcons.ellipsis,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (video.description ??
                            'Proyecto profesional presentado en formato visual.')
                        .trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags
                        .map(
                          (tag) => MployaPill(
                            label: tag,
                            color: NexTheme.brandAccentDark,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _InlineMetric(
                        icon: CupertinoIcons.calendar,
                        value: _yearFromDate(video.createdAt),
                      ),
                      const SizedBox(width: 16),
                      _InlineMetric(
                        icon: CupertinoIcons.eye,
                        value: _compact(video.viewCount),
                      ),
                      const Spacer(),
                      const Icon(CupertinoIcons.bookmark, size: 18),
                    ],
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

class _InlineMetric extends StatelessWidget {
  final IconData icon;
  final String value;

  const _InlineMetric({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.textSecondary),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: context.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final int score;
  final String label;
  final bool darkMode;

  const _ScoreRing({
    required this.score,
    required this.label,
    this.darkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = score.clamp(0, 100) / 100;
    final text = darkMode ? Colors.white : context.textPrimary;
    final helper = darkMode
        ? Colors.white.withValues(alpha: 0.72)
        : context.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 92,
          height: 92,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 7,
                  backgroundColor: darkMode
                      ? Colors.white.withValues(alpha: 0.14)
                      : const Color(0xFFE8EAF6),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    NexTheme.brandAccent,
                  ),
                ),
              ),
              Text(
                '$score%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              score >= 85
                  ? 'Muy alto'
                  : (score >= 70 ? 'Fuerte' : 'En progreso'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: helper,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MiniMetric({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.primaryAccent),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13.5, color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.74)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14.5,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}

class _GlassActionMetric extends StatelessWidget {
  final String title;
  final String value;

  const _GlassActionMetric({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeMetric extends StatelessWidget {
  final String label;
  final String value;

  const _LargeMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 14.5, color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _IndustryBar extends StatelessWidget {
  final String label;
  final double value;

  const _IndustryBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(fontSize: 13.5, color: context.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: const Color(0xFFE7EBF6),
            valueColor: const AlwaysStoppedAnimation<Color>(
              NexTheme.brandAccent,
            ),
          ),
        ),
      ],
    );
  }
}

class _AchievementLine extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AchievementLine({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: context.primaryAccent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            CupertinoIcons.star_fill,
            size: 18,
            color: context.primaryAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13.5, color: context.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileLoadingScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Future<void> Function()? onCancel;

  const _ProfileLoadingScaffold({
    required this.title,
    required this.subtitle,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: NexTheme.shellBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 18),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: context.textSecondary,
                ),
              ),
              if (onCancel != null) ...[
                const SizedBox(height: 18),
                CupertinoButton(
                  onPressed: onCancel,
                  child: const Text('Cerrar sesión si quedó colgado'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileErrorScaffold extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ProfileErrorScaffold({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: NexTheme.shellBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                size: 56,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              MployaPrimaryButton(label: 'Reintentar', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}

Widget profileImageOrFallback({NexUser? profile}) {
  if (profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty) {
    return Image.network(profile.avatarUrl!, fit: BoxFit.cover);
  }
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          NexTheme.brandAccent.withValues(alpha: 0.50),
          NexTheme.brandAccentDark.withValues(alpha: 0.30),
        ],
      ),
    ),
  );
}

String _connectionLabel(String status) {
  switch (status) {
    case 'accepted':
      return 'Conectados';
    case 'pending':
      return 'Invitación enviada';
    default:
      return 'Invitar a entrevista';
  }
}

String _compact(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

String _yearFromDate(DateTime date) => date.year.toString();

List<String> _extractTags(String? text, {List<String> fallback = const []}) {
  final value = (text ?? '').trim();
  if (value.isEmpty) return fallback;
  final words = value
      .split(RegExp(r'[,\.\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .take(4)
      .toList();
  return words.isEmpty ? fallback : words;
}

class _ProfileBundle {
  final List<PortfolioVideo> portfolio;
  final int viewCount;

  const _ProfileBundle({required this.portfolio, required this.viewCount});
}

class _ProfileFacts {
  final String aboutText;

  /// `aboutText` trae un texto de relleno cuando la persona no escribió nada.
  /// Esta bandera permite distinguirlo para no presentar ese relleno como si
  /// fuera la descripción real del perfil.
  final bool aboutVacio;

  final String locationLabel;
  final String modalityLabel;
  final String salaryLabel;
  final String availabilityShort;
  final String availabilityLine;
  final String specialtyLabel;
  final String experienceYearsLabel;
  final String pitchStatus;
  final String connectionsSummary;
  final int viewCount;
  final int contextualScore;
  final int profileStrengthScore;
  final List<String> languages;
  final List<String> preferences;
  final List<String> certifications;
  final List<String> primarySkills;
  final List<String> secondarySkills;
  final List<Experience> experience;
  final List<Education> education;
  final List<PortfolioVideo> portfolio;

  const _ProfileFacts({
    required this.aboutText,
    required this.aboutVacio,
    required this.locationLabel,
    required this.modalityLabel,
    required this.salaryLabel,
    required this.availabilityShort,
    required this.availabilityLine,
    required this.specialtyLabel,
    required this.experienceYearsLabel,
    required this.pitchStatus,
    required this.connectionsSummary,
    required this.viewCount,
    required this.contextualScore,
    required this.profileStrengthScore,
    required this.languages,
    required this.preferences,
    required this.certifications,
    required this.primarySkills,
    required this.secondarySkills,
    required this.experience,
    required this.education,
    required this.portfolio,
  });

  factory _ProfileFacts.fromUser(NexUser profile, _ProfileBundle bundle) {
    final lines = (profile.about ?? '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    String? readLine(String prefix) {
      for (final line in lines) {
        if (line.toLowerCase().startsWith(prefix.toLowerCase())) {
          return line.substring(prefix.length).trim();
        }
      }
      return null;
    }

    final narrativeLines = lines.where((line) {
      final lower = line.toLowerCase();
      return !lower.startsWith('portfolio:') &&
          !lower.startsWith('preferencias:') &&
          !lower.startsWith('idiomas:') &&
          !lower.startsWith('certificaciones:');
    }).toList();

    List<String> splitValues(String? raw) {
      if (raw == null || raw.trim().isEmpty) return [];
      return raw
          .split(RegExp(r'[,/•]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final preferences = splitValues(readLine('Preferencias:'));
    final languages = splitValues(readLine('Idiomas:'));
    final certifications = splitValues(readLine('Certificaciones:'));

    final tags = profile.tags
        .where((item) => item.trim().isNotEmpty)
        .map((item) => item.trim())
        .toList();
    final skills = profile.skills
        .where((item) => item.trim().isNotEmpty)
        .map((item) => item.trim())
        .toList();
    final chips = <String>{...skills, ...tags}.toList();
    final modality = preferences.firstWhere(
      (item) =>
          item.toLowerCase().contains('remoto') ||
          item.toLowerCase().contains('hibr') ||
          item.toLowerCase().contains('presencial'),
      orElse: () => tags.firstWhere(
        (item) =>
            item.toLowerCase().contains('remote') ||
            item.toLowerCase().contains('remoto') ||
            item.toLowerCase().contains('hibrido') ||
            item.toLowerCase().contains('híbrido'),
        orElse: () => 'Modalidad no informada',
      ),
    );

    final profileScoreBase =
        55 +
        (profile.videoUrl != null && profile.videoUrl!.isNotEmpty ? 16 : 0) +
        (profile.skills.isNotEmpty ? 10 : 0) +
        (profile.about != null && profile.about!.trim().isNotEmpty ? 8 : 0) +
        (bundle.portfolio.isNotEmpty ? 8 : 0) +
        (profile.education.isNotEmpty ? 6 : 0);

    final contextualScore = profile.matchPercentage > 0
        ? profile.matchPercentage.round().clamp(0, 100)
        : 0;

    return _ProfileFacts(
      aboutText: narrativeLines.isEmpty
          ? 'Este perfil todavía no tiene una descripción larga, pero ya conserva sus datos reales de video, experiencia y skills.'
          : narrativeLines.join(' '),
      aboutVacio: narrativeLines.isEmpty,
      locationLabel: profile.location?.trim().isNotEmpty == true
          ? profile.location!.trim()
          : 'Ubicación por definir',
      modalityLabel: modality,
      salaryLabel: profile.salaryExpectation?.trim().isNotEmpty == true
          ? profile.salaryExpectation!.trim()
          : 'No informado',
      availabilityShort: profile.isOpenToWork ? 'Disponible' : 'No informada',
      availabilityLine: profile.isOpenToWork
          ? 'Disponible para trabajar'
          : 'Disponibilidad no informada',
      specialtyLabel: profile.headline.isNotEmpty
          ? profile.headline.split(' ').take(2).join(' ')
          : 'Especialidad',
      experienceYearsLabel: profile.experience.isEmpty
          ? 'Sin datos'
          : '${profile.experience.length} ${profile.experience.length == 1 ? 'registro' : 'registros'}',
      pitchStatus: profile.videoUrl != null && profile.videoUrl!.isNotEmpty
          ? 'Activo'
          : 'Pendiente',
      connectionsSummary: profile.connections > 0
          ? 'Tiene ${profile.connections} conexiones visibles dentro de Mploya.'
          : 'Todavía no hay conexiones visibles en común.',
      viewCount: bundle.viewCount,
      contextualScore: contextualScore,
      profileStrengthScore: profileScoreBase.clamp(0, 100),
      languages: languages,
      preferences: preferences,
      certifications: certifications,
      primarySkills: chips.take(6).toList(),
      secondarySkills: chips.skip(6).take(6).toList(),
      experience: profile.experience,
      education: profile.education,
      portfolio: bundle.portfolio,
    );
  }

  String get languagesSummary {
    if (languages.isEmpty) return 'Sin datos';
    if (languages.length == 1) return languages.first;
    return '${languages.first} +${languages.length - 1}';
  }
}

class _TimelineNode {
  final String leftLabel;
  final String title;
  final String subtitle;
  final String description;
  final List<String> tags;
  final Color accent;

  const _TimelineNode({
    required this.leftLabel,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.tags,
    this.accent = NexTheme.brandAccent,
  });
}

class _ReferenceMetric {
  final String label;
  final String value;
  final String helper;

  const _ReferenceMetric({
    required this.label,
    required this.value,
    required this.helper,
  });
}
