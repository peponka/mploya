part of 'profile_screen.dart';

class _CandidateTimelineScreen extends StatelessWidget {
  final NexUser profile;
  final _ProfileFacts facts;
  final bool isOwnProfile;

  const _CandidateTimelineScreen({
    required this.profile,
    required this.facts,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: NexTheme.shellBg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
          children: [
            _ScreenHeader(
              title: 'Timeline Profesional',
              subtitle:
                  'El recorrido completo de ${profile.name.split(' ').first}',
              onShare: () => ShareService.instance.shareProfile(
                name: profile.name,
                headline: profile.headline,
                userId: profile.id,
                accountType: profile.accountType,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 980;
                final hero = _LightSummaryHero(
                  profile: profile,
                  facts: facts,
                  ctaLabel: 'Ver perfil público',
                );
                final summary = _SignalSummaryCard(
                  facts: facts,
                  ownMode: false,
                );
                if (stacked) {
                  return Column(
                    children: [hero, const SizedBox(height: 16), summary],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: hero),
                    const SizedBox(width: 16),
                    SizedBox(width: 240, child: summary),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _TabStrip(
              items: const [
                'Experiencia',
                'Educación',
                'Certificaciones',
                'Logros',
                'Todo',
              ],
              selectedIndex: 4,
              onChanged: (_) {},
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _LargeMetric(
                    label: 'Experiencia total',
                    value: facts.experienceYearsLabel,
                  ),
                ),
                Expanded(
                  child: _LargeMetric(
                    label: 'Proyectos',
                    value: '${math.max(3, facts.portfolio.length)}',
                  ),
                ),
                Expanded(
                  child: _LargeMetric(
                    label: 'Empresas',
                    value: '${math.max(1, profile.experience.length)}',
                  ),
                ),
                Expanded(
                  child: _LargeMetric(
                    label: 'Skills aplicados',
                    value: '${profile.skills.length}+',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 980;
                final timeline = _TimelineRail(profile: profile, facts: facts);
                final sidebar = _TimelineSidebar(facts: facts);
                if (stacked) {
                  return Column(
                    children: [timeline, const SizedBox(height: 16), sidebar],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: timeline),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: sidebar),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            MployaShellCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOwnProfile
                              ? 'Tu recorrido ya está listo para impresionar'
                              : '¿Quieres conocer más sobre ${profile.name.split(' ').first}?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isOwnProfile
                              ? 'Seguimos usando tu experiencia real, educación y señales actuales sin dejar el perfil en un formato de CV clásico.'
                              : 'Este timeline ya está conectado con video pitch, portfolio y señales profesionales reales.',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.55,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  MployaPrimaryButton(
                    label: isOwnProfile ? 'Editar experiencia' : 'Abrir perfil',
                    icon: isOwnProfile
                        ? CupertinoIcons.pencil
                        : CupertinoIcons.person,
                    onPressed: null,
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

class _CandidateReferencesScreen extends StatelessWidget {
  final NexUser profile;
  final _ProfileFacts facts;
  final bool isOwnProfile;

  const _CandidateReferencesScreen({
    required this.profile,
    required this.facts,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    final referenceSignals = <_ReferenceMetric>[
      _ReferenceMetric(
        label: 'Calificación promedio',
        value: profile.ratingStars > 0
            ? profile.ratingStars.toStringAsFixed(1)
            : '0.0',
        helper: profile.ratingCount > 0
            ? '${profile.ratingCount} evaluaciones'
            : 'Sin referencias verificadas',
      ),
      _ReferenceMetric(
        label: 'Referencias verificadas',
        value: '0',
        helper: 'Backend pendiente',
      ),
      _ReferenceMetric(
        label: 'Tasa de respuesta',
        value: '0%',
        helper: 'Sin solicitudes activas',
      ),
      _ReferenceMetric(
        label: 'Tiempo promedio',
        value: '--',
        helper: 'Pendiente de datos',
      ),
    ];

    return CupertinoPageScaffold(
      backgroundColor: NexTheme.shellBg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
          children: [
            _ScreenHeader(
              title: 'Referencias Laborales',
              subtitle:
                  'Verificá experiencia, señales y preparación del candidato',
              primaryAction: isOwnProfile ? 'Solicitar referencia' : null,
            ),
            const SizedBox(height: 18),
            _ReferencesHero(profile: profile, facts: facts),
            const SizedBox(height: 18),
            _TabStrip(
              items: const [
                'Resumen',
                'Referencias',
                'Historial',
                'Solicitudes',
              ],
              selectedIndex: 0,
              onChanged: (_) {},
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: referenceSignals
                  .map(
                    (metric) => SizedBox(
                      width: (MediaQuery.of(context).size.width - 60) / 2,
                      child: MployaShellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metric.value,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              metric.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              metric.helper,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            _ReferenceSidebar(
              profile: profile,
              facts: facts,
              isOwnProfile: isOwnProfile,
            ),
            const SizedBox(height: 18),
            MployaShellCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historial de referencias',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FD),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Todavía no existen referencias verificadas conectadas desde backend.',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dejamos la arquitectura y la experiencia preparadas para mostrar solicitudes, validaciones, comentarios y estados reales apenas esa fuente esté disponible.',
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final String shareLabel;
  final VoidCallback onShare;
  final VoidCallback onMore;

  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.shareLabel,
    required this.onShare,
    required this.onMore,
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
                  letterSpacing: -0.8,
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
        MployaSecondaryButton(
          label: shareLabel,
          icon: CupertinoIcons.share,
          onPressed: onShare,
        ),
        const SizedBox(width: 10),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onMore,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.shellBorder),
            ),
            child: const Icon(
              CupertinoIcons.ellipsis,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }
}

class _OwnedHero extends StatelessWidget {
  final NexUser profile;
  final _ProfileFacts facts;
  final bool isMobile;
  final VoidCallback onPickAvatar;

  const _OwnedHero({
    required this.profile,
    required this.facts,
    required this.isMobile,
    required this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF151A2B),
            const Color(0xFF0B1020),
            NexTheme.brandAccent.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF151A2B).withValues(alpha: 0.26),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 18 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MployaPill(
                        label: profile.isOpenToWork
                            ? 'Disponible ahora'
                            : 'Perfil activo',
                        icon: CupertinoIcons.circle_fill,
                        color: profile.isOpenToWork
                            ? NexTheme.brandMint
                            : NexTheme.brandSky,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        profile.name,
                        style: const TextStyle(
                          fontSize: 34,
                          height: 1.0,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        profile.headline.isNotEmpty
                            ? profile.headline
                            : 'Talento en construcción',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: NexTheme.brandAccentDark,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          _HeroMeta(
                            icon: CupertinoIcons.location_solid,
                            label: facts.locationLabel,
                          ),
                          _HeroMeta(
                            icon: CupertinoIcons.briefcase_fill,
                            label: facts.modalityLabel,
                          ),
                          _HeroMeta(
                            icon: CupertinoIcons.money_dollar_circle_fill,
                            label: facts.salaryLabel,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Column(
                  children: [
                    GestureDetector(
                      onTap: onPickAvatar,
                      child: Container(
                        width: isMobile ? 84 : 112,
                        height: isMobile ? 84 : 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          image:
                              profile.avatarUrl != null &&
                                  profile.avatarUrl!.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(profile.avatarUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                        child:
                            profile.avatarUrl == null ||
                                profile.avatarUrl!.isEmpty
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
                    ),
                    const SizedBox(height: 16),
                    _ScoreRing(
                      score: facts.profileStrengthScore,
                      label: 'Perfil listo',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _GlassActionMetric(
                    title: 'Video Pitch',
                    value:
                        profile.videoUrl != null && profile.videoUrl!.isNotEmpty
                        ? 'Activo'
                        : 'Pendiente',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GlassActionMetric(
                    title: 'Portfolio',
                    value: '${facts.portfolio.length} piezas',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GlassActionMetric(
                    title: 'Visibilidad',
                    value: '${facts.viewCount} vistas',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicHero extends StatelessWidget {
  final NexUser profile;
  final _ProfileFacts facts;
  final bool isMobile;
  final VoidCallback onContact;
  final VoidCallback onInvite;
  final VoidCallback onToggleSaved;
  final VoidCallback onShowMore;
  final String connectionStatus;
  final bool isLoadingConnection;
  final bool isSavedProfile;
  final bool isSavingProfile;

  const _PublicHero({
    required this.profile,
    required this.facts,
    required this.isMobile,
    required this.onContact,
    required this.onInvite,
    required this.onToggleSaved,
    required this.onShowMore,
    required this.connectionStatus,
    required this.isLoadingConnection,
    required this.isSavedProfile,
    required this.isSavingProfile,
  });

  @override
  Widget build(BuildContext context) {
    final isCompany = profile.isCompanyAct;
    final hasContextualScore = !isCompany && profile.matchPercentage > 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2234), Color(0xFF101726), Color(0xFF111827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.16),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 18 : 24),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: isMobile ? 94 : 120,
                  height: isMobile ? 94 : 120,
                  decoration: BoxDecoration(
                    shape: isCompany ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: isCompany ? BorderRadius.circular(24) : null,
                    border: Border.all(color: Colors.white, width: 3),
                    image:
                        profile.avatarUrl != null &&
                            profile.avatarUrl!.isNotEmpty
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
                              fontSize: 34,
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
                          fontSize: 34,
                          height: 1.0,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.headline.isNotEmpty
                                  ? profile.headline
                                  : (isCompany
                                        ? 'Empresa empleadora'
                                        : 'Perfil profesional'),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.90),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          MployaPill(
                            label: isCompany
                                ? (profile.isHiring
                                      ? 'Buscando talento'
                                      : 'Empresa')
                                : (profile.isOpenToWork
                                      ? 'Abierta a oportunidades'
                                      : 'Perfil activo'),
                            color: isCompany
                                ? NexTheme.brandAccentDark
                                : (profile.isOpenToWork
                                      ? NexTheme.brandAccentDark
                                      : NexTheme.brandMint),
                            active: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 14,
                        runSpacing: 10,
                        children: [
                          if ((profile.location ?? '').trim().isNotEmpty)
                            _HeroMeta(
                              icon: CupertinoIcons.location_solid,
                              label: facts.locationLabel,
                            ),
                          if (!isCompany && profile.isOpenToWork)
                            _HeroMeta(
                              icon: CupertinoIcons.airplane,
                              label: facts.availabilityLine,
                            ),
                          if (isCompany && profile.isHiring)
                            const _HeroMeta(
                              icon: CupertinoIcons.briefcase_fill,
                              label: 'Buscando talento',
                            )
                          else if (!isCompany &&
                              facts.modalityLabel != 'Modalidad no informada')
                            _HeroMeta(
                              icon: CupertinoIcons.briefcase_fill,
                              label: facts.modalityLabel,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isMobile && hasContextualScore)
                  Container(
                    width: 220,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ScoreRing(
                          score: facts.contextualScore,
                          label: 'Afinidad estimada',
                          darkMode: true,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Según el match disponible para esta búsqueda',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.76),
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (isMobile && hasContextualScore) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: _ScoreRing(
                  score: facts.contextualScore,
                  label: 'Afinidad estimada',
                  darkMode: true,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                MployaPrimaryButton(
                  label: 'Contactar',
                  icon: CupertinoIcons.paperplane_fill,
                  onPressed: onContact,
                ),
                MployaSecondaryButton(
                  label: _connectionLabel(connectionStatus),
                  icon: CupertinoIcons.calendar,
                  onPressed: isLoadingConnection ? null : onInvite,
                ),
                MployaSecondaryButton(
                  label: isSavedProfile ? 'Guardado' : 'Guardar',
                  icon: isSavedProfile
                      ? CupertinoIcons.bookmark_fill
                      : CupertinoIcons.bookmark,
                  onPressed: isSavingProfile ? null : onToggleSaved,
                ),
                MployaSecondaryButton(
                  label: 'Más',
                  icon: CupertinoIcons.ellipsis,
                  onPressed: onShowMore,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicMetricsStrip extends StatelessWidget {
  final NexUser profile;
  final _ProfileFacts facts;

  const _PublicMetricsStrip({required this.profile, required this.facts});

  @override
  Widget build(BuildContext context) {
    return MployaShellCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          if (profile.experience.isNotEmpty)
            _MiniMetric(
              icon: CupertinoIcons.briefcase_fill,
              title: facts.experienceYearsLabel,
              subtitle: 'Experiencia',
            ),
          if (profile.headline.isNotEmpty)
            _MiniMetric(
              icon: CupertinoIcons.sparkles,
              title: facts.specialtyLabel,
              subtitle: 'Especialidad',
            ),
          if (profile.isOpenToWork)
            _MiniMetric(
              icon: CupertinoIcons.time,
              title: facts.availabilityShort,
              subtitle: 'Disponibilidad',
            ),
          if (facts.modalityLabel != 'Modalidad no informada')
            _MiniMetric(
              icon: CupertinoIcons.house_alt_fill,
              title: facts.modalityLabel,
              subtitle: 'Modalidad',
            ),
          if (facts.languages.isNotEmpty)
            _MiniMetric(
              icon: CupertinoIcons.globe,
              title: facts.languagesSummary,
              subtitle: 'Idiomas',
            ),
        ],
      ),
    );
  }
}

class _PrivateActionDeck extends StatelessWidget {
  final VoidCallback onOpenEdit;
  final VoidCallback onOpenVideoPitch;
  final VoidCallback onOpenPitchCamera;
  final VoidCallback onShare;
  final VoidCallback onShowMore;

  const _PrivateActionDeck({
    required this.onOpenEdit,
    required this.onOpenVideoPitch,
    required this.onOpenPitchCamera,
    required this.onShare,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _ActionDeckItem(
        icon: CupertinoIcons.pencil,
        label: 'Editar',
        onTap: onOpenEdit,
      ),
      _ActionDeckItem(
        icon: CupertinoIcons.play_rectangle_fill,
        label: 'Video pitch',
        onTap: onOpenVideoPitch,
      ),
      _ActionDeckItem(
        icon: CupertinoIcons.camera_fill,
        label: 'Grabar',
        onTap: onOpenPitchCamera,
      ),
      _ActionDeckItem(
        icon: CupertinoIcons.share,
        label: 'Compartir',
        onTap: onShare,
      ),
      _ActionDeckItem(
        icon: CupertinoIcons.ellipsis,
        label: 'Más',
        onTap: onShowMore,
      ),
    ];

    return MployaShellCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        children:
            items
                .map((item) => Expanded(child: item))
                .expand((widget) => [widget, const SizedBox(width: 8)])
                .toList()
              ..removeLast(),
      ),
    );
  }
}

class _ActionDeckItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionDeckItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FD),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: context.primaryAccent),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
