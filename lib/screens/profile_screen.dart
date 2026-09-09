import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        CircularProgressIndicator,
        Colors,
        LinearProgressIndicator,
        RefreshIndicator;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/profile_view_service.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';
import '../services/my_profile_service.dart';
import '../services/job_application_flow.dart';
import '../services/video_preload_manager.dart';
import '../theme/app_theme.dart';
import '../theme/mploya_tokens.dart';
import '../widgets/candidato/cand_perfil.dart';
import '../widgets/candidato/cand_ui.dart';
import '../widgets/mploya_shell.dart';
import '../widgets/profile_video_widgets.dart';
import 'camera_screen.dart';
import 'candidate_profile_form_screen.dart';
import 'chat_inmail_screen.dart';
import 'company_profile_form_screen.dart';
import 'headhunter/headhunter_edit_profile_screen.dart';
import 'headhunter/headhunter_settings_screen.dart';
import 'headhunter/headhunter_video_pitch_screen.dart';
import 'job_detail_screen.dart';
import 'mis_postulaciones_screen.dart';
import 'ofertas_recibidas_screen.dart';
import 'onboarding_pitch_screen.dart';
import 'preferencias_laborales_screen.dart';
import 'settings_screen.dart';
import 'tools_hub_entry_screen.dart';
import 'saved_jobs_screen.dart';
import 'splash_screen.dart';
import 'stealth_profile_form_screen.dart';
import '../services/portfolio_service.dart';
import '../utils/headhunter_candidate_privacy.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
part 'profile_screen_bodies.dart';
part 'profile_screen_hero.dart';
part 'profile_screen_sections.dart';
part 'profile_screen_experience.dart';
part 'profile_screen_metrics.dart';

/// Perfil propio ya resuelto para render tests y capturas. Mismo patrón que
/// `JobsPreviewData` y `NetworkPreviewData`: si llega, la pantalla NO consulta
/// Supabase. El widget que se monta sigue siendo `ProfileScreen` productivo.
@immutable
class ProfilePreviewData {
  const ProfilePreviewData({
    required this.usuario,
    this.portfolio = const [],
    this.viewCount = 0,
    this.isOwnProfile = true,
    this.viewerAccountType,
  });

  /// Fila de `users` con la forma que devuelve la base.
  final Map<String, dynamic> usuario;

  final List<PortfolioVideo> portfolio;
  final int viewCount;
  final bool isOwnProfile;
  final String? viewerAccountType;
}

class ProfileScreen extends StatefulWidget {
  final NexUser? user;

  /// Sólo lo usan los tests y el generador de capturas. En producción es `null`
  /// y el comportamiento es exactamente el de antes.
  final ProfilePreviewData? previewData;
  final String? viewerAccountType;

  const ProfileScreen({
    super.key,
    this.user,
    this.previewData,
    this.viewerAccountType,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>?>? _ownFuture;
  final Map<String, Future<_ProfileBundle>> _bundleFutures = {};

  String _connectionStatus = 'none';
  bool _isLoadingConnection = false;
  bool _isSavedProfile = false;
  bool _isSavingProfile = false;
  int _selectedPublicTab = 0;
  Future<String?>? _viewerAccountTypeFuture;

  @override
  void initState() {
    super.initState();
    // Render aislado: los datos ya vienen resueltos y no se toca la red.
    if (widget.previewData != null) return;
    if (widget.user == null) {
      _reloadOwnProfile();
    } else {
      if (widget.viewerAccountType == null &&
          isConfidentialCandidate(widget.user!)) {
        _viewerAccountTypeFuture = _loadViewerAccountType();
      }
      ProfileViewService.instance.recordView(widget.user!.id);
      _fetchConnectionStatus(widget.user!.id);
      _loadSavedProfileStatus();
    }
  }

  Future<String?> _loadViewerAccountType() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await loadMyProfile();
    return row?['account_type']?.toString();
  }

  void _reloadOwnProfile() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    setState(() {
      _ownFuture = loadMyProfile();
      _bundleFutures.remove(uid);
    });
  }

  Future<_ProfileBundle> _loadBundle(NexUser profile, bool isOwnProfile) async {
    final portfolioFuture = isOwnProfile
        ? PortfolioService.instance.getMyPortfolio(forceRefresh: true)
        : PortfolioService.instance.getPortfolioFor(profile.id);
    final viewsFuture = isOwnProfile
        ? ProfileViewService.instance.getMyViewCount()
        : Future<int>.value(profile.profileViews);

    final results = await Future.wait<dynamic>([portfolioFuture, viewsFuture]);

    return _ProfileBundle(
      portfolio: results[0] as List<PortfolioVideo>,
      viewCount: results[1] as int,
    );
  }

  Future<_ProfileBundle> _bundleFutureFor(NexUser profile, bool isOwnProfile) {
    final preview = widget.previewData;
    if (preview != null) {
      return Future.value(
        _ProfileBundle(
          portfolio: preview.portfolio,
          viewCount: preview.viewCount,
        ),
      );
    }
    final key = '${profile.id}_${isOwnProfile ? 'own' : 'public'}';
    return _bundleFutures.putIfAbsent(
      key,
      () => _loadBundle(profile, isOwnProfile),
    );
  }

  Future<void> _loadSavedProfileStatus() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final otherId = widget.user?.id;
    if (myId == null || otherId == null || myId == otherId) return;
    try {
      final row = await Supabase.instance.client
          .from('saved_profiles')
          .select('saved_user_id')
          .eq('user_id', myId)
          .eq('saved_user_id', otherId)
          .maybeSingle();
      if (mounted) {
        setState(() => _isSavedProfile = row != null);
      }
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'profile_screen: leer si el perfil esta guardado',
        fatal: false,
      );
    }
  }

  Future<void> _toggleSavedProfile(NexUser profile) async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null || myId == profile.id || _isSavingProfile) return;
    setState(() {
      _isSavingProfile = true;
      _isSavedProfile = !_isSavedProfile;
    });
    try {
      if (_isSavedProfile) {
        await Supabase.instance.client.from('saved_profiles').upsert({
          'user_id': myId,
          'saved_user_id': profile.id,
        }, onConflict: 'user_id,saved_user_id');
      } else {
        await Supabase.instance.client
            .from('saved_profiles')
            .delete()
            .eq('user_id', myId)
            .eq('saved_user_id', profile.id);
      }
    } catch (_) {
      if (mounted) setState(() => _isSavedProfile = !_isSavedProfile);
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _fetchConnectionStatus(String otherId) async {
    setState(() => _isLoadingConnection = true);
    try {
      final res = await Supabase.instance.client.rpc(
        'get_connection_status',
        params: {'p_other_user_id': otherId},
      );
      if (mounted && res != null && res['status'] != null) {
        setState(() => _connectionStatus = res['status'] as String);
      }
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'profile_screen: get_connection_status',
        fatal: false,
      );
    } finally {
      if (mounted) setState(() => _isLoadingConnection = false);
    }
  }

  Future<void> _sendConnectionRequest(String otherId) async {
    setState(() => _isLoadingConnection = true);
    try {
      final res = await Supabase.instance.client.rpc(
        'send_connection_request',
        params: {'p_addressee_id': otherId},
      );
      if (mounted && res != null && res['status'] != null) {
        setState(() => _connectionStatus = res['status'] as String);
      }
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'profile_screen: send_connection_request',
        fatal: false,
      );
    } finally {
      if (mounted) setState(() => _isLoadingConnection = false);
    }
  }

  Future<void> _pickAndUploadAvatar(NexUser profile) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CupertinoActivityIndicator(radius: 16)),
    );

    final url = await StorageService.instance.uploadAvatar(uid, picked);
    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (url == null) {
      if (!mounted) return;
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('No se pudo actualizar'),
          content: Text(
            StorageService.instance.lastError ??
                'Intenta nuevamente en unos segundos.',
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

    await setMyProfileAvatar(url);
    _reloadOwnProfile();
  }

  Future<void> _openEditProfile(BuildContext context, NexUser profile) async {
    final type = profile.accountType.toLowerCase();
    final route = type == 'empresa'
        ? CupertinoPageRoute(builder: (_) => const CompanyProfileFormScreen())
        : type == 'headhunter'
        ? CupertinoPageRoute(
            builder: (_) => const HeadhunterEditProfileScreen(),
          )
        : (type == 'confidencial' || type == 'stealth')
        ? CupertinoPageRoute(builder: (_) => const StealthProfileFormScreen())
        : CupertinoPageRoute(
            builder: (_) => const CandidateProfileFormScreen(isEditing: true),
          );
    await Navigator.of(context).push(route);
    _reloadOwnProfile();
  }

  Future<void> _openVideoPitchFlow(
    BuildContext context,
    NexUser profile,
  ) async {
    final type = profile.accountType.toLowerCase();
    if (type == 'headhunter') {
      await Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const HeadhunterVideoPitchScreen()),
      );
      _reloadOwnProfile();
      return;
    }
    final isCompany = type == 'empresa' || type == 'headhunter';
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => OnboardingPitchScreen(isCompany: isCompany),
      ),
    );
    _reloadOwnProfile();
  }

  Future<void> _openPitchCamera(BuildContext context, NexUser profile) async {
    await Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (_) => const CameraScreen()));
    _reloadOwnProfile();
  }

  void _showMoreActions(
    BuildContext context,
    NexUser profile,
    bool isOwnProfile,
  ) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(
          isOwnProfile ? 'Tu perfil profesional' : 'Acciones del perfil',
        ),
        message: Text(
          isOwnProfile
              ? 'Gestioná visibilidad, edición y distribución de tu perfil.'
              : 'Elegí cómo querés continuar con este perfil.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              ShareService.instance.shareProfile(
                name: profile.name,
                headline: profile.headline,
                userId: profile.id,
                accountType: profile.accountType,
              );
            },
            child: const Text('Compartir perfil'),
          ),
          if (isOwnProfile)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => profile.accountType == 'headhunter'
                        ? const HeadhunterSettingsScreen()
                        : const SettingsScreen(),
                  ),
                );
              },
              child: const Text('Configuración y visibilidad'),
            ),
          if (isOwnProfile)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _openEditProfile(context, profile);
              },
              child: const Text('Editar perfil'),
            ),
          if (isOwnProfile)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const MisPostulacionesScreen(),
                  ),
                );
              },
              child: const Text('Mis Postulaciones'),
            ),
          if (isOwnProfile)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const PreferenciasLaboralesScreen(),
                  ),
                );
              },
              child: const Text('Preferencias laborales'),
            ),
          if (isOwnProfile)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const OfertasRecibidasScreen(),
                  ),
                );
              },
              child: const Text('Ofertas recibidas'),
            ),
          // Mis Herramientas y Guardados no tenían NINGUNA entrada: el hub de
          // herramientas vivía en una ranura del IndexedStack que la barra de
          // candidato no publicaba, así que ni él ni las pantallas que cuelgan
          // de él (CV, referidos, quién vio tu perfil, impulsar perfil) eran
          // alcanzables. Se abren por `push`, no cambiando de pestaña.
          if (isOwnProfile)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const ToolsHubEntryScreen(),
                  ),
                );
              },
              child: const Text('Mis Herramientas'),
            ),
          if (isOwnProfile)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const SavedJobsScreen()),
                );
              },
              child: const Text('Guardados'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cerrar'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.previewData;
    if (preview != null) {
      return _buildProfileLoader(
        context,
        NexUser.fromJson(preview.usuario),
        preview.isOwnProfile,
        viewerAccountType: preview.viewerAccountType,
      );
    }

    if (widget.user != null) {
      final viewerType = widget.viewerAccountType;
      final future = _viewerAccountTypeFuture;
      if (viewerType != null || future == null) {
        return _buildProfileLoader(
          context,
          widget.user!,
          false,
          viewerAccountType: viewerType,
        );
      }
      return FutureBuilder<String?>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ProtectedCandidateProfile();
          }
          return _buildProfileLoader(
            context,
            widget.user!,
            false,
            viewerAccountType: snapshot.data,
          );
        },
      );
    }

    if (_ownFuture == null) {
      return CupertinoPageScaffold(
        backgroundColor: NexTheme.shellBg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.person_crop_circle_badge_exclam,
                size: 58,
              ),
              const SizedBox(height: 16),
              const Text(
                'Inicia sesión para abrir tu perfil',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text(
                'Necesitamos una sesión activa para cargar tu identidad profesional.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    CupertinoPageRoute(builder: (_) => const SplashScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Ir al inicio'),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _ownFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _ProfileLoadingScaffold(
            title: 'Cargando tu perfil',
            subtitle:
                'Estamos armando tu identidad profesional con video, experiencia y señales reales.',
            onCancel: () async {
              VideoPreloadManager.instance.disposeAll();
              await Supabase.instance.client.auth.signOut();
              if (!context.mounted) return;
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                CupertinoPageRoute(builder: (_) => const SplashScreen()),
                (route) => false,
              );
            },
          );
        }

        if (snapshot.hasError) {
          return _ProfileErrorScaffold(
            title: 'No pudimos cargar tu perfil',
            message: snapshot.error.toString(),
            onRetry: _reloadOwnProfile,
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return _ProfileErrorScaffold(
            title: 'Tu perfil todavía está vacío',
            message:
                'Completá tu identidad profesional para activar video pitch, portfolio y referencias.',
            onRetry: _reloadOwnProfile,
          );
        }

        return _buildProfileLoader(
          context,
          NexUser.fromJson(snapshot.data!),
          true,
        );
      },
    );
  }

  Widget _buildProfileLoader(
    BuildContext context,
    NexUser profile,
    bool isOwnProfile, {
    String? viewerAccountType,
  }) {
    if (!isOwnProfile &&
        shouldProtectCandidateForHeadhunter(profile, viewerAccountType)) {
      return _ProtectedCandidateProfile(
        profile: protectCandidateForHeadhunter(profile, viewerAccountType),
      );
    }
    return FutureBuilder<_ProfileBundle>(
      future: _bundleFutureFor(profile, isOwnProfile),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _ProfileLoadingScaffold(
            title: isOwnProfile
                ? 'Preparando tu perfil'
                : 'Preparando perfil público',
            subtitle:
                'Estamos cargando portfolio, video pitch y señales profesionales.',
          );
        }

        if (snapshot.hasError) {
          return _ProfileErrorScaffold(
            title: 'No pudimos completar la vista',
            message:
                'El perfil base está disponible, pero falló la carga complementaria. Reintentá para ver portfolio y métricas.',
            onRetry: () {
              setState(() {
                _bundleFutures.remove(
                  '${profile.id}_${isOwnProfile ? 'own' : 'public'}',
                );
              });
            },
          );
        }

        final bundle =
            snapshot.data ?? const _ProfileBundle(portfolio: [], viewCount: 0);
        final facts = _ProfileFacts.fromUser(profile, bundle);
        return _ProfileShell(
          isOwnProfile: isOwnProfile,
          profile: profile,
          facts: facts,
          selectedPublicTab: _selectedPublicTab,
          onPublicTabChanged: (value) =>
              setState(() => _selectedPublicTab = value),
          onOpenEdit: () => _openEditProfile(context, profile),
          onOpenSettings: () => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => profile.accountType == 'headhunter'
                  ? const HeadhunterSettingsScreen()
                  : const SettingsScreen(),
            ),
          ),
          onOpenVideoPitch: () => _openVideoPitchFlow(context, profile),
          onOpenPitchCamera: () => _openPitchCamera(context, profile),
          onPickAvatar: () => _pickAndUploadAvatar(profile),
          onOpenTools: () => Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => const ToolsHubEntryScreen()),
          ),
          onOpenSaved: () => Navigator.of(
            context,
          ).push(CupertinoPageRoute(builder: (_) => const SavedJobsScreen())),
          onShare: () => ShareService.instance.shareProfile(
            name: profile.name,
            headline: profile.headline,
            userId: profile.id,
            accountType: profile.accountType,
          ),
          onContact: () => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => ChatInmailScreen(targetUser: profile),
            ),
          ),
          onInvite: () => _sendConnectionRequest(profile.id),
          connectionStatus: _connectionStatus,
          isLoadingConnection: _isLoadingConnection,
          isSavedProfile: _isSavedProfile,
          isSavingProfile: _isSavingProfile,
          onToggleSaved: () => _toggleSavedProfile(profile),
          onShowMore: () => _showMoreActions(context, profile, isOwnProfile),
          onOpenPortfolio: () async {
            await Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => _CandidatePortfolioScreen(
                  profile: profile,
                  isOwnProfile: isOwnProfile,
                ),
              ),
            );
            setState(() {
              _bundleFutures.remove(
                '${profile.id}_${isOwnProfile ? 'own' : 'public'}',
              );
            });
          },
          onOpenTimeline: () => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => _CandidateTimelineScreen(
                profile: profile,
                facts: facts,
                isOwnProfile: isOwnProfile,
              ),
            ),
          ),
          onOpenReferences: () => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => _CandidateReferencesScreen(
                profile: profile,
                facts: facts,
                isOwnProfile: isOwnProfile,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProtectedCandidateProfile extends StatelessWidget {
  final NexUser? profile;

  const _ProtectedCandidateProfile({this.profile});

  @override
  Widget build(BuildContext context) {
    final candidate = profile;

    return CupertinoPageScaffold(
      backgroundColor: NexTheme.shellBg,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Perfil confidencial'),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
          children: [
            Center(
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: context.brandAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.lock_shield_fill,
                  size: 42,
                  color: context.brandAccent,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              headhunterProtectedCandidateName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
            if (candidate?.headline.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                candidate!.headline,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: context.textSecondary),
              ),
            ],
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    CupertinoIcons.eye_slash_fill,
                    color: context.brandAccent,
                    size: 28,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Identidad protegida',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Este candidato eligió mantener privados su nombre, foto, ubicación, video y portfolio.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (candidate?.skills.isNotEmpty == true) ...[
              const SizedBox(height: 24),
              Text(
                'Habilidades declaradas',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: candidate!.skills
                    .take(6)
                    .map((skill) => MployaPill(label: skill))
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'No hay un desbloqueo disponible en esta pantalla. No mostramos datos reales sin una autorización existente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileShell extends StatelessWidget {
  final bool isOwnProfile;
  final NexUser profile;
  final _ProfileFacts facts;
  final int selectedPublicTab;
  final ValueChanged<int> onPublicTabChanged;
  final VoidCallback onOpenEdit;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenVideoPitch;
  final VoidCallback onOpenPitchCamera;
  final VoidCallback onPickAvatar;
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
  final VoidCallback onOpenTools;
  final VoidCallback onOpenSaved;

  const _ProfileShell({
    required this.isOwnProfile,
    required this.profile,
    required this.facts,
    required this.selectedPublicTab,
    required this.onPublicTabChanged,
    required this.onOpenEdit,
    required this.onOpenSettings,
    required this.onOpenVideoPitch,
    required this.onOpenPitchCamera,
    required this.onPickAvatar,
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
    required this.onOpenTools,
    required this.onOpenSaved,
  });

  /// Candidato (incluida su variante confidencial). Empresa y Headhunter
  /// conservan intacto el cuerpo anterior: esta tanda es sólo de Candidato.
  static const _tiposCandidato = {'candidato', 'confidencial', 'stealth'};

  @override
  Widget build(BuildContext context) {
    // Perfil PROPIO de candidato → composición aprobada de la Tanda 1.
    if (isOwnProfile &&
        _tiposCandidato.contains(profile.accountType.toLowerCase())) {
      return CupertinoPageScaffold(
        backgroundColor: MpTokens.lightBg,
        child: _CandidatoOwnProfileBody(
          profile: profile,
          facts: facts,
          onOpenEdit: onOpenEdit,
          onOpenSettings: onOpenSettings,
          onOpenVideoPitch: onOpenVideoPitch,
          onOpenPitchCamera: onOpenPitchCamera,
          onPickAvatar: onPickAvatar,
          onShare: onShare,
          onOpenPortfolio: onOpenPortfolio,
          onOpenTimeline: onOpenTimeline,
          onOpenReferences: onOpenReferences,
          onOpenTools: onOpenTools,
          onOpenSaved: onOpenSaved,
        ),
      );
    }

    final isCompanyProfile = profile.isCompanyAct;

    return CupertinoPageScaffold(
      backgroundColor: NexTheme.shellBg,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 760;
            final scrollPadding = EdgeInsets.fromLTRB(
              isMobile ? 16 : 24,
              8,
              isMobile ? 16 : 24,
              isMobile ? 116 : 40,
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: NexTheme.shellGradient),
                  ),
                ),
                SingleChildScrollView(
                  padding: scrollPadding,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1360),
                      child: isOwnProfile
                          ? _OwnProfileBody(
                              profile: profile,
                              facts: facts,
                              isMobile: isMobile,
                              onOpenEdit: onOpenEdit,
                              onOpenSettings: onOpenSettings,
                              onOpenVideoPitch: onOpenVideoPitch,
                              onOpenPitchCamera: onOpenPitchCamera,
                              onPickAvatar: onPickAvatar,
                              onShare: onShare,
                              onShowMore: onShowMore,
                              onOpenPortfolio: onOpenPortfolio,
                              onOpenTimeline: onOpenTimeline,
                              onOpenReferences: onOpenReferences,
                            )
                          : _PublicProfileBody(
                              profile: profile,
                              facts: facts,
                              isMobile: isMobile,
                              selectedTab: selectedPublicTab,
                              onTabChanged: onPublicTabChanged,
                              onShare: onShare,
                              onContact: onContact,
                              onInvite: onInvite,
                              connectionStatus: connectionStatus,
                              isLoadingConnection: isLoadingConnection,
                              isSavedProfile: isSavedProfile,
                              isSavingProfile: isSavingProfile,
                              onToggleSaved: onToggleSaved,
                              onShowMore: onShowMore,
                              onOpenPortfolio: onOpenPortfolio,
                              onOpenTimeline: onOpenTimeline,
                              onOpenReferences: onOpenReferences,
                            ),
                    ),
                  ),
                ),
                if (isMobile)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        border: Border(
                          top: BorderSide(color: context.shellBorder),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0F172A,
                            ).withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, -8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: isOwnProfile
                            ? [
                                Expanded(
                                  child: MployaSecondaryButton(
                                    label: 'Editar perfil',
                                    icon: CupertinoIcons.pencil,
                                    onPressed: onOpenEdit,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: MployaPrimaryButton(
                                    label: 'Video pitch',
                                    icon: CupertinoIcons.play_rectangle_fill,
                                    onPressed: onOpenVideoPitch,
                                  ),
                                ),
                              ]
                            : [
                                Expanded(
                                  child: MployaSecondaryButton(
                                    label: isSavedProfile
                                        ? 'Guardado'
                                        : 'Guardar',
                                    icon: isSavedProfile
                                        ? CupertinoIcons.bookmark_fill
                                        : CupertinoIcons.bookmark,
                                    onPressed: isSavingProfile
                                        ? null
                                        : onToggleSaved,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: MployaPrimaryButton(
                                    label: isCompanyProfile
                                        ? 'Contactar'
                                        : _connectionLabel(connectionStatus),
                                    icon: isCompanyProfile
                                        ? CupertinoIcons.chat_bubble_2_fill
                                        : CupertinoIcons.paperplane_fill,
                                    onPressed: isCompanyProfile
                                        ? onContact
                                        : (isLoadingConnection
                                              ? null
                                              : onInvite),
                                    compact: true,
                                  ),
                                ),
                              ],
                      ),
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

/// ─────────────────────────────────────────────────────────────────────────────
/// PERFIL PROPIO DE CANDIDATO — composición aprobada de la Tanda 1.
///
/// Referencia: `design-reference/Candidato_Tanda1_Final/*/05_perfil.png`.
/// Las piezas viven en `lib/widgets/candidato/cand_perfil.dart` y no saben nada
/// de Supabase: acá se les pasa lo que el perfil real ya trajo.
///
/// Todo lo que se pinta es dato real del usuario. Si algo falta, la pieza lo
/// dice o no se dibuja; nada se rellena con datos de ejemplo.
/// ─────────────────────────────────────────────────────────────────────────────
