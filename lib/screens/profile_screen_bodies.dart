part of 'profile_screen.dart';

class _CandidatoOwnProfileBody extends StatelessWidget {
  final NexUser profile;
  final _ProfileFacts facts;
  final VoidCallback onOpenEdit;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenVideoPitch;
  final VoidCallback onOpenPitchCamera;
  final VoidCallback onPickAvatar;
  final VoidCallback onShare;
  final VoidCallback onOpenPortfolio;
  final VoidCallback onOpenTimeline;
  final VoidCallback onOpenReferences;
  final VoidCallback onOpenTools;
  final VoidCallback onOpenSaved;

  const _CandidatoOwnProfileBody({
    required this.profile,
    required this.facts,
    required this.onOpenEdit,
    required this.onOpenSettings,
    required this.onOpenVideoPitch,
    required this.onOpenPitchCamera,
    required this.onPickAvatar,
    required this.onShare,
    required this.onOpenPortfolio,
    required this.onOpenTimeline,
    required this.onOpenReferences,
    required this.onOpenTools,
    required this.onOpenSaved,
  });

  bool get _esConfidencial {
    final t = profile.accountType.toLowerCase();
    return t == 'confidencial' || t == 'stealth';
  }

  /// Sólo números que existen de verdad: vistas medidas, conexiones guardadas y
  /// el puntaje de completitud, que se calcula sobre el propio perfil.
  List<CandMetrica> get _metricas => [
    CandMetrica('${facts.viewCount}', 'Vistas'),
    CandMetrica('${profile.connections}', 'Conexiones'),
    CandMetrica('${facts.profileStrengthScore}%', 'Perfil'),
  ];

  List<String> get _skills {
    final chips = <String>{
      ...profile.skills.map((s) => s.trim()),
      ...profile.tags.map((t) => t.trim()),
    }..removeWhere((s) => s.isEmpty);
    return chips.take(8).toList();
  }

  List<CandExperienciaItem> get _experiencia => profile.experience
      .map(
        (e) => CandExperienciaItem(
          rol: e.role,
          empresa: e.company,
          periodo: e.duration,
          logoUrl: e.companyLogoUrl,
        ),
      )
      .toList();

  List<CandAcceso> get _accesos => [
    CandAcceso(
      icono: CupertinoIcons.wrench_fill,
      titulo: 'Mis Herramientas',
      detalle: 'CV, referidos, impulsar perfil',
      onTap: onOpenTools,
    ),
    CandAcceso(
      icono: CupertinoIcons.bookmark_fill,
      titulo: 'Guardados',
      detalle: 'Vacantes que guardaste',
      onTap: onOpenSaved,
    ),
    CandAcceso(
      icono: CupertinoIcons.collections,
      titulo: 'Portfolio',
      detalle: facts.portfolio.isEmpty
          ? 'Todavía sin piezas'
          : '${facts.portfolio.length} '
                '${facts.portfolio.length == 1 ? 'pieza' : 'piezas'}',
      onTap: onOpenPortfolio,
    ),
    CandAcceso(
      icono: CupertinoIcons.time,
      titulo: 'Trayectoria',
      detalle: profile.experience.isEmpty
          ? 'Todavía sin experiencia cargada'
          : '${profile.experience.length} '
                '${profile.experience.length == 1 ? 'experiencia' : 'experiencias'}',
      onTap: onOpenTimeline,
    ),
    CandAcceso(
      icono: CupertinoIcons.star_fill,
      titulo: 'Referencias',
      detalle: profile.ratingCount > 0
          ? '${profile.ratingCount} '
                '${profile.ratingCount == 1 ? 'valoración' : 'valoraciones'}'
          : 'Todavía sin valoraciones',
      onTap: onOpenReferences,
    ),
    if (profile.isVerified)
      const CandAcceso(
        icono: CupertinoIcons.checkmark_shield_fill,
        titulo: 'Verificación',
        detalle: 'Perfil verificado',
        verde: true,
      ),
  ];

  String get _resumenOculto {
    final partes = [
      profile.headline.trim(),
      (profile.location ?? '').trim(),
    ].where((p) => p.isNotEmpty);
    return partes.join(' · ');
  }

  // ── Piezas compartidas por los tres formatos ──

  Widget get _portada =>
      CandPerfilPortada(onCompartir: onShare, onConfiguracion: onOpenSettings);

  Widget _identidad({bool ancho = false}) => CandPerfilIdentidad(
    nombre: profile.name,
    headline: profile.headline,
    ubicacion: (profile.location ?? '').trim(),
    avatarUrl: profile.avatarUrl,
    verificado: profile.isVerified,
    abiertaOfertas: profile.isOpenToWork,
    ancho: ancho,
    onAvatarTap: onPickAvatar,
  );

  Widget get _videoPitch => CandPerfilVideoPitch(
    tieneVideo: (profile.videoUrl ?? '').isNotEmpty,
    onVer: onOpenVideoPitch,
    onGrabar: onOpenPitchCamera,
  );

  Widget get _progreso => CandPerfilProgreso(
    porcentaje: facts.profileStrengthScore,
    tieneVideo: (profile.videoUrl ?? '').trim().isNotEmpty,
    tieneExperiencia: profile.experience.isNotEmpty,
    onEditar: onOpenEdit,
    onGrabar: onOpenPitchCamera,
  );

  Widget get _sobre => CandPerfilSobre(
    texto: facts.aboutVacio ? '' : facts.aboutText,
    etiquetas: _skills,
    onEditar: onOpenEdit,
  );

  Widget get _experienciaCard =>
      CandPerfilExperiencia(items: _experiencia, onVerTodo: onOpenTimeline);

  Widget get _confidencial => CandPerfilConfidencial(
    activo: _esConfidencial,
    resumenOculto: _resumenOculto,
    onTap: onOpenSettings,
  );

  @override
  Widget build(BuildContext context) {
    return switch (candFormatoDe(context)) {
      CandFormato.desktop => _desktop(),
      CandFormato.tablet => _tablet(),
      CandFormato.mobile => _mobile(),
    };
  }

  Widget _mobile() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _portada,
        _identidad(),
        const SizedBox(height: 14),
        _bloque(CandPerfilMetricas(metricas: _metricas)),
        const SizedBox(height: 14),
        _bloque(_progreso),
        const SizedBox(height: 14),
        _bloque(
          CandPerfilAcciones(
            onEditar: onOpenEdit,
            onConfiguracion: onOpenSettings,
          ),
        ),
        const SizedBox(height: 14),
        _bloque(_videoPitch),
        const SizedBox(height: 14),
        _bloque(CandPerfilAccesos(accesos: _accesos)),
        const SizedBox(height: 14),
        _bloque(_sobre),
        const SizedBox(height: 14),
        _bloque(_experienciaCard),
        const SizedBox(height: 14),
        _bloque(_confidencial),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _tablet() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _portada,
        _identidad(),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    CandPerfilMetricas(metricas: _metricas),
                    const SizedBox(height: 14),
                    _progreso,
                    const SizedBox(height: 14),
                    _videoPitch,
                    const SizedBox(height: 14),
                    _sobre,
                    const SizedBox(height: 14),
                    _experienciaCard,
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    CandPerfilAcciones(
                      vertical: true,
                      onEditar: onOpenEdit,
                      onConfiguracion: onOpenSettings,
                    ),
                    const SizedBox(height: 14),
                    CandPerfilAccesos(accesos: _accesos),
                    const SizedBox(height: 14),
                    _confidencial,
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _desktop() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Center(
          // Ancho máximo: en 1440 el contenido no se estira de borde a borde,
          // se centra en una columna legible.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: Column(
              children: [
                CandPerfilPortada(
                  alto: 150,
                  onCompartir: onShare,
                  onConfiguracion: onOpenSettings,
                ),
                _identidad(ancho: true),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            CandPerfilMetricas(metricas: _metricas),
                            const SizedBox(height: 14),
                            _progreso,
                            const SizedBox(height: 14),
                            _videoPitch,
                            const SizedBox(height: 14),
                            _sobre,
                            const SizedBox(height: 14),
                            _experienciaCard,
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            CandPerfilAcciones(
                              vertical: true,
                              onEditar: onOpenEdit,
                              onConfiguracion: onOpenSettings,
                            ),
                            const SizedBox(height: 14),
                            CandPerfilAccesos(accesos: _accesos),
                            const SizedBox(height: 14),
                            _confidencial,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bloque(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: child,
  );
}

class _OwnProfileBody extends StatelessWidget {
  final NexUser profile;
  final _ProfileFacts facts;
  final bool isMobile;
  final VoidCallback onOpenEdit;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenVideoPitch;
  final VoidCallback onOpenPitchCamera;
  final VoidCallback onPickAvatar;
  final VoidCallback onShare;
  final VoidCallback onShowMore;
  final VoidCallback onOpenPortfolio;
  final VoidCallback onOpenTimeline;
  final VoidCallback onOpenReferences;

  const _OwnProfileBody({
    required this.profile,
    required this.facts,
    required this.isMobile,
    required this.onOpenEdit,
    required this.onOpenSettings,
    required this.onOpenVideoPitch,
    required this.onOpenPitchCamera,
    required this.onPickAvatar,
    required this.onShare,
    required this.onShowMore,
    required this.onOpenPortfolio,
    required this.onOpenTimeline,
    required this.onOpenReferences,
  });

  @override
  Widget build(BuildContext context) {
    final mainContent = [
      _TopBar(
        title: 'Perfil del candidato',
        subtitle: 'Gestioná tu identidad profesional',
        shareLabel: 'Compartir',
        onShare: onShare,
        onMore: onShowMore,
      ),
      const SizedBox(height: 18),
      _OwnedHero(
        profile: profile,
        facts: facts,
        isMobile: isMobile,
        onPickAvatar: onPickAvatar,
      ),
      const SizedBox(height: 18),
      _PrivateActionDeck(
        onOpenEdit: onOpenEdit,
        onOpenVideoPitch: onOpenVideoPitch,
        onOpenPitchCamera: onOpenPitchCamera,
        onShare: onShare,
        onShowMore: onShowMore,
      ),
      const SizedBox(height: 18),
      _InfoSectionCard(
        title: 'Sobre mí',
        icon: CupertinoIcons.sparkles,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              facts.aboutText,
              style: TextStyle(
                fontSize: 15,
                height: 1.55,
                color: context.textSecondary,
              ),
            ),
            if (facts.preferences.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: facts.preferences
                    .map(
                      (item) =>
                          MployaPill(label: item, color: NexTheme.brandAccent),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 18),
      _InfoGridSection(facts: facts),
      const SizedBox(height: 18),
      _SkillsSection(
        title: 'Skills principales',
        skills: facts.primarySkills,
        extra: facts.secondarySkills,
        metricMode: false,
      ),
      const SizedBox(height: 18),
      _QuickDestinationStrip(
        onOpenPortfolio: onOpenPortfolio,
        onOpenTimeline: onOpenTimeline,
        onOpenReferences: onOpenReferences,
        portfolioCount: facts.portfolio.length,
      ),
      const SizedBox(height: 18),
      _ExperiencePreview(facts: facts, onOpenTimeline: onOpenTimeline),
      const SizedBox(height: 18),
      _EducationPreview(facts: facts),
      const SizedBox(height: 18),
      _VisibilityAndToolsCard(
        facts: facts,
        onOpenSettings: onOpenSettings,
        onOpenPortfolio: onOpenPortfolio,
      ),
    ];

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: mainContent,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        mainContent[0],
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: Column(
                children: [
                  mainContent[1],
                  const SizedBox(height: 18),
                  mainContent[2],
                  const SizedBox(height: 18),
                  mainContent[3],
                  const SizedBox(height: 18),
                  mainContent[4],
                  const SizedBox(height: 18),
                  mainContent[5],
                  const SizedBox(height: 18),
                  mainContent[6],
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _SignalSummaryCard(facts: facts, ownMode: true),
                  const SizedBox(height: 18),
                  _VideoPitchCard(
                    title: 'Video Pitch',
                    subtitle: 'Tu presentación profesional en video',
                    videoUrl: profile.videoUrl,
                    onPrimary: onOpenVideoPitch,
                    primaryLabel: 'Actualizar pitch',
                    secondaryLabel: 'Abrir cámara',
                    onSecondary: onOpenPitchCamera,
                    compact: false,
                  ),
                  const SizedBox(height: 18),
                  mainContent[7],
                  const SizedBox(height: 18),
                  mainContent[8],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PublicProfileBody extends StatelessWidget {
  final NexUser profile;
  final _ProfileFacts facts;
  final bool isMobile;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onShare;
  final VoidCallback onContact;
  final VoidCallback onInvite;
  final String connectionStatus;
  final bool isLoadingConnection;
  final bool isSavedProfile;
  final bool isSavingProfile;
  final VoidCallback onToggleSaved;
  final VoidCallback onShowMore;
  final VoidCallback onOpenPortfolio;
  final VoidCallback onOpenTimeline;
  final VoidCallback onOpenReferences;

  const _PublicProfileBody({
    required this.profile,
    required this.facts,
    required this.isMobile,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onShare,
    required this.onContact,
    required this.onInvite,
    required this.connectionStatus,
    required this.isLoadingConnection,
    required this.isSavedProfile,
    required this.isSavingProfile,
    required this.onToggleSaved,
    required this.onShowMore,
    required this.onOpenPortfolio,
    required this.onOpenTimeline,
    required this.onOpenReferences,
  });

  @override
  Widget build(BuildContext context) {
    final isCompany = profile.isCompanyAct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(
          title: isCompany ? 'Empresa' : 'Perfil público',
          subtitle: isCompany
              ? 'Conocé la empresa antes de postularte'
              : 'Vista premium para empresas y headhunters',
          shareLabel: 'Compartir',
          onShare: onShare,
          onMore: onShowMore,
        ),
        const SizedBox(height: 18),
        if (isCompany) ...[
          _CompanyPublicVideoHero(profile: profile),
          const SizedBox(height: 18),
        ],
        _PublicHero(
          profile: profile,
          facts: facts,
          isMobile: isMobile,
          onContact: onContact,
          onInvite: onInvite,
          onToggleSaved: onToggleSaved,
          onShowMore: onShowMore,
          connectionStatus: connectionStatus,
          isLoadingConnection: isLoadingConnection,
          isSavedProfile: isSavedProfile,
          isSavingProfile: isSavingProfile,
        ),
        const SizedBox(height: 18),
        isCompany
            ? _CompanyPublicMetrics(profile: profile)
            : _PublicMetricsStrip(profile: profile, facts: facts),
        const SizedBox(height: 18),
        if (isCompany) ...[
          _CompanyPublicDetails(profile: profile, facts: facts),
          const SizedBox(height: 18),
          _CompanyPublicVacancies(companyId: profile.id),
        ] else if (isMobile)
          Column(
            children: [
              _InfoSectionCard(
                title: 'Sobre mí',
                icon: CupertinoIcons.sparkles,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facts.aboutText,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.55,
                        color: context.textSecondary,
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
                              color: NexTheme.brandAccent,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _VideoPitchCard(
                title: 'Video presentación',
                subtitle: 'El pitch profesional del candidato',
                videoUrl: profile.videoUrl,
                onPrimary: onContact,
                primaryLabel: 'Ver video completo',
                compact: true,
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _InfoSectionCard(
                  title: 'Sobre mí',
                  icon: CupertinoIcons.sparkles,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        facts.aboutText,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.55,
                          color: context.textSecondary,
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
                                color: NexTheme.brandAccent,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _VideoPitchCard(
                  title: 'Video presentación',
                  subtitle: 'Video-first y listo para entrevistas',
                  videoUrl: profile.videoUrl,
                  onPrimary: onContact,
                  primaryLabel: 'Ver video completo',
                ),
              ),
            ],
          ),
        if (!isCompany) ...[
          const SizedBox(height: 18),
          _TabStrip(
            items: const [
              'Experiencia',
              'Skills',
              'Educación',
              'Certificaciones',
              'Logros',
              'Idiomas',
            ],
            selectedIndex: selectedTab,
            onChanged: onTabChanged,
          ),
          const SizedBox(height: 18),
          _PublicTabContent(
            selectedTab: selectedTab,
            profile: profile,
            facts: facts,
            isMobile: isMobile,
            onOpenTimeline: onOpenTimeline,
          ),
          const SizedBox(height: 18),
          _ProjectShowcase(
            portfolio: facts.portfolio,
            onOpenPortfolio: onOpenPortfolio,
            isMobile: isMobile,
          ),
          const SizedBox(height: 18),
          _QuickDestinationStrip(
            onOpenPortfolio: onOpenPortfolio,
            onOpenTimeline: onOpenTimeline,
            onOpenReferences: onOpenReferences,
            portfolioCount: facts.portfolio.length,
          ),
        ],
      ],
    );
  }
}

/// Información de empresa basada exclusivamente en el perfil y en las
/// vacantes reales. Evita reutilizar secciones de candidato (experiencia,
/// educación o portfolio) que no explicaban una marca empleadora.
class _CompanyPublicDetails extends StatelessWidget {
  const _CompanyPublicDetails({required this.profile, required this.facts});

  final NexUser profile;
  final _ProfileFacts facts;

  @override
  Widget build(BuildContext context) {
    final tags = <String>{
      ...profile.tags.map((tag) => tag.trim()),
      ...profile.skills.map((skill) => skill.trim()),
    }.where((tag) => tag.isNotEmpty).take(8).toList();
    final about = facts.aboutText.trim();

    return Column(
      children: [
        _InfoSectionCard(
          title: 'Sobre ${profile.name}',
          icon: CupertinoIcons.building_2_fill,
          child: Text(
            about.isEmpty
                ? 'Esta empresa todavía no agregó una descripción.'
                : about,
            style: TextStyle(
              fontSize: 15,
              height: 1.55,
              color: context.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _InfoSectionCard(
          title: 'Especialidades',
          icon: CupertinoIcons.sparkles,
          child: tags.isEmpty
              ? Text(
                  'Todavía no hay especialidades publicadas.',
                  style: TextStyle(fontSize: 15, color: context.textSecondary),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in tags)
                      MployaPill(label: tag, color: NexTheme.brandAccent),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Hero de video para el perfil público de una empresa. Usa la portada real
/// cuando existe y, si no, conserva el degradado de Mploya: nunca completa el
/// hueco con imágenes o beneficios ficticios.
class _CompanyPublicVideoHero extends StatelessWidget {
  const _CompanyPublicVideoHero({required this.profile});

  final NexUser profile;

  @override
  Widget build(BuildContext context) {
    final videoUrl = resolveVideoUrl(profile.videoUrl);
    final imageUrl = (profile.bannerUrl?.trim().isNotEmpty ?? false)
        ? profile.bannerUrl!
        : null;
    return GestureDetector(
      onTap: videoUrl.isEmpty
          ? null
          : () => showCupertinoModalPopup<void>(
              context: context,
              builder: (_) => VideoPlayerModal(videoUrl: videoUrl, index: 0),
            ),
      child: Container(
        height: 224,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A2234), Color(0xFF0E1422), Color(0xFF2A3154)],
          ),
          image: imageUrl == null
              ? null
              : DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF06101D).withValues(alpha: 0.84),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.30),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  videoUrl.isEmpty
                      ? CupertinoIcons.building_2_fill
                      : CupertinoIcons.play_fill,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      videoUrl.isEmpty
                          ? 'Esta empresa todavía no cargó su video institucional'
                          : 'Conocé la empresa en su video institucional',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (videoUrl.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Ver video',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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
    );
  }
}

class _CompanyPublicMetrics extends StatelessWidget {
  const _CompanyPublicMetrics({required this.profile});

  final NexUser profile;

  @override
  Widget build(BuildContext context) {
    final location = (profile.location ?? '').trim();
    return MployaShellCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _MiniMetric(
            icon: CupertinoIcons.building_2_fill,
            title: 'Empresa',
            subtitle: profile.isVerified
                ? 'Perfil verificado'
                : 'Perfil de empresa',
          ),
          if (location.isNotEmpty)
            _MiniMetric(
              icon: CupertinoIcons.location_solid,
              title: location,
              subtitle: 'Ubicación',
            ),
          if (profile.isHiring)
            _MiniMetric(
              icon: CupertinoIcons.briefcase_fill,
              title: 'Buscando talento',
              subtitle: 'Vacantes activas',
            ),
        ],
      ),
    );
  }
}

class _CompanyPublicVacancies extends StatelessWidget {
  const _CompanyPublicVacancies({required this.companyId});

  final String companyId;

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      final rows = await Supabase.instance.client
          .from('jobs')
          .select()
          .eq('company_id', companyId)
          .order('created_at', ascending: false)
          .limit(4);
      return List<Map<String, dynamic>>.from(
        rows.where((row) => row['is_active'] != false),
      );
    } catch (e, stackTrace) {
      // Antes esto devolvia [] en silencio: una empresa con vacantes reales
      // podia verse como "no publico nada" sin dejar rastro del error real
      // (RLS, columna, lo que sea). Ahora se loguea a Crashlytics y se
      // relanza para que la UI distinga "vacio de verdad" de "no se pudo
      // cargar".
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'CompanyPublicVacancies._load company=$companyId',
      );
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MployaShellCard(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _InfoSectionCard(
            title: 'Vacantes activas',
            icon: CupertinoIcons.briefcase_fill,
            child: Text(
              'No pudimos cargar las vacantes de esta empresa. Probá de nuevo en un rato.',
              style: TextStyle(fontSize: 15, color: context.textSecondary),
            ),
          );
        }
        final jobs = snapshot.data ?? const <Map<String, dynamic>>[];
        return _InfoSectionCard(
          title: 'Vacantes activas',
          icon: CupertinoIcons.briefcase_fill,
          child: jobs.isEmpty
              ? Text(
                  'Esta empresa todavía no publicó vacantes activas.',
                  style: TextStyle(fontSize: 15, color: context.textSecondary),
                )
              : Column(
                  children: [
                    for (final job in jobs) ...[
                      _CompanyVacancyRow(job: job),
                      if (job != jobs.last)
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          color: context.shellBorder,
                        ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _CompanyVacancyRow extends StatelessWidget {
  const _CompanyVacancyRow({required this.job});

  final Map<String, dynamic> job;

  @override
  Widget build(BuildContext context) {
    final title = job['title']?.toString().trim();
    final place = job['location']?.toString().trim();
    final salary = job['salary_range']?.toString().trim();
    final details = [
      place,
      salary,
    ].whereType<String>().where((v) => v.isNotEmpty).join(' · ');
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => JobDetailScreen(
            job: job,
            onApply: () => JobApplicationFlow.apply(
              context: context,
              jobId: job['id']?.toString() ?? '',
              jobTitle: job['title']?.toString() ?? 'Vacante',
            ),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.primaryAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.briefcase_fill,
              color: context.primaryAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title == null || title.isEmpty ? 'Vacante' : title,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    details,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidatePortfolioScreen extends StatefulWidget {
  final NexUser profile;
  final bool isOwnProfile;

  const _CandidatePortfolioScreen({
    required this.profile,
    required this.isOwnProfile,
  });

  @override
  State<_CandidatePortfolioScreen> createState() =>
      _CandidatePortfolioScreenState();
}

class _CandidatePortfolioScreenState extends State<_CandidatePortfolioScreen> {
  late Future<List<PortfolioVideo>> _future;
  String _activeChip = 'Todos';
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PortfolioVideo>> _load() {
    return widget.isOwnProfile
        ? PortfolioService.instance.getMyPortfolio(forceRefresh: true)
        : PortfolioService.instance.getPortfolioFor(widget.profile.id);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _addPortfolioVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var confirmed = false;

    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Nuevo proyecto visual'),
        content: Column(
          children: [
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: titleController,
              placeholder: 'Título del proyecto',
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: descriptionController,
              placeholder: 'Resultado, contexto o impacto',
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              confirmed = true;
              Navigator.pop(ctx);
            },
            child: const Text('Subir'),
          ),
        ],
      ),
    );

    if (!confirmed) return;

    setState(() => _uploading = true);
    final uploaded = await PortfolioService.instance.uploadVideo(
      file: picked,
      title: titleController.text.trim().isEmpty
          ? 'Proyecto profesional'
          : titleController.text.trim(),
      description: descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      durationSeconds: 30,
    );
    if (mounted) setState(() => _uploading = false);

    if (!mounted) return;
    if (uploaded == null) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('No se pudo subir'),
          content: const Text(
            'Verificá el archivo, la conexión y el límite de tu portfolio.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    await _refresh();
  }

  Future<void> _editVideo(PortfolioVideo video) async {
    final titleController = TextEditingController(text: video.title);
    final descriptionController = TextEditingController(
      text: video.description ?? '',
    );
    var confirmed = false;

    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Editar proyecto'),
        content: Column(
          children: [
            const SizedBox(height: 10),
            CupertinoTextField(controller: titleController),
            const SizedBox(height: 10),
            CupertinoTextField(controller: descriptionController, maxLines: 3),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              confirmed = true;
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (!confirmed) return;
    await PortfolioService.instance.updateVideo(
      videoId: video.id,
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
    );
    await _refresh();
  }

  Future<void> _deleteVideo(PortfolioVideo video) async {
    var confirmed = false;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Eliminar proyecto'),
        content: Text('¿Eliminar "${video.title}" del portfolio?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              confirmed = true;
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (!confirmed) return;
    await PortfolioService.instance.deleteVideo(video.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final skillChips = ['Todos', ...widget.profile.skills.take(4)];
    return CupertinoPageScaffold(
      backgroundColor: NexTheme.shellDark,
      child: SafeArea(
        bottom: false,
        child: FutureBuilder<List<PortfolioVideo>>(
          future: _future,
          builder: (context, snapshot) {
            final videos = snapshot.data ?? const <PortfolioVideo>[];
            final filtered = _activeChip == 'Todos'
                ? videos
                : videos.where((video) {
                    final haystack = '${video.title} ${video.description ?? ''}'
                        .toLowerCase();
                    return haystack.contains(_activeChip.toLowerCase());
                  }).toList();
            final totalViews = videos.fold<int>(
              0,
              (sum, item) => sum + item.viewCount,
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF09111E),
                          NexTheme.shellDark,
                          Color(0xFF10182A),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                    children: [
                      _ScreenHeader(
                        title: 'Portfolio',
                        subtitle: 'Proyectos y trabajos destacados',
                        onShare: () => ShareService.instance.shareProfile(
                          name: widget.profile.name,
                          headline: widget.profile.headline,
                          userId: widget.profile.id,
                          accountType: widget.profile.accountType,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _DarkSummaryHero(profile: widget.profile),
                          ),
                          if (MediaQuery.of(context).size.width >= 820) ...[
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 230,
                              child: _SignalSummaryCard(
                                facts: _ProfileFacts.fromUser(
                                  widget.profile,
                                  _ProfileBundle(
                                    portfolio: videos,
                                    viewCount: widget.profile.profileViews,
                                  ),
                                ),
                                ownMode: false,
                                darkMode: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),
                      _TabStrip(
                        items: const [
                          'Resumen',
                          'Experiencia',
                          'Skills',
                          'Portfolio',
                          'Referencias',
                          'Logros',
                        ],
                        selectedIndex: 3,
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 18),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: skillChips.map((chip) {
                            final active = chip == _activeChip;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: GestureDetector(
                                onTap: () => setState(() => _activeChip = chip),
                                child: MployaPill(
                                  label: chip,
                                  active: active,
                                  color: active
                                      ? NexTheme.brandAccent
                                      : NexTheme.brandAccentDark,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: CupertinoActivityIndicator(radius: 16),
                          ),
                        )
                      else if (filtered.isEmpty)
                        MployaShellCard(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.isOwnProfile
                                      ? 'Todavía no cargaste proyectos visuales'
                                      : 'Este portfolio todavía no tiene proyectos visibles',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.isOwnProfile
                                      ? 'Subí piezas reales para mostrar impacto, proceso y resultados sin convertir tu perfil en un CV plano.'
                                      : 'Cuando este perfil publique piezas visuales, aparecerán acá con video, contexto y resultados.',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    height: 1.5,
                                    color: context.textSecondary,
                                  ),
                                ),
                                if (widget.isOwnProfile) ...[
                                  const SizedBox(height: 18),
                                  MployaPrimaryButton(
                                    label: 'Agregar proyecto visual',
                                    icon: CupertinoIcons.plus,
                                    onPressed: _uploading
                                        ? null
                                        : _addPortfolioVideo,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 1120
                                ? 3
                                : (constraints.maxWidth >= 760 ? 2 : 1);
                            final cardWidth =
                                (constraints.maxWidth - ((columns - 1) * 14)) /
                                columns;
                            return Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: filtered.map((video) {
                                return SizedBox(
                                  width: cardWidth,
                                  child: _PortfolioProjectCard(
                                    video: video,
                                    tags: widget.profile.skills
                                        .take(2)
                                        .toList(),
                                    canEdit: widget.isOwnProfile,
                                    onTap: () {
                                      showCupertinoModalPopup<void>(
                                        context: context,
                                        builder: (_) => VideoPlayerModal(
                                          videoUrl: resolveVideoUrl(
                                            video.videoUrl,
                                          ),
                                          index: math.max(
                                            0,
                                            filtered.indexOf(video),
                                          ),
                                        ),
                                      );
                                    },
                                    onEdit: widget.isOwnProfile
                                        ? () => _editVideo(video)
                                        : null,
                                    onDelete: widget.isOwnProfile
                                        ? () => _deleteVideo(video)
                                        : null,
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _LargeMetric(
                                label: 'Proyectos',
                                value: '${videos.length}',
                              ),
                            ),
                            Expanded(
                              child: _LargeMetric(
                                label: 'Visualizaciones',
                                value: _compact(totalViews),
                              ),
                            ),
                            Expanded(
                              child: _LargeMetric(
                                label: 'Skills visibles',
                                value: '${widget.profile.skills.length}',
                              ),
                            ),
                            Expanded(
                              child: _LargeMetric(
                                label: 'Entregas destacadas',
                                value: '${math.max(90, 92 + videos.length)}%',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      MployaShellCard(
                        color: Colors.white,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '¿Quieres ver el portfolio completo?',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.isOwnProfile
                                        ? 'Completá tus piezas con contexto, resultados y video para mejorar la evaluación profesional.'
                                        : 'Desbloqueá más contexto, casos de estudio y evidencia profesional cuando el backend lo habilite.',
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
                              label: widget.isOwnProfile
                                  ? 'Agregar proyecto'
                                  : 'Solicitar más contexto',
                              icon: widget.isOwnProfile
                                  ? CupertinoIcons.plus
                                  : CupertinoIcons.lock,
                              onPressed: widget.isOwnProfile
                                  ? _addPortfolioVideo
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_uploading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.25),
                    child: const Center(
                      child: CupertinoActivityIndicator(radius: 18),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
