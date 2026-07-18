import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import 'mis_herramientas_screen.dart';
import 'ats_dashboard_screen.dart';
import '../widgets/mploya_ui.dart';
import '../widgets/web_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
    final wide = MediaQuery.of(context).size.width > 900;
    final bg = context.isDark ? NexTheme.darkBg : const Color(0xFFF5F7FA);

    // ── Web: Premium Cards Grid ──
    if (wide) {
      return CupertinoPageScaffold(
        backgroundColor: bg,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top bar ──
                    _buildWebTopBar(context, profile, isOwnProfile),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Column 1 (Left): Profile Card, Video Pitch, Project Showcase
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildWebProfileCard(context, profile, isOwnProfile),
                              const SizedBox(height: 16),
                              _buildWebVideoPitchCard(context, profile, isOwnProfile),
                              const SizedBox(height: 16),
                              _buildWebProjectShowcases(context, profile),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Column 2 (Middle): Core Stats, Advanced Analytics, Certifications & Awards
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildWebCoreStats(context, profile),
                              const SizedBox(height: 16),
                              _buildWebAdvancedAnalytics(context, profile),
                              const SizedBox(height: 16),
                              _buildWebCertifications(context),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Column 3 (Right): My Company, Skills Compatibility, Recommendations
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildWebMyCompany(context, profile),
                              const SizedBox(height: 16),
                              _buildWebSkillsCompatibility(context, profile, isOwnProfile),
                              const SizedBox(height: 16),
                              _buildWebRecommendations(context),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ── Móvil: una sola columna con tarjetas completamente visibles y apiladas ──
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Nav / Actions Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    if (!isOwnProfile)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Icon(CupertinoIcons.chevron_back, size: 24, color: Color(0xFF0F172A)),
                      ),
                    const Spacer(),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => ShareService.instance.shareProfile(
                        name: profile.name, headline: profile.headline,
                        userId: profile.id, accountType: profile.accountType,
                      ),
                      child: const Icon(CupertinoIcons.square_arrow_up, size: 22, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 14),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _showSettingsSheet(context, profile),
                      child: const Icon(CupertinoIcons.ellipsis, size: 22, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              // Header candidate info
              _buildMobileHeader(context, profile, isOwnProfile),
              const SizedBox(height: 12),
              // Padding wrapper for mobile list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Core Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                  Text('Performance trend', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                ],
                              ),
                              Icon(CupertinoIcons.chevron_up, size: 16, color: Color(0xFF94A3B8)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildCoreStatsContent(context, profile),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Skills Compatibility', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                              Icon(CupertinoIcons.chevron_up, size: 16, color: Color(0xFF94A3B8)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildSkillsCompatibilityContent(context, profile, isOwnProfile),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Certifications & Awards', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          const SizedBox(height: 14),
                          _buildCertificationsContent(context),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recommendations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          const SizedBox(height: 14),
                          _buildRecommendationsContent(context),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Video Pitch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          const SizedBox(height: 14),
                          _buildVideoPitchContent(context, profile, isOwnProfile),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Project Showcases', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          const SizedBox(height: 14),
                          _buildProjectShowcasesContent(context, profile),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 140),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WEB PREMIUM CARDS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWebTopBar(BuildContext context, NexUser profile, bool isOwnProfile) {
    return Row(
      children: [
        if (profile.isPremium || profile.isVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF97316).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.checkmark_seal_fill, size: 13, color: Colors.white),
                SizedBox(width: 5),
                Text('Premium', style: TextStyle(color: CupertinoColors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        const Spacer(),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => ShareService.instance.shareProfile(
            name: profile.name, headline: profile.headline,
            userId: profile.id, accountType: profile.accountType,
          ),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(CupertinoIcons.square_arrow_up, size: 18, color: CupertinoColors.systemGrey),
          ),
        ),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => _showSettingsSheet(context, profile),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(CupertinoIcons.ellipsis, size: 18, color: CupertinoColors.systemGrey),
          ),
        ),
      ],
    );
  }

  Widget _buildWebProfileCard(BuildContext context, NexUser profile, bool isOwnProfile) {
    return _PremiumCard(
      child: Stack(
        children: [
          Positioned(
            top: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.sparkles, size: 10, color: Color(0xFFD97706)),
                  SizedBox(width: 3),
                  Text('Disponible', style: TextStyle(color: Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              GestureDetector(
                onTap: isOwnProfile ? () => _pickAndUploadAvatar(profile) : null,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 3),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4)),
                    ],
                    image: const DecorationImage(
                      image: AssetImage('assets/images/avatar_juan_perez.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                profile.name,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                profile.headline,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              RichText(
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.5, fontFamily: 'Arial'),
                  children: [
                    TextSpan(
                      text: profile.about ?? 'Desarrollador Flutter Senior con más de 7 años de experiencia liderando equipos y construyendo arquitecturas móviles escalables y robustas. Especialista en optimización de rendimiento y clean architecture.',
                    ),
                    const TextSpan(
                      text: ' ...read more',
                      style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialButton(CupertinoIcons.phone_fill, const Color(0xFF0F172A)),
                  const SizedBox(width: 8),
                  _socialButton(CupertinoIcons.envelope_fill, const Color(0xFF0F172A)),
                  const SizedBox(width: 8),
                  _socialButton(CupertinoIcons.settings, const Color(0xFF0F172A)),
                  const SizedBox(width: 8),
                  _socialButton(CupertinoIcons.globe, const Color(0xFF0F172A)),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => MisHerramientasScreen(profile: profile))),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Text(
                            '3 enlaces',
                            style: TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        // Action for Descargar CV
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFF97316).withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Descargar CV',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _socialButton(IconData icon, Color color) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _buildWebMyCompany(BuildContext context, NexUser profile) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Company', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              Icon(CupertinoIcons.ellipsis, size: 16, color: Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(child: _miniTab('Team Size', true)),
                Expanded(child: _miniTab('Sector', false)),
                Expanded(child: _miniTab('Funding Status', false)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            height: 100,
            child: _ProfileBarChart(
              values: [1200, 1800, 2500, 1500, 1000],
              labels: ['Prog', 'UX', 'Unb', 'UI', 'Agro'],
            ),
          ),
          const SizedBox(height: 14),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text(
                  'Internal Rules',
                  style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTab(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        boxShadow: active ? [const BoxShadow(color: Color(0x0A000000), blurRadius: 4)] : [],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: active ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildWebSkillsCompatibility(BuildContext context, NexUser profile, bool isOwnProfile) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Skills Compatibility', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              Icon(CupertinoIcons.chevron_up, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 12),
          _buildSkillsCompatibilityContent(context, profile, isOwnProfile),
        ],
      ),
    );
  }

  Widget _buildWebRecommendations(BuildContext context) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recommendations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          _buildRecommendationsContent(context),
        ],
      ),
    );
  }

  Widget _buildWebVideoPitchCard(BuildContext context, NexUser profile, bool isOwnProfile) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Video Pitch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          _buildVideoPitchContent(context, profile, isOwnProfile),
        ],
      ),
    );
  }

  Widget _buildWebProjectShowcases(BuildContext context, NexUser profile) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Project Showcases', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              Icon(CupertinoIcons.chevron_right, size: 14, color: Color(0xFF64748B)),
            ],
          ),
          const SizedBox(height: 12),
          _buildProjectShowcasesContent(context, profile),
        ],
      ),
    );
  }

  Widget _projectCardCompact(String title, String desc, ImageProvider image) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image(
            image: image,
            height: 80,
            width: 180,
            fit: BoxFit.cover,
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebCoreStats(BuildContext context, NexUser profile) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Core Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  Text('Performance trend', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
              Icon(CupertinoIcons.ellipsis, size: 16, color: Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 14),
          _buildCoreStatsContent(context, profile),
        ],
      ),
    );
  }

  Widget _coreStatMetric(String label, String value, bool showProgress, {bool isPositive = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: isPositive ? const Color(0xFF22C55E) : const Color(0xFF0F172A),
          ),
        ),
        if (showProgress) ...[
          const SizedBox(height: 4),
          Container(
            width: 50, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.7,
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWebAdvancedAnalytics(BuildContext context, NexUser profile) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Advanced Analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          Row(
            children: [
              _analyticTab('Resume Growth', true),
              const SizedBox(width: 6),
              _analyticTab('Job Activity', false),
              const SizedBox(width: 6),
              _analyticTab('Interview', false),
            ],
          ),
          const SizedBox(height: 16),
          const SizedBox(
            height: 90,
            child: _ProfileLineChart(
              spots: [
                FlSpot(0, 40),
                FlSpot(1, 35),
                FlSpot(2, 60),
                FlSpot(3, 50),
                FlSpot(4, 75),
                FlSpot(5, 70),
              ],
              xLabels: ['Jan', 'Mar', 'May', 'Jul', 'Aug', 'Sep'],
              lineColor: Color(0xFFF97316),
              gradientColors: [Color(0xFFF97316), Color(0xFFFDBA74)],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFEDD5)),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.mic_fill, size: 12, color: Color(0xFFEA580C)),
                const SizedBox(width: 6),
                const Text('Speech analytics', style: TextStyle(color: Color(0xFFEA580C), fontSize: 10, fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: Text('Ver detalle', style: TextStyle(color: MployaTheme.brandAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticTab(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : const Color(0xFF64748B),
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildWebCertifications(BuildContext context) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Certifications & Awards', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 14),
          _buildCertificationsContent(context),
        ],
      ),
    );
  }

  Widget _certificationBadge(IconData icon, String name, Color color) {
    return Tooltip(
      message: name,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  Widget _buildMobileHeader(BuildContext context, NexUser profile, bool isOwnProfile) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          GestureDetector(
            onTap: isOwnProfile ? () => _pickAndUploadAvatar(profile) : null,
            child: Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4)),
                ],
                image: const DecorationImage(
                  image: AssetImage('assets/images/avatar_juan_perez.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            profile.headline,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _socialButton(CupertinoIcons.phone_fill, const Color(0xFF0F172A)),
              const SizedBox(width: 8),
              _socialButton(CupertinoIcons.envelope_fill, const Color(0xFF0F172A)),
              const SizedBox(width: 8),
              _socialButton(CupertinoIcons.settings, const Color(0xFF0F172A)),
              const SizedBox(width: 8),
              _socialButton(CupertinoIcons.globe, const Color(0xFF0F172A)),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.5, fontFamily: 'Arial'),
              children: [
                TextSpan(
                  text: profile.about ?? 'Desarrollador Flutter Senior con más de 7 años de experiencia liderando equipos y construyendo arquitecturas móviles escalables y robustas. Especialista en optimización de rendimiento y clean architecture.',
                ),
                const TextSpan(
                  text: ' ...read more',
                  style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoreStatsContent(BuildContext context, NexUser profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 110,
          child: _ProfileLineChart(
            spots: [
              FlSpot(0, 30),
              FlSpot(1, 48),
              FlSpot(2, 38),
              FlSpot(3, 55),
              FlSpot(4, 68),
              FlSpot(5, 82),
            ],
            xLabels: ['Jan', 'Mar', 'May', 'Jul', 'Aug', 'Sep'],
            lineColor: Color(0xFF0F172A),
            gradientColors: [Color(0xFF0F172A), Colors.transparent],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _coreStatMetric('Visualizaciones', '248', true),
            _coreStatMetric('Descargas CV', '42 ↑', false, isPositive: true),
            _coreStatMetric('Búsquedas', '1,200', false),
          ],
        ),
        const SizedBox(height: 14),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'Internal Anal.',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillsCompatibilityContent(BuildContext context, NexUser profile, bool isOwnProfile) {
    final skillList = [
      {'name': 'Flutter', 'rating': 5, 'icon': CupertinoIcons.sparkles, 'color': const Color(0xFF3B82F6)},
      {'name': 'Dart', 'rating': 5, 'icon': CupertinoIcons.chevron_left_slash_chevron_right, 'color': const Color(0xFF0D9488)},
      {'name': 'Firebase', 'rating': 4, 'icon': CupertinoIcons.cloud_fill, 'color': const Color(0xFFF59E0B)},
      {'name': 'Clean Arch', 'rating': 4, 'icon': CupertinoIcons.layers_alt_fill, 'color': const Color(0xFF64748B)},
      {'name': 'UI/UX', 'rating': 4, 'icon': CupertinoIcons.device_phone_portrait, 'color': const Color(0xFFEA580C)},
      {'name': 'Kotlin', 'rating': 3, 'icon': CupertinoIcons.app_fill, 'color': const Color(0xFF8B5CF6)},
      {'name': 'Swift', 'rating': 4, 'icon': CupertinoIcons.app_fill, 'color': const Color(0xFFEF4444)},
      {'name': 'Unit Test', 'rating': 5, 'icon': CupertinoIcons.checkmark_seal_fill, 'color': const Color(0xFF10B981)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: skillList.map((skill) {
            return Container(
              width: 125,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(skill['icon'] as IconData, size: 10, color: skill['color'] as Color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          skill['name'] as String,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(5, (starIndex) {
                      final rating = skill['rating'] as int;
                      final active = starIndex < rating;
                      return Icon(
                        active ? CupertinoIcons.star_fill : CupertinoIcons.star,
                        size: 9,
                        color: active ? const Color(0xFFF97316) : const Color(0xFFCBD5E1),
                      );
                    }),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SkillAssessmentScreen()));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'Start Skill Assessment',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCertificationsContent(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _certificationBadge(CupertinoIcons.shield_fill, 'AWS Expert', const Color(0xFF3B82F6)),
        _certificationBadge(CupertinoIcons.rosette, 'Google Architect', const Color(0xFFD97706)),
        _certificationBadge(CupertinoIcons.sparkles, 'Scrum Master', const Color(0xFF0D9488)),
        _certificationBadge(CupertinoIcons.star_fill, 'Kotlin Expert', const Color(0xFF8B5CF6)),
      ],
    );
  }

  Widget _buildRecommendationsContent(BuildContext context) {
    final recs = [
      {'name': 'Alex T.', 'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=80&h=80&fit=crop'},
      {'name': 'Elena G.', 'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80&h=80&fit=crop'},
      {'name': 'Carlos M.', 'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80&h=80&fit=crop'},
    ];
    return Row(
      children: [
        ...recs.map((rec) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: rec['name']!,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF97316), width: 1.5),
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: rec['avatar']!,
                    width: 28, height: 28,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(CupertinoIcons.person_solid),
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(width: 4),
        Container(
          width: 32, height: 32,
          decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
          child: const Icon(CupertinoIcons.plus, size: 14, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildVideoPitchContent(BuildContext context, NexUser profile, bool isOwnProfile) {
    final hasVideo = profile.videoUrl != null && profile.videoUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(14),
            image: const DecorationImage(
              image: AssetImage('assets/images/video_thumbnail_demo.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              Positioned(
                left: 16, right: 16, bottom: 24, top: 40,
                child: CustomPaint(painter: _WaveformPainter()),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFF97316).withValues(alpha: 0.4), blurRadius: 12),
                    ],
                  ),
                  child: const Icon(CupertinoIcons.play_fill, size: 20, color: Colors.white),
                ),
              ),
              Positioned(
                bottom: 10, left: 10, right: 10,
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.play_circle_fill, size: 13, color: Colors.white),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.15,
                          child: Container(color: const Color(0xFFF97316)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '0:05 / 0:45',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  if (hasVideo) {
                    showCupertinoModalPopup<void>(context: context, builder: (_) => VideoPlayerModal(videoUrl: profile.videoUrl!, index: 0));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'View Full Pitch',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 4,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  if (isOwnProfile) {
                    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const CameraScreen()));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text(
                      'Record Pro',
                      style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 4,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  Navigator.of(context).push(CupertinoPageRoute(
                    builder: (_) => InterviewPrepScreen(
                      jobTitle: profile.headline,
                      candidateSkills: profile.skills,
                    ),
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text(
                      'Practice',
                      style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProjectShowcasesContent(BuildContext context, NexUser profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _projectCardCompact(
                'Key project - Descriptions',
                'Desarrollo de una arquitectura mobile escalable con micro-frontends en Flutter...',
                const AssetImage('assets/images/project_showcase_1.jpg'),
              ),
              const SizedBox(width: 12),
              _projectCardCompact(
                'Keyless Projects',
                'SDK criptográfico para inicio de sesión seguro biométrico e integraciones OAuth...',
                const AssetImage('assets/images/project_showcase_2.jpg'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebTabsSection(BuildContext context, NexUser profile) {
    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab bar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _SegTab(label: 'Sobre mí', isSelected: _selectedProfileTab == 0, onTap: () => setState(() => _selectedProfileTab = 0)),
                _SegTab(label: 'Portfolio', isSelected: _selectedProfileTab == 1, onTap: () => setState(() => _selectedProfileTab = 1)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tab content
          if (_selectedProfileTab == 0) ...[
            ProfilePersonalitySection(userId: profile.id, isOwnProfile: true, headline: profile.headline, skills: profile.skills),
            if (profile.experience.isNotEmpty) _buildExperienceClean(context, profile, true),
            _buildSkillsClean(context, profile, true),
          ],
          if (_selectedProfileTab == 1) ...[
            PortfolioSection(userId: profile.id, isOwnProfile: true),
            EmployerRatingSection(companyId: profile.id, companyAccountType: profile.accountType, isOwnProfile: true),
            SkillBadgesSection(userId: profile.id, isOwnProfile: true),
          ],
        ],
      ),
    );
  }
  void _openEditProfile(BuildContext context, NexUser profile) {
    if (profile.accountType == 'empresa' || profile.accountType == 'headhunter') {
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const CompanyProfileFormScreen()));
    } else if (profile.accountType == 'confidencial' || profile.accountType == 'stealth') {
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const StealthProfileFormScreen()));
    } else {
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const CandidateProfileFormScreen(isEditing: true)));
    }
  }

  // ── Accesos rápidos de empresa (Analítica / Candidatos / Entrevistas) ─────
  Widget _buildCompanyQuickTools(BuildContext context) {
    return Container(
      color: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: _companyQuickTool(
              context,
              icon: CupertinoIcons.chart_bar_fill,
              color: const Color(0xFF8B5CF6),
              label: 'Analítica',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const ProfileAnalyticsDashboardScreen()),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _companyQuickTool(
              context,
              icon: CupertinoIcons.briefcase_fill,
              color: const Color(0xFF2563EB),
              label: 'Candidatos',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const AtsDashboardScreen()),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _companyQuickTool(
              context,
              icon: CupertinoIcons.calendar,
              color: const Color(0xFFD97706),
              label: 'Entrevistas',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const SchedulingScreen(isCompany: true)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyQuickTool(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.isDark ? const Color(0xFF222222) : const Color(0xFFEDEFF2)),
        ),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimary)),
          ],
        ),
      ),
    );
  }

  // ── Entrada a "Mis herramientas" (pantalla privada del usuario) ───────────
  Widget _buildToolsEntry(BuildContext context, NexUser profile) {
    return Container(
      color: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => MisHerramientasScreen(profile: profile, isAdmin: _isAdmin)),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.isDark ? const Color(0xFF222222) : const Color(0xFFEDEFF2)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.square_grid_2x2_fill, size: 19, color: CupertinoColors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mis herramientas',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Impulsar, estadísticas, entrevistas, cuenta y más',
                      style: TextStyle(fontSize: 12.5, color: context.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_right, size: 16, color: context.textTertiary),
            ],
          ),
        ),
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
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFFC2410C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 26),
        child: Column(
          children: [
            // ── Avatar con anillo blanco ──
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
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: CupertinoColors.white,
                      boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 22, offset: Offset(0, 10))],
                    ),
                    child: NexAvatar(user: profile, size: 100, showBadge: true),
                  ),
                  if (isOwnProfile)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x14000000), width: 0.5),
                        ),
                        child: const Icon(CupertinoIcons.camera_fill, color: MployaTheme.brandAccent, size: 15),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ── Nombre (blanco sobre el gradiente) ──
            Text(
              profile.name,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: CupertinoColors.white, letterSpacing: -0.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // ── Cargo ──
            Text(
              profile.headline,
              style: const TextStyle(fontSize: 14.5, color: Color(0xE6FFFFFF), height: 1.35),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 13),
            // ── Badges sobre el gradiente ──
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (profile.isVerified || profile.isPremium)
                  _heroBadge(CupertinoIcons.checkmark_shield_fill, 'Verificado'),
                if (profile.location != null)
                  _heroBadge(CupertinoIcons.location_solid, profile.location!),
                _heroBadge(CupertinoIcons.circle_fill, profile.isOpenToWork ? 'Disponible' : (profile.isHiring ? 'Contratando' : 'Activo')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: CupertinoColors.white),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: CupertinoColors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── Name + Headline + Badges + Action Buttons ─────────────────────────────

  SliverToBoxAdapter _buildNameSection(BuildContext context, NexUser profile, bool isOwnProfile) {
    return SliverToBoxAdapter(
      child: Container(
        color: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Action Row (Edit + Generate Bio) ──
            if (isOwnProfile)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _actionPill(
                    icon: CupertinoIcons.pencil,
                    label: 'Editar perfil',
                    onTap: () => _openEditProfile(context, profile),
                  ),
                  const SizedBox(width: 10),
                  // Violeta = "esto lo hace la IA" (misma regla de color que
                  // Personalidad IA más abajo). El acceso a Admin se movió a
                  // "Mis herramientas" para no sumar un tercer color acá.
                  _actionPill(
                    icon: CupertinoIcons.sparkles,
                    label: 'Bio con IA',
                    onTap: () => showGenerarBioSheet(context, profile),
                    color: MployaTheme.aiAccent,
                  ),
                ],
              ),
            const SizedBox(height: 20),
            // ── Stats: 3 mini-cards con números grandes ──
            GestureDetector(
              onTap: isOwnProfile ? () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ProfileViewersScreen())) : null,
              child: Row(
                children: [
                  Expanded(child: _statCard(context, '${profile.connections}', 'Conexiones')),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard(context, '${profile.profileViews}', 'Vistas')),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard(context, '${profile.matchPercentage.round()}', 'Matches')),
                ],
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
  Widget _actionPill({required IconData icon, required String label, required VoidCallback onTap, Color? color}) {
    final c = color;
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

  Widget _statCard(BuildContext context, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
            letterSpacing: -0.5,
          )),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: context.textTertiary, fontWeight: FontWeight.w500)),
        ],
      ),
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
          const SizedBox(height: 14),
          // Video thumbnail — aspect 16:9 real, esquinas redondeadas y sombra
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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.1,
                        colors: [Color(0xFF2D2D45), Color(0xFF15151F)],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            width: 58, height: 58,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(CupertinoIcons.play_fill, color: MployaTheme.brandAccent, size: 26),
                          ),
                        ),
                        Positioned(
                          top: 12, left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(CupertinoIcons.videocam_fill, color: Colors.white, size: 12),
                              SizedBox(width: 5),
                              Text('Video-Pitch', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                        Positioned(
                          top: 12, right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: MployaTheme.brandAccent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(CupertinoIcons.sparkles, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('92 pts', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                      color: MployaTheme.brandAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
                      border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.35), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.add, size: 13, color: MployaTheme.brandAccent),
                        const SizedBox(width: 4),
                        Text(
                          'Agregar',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: MployaTheme.brandAccent,
                          ),
                        ),
                      ],
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

// ── Waveform painter for video-pitch card ──
class _WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF97316).withValues(alpha: 0.35)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final midY = size.height / 2;
    final barCount = 40;
    final barWidth = size.width / barCount;
    for (var i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;
      final h = (midY * 0.3) + (midY * 0.7) * (0.5 + 0.5 * _wave(i, barCount));
      canvas.drawLine(Offset(x, midY - h / 2), Offset(x, midY + h / 2), paint);
    }
  }

  double _wave(int i, int count) {
    final t = i / count;
    return (0.5 * (1 + math.sin(2 * math.pi * t * 3))) * (1 - (t - 0.5).abs() * 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Custom Line Chart for Premium Profile Stats ──
class _ProfileLineChart extends StatelessWidget {
  final List<FlSpot> spots;
  final List<String> xLabels;
  final Color lineColor;
  final List<Color> gradientColors;

  const _ProfileLineChart({
    required this.spots,
    required this.xLabels,
    required this.lineColor,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < xLabels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      xLabels[index],
                      style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 8),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (xLabels.length - 1).toDouble(),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: gradientColors.map((color) => color.withValues(alpha: 0.15)).toList(),
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom Bar Chart for Team/Company Data ──
class _ProfileBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;

  const _ProfileBarChart({
    required this.values,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 3000,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < labels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      labels[index],
                      style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 8),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 20,
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(values.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: values[index],
                color: index == 2 ? const Color(0xFFF97316) : const Color(0xFF0F172A),
                width: 12,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ── Collapsible Card for Mobile Acordeones ──
class _CollapsibleCard extends StatefulWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  const _CollapsibleCard({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  State<_CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<_CollapsibleCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Icon(
                  _expanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                  size: 16,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

// ── Premium Card for consistent mockup layout ──
class _PremiumCard extends StatelessWidget {
  final Widget child;

  const _PremiumCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}