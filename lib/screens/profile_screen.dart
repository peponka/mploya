import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/nex_avatar.dart';
import '../widgets/spring_interaction.dart';
import '../widgets/profile_section_widgets.dart';
import '../widgets/profile_video_widgets.dart';
import 'messaging_screen.dart';
import 'splash_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../services/profile_view_service.dart';
import '../services/claude_ai_service.dart';
import '../services/video_preload_manager.dart';
import '../services/company_verification_service.dart';
import 'profile_viewers_screen.dart';
import 'admin_dashboard_screen.dart';
import 'candidate_profile_form_screen.dart';
import 'company_profile_form_screen.dart';
import 'stealth_profile_form_screen.dart';
import 'boost_profile_screen.dart';
import 'pitch_challenge_screen.dart';
import '../widgets/portfolio_section.dart';
import '../widgets/employer_rating_section.dart';
import '../widgets/skill_badges_section.dart';
import 'skill_assessment_screen.dart';
import 'interview_prep_screen.dart';
import 'profile_analytics_dashboard_screen.dart';
import 'referral_screen.dart';
import 'resume_builder_screen.dart';
import 'scheduling_screen.dart';
import 'company_review_screen.dart';
import 'saved_profiles_screen.dart';
import '../widgets/coach_mark.dart';
import '../services/video_personality_service.dart';
import 'personality_result_screen.dart';
import '../widgets/profile_bio_generator.dart';
import '../widgets/profile_personality_section.dart';
import 'trending_hashtags_screen.dart';
import '../services/hashtag_service.dart';
import '../services/share_service.dart';
import 'camera_screen.dart';
import 'onboarding_pitch_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final NexUser? user;

  const ProfileScreen({super.key, this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>?>? _ownFuture;
  String _connectionStatus = 'none';
  bool _isLoadingConnection = false;
  int _selectedProfileTab = 0; // 0=Sobre mí, 1=Portfolio, 2=Herramientas
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _fetchConnectionStatus(widget.user!.id);
      // Registrar vista de perfil
      ProfileViewService.instance.recordView(widget.user!.id);
    } else {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        _ownFuture = Supabase.instance.client
            .from('users')
            .select()
            .eq('id', uid)
            .maybeSingle();
        _checkAdmin(uid);
      }
    }
  }

  Future<void> _checkAdmin(String uid) async {
    try {
      final row = await Supabase.instance.client
          .from('users').select('is_admin').eq('id', uid).maybeSingle();
      if (mounted && row?['is_admin'] == true) setState(() => _isAdmin = true);
    } catch (_) {}
  }

  Future<void> _fetchConnectionStatus(String otherId) async {
    setState(() => _isLoadingConnection = true);
    try {
      final res = await Supabase.instance.client
          .rpc('get_connection_status', params: {'p_other_user_id': otherId});
      if (res != null && res['status'] != null) {
        setState(() => _connectionStatus = res['status'] as String);
      }
    } catch (e) {
      debugPrint('Error fetch connection: $e');
    } finally {
      if (mounted) setState(() => _isLoadingConnection = false);
    }
  }

  Future<void> _handleConnect(String otherId) async {
    setState(() => _isLoadingConnection = true);
    try {
      final res = await Supabase.instance.client
          .rpc('send_connection_request', params: {'p_addressee_id': otherId});
      if (res != null && res['status'] != null) {
        setState(() => _connectionStatus = res['status'] as String);
      }
    } catch (e) {
      debugPrint('Error send connection: $e');
    } finally {
      if (mounted) setState(() => _isLoadingConnection = false);
    }
  }

  Future<void> _pickAndUploadAvatar(NexUser profile) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 85,
    );
    if (picked == null) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    if (mounted) {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 18)),
      );
    }

    final url = await StorageService.instance.uploadAvatar(uid, picked);

    if (mounted) Navigator.of(context).pop();

    if (url != null) {
      await Supabase.instance.client.from('users').update({
        'avatar_url': url,
      }).eq('id', uid);

      if (mounted) {
        setState(() {
          _ownFuture = Supabase.instance.client
              .from('users')
              .select()
              .eq('id', uid)
              .maybeSingle();
        });
      }
    } else {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(StorageService.instance.lastError ?? 'No se pudo subir la foto'),
            actions: [
              CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Perfil de otro usuario: render directo sin stream
    if (widget.user != null) {
      return _buildScaffold(context, widget.user!, false);
    }
    // Sin sesión activa: redirigir al splash para login
    if (_ownFuture == null) {
      return CupertinoPageScaffold(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.person_crop_circle, size: 64, color: context.textTertiary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text('Inicia sesión para ver tu perfil', style: TextStyle(fontSize: 16, color: context.textSecondary)),
              const SizedBox(height: 24),
              CupertinoButton(
                color: MployaTheme.brandAccent,
                child: const Text('Iniciar Sesión'),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    CupertinoPageRoute(builder: (_) => const SplashScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      );
    }
    // Perfil propio: fetch normal desde Supabase
    return FutureBuilder<Map<String, dynamic>?>(
      future: _ownFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return CupertinoPageScaffold(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CupertinoActivityIndicator(radius: 16),
                  const SizedBox(height: 24),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Cerrar Sesión (Si no carga)', style: TextStyle(fontSize: 13, color: CupertinoColors.destructiveRed)),
                    onPressed: () async {
                      VideoPreloadManager.instance.disposeAll();
                      await Supabase.instance.client.auth.signOut();
                      if (!ctx.mounted) return;
                      Navigator.of(ctx, rootNavigator: true).pushAndRemoveUntil(
                          CupertinoPageRoute(builder: (_) => const SplashScreen()), (route) => false);
                    },
                  )
                ],
              ),
            ),
          );
        }

        if (snap.hasError) {
          return CupertinoPageScaffold(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error de Red/DB:\n${snap.error}\nSi eres nuevo, verifica que completaste el Formulario de Perfil.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CupertinoColors.destructiveRed),
                ),
              ),
            ),
          );
        }

        if (!snap.hasData || snap.data == null) {
          return const CupertinoPageScaffold(
            child: Center(child: Text('Perfil vacío')),
          );
        }

        return _buildScaffold(context, NexUser.fromJson(snap.data!), true);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, NexUser profile, bool isOwnProfile) {
    return CupertinoPageScaffold(
      backgroundColor: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // ── Nav Bar (minimal) ──
          SliverToBoxAdapter(
            child: Container(
              color: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, bottom: 4),
              child: Row(
                children: [
                  if (!isOwnProfile)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: Size.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Icon(CupertinoIcons.back, size: 22, color: context.textPrimary),
                    )
                  else
                    const SizedBox(width: 16),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => ShareService.instance.shareProfile(
                      name: profile.name,
                      headline: profile.headline,
                      userId: profile.id,
                      accountType: profile.accountType,
                    ),
                    child: Icon(CupertinoIcons.square_arrow_up, size: 20, color: context.textPrimary),
                  ),
                  const SizedBox(width: 16),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => _showSettingsSheet(context, profile),
                    child: Icon(CupertinoIcons.ellipsis, size: 22, color: context.textPrimary),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),

          // ── Avatar + Edit Button ──
          _buildProfileHeader(context, profile, isOwnProfile),

          // ── Name + Headline + Badges ──
          _buildNameSection(context, profile, isOwnProfile),

          // ── Tab Selector (only for own profile) ──
          if (isOwnProfile)
            SliverToBoxAdapter(
              child: Container(
                color: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _SegTab(label: 'Sobre mí', isSelected: _selectedProfileTab == 0, onTap: () => setState(() => _selectedProfileTab = 0)),
                      _SegTab(label: 'Portfolio', isSelected: _selectedProfileTab == 1, onTap: () => setState(() => _selectedProfileTab = 1)),
                      _SegTab(label: 'Herramientas', isSelected: _selectedProfileTab == 2, onTap: () => setState(() => _selectedProfileTab = 2)),
                    ],
                  ),
                ),
              ),
            ),

          // ════════════════════════════════════════════════════════════════════
          // TAB 0: SOBRE MÍ — Video-Pitch, Experiencia, Personalidad, Skills
          // ════════════════════════════════════════════════════════════════════
          if (!isOwnProfile || _selectedProfileTab == 0) ...[
            // ── Video-Pitch Section ──
            SliverToBoxAdapter(
              child: _buildVideoPitchSection(context, profile),
            ),

            // ── PERSONALIDAD IA — Análisis de soft skills ──
            SliverToBoxAdapter(
              child: ProfilePersonalitySection(
                userId: profile.id,
                isOwnProfile: isOwnProfile,
                headline: profile.headline,
                skills: profile.skills,
              ),
            ),

            // ── EXPERIENCIA — Clean timeline ──
            if (profile.experience.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildExperienceClean(context, profile, isOwnProfile),
              ),

            // ── SKILLS — Clean pills ──
            SliverToBoxAdapter(
              child: _buildSkillsClean(context, profile, isOwnProfile),
            ),
          ],

          // ════════════════════════════════════════════════════════════════════
          // TAB 1: PORTFOLIO — Videos, Replies, Ratings, Badges
          // ════════════════════════════════════════════════════════════════════
          if (!isOwnProfile || _selectedProfileTab == 1) ...[
            // ── PORTFOLIO — Hasta 3 vídeos de proyectos ──
            SliverToBoxAdapter(
              child: PortfolioSection(
                userId: profile.id,
                isOwnProfile: isOwnProfile,
              ),
            ),

            // ── Video Replies de Empresas ──
            SliverToBoxAdapter(
              child: _buildVideoReplies(context, profile, isOwnProfile),
            ),

            // ── EMPLOYER RATING — Reputación de empresa ──
            SliverToBoxAdapter(
              child: EmployerRatingSection(
                companyId: profile.id,
                companyAccountType: profile.accountType,
                isOwnProfile: isOwnProfile,
              ),
            ),

            // ── SKILL BADGES — Validated skill certificates ──
            SliverToBoxAdapter(
              child: SkillBadgesSection(
                userId: profile.id,
                isOwnProfile: isOwnProfile,
              ),
            ),
          ],

          // ════════════════════════════════════════════════════════════════════
          // TAB 2: HERRAMIENTAS — IA, Crecimiento, Cuenta (own profile only)
          // ════════════════════════════════════════════════════════════════════
          if (isOwnProfile && _selectedProfileTab == 2) ...[
            // ── PROGRESO — Clean completion bar ──
            SliverToBoxAdapter(
              child: ProfileCompletionBar(profile: profile),
            ),

            // ── AI SPOTLIGHT CARDS — Feature discovery ──
            SliverToBoxAdapter(
              child: _buildAISpotlightCards(context, profile),
            ),

            // ── QUICK ACTIONS — Crecimiento horizontal ──
            SliverToBoxAdapter(
              child: _buildQuickActions(context, profile),
            ),

            // ── CUENTA — Settings compacto ──
            SliverToBoxAdapter(
              child: _buildAccountSection(context, profile),
            ),
          ],

          // ── Bottom nav spacer ──
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── Settings Sheet ──────────────────────────────────────────────────────

  // ── Generar Bio con Claude AI ─────────────────────────────────────────────

  // Bio generation is now handled by showGenerarBioSheet() from profile_bio_generator.dart


  void _showSettingsSheet(BuildContext context, NexUser profile) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text(
          'Cuenta',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        message: const Text(
          'Gestioná tu cuenta y sesión',
          style: TextStyle(fontSize: 12.5),
        ),
        actions: [
          // ── Verificación de Empresa ──
          if (profile.accountType == 'empresa' || profile.accountType == 'headhunter')
            CupertinoActionSheetAction(
              child: const Text(
                'Verificar empresa',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final verified = await CompanyVerificationService.instance.autoVerifyEmail();
                if (context.mounted) {
                  showCupertinoDialog(
                    context: context,
                    builder: (d) => CupertinoAlertDialog(
                      title: Text(verified ? '¡Verificada!' : 'Verificación'),
                      content: Text(verified
                          ? 'Tu email corporativo fue verificado. Los candidatos verán un badge de confianza en tu perfil.'
                          : 'Para verificar tu empresa necesitás un email corporativo (no Gmail/Hotmail). Contactá soporte para verificación manual.'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('Entendido'),
                          onPressed: () => Navigator.pop(d),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          // ── Cerrar Sesión ──
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              VideoPreloadManager.instance.disposeAll();
              await Supabase.instance.client.auth.signOut();
              if (!context.mounted) return;
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                CupertinoPageRoute(builder: (_) => const SplashScreen()),
                (route) => false,
              );
            },
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          )
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'Cancelar',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  // ── Clean Profile Header (Avatar + Edit) ─────────────────────────────────

  SliverToBoxAdapter _buildProfileHeader(BuildContext context, NexUser profile, bool isOwnProfile) {
    return SliverToBoxAdapter(
      child: Container(
        color: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          children: [
            // ── Avatar (centered) ──
            GestureDetector(
              onTap: () {
                if (isOwnProfile) {
                  _pickAndUploadAvatar(profile);
                } else {
                  showCupertinoModalPopup<void>(
                    context: context,
                    builder: (_) => VideoPlayerModal(
                      videoUrl: profile.videoUrl ?? 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
                      index: 0,
                    ),
                  );
                }
              },
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
                      border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.2), width: 2),
                    ),
                    child: NexAvatar(user: profile, size: 96, showBadge: true),
                  ),
                  if (isOwnProfile)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: MployaTheme.brandAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: CupertinoColors.white, width: 2.5),
                        ),
                        child: const Icon(CupertinoIcons.camera_fill, color: CupertinoColors.white, size: 13),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  // ── Name + Headline + Badges + Action Buttons ─────────────────────────────

  SliverToBoxAdapter _buildNameSection(BuildContext context, NexUser profile, bool isOwnProfile) {
    return SliverToBoxAdapter(
      child: Container(
        color: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Name ──
            Text(
              profile.name,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.textPrimary, letterSpacing: -0.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // ── Headline ──
            Text(
              profile.headline,
              style: TextStyle(fontSize: 15, color: context.textSecondary, height: 1.35),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            // ── Inline Badges (compact row) ──
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                if (profile.isVerified || profile.isPremium)
                  _profileBadge(
                    icon: CupertinoIcons.checkmark_shield_fill,
                    label: 'Verificado',
                    color: MployaTheme.brandAccent,
                  ),
                if (profile.location != null)
                  _profileBadge(
                    icon: CupertinoIcons.location_solid,
                    label: profile.location!,
                    color: context.textSecondary,
                  ),
                _profileBadge(
                  icon: CupertinoIcons.circle_fill,
                  label: profile.isOpenToWork ? 'Disponible' : (profile.isHiring ? 'Contratando' : 'Activo'),
                  color: profile.isOpenToWork ? MployaTheme.openToWork : (profile.isHiring ? MployaTheme.hiring : MployaTheme.brandAccent),
                  filled: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Action Row (Edit + Generate Bio) ──
            if (isOwnProfile)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _actionPill(
                    icon: CupertinoIcons.pencil,
                    label: 'Editar perfil',
                    onTap: () {
                      if (profile.accountType == 'empresa' || profile.accountType == 'headhunter') {
                        Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const CompanyProfileFormScreen()));
                      } else if (profile.accountType == 'confidencial' || profile.accountType == 'stealth') {
                        Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const StealthProfileFormScreen()));
                      } else {
                        Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const CandidateProfileFormScreen(isEditing: true)));
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  _actionPill(
                    icon: CupertinoIcons.sparkles,
                    label: 'Bio con IA',
                    onTap: () => showGenerarBioSheet(context, profile),
                    accent: true,
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(width: 10),
                    _actionPill(
                      icon: CupertinoIcons.shield_fill,
                      label: 'Admin',
                      onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const AdminDashboardScreen())),
                      color: const Color(0xFF6366F1),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 20),
            // ── Stats Row (3 columns, compact) ──
            GestureDetector(
              onTap: isOwnProfile ? () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ProfileViewersScreen())) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(child: _statColumn(profile.connections == 0 ? '—' : '${profile.connections}', 'Conexiones', context)),
                    Container(width: 0.5, height: 32, color: context.dividerColor),
                    Expanded(child: _statColumn(profile.profileViews == 0 ? '—' : '${profile.profileViews}', 'Vistas', context)),
                    Container(width: 0.5, height: 32, color: context.dividerColor),
                    Expanded(child: _statColumn(profile.matchPercentage == 0 ? '—' : '${profile.matchPercentage.round()}', 'Matches', context)),
                  ],
                ),
              ),
            ),

            // ── Action buttons (only for other profiles) ──
            if (!isOwnProfile) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SpringInteraction(
                      onTap: () {
                        if (_connectionStatus == 'none' && !_isLoadingConnection) {
                          _handleConnect(profile.id);
                        }
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _connectionStatus == 'none'
                              ? MployaTheme.brandAccent
                              : MployaTheme.brandAccent.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
                        ),
                        child: _isLoadingConnection
                            ? const CupertinoActivityIndicator(radius: 10, color: CupertinoColors.white)
                            : Text(
                                _connectionStatus == 'pending'
                                    ? 'Pendiente'
                                    : (_connectionStatus == 'accepted'
                                        ? 'Contactos'
                                        : 'Mostrar Interés'),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CupertinoColors.white),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SpringInteraction(
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(builder: (_) => ChatDetailScreen(otherUser: profile)),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: context.brandAccent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
                        ),
                        child: Text('Mensaje', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.brandAccent)),
                      ),
                    ),
                  ),
                ],
              ),
              if (profile.accountType == 'empresa' || profile.accountType == 'headhunter') ...[
                const SizedBox(height: 8),
                SpringInteraction(
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(
                    builder: (_) => CompanyReviewScreen(companyId: profile.id, companyName: profile.name),
                  )),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(CupertinoIcons.star_fill, size: 14, color: Color(0xFFFFB800)),
                      SizedBox(width: 6),
                      Text('Ver Reviews', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFFFB800))),
                    ]),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Badge Helper ──
  Widget _profileBadge({required IconData icon, required String label, required Color color, bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: 0.1)
            : (context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: icon == CupertinoIcons.circle_fill ? 6 : 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: filled ? color : context.textSecondary)),
        ],
      ),
    );
  }

  // ── Action Pill Helper ──
  Widget _actionPill({required IconData icon, required String label, required VoidCallback onTap, bool accent = false, Color? color}) {
    final c = color ?? (accent ? MployaTheme.brandAccent : null);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: c != null
              ? c.withValues(alpha: 0.08)
              : (context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7)),
          borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c ?? context.textPrimary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c ?? context.textPrimary)),
          ],
        ),
      ),
    );
  }

  // ── Stat Column Helper ──────────────────────────────────────────────────────

  Widget _statColumn(String value, String label, BuildContext context) {
    final isEmpty = value == '—';
    return Column(
      children: [
        Text(value, style: TextStyle(
          fontSize: isEmpty ? 22 : 20,
          fontWeight: FontWeight.w800,
          color: isEmpty ? context.textTertiary : context.textPrimary,
          letterSpacing: -0.5,
        )),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ── Video Replies de Empresas ──────────────────────────────────────────────

  Widget _buildVideoReplies(BuildContext context, NexUser profile, bool isOwnProfile) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('nexus_signals')
          .select('id, sender_id, video_url, signal_type, created_at')
          .eq('receiver_id', profile.id)
          .eq('signal_type', 'micro_pitch')
          .order('created_at', ascending: false)
          .limit(10),
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null || snap.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final pitches = snap.data!;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(MployaTheme.radiusMD),
            boxShadow: context.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF5F3DC4), Color(0xFFAE3EC9)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(CupertinoIcons.videocam_fill, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isOwnProfile ? 'Video Replies Recibidos' : 'Video Replies de Empresas',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.textPrimary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF5F3DC4), Color(0xFFAE3EC9)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${pitches.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: pitches.length,
                  itemBuilder: (context, i) {
                    final pitch = pitches[i];
                    final videoUrl = pitch['video_url'] as String? ?? '';
                    final senderId = pitch['sender_id'] as String? ?? '';
                    final createdAt = pitch['created_at'] as String? ?? '';
                    final dateStr = createdAt.length >= 10 ? createdAt.substring(0, 10) : '';

                    return GestureDetector(
                      onTap: () {
                        if (videoUrl.isNotEmpty) {
                          showCupertinoModalPopup<void>(
                            context: context,
                            builder: (_) => VideoPlayerModal(videoUrl: videoUrl, index: i),
                          );
                        }
                      },
                      child: Container(
                        width: 200,
                        margin: EdgeInsets.only(right: i < pitches.length - 1 ? 12 : 0),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1A0D2E), Color(0xFF2D1045)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.30), width: 0.5),
                          boxShadow: [BoxShadow(color: const Color(0xFF5F3DC4).withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Color(0xFF5F3DC4), Color(0xFFAE3EC9)]),
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: const Color(0xFF5F3DC4).withValues(alpha: 0.4), blurRadius: 8)],
                                    ),
                                    child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 20),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFAE3EC9).withValues(alpha: 0.20),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFAE3EC9).withValues(alpha: 0.3)),
                                    ),
                                    child: const Text('🎬 Reply', style: TextStyle(fontSize: 11, color: Color(0xFFD4A5FF), fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              FutureBuilder<Map<String, dynamic>?>(
                                future: Supabase.instance.client
                                    .from('users')
                                    .select('name, avatar_url')
                                    .eq('id', senderId)
                                    .maybeSingle(),
                                builder: (ctx, userSnap) {
                                  final senderName = userSnap.data?['name'] ?? 'Empresa';
                                  final avatarUrl = userSnap.data?['avatar_url'] as String?;
                                  return Row(
                                    children: [
                                      if (avatarUrl != null) ...[
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            avatarUrl,
                                            width: 24, height: 24, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 24, height: 24,
                                              decoration: const BoxDecoration(color: Color(0xFF5F3DC4), shape: BoxShape.circle),
                                              child: Center(child: Text(senderName[0], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        child: Text(senderName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 4),
                              Text(dateStr, style: TextStyle(color: Colors.white.withValues(alpha: 0.40), fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Video-Pitch Section ─────────────────────────────────────────────────

  Widget _buildVideoPitchSection(BuildContext context, NexUser profile) {
    return Container(
      color: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Video-Pitch',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.textPrimary, letterSpacing: -0.3),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const OnboardingPitchScreen(isCompany: false)),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: MployaTheme.brandAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.video_camera, size: 13, color: MployaTheme.brandAccent),
                      const SizedBox(width: 5),
                      Text('Grabar nuevo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MployaTheme.brandAccent)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Video thumbnail
          GestureDetector(
            onTap: () {
              showCupertinoModalPopup<void>(
                context: context,
                builder: (_) => VideoPlayerModal(
                  videoUrl: profile.videoUrl ?? 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
                  index: 0,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 24),
                    ),
                  ),
                  // Duration
                  Positioned(
                    top: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Video', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  // Score
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: MployaTheme.brandAccent.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('92 pts', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
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



  // ── Experience Clean (vertical timeline like reference) ─────────────────

  Widget _buildExperienceClean(BuildContext context, NexUser profile, bool isOwnProfile) {
    return Container(
      color: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Experiencia',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary),
              ),
              if (isOwnProfile)
                GestureDetector(
                  onTap: () {
                    if (profile.accountType == 'empresa' || profile.accountType == 'headhunter') {
                      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const CompanyProfileFormScreen()));
                    } else if (profile.accountType == 'confidencial' || profile.accountType == 'stealth') {
                      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const StealthProfileFormScreen()));
                    } else {
                      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const CandidateProfileFormScreen()));
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Editar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary)),
                      const SizedBox(width: 4),
                      Icon(CupertinoIcons.chevron_right, size: 12, color: context.textTertiary),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Timeline items
          ...profile.experience.asMap().entries.map((entry) {
            final i = entry.key;
            final exp = entry.value;
            final isFirst = i == 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dot indicator
                  Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isFirst
                              ? MployaTheme.brandAccent
                              : (context.isDark ? NexTheme.darkBg : CupertinoColors.white),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isFirst ? MployaTheme.brandAccent : context.dividerColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                      if (i < profile.experience.length - 1)
                        Container(
                          width: 1,
                          height: 50,
                          color: context.dividerColor,
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exp.role,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${exp.company} · ${exp.duration}${exp.isCurrent ? ' — ahora' : ''}',
                          style: TextStyle(fontSize: 13, color: context.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Interactive Hashtags Section ──────────────────────────────────────────

  Widget _buildSkillsClean(BuildContext context, NexUser profile, bool isOwnProfile) {
    final hashtags = profile.tags.isNotEmpty
        ? profile.tags
        : (profile.skills.isNotEmpty ? profile.skills : <String>[]);

    if (hashtags.isEmpty && !isOwnProfile) return const SizedBox.shrink();

    return Container(
      color: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hashtags',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Trending button
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const TrendingHashtagsScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: MployaTheme.brandAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.flame_fill, size: 11, color: MployaTheme.brandAccent),
                          SizedBox(width: 4),
                          Text('Trending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: MployaTheme.brandAccent)),
                        ],
                      ),
                    ),
                  ),
                  if (isOwnProfile) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        if (profile.accountType == 'empresa' || profile.accountType == 'headhunter') {
                          Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const CompanyProfileFormScreen()));
                        } else {
                          Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const CandidateProfileFormScreen()));
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Editar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary)),
                          const SizedBox(width: 4),
                          Icon(CupertinoIcons.chevron_right, size: 12, color: context.textTertiary),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...hashtags.map((tag) => _InteractiveHashtagPill(
                tag: tag,
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => TrendingHashtagsScreen(initialTag: tag),
                  ),
                ),
              )),
              if (isOwnProfile)
                GestureDetector(
                  onTap: () {
                    if (profile.accountType == 'empresa' || profile.accountType == 'headhunter') {
                      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const CompanyProfileFormScreen()));
                    } else {
                      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const CandidateProfileFormScreen()));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.isDark ? CupertinoColors.white : const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
                    ),
                    child: Text(
                      '+ agregar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.isDark ? CupertinoColors.black : CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── AI Spotlight Cards — Feature Discovery Premium ────────────────────────

  Widget _buildAISpotlightCards(BuildContext context, NexUser profile) {
    return Container(
      color: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF5F3DC4), Color(0xFFAE3EC9)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.sparkles, size: 14, color: CupertinoColors.white),
              ),
              const SizedBox(width: 10),
              Text(
                'Herramientas IA',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary, letterSpacing: -0.3),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF5F3DC4).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF5F3DC4))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Potenciá tu carrera con inteligencia artificial',
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
          const SizedBox(height: 16),
          // ── 3 Spotlight Cards ──
          _SpotlightCard(
            title: 'Validá tus skills',
            subtitle: 'Evaluá tus habilidades con IA y obtené un certificado verificable',
            icon: CupertinoIcons.checkmark_seal_fill,
            gradient: const [Color(0xFF059669), Color(0xFF10B981)],
            tag: 'NUEVO',
            onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SkillAssessmentScreen())),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SpotlightCardCompact(
                  title: 'Prep. Entrevistas',
                  icon: CupertinoIcons.lightbulb_fill,
                  gradient: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(
                    builder: (_) => InterviewPrepScreen(
                      jobTitle: profile.headline,
                      candidateSkills: profile.skills,
                    ),
                  )),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SpotlightCardCompact(
                  title: 'CV con IA',
                  icon: CupertinoIcons.doc_text_fill,
                  gradient: const [Color(0xFFD97706), Color(0xFFF59E0B)],
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ResumeBuilderScreen())),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Quick Actions — Horizontal chips for growth features ──────────────────

  Widget _buildQuickActions(BuildContext context, NexUser profile) {
    final isCompany = profile.accountType == 'empresa' || profile.accountType == 'headhunter';

    return Container(
      color: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
      padding: const EdgeInsets.fromLTRB(16, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Crecimiento',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary, letterSpacing: -0.3),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(right: 16),
              children: [
                // Boost: feature universal de crecimiento. Siempre visible; el
                // precio se ajusta según sea empresa (un poco más) o candidato.
                _QuickActionChip(
                  icon: CupertinoIcons.rocket_fill,
                  label: 'Impulsar',
                  color: MployaTheme.brandAccent,
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => BoostProfileScreen(isCompany: isCompany)),
                  ),
                ),
                _QuickActionChip(
                  icon: CupertinoIcons.flame_fill,
                  label: 'Challenge',
                  color: const Color(0xFFFF6B35),
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const PitchChallengeScreen())),
                ),
                _QuickActionChip(
                  icon: CupertinoIcons.eye_fill,
                  label: 'Vistas',
                  color: const Color(0xFF0EA5E9),
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ProfileViewersScreen())),
                ),
                _QuickActionChip(
                  icon: CupertinoIcons.chart_bar_fill,
                  label: 'Analytics',
                  color: const Color(0xFF8B5CF6),
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ProfileAnalyticsDashboardScreen())),
                ),
                _QuickActionChip(
                  icon: CupertinoIcons.person_2_fill,
                  label: 'Invitar',
                  color: const Color(0xFF059669),
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ReferralScreen())),
                ),
                _QuickActionChip(
                  icon: CupertinoIcons.bookmark_fill,
                  label: 'Guardados',
                  color: const Color(0xFFEAB308),
                  onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SavedProfilesScreen())),
                ),
                if (isCompany) ...[
                  _QuickActionChip(
                    icon: CupertinoIcons.briefcase_fill,
                    label: 'Hiring',
                    color: const Color(0xFF2563EB),
                    onTap: () {},
                  ),
                  _QuickActionChip(
                    icon: CupertinoIcons.calendar,
                    label: 'Agenda',
                    color: const Color(0xFFD97706),
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SchedulingScreen(isCompany: true))),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Account Section — Compact settings ────────────────────────────────────

  Widget _buildAccountSection(BuildContext context, NexUser profile) {
    return Container(
      color: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cuenta',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary, letterSpacing: -0.3),
          ),
          const SizedBox(height: 12),
          _masItem(
            context,
            'Configuración',
            icon: CupertinoIcons.gear,
            onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _masItem(BuildContext context, String label, {IconData? icon, Widget? trailing, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: context.textSecondary),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.textPrimary),
              ),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 8),
            ],
            Icon(CupertinoIcons.chevron_right, size: 14, color: context.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ── Interactive Hashtag Pill Widget ────────────────────────────────────────────

class _InteractiveHashtagPill extends StatefulWidget {
  final String tag;
  final VoidCallback onTap;

  const _InteractiveHashtagPill({required this.tag, required this.onTap});

  @override
  State<_InteractiveHashtagPill> createState() => _InteractiveHashtagPillState();
}

class _InteractiveHashtagPillState extends State<_InteractiveHashtagPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  int? _count;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _loadCount();
  }

  Future<void> _loadCount() async {
    final count = await HashtagService.instance.getHashtagCount(widget.tag);
    if (mounted) setState(() => _count = count);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: MployaTheme.brandAccent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
            border: Border.all(
              color: MployaTheme.brandAccent.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '#${widget.tag}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              if (_count != null && _count! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MployaTheme.brandAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_count',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: MployaTheme.brandAccent,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_right,
                size: 10,
                color: context.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// _BioResultCard and _PersonalitySection are now in:
// - lib/widgets/profile_bio_generator.dart (BioResultCard)
// - lib/widgets/profile_personality_section.dart (ProfilePersonalitySection)

// ─────────────────────────────────────────────────────────────────────────────
// Profile Tab Button — Custom tab with icon + label + optional badge
// ─────────────────────────────────────────────────────────────────────────────

// ── Segmented Tab (iOS segmented control style) ───────────────────────────────

class _SegTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegTab({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (context.isDark ? NexTheme.darkCard : CupertinoColors.white)
                : CupertinoColors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [BoxShadow(color: const Color(0x1A000000), blurRadius: 6, offset: const Offset(0, 1))]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? context.textPrimary : context.textSecondary,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final String? badge;
  final VoidCallback onTap;

  const _ProfileTabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? MployaTheme.brandAccent.withValues(alpha: 0.10)
                : (context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? MployaTheme.brandAccent.withValues(alpha: 0.30)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? MployaTheme.brandAccent : context.textSecondary,
                  ),
                  if (badge != null)
                    Positioned(
                      top: -6,
                      right: -10,
                      child: Text(badge!, style: const TextStyle(fontSize: 10)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? MployaTheme.brandAccent : context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Spotlight Card — Full-width gradient card for premium AI features
// ─────────────────────────────────────────────────────────────────────────────

class _SpotlightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String? tag;
  final VoidCallback onTap;

  const _SpotlightCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.tag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.30),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (tag != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag!,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Spotlight Card Compact — Half-width gradient card
// ─────────────────────────────────────────────────────────────────────────────

class _SpotlightCardCompact extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _SpotlightCardCompact({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Empezar',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.80),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(CupertinoIcons.chevron_right, size: 10, color: Colors.white.withValues(alpha: 0.80)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Action Chip — Vertical icon chip for horizontal scroll
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}