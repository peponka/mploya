part of 'profile_screen.dart';

class _InfoSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _InfoSectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MployaShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.primaryAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: context.primaryAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _InfoGridSection extends StatelessWidget {
  final _ProfileFacts facts;

  const _InfoGridSection({required this.facts});

  @override
  Widget build(BuildContext context) {
    final items = [
      _GridInfoItem(
        'Experiencia',
        facts.experienceYearsLabel,
        CupertinoIcons.briefcase_fill,
      ),
      _GridInfoItem(
        'Ubicación',
        facts.locationLabel,
        CupertinoIcons.location_solid,
      ),
      _GridInfoItem(
        'Modalidad',
        facts.modalityLabel,
        CupertinoIcons.house_alt_fill,
      ),
      _GridInfoItem(
        'Disponibilidad',
        facts.availabilityShort,
        CupertinoIcons.time,
      ),
      _GridInfoItem(
        'Salario esperado',
        facts.salaryLabel,
        CupertinoIcons.money_dollar_circle_fill,
      ),
      _GridInfoItem('Idiomas', facts.languagesSummary, CupertinoIcons.globe),
    ];

    return MployaShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información clave',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 880 ? 3 : 2;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 12)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: items
                    .map((item) => SizedBox(width: width, child: item))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GridInfoItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _GridInfoItem(this.title, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: context.primaryAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
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

class _SkillsSection extends StatelessWidget {
  final String title;
  final List<String> skills;
  final List<String> extra;
  final bool metricMode;

  const _SkillsSection({
    required this.title,
    required this.skills,
    required this.extra,
    required this.metricMode,
  });

  @override
  Widget build(BuildContext context) {
    return MployaShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          if (!metricMode)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...skills.map(
                  (skill) =>
                      MployaPill(label: skill, color: NexTheme.brandAccent),
                ),
                ...extra
                    .take(5)
                    .map(
                      (skill) => MployaPill(
                        label: skill,
                        color: NexTheme.brandAccentDark,
                      ),
                    ),
              ],
            )
          else
            Column(
              children: [
                for (var i = 0; i < skills.length; i++) ...[
                  _SkillMeter(
                    label: skills[i],
                    value: math.max(0.42, 0.92 - (i * 0.08)),
                  ),
                  if (i != skills.length - 1) const SizedBox(height: 14),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _SkillMeter extends StatelessWidget {
  final String label;
  final double value;

  const _SkillMeter({required this.label, required this.value});

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
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 9,
            backgroundColor: const Color(0xFFECEFFF),
            valueColor: AlwaysStoppedAnimation<Color>(context.primaryAccent),
          ),
        ),
      ],
    );
  }
}

class _QuickDestinationStrip extends StatelessWidget {
  final VoidCallback onOpenPortfolio;
  final VoidCallback onOpenTimeline;
  final VoidCallback onOpenReferences;
  final int portfolioCount;

  const _QuickDestinationStrip({
    required this.onOpenPortfolio,
    required this.onOpenTimeline,
    required this.onOpenReferences,
    required this.portfolioCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 780;
        final items = [
          _JumpCard(
            title: 'Portfolio visual',
            subtitle: portfolioCount > 0
                ? '$portfolioCount piezas reales conectadas al perfil'
                : 'Preparado para mostrar proyectos reales',
            icon: CupertinoIcons.collections,
            onTap: onOpenPortfolio,
          ),
          _JumpCard(
            title: 'Timeline profesional',
            subtitle: 'Roles, educación, evolución y señales del recorrido',
            icon: CupertinoIcons.chart_bar_alt_fill,
            onTap: onOpenTimeline,
          ),
          _JumpCard(
            title: 'Referencias laborales',
            subtitle: 'Arquitectura preparada para validaciones y reputación',
            icon: CupertinoIcons.shield_lefthalf_fill,
            onTap: onOpenReferences,
          ),
        ];
        if (vertical) {
          return Column(
            children:
                items.expand((e) => [e, const SizedBox(height: 12)]).toList()
                  ..removeLast(),
          );
        }
        return Row(
          children:
              items
              .map((item) => Expanded(child: item))
              .expand((widget) => [widget, const SizedBox(width: 12)])
              .toList()
            ..removeLast(),
        );
      },
    );
  }
}

class _JumpCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _JumpCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MployaShellCard(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: context.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(CupertinoIcons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ExperiencePreview extends StatelessWidget {
  final _ProfileFacts facts;
  final VoidCallback onOpenTimeline;

  const _ExperiencePreview({required this.facts, required this.onOpenTimeline});

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
                child: const Text('Ver timeline'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (facts.experience.isEmpty)
            Text(
              'Todavía no registraste experiencia profesional estructurada.',
              style: TextStyle(fontSize: 14.5, color: context.textSecondary),
            )
          else
            Column(
              children: facts.experience.take(3).map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _TimelinePreviewItem(
                    title: item.role,
                    subtitle: item.company,
                    meta: item.duration,
                    description:
                        item.description ??
                        'Experiencia profesional activa dentro del perfil.',
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _EducationPreview extends StatelessWidget {
  final _ProfileFacts facts;

  const _EducationPreview({required this.facts});

  @override
  Widget build(BuildContext context) {
    return MployaShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Educación',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          if (facts.education.isEmpty)
            Text(
              'Todavía no cargaste educación o certificaciones visibles.',
              style: TextStyle(fontSize: 14.5, color: context.textSecondary),
            )
          else
            Column(
              children: facts.education.take(2).map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _TimelinePreviewItem(
                    title: item.degree,
                    subtitle: item.school,
                    meta: item.years,
                    description:
                        item.field ??
                        'Formación vinculada a la identidad profesional.',
                    accent: const Color(0xFF3B82F6),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _VisibilityAndToolsCard extends StatelessWidget {
  final _ProfileFacts facts;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenPortfolio;

  const _VisibilityAndToolsCard({
    required this.facts,
    required this.onOpenSettings,
    required this.onOpenPortfolio,
  });

  @override
  Widget build(BuildContext context) {
    return MployaShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visibilidad y herramientas',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Conservamos tu configuración real de perfil, notificaciones y privacidad. Desde acá seguimos integrando portfolio, referencias y video pitch dentro del nuevo sistema.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.55,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              MployaSecondaryButton(
                label: 'Configuración',
                icon: CupertinoIcons.settings,
                onPressed: onOpenSettings,
              ),
              MployaSecondaryButton(
                label: 'Abrir portfolio',
                icon: CupertinoIcons.collections,
                onPressed: onOpenPortfolio,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalSummaryCard extends StatelessWidget {
  final _ProfileFacts facts;
  final bool ownMode;
  final bool darkMode;

  const _SignalSummaryCard({
    required this.facts,
    required this.ownMode,
    this.darkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = darkMode ? Colors.white : context.textPrimary;
    final sub = darkMode
        ? Colors.white.withValues(alpha: 0.72)
        : context.textSecondary;
    return Container(
      decoration: BoxDecoration(
        color: darkMode ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: darkMode
              ? Colors.white.withValues(alpha: 0.10)
              : context.shellBorder,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScoreRing(
            score: ownMode ? facts.profileStrengthScore : facts.contextualScore,
            label: ownMode ? 'Perfil listo' : 'Afinidad estimada',
            darkMode: darkMode,
          ),
          const SizedBox(height: 14),
          Text(
            ownMode
                ? 'Tu perfil ya combina video, experiencia, skills y señales profesionales.'
                : 'Lectura rápida del perfil desde una mirada profesional y contextual.',
            style: TextStyle(fontSize: 14.5, height: 1.5, color: sub),
          ),
          const SizedBox(height: 18),
          _SignalRow(
            label: 'Video pitch',
            value: facts.pitchStatus,
            foreground: foreground,
            subtitle: sub,
          ),
          const SizedBox(height: 10),
          _SignalRow(
            label: 'Portfolio',
            value: '${facts.portfolio.length} piezas',
            foreground: foreground,
            subtitle: sub,
          ),
          const SizedBox(height: 10),
          _SignalRow(
            label: 'Skills visibles',
            value: '${facts.primarySkills.length}+ ',
            foreground: foreground,
            subtitle: sub,
          ),
          const SizedBox(height: 10),
          _SignalRow(
            label: 'Vistas',
            value: '${facts.viewCount}',
            foreground: foreground,
            subtitle: sub,
          ),
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color foreground;
  final Color subtitle;

  const _SignalRow({
    required this.label,
    required this.value,
    required this.foreground,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 13.5, color: subtitle)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: foreground,
          ),
        ),
      ],
    );
  }
}

class _VideoPitchCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? videoUrl;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final String primaryLabel;
  final String? secondaryLabel;
  final bool compact;

  const _VideoPitchCard({
    required this.title,
    required this.subtitle,
    required this.videoUrl,
    required this.onPrimary,
    required this.primaryLabel,
    this.onSecondary,
    this.secondaryLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = resolveVideoUrl(videoUrl);
    return MployaShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14.5, color: context.textSecondary),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: effectiveUrl.isEmpty
                ? null
                : () {
                    showCupertinoModalPopup<void>(
                      context: context,
                      builder: (_) =>
                          VideoPlayerModal(videoUrl: effectiveUrl, index: 0),
                    );
                  },
            child: Container(
              height: compact ? 190 : 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1A2234),
                    Color(0xFF0E1422),
                    Color(0xFF2A3154),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.20,
                      child: profileImageOrFallback(profile: null),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: compact ? 66 : 82,
                      height: compact ? 66 : 82,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        CupertinoIcons.play_fill,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            effectiveUrl.isEmpty
                                ? 'Todavía no hay video pitch cargado'
                                : 'Video pitch listo para reproducir',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (effectiveUrl.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Video',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              MployaPrimaryButton(
                label: primaryLabel,
                icon: CupertinoIcons.play_rectangle_fill,
                onPressed: onPrimary,
              ),
              if (secondaryLabel != null)
                MployaSecondaryButton(
                  label: secondaryLabel!,
                  icon: CupertinoIcons.camera_fill,
                  onPressed: onSecondary,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _TabStrip({
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(items.length, (index) {
          final selected = index == selectedIndex;
          return Padding(
            padding: EdgeInsets.only(right: index == items.length - 1 ? 0 : 10),
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected ? context.primaryAccent : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? context.primaryAccent
                        : context.shellBorder,
                  ),
                ),
                child: Text(
                  items[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : context.textPrimary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PublicTabContent extends StatelessWidget {
  final int selectedTab;
  final NexUser profile;
  final _ProfileFacts facts;
  final bool isMobile;
  final VoidCallback onOpenTimeline;

  const _PublicTabContent({
    required this.selectedTab,
    required this.profile,
    required this.facts,
    required this.isMobile,
    required this.onOpenTimeline,
  });

  @override
  Widget build(BuildContext context) {
    switch (selectedTab) {
      case 0:
        return LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 980;
            final experience = _ExperienceColumn(
              profile: profile,
              facts: facts,
              onOpenTimeline: onOpenTimeline,
            );
            final side = _ExperienceSideColumn(facts: facts);
            if (stacked) {
              return Column(
                children: [experience, const SizedBox(height: 16), side],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: experience),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: side),
              ],
            );
          },
        );
      case 1:
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
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
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
          ],
        );
      case 2:
        return _EducationPreview(facts: facts);
      case 3:
        return MployaShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Certificaciones',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              if (facts.certifications.isEmpty)
                Text(
                  'Todavía no hay certificaciones estructuradas en el backend actual.',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: context.textSecondary,
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: facts.certifications
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
        );
      case 4:
        return MployaShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Logros y señales destacadas',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _TimelinePreviewItem(
                title: 'Perfil video-first listo para procesos',
                subtitle: 'Video pitch + experiencia + portfolio',
                meta: '${facts.contextualScore}%',
                description:
                    'La identidad profesional ya está armada dentro del nuevo sistema de Mploya.',
              ),
              const SizedBox(height: 14),
              _TimelinePreviewItem(
                title: 'Señales visibles de mercado',
                subtitle:
                    '${facts.viewCount} vistas · ${profile.connections} conexiones',
                meta: facts.experienceYearsLabel,
                description:
                    'El perfil conserva sus métricas reales sin volver al formato legacy.',
                accent: const Color(0xFF10B981),
              ),
            ],
          ),
        );
      case 5:
        return MployaShellCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Idiomas',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: facts.languages
                    .map(
                      (language) => MployaPill(
                        label: language,
                        color: const Color(0xFF2563EB),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
