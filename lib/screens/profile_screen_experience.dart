part of 'profile_screen.dart';

class _ExperienceColumn extends StatelessWidget {
  final NexUser profile;
  final _ProfileFacts facts;
  final VoidCallback onOpenTimeline;

  const _ExperienceColumn({
    required this.profile,
    required this.facts,
    required this.onOpenTimeline,
  });

  @override
  Widget build(BuildContext context) {
    return MployaShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Experiencia',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onOpenTimeline,
                child: const Text('Ver toda mi experiencia'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (profile.experience.isEmpty)
            Text(
              'No hay experiencia visible todavía.',
              style: TextStyle(fontSize: 14.5, color: context.textSecondary),
            )
          else
            Column(
              children: profile.experience.map((experience) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _TimelinePreviewItem(
                    title: experience.role,
                    subtitle: experience.company,
                    meta: experience.duration,
                    description:
                        experience.description ??
                        'Experiencia real cargada en el perfil.',
                    tags: _extractTags(
                      experience.description,
                      fallback: facts.primarySkills.take(3).toList(),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _ExperienceSideColumn extends StatelessWidget {
  final _ProfileFacts facts;

  const _ExperienceSideColumn({required this.facts});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SkillsSection(
          title: 'Skills principales',
          skills: facts.primarySkills,
          extra: facts.secondarySkills,
          metricMode: true,
        ),
        const SizedBox(height: 16),
        MployaShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Intereses profesionales',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: facts.preferences
                    .map(
                      (item) => MployaPill(
                        label: item,
                        color: NexTheme.brandAccentDark,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        MployaShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Conexiones en común',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                facts.connectionsSummary,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProjectShowcase extends StatelessWidget {
  final List<PortfolioVideo> portfolio;
  final VoidCallback onOpenPortfolio;
  final bool isMobile;

  const _ProjectShowcase({
    required this.portfolio,
    required this.onOpenPortfolio,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return MployaShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Proyectos destacados',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onOpenPortfolio,
                child: const Text('Ver todos'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (portfolio.isEmpty)
            Text(
              'Todavía no hay piezas visuales publicadas en este portfolio.',
              style: TextStyle(fontSize: 14.5, color: context.textSecondary),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = isMobile
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 24) / 3;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: portfolio.take(3).map((video) {
                    return SizedBox(
                      width: width,
                      child: _CompactProjectCard(video: video),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CompactProjectCard extends StatelessWidget {
  final PortfolioVideo video;

  const _CompactProjectCard({required this.video});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 140,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF2B3155),
                  Color(0xFF0E1726),
                  Color(0xFF1B2441),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.play_circle,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (video.description ?? 'Proyecto profesional visual').trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: context.textSecondary,
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

class _ScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onShare;
  final String? primaryAction;

  const _ScreenHeader({
    required this.title,
    required this.subtitle,
    this.onShare,
    this.primaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.shellBorder),
            ),
            child: const Icon(CupertinoIcons.back, color: Color(0xFF111827)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 15, color: context.textSecondary),
              ),
            ],
          ),
        ),
        if (primaryAction != null) ...[
          MployaSecondaryButton(
            label: primaryAction!,
            icon: CupertinoIcons.plus,
            onPressed: null,
          ),
          const SizedBox(width: 10),
        ],
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onShare,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.shellBorder),
            ),
            child: Icon(
              onShare == null ? CupertinoIcons.ellipsis : CupertinoIcons.share,
              color: const Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }
}

class _DarkSummaryHero extends StatelessWidget {
  final NexUser profile;

  const _DarkSummaryHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              image: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(profile.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: Colors.white.withValues(alpha: 0.10),
            ),
            child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                ? Center(
                    child: Text(
                      profile.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  profile.headline.isNotEmpty
                      ? profile.headline
                      : 'Perfil profesional',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${profile.location ?? 'Ubicación por definir'} • ${profile.isOpenToWork ? 'Disponible para trabajar' : 'Perfil activo'}',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Colors.white.withValues(alpha: 0.74),
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

class _LightSummaryHero extends StatelessWidget {
  final NexUser profile;
  final _ProfileFacts facts;
  final String ctaLabel;

  const _LightSummaryHero({
    required this.profile,
    required this.facts,
    required this.ctaLabel,
  });

  @override
  Widget build(BuildContext context) {
    return MployaShellCard(
      child: Row(
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              image: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(profile.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: const Color(0xFFF1F3FD),
            ),
            child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                ? Center(
                    child: Text(
                      profile.initials,
                      style: TextStyle(
                        color: context.primaryAccent,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  profile.headline.isNotEmpty
                      ? profile.headline
                      : 'Perfil profesional',
                  style: TextStyle(fontSize: 18, color: context.textPrimary),
                ),
                const SizedBox(height: 12),
                Text(
                  '${facts.locationLabel} • ${facts.availabilityLine}',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => launchUrl(
                    Uri.parse(ShareService.instance.profileUrl(profile.id)),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(ctaLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRail extends StatelessWidget {
  final NexUser profile;
  final _ProfileFacts facts;

  const _TimelineRail({required this.profile, required this.facts});

  @override
  Widget build(BuildContext context) {
    final items = <_TimelineNode>[
      ...profile.experience.map(
        (item) => _TimelineNode(
            leftLabel: item.duration.isEmpty ? 'Experiencia' : item.duration,
            title: item.role,
            subtitle: item.company,
          description:
              item.description ??
              'Experiencia profesional activa dentro del perfil.',
          tags: _extractTags(
            item.description,
            fallback: facts.primarySkills.take(4).toList(),
          ),
        ),
      ),
      ...facts.education.map(
        (item) => _TimelineNode(
            leftLabel: item.years,
            title: item.degree,
            subtitle: item.school,
          description:
              item.field ??
              'Formación conectada con la trayectoria profesional.',
            tags: _extractTags(item.field, fallback: const ['Educación']),
            accent: const Color(0xFF2563EB),
        ),
      ),
    ];

    return MployaShellCard(
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == items.length - 1 ? 0 : 18,
            ),
            child: _TimelineRailItem(item: item),
          );
        }),
      ),
    );
  }
}

class _TimelineSidebar extends StatelessWidget {
  final _ProfileFacts facts;

  const _TimelineSidebar({required this.facts});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MployaShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vista rápida',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _SignalRow(
                label: 'Experiencia',
                value: facts.experienceYearsLabel,
                foreground: context.textPrimary,
                subtitle: context.textSecondary,
              ),
              const SizedBox(height: 10),
              _SignalRow(
                label: 'Empresas',
                value: '${facts.experience.length}',
                foreground: context.textPrimary,
                subtitle: context.textSecondary,
              ),
              const SizedBox(height: 10),
              _SignalRow(
                label: 'Industrias',
                value: '${math.max(1, facts.preferences.length)}',
                foreground: context.textPrimary,
                subtitle: context.textSecondary,
              ),
              const SizedBox(height: 10),
              _SignalRow(
                label: 'Skills',
                value: '${facts.primarySkills.length}+ ',
                foreground: context.textPrimary,
                subtitle: context.textSecondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        MployaShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Industrias',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              for (final item in facts.preferences.take(4)) ...[
                _IndustryBar(
                  label: item,
                  value: math.max(
                    0.14,
                    0.72 - (facts.preferences.indexOf(item) * 0.14),
                  ),
                ),
                if (facts.preferences.take(4).last != item)
                  const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        MployaShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Logros destacados',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _AchievementLine(
                title: 'Perfil video-first',
                subtitle: 'Conecta pitch, skills y experiencia',
              ),
              const SizedBox(height: 12),
              _AchievementLine(
                title: 'Portfolio activo',
                subtitle:
                    '${facts.portfolio.length} piezas listas para revisión',
              ),
              const SizedBox(height: 12),
              _AchievementLine(
                title: 'Señal profesional',
                subtitle: '${facts.contextualScore}% de lectura contextual',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReferenceSidebar extends StatelessWidget {
  final NexUser profile;
  final _ProfileFacts facts;
  final bool isOwnProfile;

  const _ReferenceSidebar({
    required this.profile,
    required this.facts,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MployaShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estado de verificaciones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Todavía no hay referencias verificadas conectadas. Dejamos esta vista lista para mostrar quien respondió, su relación profesional y la validación real apenas el backend esté disponible.',
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        MployaShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IA Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Con los datos reales ya visibles, el perfil destaca por ${facts.primarySkills.take(2).join(' y ').toLowerCase()}, una narrativa clara en video y una identidad profesional consistente.',
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        MployaShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Solicitudes de referencia',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _SignalRow(
                label: 'Pendientes',
                value: '0',
                foreground: context.textPrimary,
                subtitle: context.textSecondary,
              ),
              const SizedBox(height: 10),
              _SignalRow(
                label: 'Expiradas',
                value: '0',
                foreground: context.textPrimary,
                subtitle: context.textSecondary,
              ),
              const SizedBox(height: 14),
              Text(
                isOwnProfile
                    ? 'La UI ya está lista para que puedas pedir referencias reales sin inventar registros.'
                    : 'La experiencia pública mostrará respuestas verificadas cuando esa capa exista en backend.',
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReferencesHero extends StatelessWidget {
  final NexUser profile;
  final _ProfileFacts facts;

  const _ReferencesHero({required this.profile, required this.facts});

  @override
  Widget build(BuildContext context) {
    return MployaShellCard(
      child: Row(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(profile.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: const Color(0xFFF3F4FA),
            ),
            child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                ? Center(
                    child: Text(
                      profile.initials,
                      style: TextStyle(
                        color: context.primaryAccent,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  profile.headline.isNotEmpty
                      ? profile.headline
                      : 'Perfil profesional',
                  style: TextStyle(fontSize: 16.5, color: context.textPrimary),
                ),
                const SizedBox(height: 12),
                Text(
                  '${facts.locationLabel} • ${facts.modalityLabel}',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _ScoreRing(
            score: math.max(0, (profile.ratingStars * 20).round()),
            label: 'Reputación',
          ),
        ],
      ),
    );
  }
}

class _TimelinePreviewItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String meta;
  final String description;
  final List<String> tags;
  final Color accent;

  const _TimelinePreviewItem({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.description,
    this.tags = const [],
    this.accent = NexTheme.brandAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(CupertinoIcons.circle_fill, size: 16, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    meta,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: context.textSecondary,
                ),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags
                      .map((tag) => MployaPill(label: tag, color: accent))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
