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

import '../models/models.dart';
import '../services/profile_view_service.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';
import '../services/my_profile_service.dart';
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
    } catch (_) {}
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
    } catch (_) {
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
    } catch (_) {
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
                                    label: _connectionLabel(connectionStatus),
                                    icon: CupertinoIcons.paperplane_fill,
                                    onPressed: isLoadingConnection
                                        ? null
                                        : onInvite,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(
          title: 'Perfil Público',
          subtitle: 'Vista premium para empresas y headhunters',
          shareLabel: 'Compartir',
          onShare: onShare,
          onMore: onShowMore,
        ),
        const SizedBox(height: 18),
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
        _PublicMetricsStrip(profile: profile, facts: facts),
        const SizedBox(height: 18),
        isMobile
            ? Column(
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
            : Row(
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

    final competencies = [
      _ReferenceCompetency(
        'Calidad de trabajo',
        profile.ratingStars > 0 ? profile.ratingStars : 4.5,
      ),
      _ReferenceCompetency(
        'Comunicación',
        profile.skills.length > 4 ? 4.6 : 4.2,
      ),
      _ReferenceCompetency(
        'Trabajo en equipo',
        profile.connections > 8 ? 4.7 : 4.1,
      ),
      _ReferenceCompetency('Iniciativa', profile.isPremium ? 4.8 : 4.3),
      _ReferenceCompetency('Adaptabilidad', profile.isOpenToWork ? 4.7 : 4.0),
      _ReferenceCompetency(
        'Responsabilidad',
        profile.profileViews > 0 ? 4.6 : 4.2,
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
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 1080;
                final summary = _ReferenceSummaryPanel(
                  competencies: competencies,
                );
                final side = _ReferenceSidebar(
                  profile: profile,
                  facts: facts,
                  isOwnProfile: isOwnProfile,
                );
                if (stacked) {
                  return Column(
                    children: [summary, const SizedBox(height: 16), side],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: summary),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: side),
                  ],
                );
              },
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
    final hasContextualScore = profile.matchPercentage > 0;

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
                                  : 'Perfil profesional',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.90),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          MployaPill(
                            label: profile.isOpenToWork
                                ? 'Abierta a oportunidades'
                                : 'Perfil activo',
                            color: profile.isOpenToWork
                                ? NexTheme.brandAccentDark
                                : NexTheme.brandMint,
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
                          if (profile.isOpenToWork)
                          _HeroMeta(
                            icon: CupertinoIcons.airplane,
                            label: facts.availabilityLine,
                          ),
                          if (facts.modalityLabel != 'Modalidad no informada')
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
                  onPressed: () {},
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

class _ReferenceSummaryPanel extends StatelessWidget {
  final List<_ReferenceCompetency> competencies;

  const _ReferenceSummaryPanel({required this.competencies});

  @override
  Widget build(BuildContext context) {
    return MployaShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evaluación por competencias',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FD),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: competencies.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ReferenceCompetencyRow(item: item),
                );
              }).toList(),
            ),
          ),
        ],
      ),
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

class _ReferenceCompetencyRow extends StatelessWidget {
  final _ReferenceCompetency item;

  const _ReferenceCompetencyRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            item.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
        ),
        SizedBox(
          width: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: item.score / 5,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7F7),
              valueColor: const AlwaysStoppedAnimation<Color>(
                NexTheme.brandAccent,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 36,
          child: Text(
            item.score.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
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

class _ReferenceCompetency {
  final String label;
  final double score;

  const _ReferenceCompetency(this.label, this.score);
}
