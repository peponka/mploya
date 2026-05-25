/// Providers de Riverpod para el perfil del usuario.
///
/// Gestiona datos del perfil, tabs activos, estadísticas,
/// items de portfolio, hashtags y porcentaje de completitud.
/// Conectado al backend real via [VideoService] y [MatchService].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mploya/core/models/video_model.dart';
import 'package:mploya/core/models/hashtag_model.dart';
import 'package:mploya/core/services/video_service.dart';
import 'package:mploya/core/services/match_service.dart';
import 'package:mploya/features/auth/providers/auth_provider.dart';

// ─── Profile Tab ───────────────────────────────────────────────────

enum ProfileTab {
  sobreMi,
  portfolio,
  herramientas;

  String get displayName {
    switch (this) {
      case ProfileTab.sobreMi:
        return 'Sobre mí';
      case ProfileTab.portfolio:
        return 'Portfolio';
      case ProfileTab.herramientas:
        return 'Herramientas';
    }
  }
}

final profileTabProvider = StateProvider<ProfileTab>(
  (ref) => ProfileTab.sobreMi,
);

// ─── Profile Stats ─────────────────────────────────────────────────

class ProfileStats {
  const ProfileStats({
    this.conexiones = 0,
    this.vistas = 0,
    this.matches = 0,
  });

  final int conexiones;
  final int vistas;
  final int matches;
}

/// Estadísticas reales del perfil, consultadas desde Supabase.
///
/// Lee conexiones desde `connections`, vistas totales de videos
/// y cantidad de matches desde las tablas correspondientes.
final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final profile = ref.watch(currentProfileProvider);
  if (profile == null) {
    return const ProfileStats();
  }

  final userId = profile.id;
  final videoService = VideoService.instance;
  final matchService = MatchService.instance;

  // Consultas paralelas para mejor rendimiento
  final results = await Future.wait([
    matchService.getConnectionCount(userId),
    videoService.getTotalViewsByUser(userId),
    matchService.getMatchCount(userId),
  ]);

  return ProfileStats(
    conexiones: results[0],
    vistas: results[1],
    matches: results[2],
  );
});

// ─── Portfolio Items Provider ──────────────────────────────────────

class PortfolioItemsNotifier
    extends StateNotifier<AsyncValue<List<VideoModel>>> {
  PortfolioItemsNotifier(this._userId) : super(const AsyncValue.loading()) {
    loadPortfolio();
  }

  final String? _userId;
  final VideoService _videoService = VideoService.instance;

  /// Carga los videos de portfolio del usuario desde Supabase.
  Future<void> loadPortfolio() async {
    state = const AsyncValue.loading();
    try {
      if (_userId == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final videos = await _videoService.getVideosByUser(_userId);
      state = AsyncValue.data(videos);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Agrega un item al portfolio (actualización optimista).
  Future<void> addItem(VideoModel item) async {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([item, ...current]);
  }

  /// Elimina un item del portfolio.
  ///
  /// Elimina el video de Supabase y actualiza el estado local.
  Future<void> removeItem(String itemId) async {
    final current = state.valueOrNull ?? [];
    try {
      await _videoService.deleteVideo(itemId);
      state = AsyncValue.data(current.where((v) => v.id != itemId).toList());
    } catch (e) {
      // Mantener el estado actual si falla
      state = AsyncValue.data(current);
      rethrow;
    }
  }
}

final portfolioItemsProvider =
    StateNotifierProvider<PortfolioItemsNotifier, AsyncValue<List<VideoModel>>>(
  (ref) {
    final profile = ref.watch(currentProfileProvider);
    return PortfolioItemsNotifier(profile?.id);
  },
);

// ─── User Hashtags Provider ────────────────────────────────────────
// Se mantiene como mock por ahora — los hashtags se gestionarán
// cuando se implemente el sistema de hashtags completo.

final List<HashtagModel> _mockUserHashtags = [
  const HashtagModel(
    id: 'h1',
    name: 'finanzas',
    count: 7,
    relatedTags: ['contabilidad', 'excel', 'presupuestos'],
  ),
  const HashtagModel(
    id: 'h2',
    name: 'fintech',
    count: 6,
    relatedTags: ['cripto', 'blockchain', 'pagos'],
  ),
  const HashtagModel(
    id: 'h3',
    name: 'excel',
    count: 5,
    relatedTags: ['macros', 'vba', 'powerbi'],
  ),
  const HashtagModel(
    id: 'h4',
    name: 'analista',
    count: 4,
    relatedTags: ['datos', 'reportes', 'kpi'],
  ),
  const HashtagModel(
    id: 'h5',
    name: 'lider',
    count: 3,
    relatedTags: ['gestión', 'equipo', 'management'],
  ),
];

final userHashtagsProvider = Provider<List<HashtagModel>>((ref) {
  return _mockUserHashtags;
});

// ─── Profile Progress Provider ─────────────────────────────────────

class ProfileProgress {
  const ProfileProgress({
    this.percentage = 0,
    this.completedItems = const [],
    this.pendingItems = const [],
  });

  final int percentage;
  final List<String> completedItems;
  final List<String> pendingItems;
}

/// Calcula el porcentaje de completitud del perfil basado
/// en los datos reales del usuario desde auth provider.
final profileProgressProvider = Provider<ProfileProgress>((ref) {
  final profile = ref.watch(currentProfileProvider);
  if (profile == null) {
    return const ProfileProgress();
  }

  final completed = <String>[];
  final pending = <String>[];

  // Verificar cada campo del perfil
  if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
    completed.add('Foto de perfil');
  } else {
    pending.add('Foto de perfil');
  }

  if (profile.fullName != null && profile.fullName!.isNotEmpty) {
    completed.add('Información básica');
  } else {
    pending.add('Información básica');
  }

  if (profile.location != null && profile.location!.isNotEmpty) {
    completed.add('Ubicación');
  } else {
    pending.add('Ubicación');
  }

  if (profile.skills != null && profile.skills!.isNotEmpty) {
    completed.add('Habilidades');
  } else {
    pending.add('Habilidades');
  }

  if (profile.experience != null && profile.experience!.isNotEmpty) {
    completed.add('Experiencia');
  } else {
    pending.add('Experiencia');
  }

  if (profile.education != null && profile.education!.isNotEmpty) {
    completed.add('Educación');
  } else {
    pending.add('Educación');
  }

  if (profile.bio != null && profile.bio!.isNotEmpty) {
    completed.add('Biografía');
  } else {
    pending.add('Biografía');
  }

  // Items que requieren videos (siempre pendientes hasta verificar)
  pending.add('Video pitch (60s)');
  pending.add('Portfolio (al menos 1 video)');

  final total = completed.length + pending.length;
  final percentage = total > 0 ? ((completed.length / total) * 100).round() : 0;

  return ProfileProgress(
    percentage: percentage,
    completedItems: completed,
    pendingItems: pending,
  );
});

// ─── Current Profile Provider (extended) ───────────────────────────

/// Profile data holder with extended fields for the profile screen.
class ProfileData {
  const ProfileData({
    required this.name,
    required this.headline,
    this.avatarUrl,
    this.bio,
    this.location,
    this.isVerified = false,
    this.videoPitchUrl,
    this.aiPersonalityAnalysis,
  });

  final String name;
  final String headline;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final bool isVerified;
  final String? videoPitchUrl;
  final String? aiPersonalityAnalysis;
}

/// Datos extendidos del perfil leídos desde el auth provider.
///
/// Convierte el [UserProfile] del auth provider a [ProfileData]
/// para la pantalla de perfil.
final currentProfileDataProvider = Provider<ProfileData>((ref) {
  final profile = ref.watch(currentProfileProvider);

  if (profile == null) {
    return const ProfileData(
      name: 'Usuario Mploya',
      headline: 'Profesional en búsqueda activa',
    );
  }

  return ProfileData(
    name: profile.displayName,
    headline: profile.headline ?? 'Profesional en búsqueda activa',
    avatarUrl: profile.avatarUrl,
    bio: profile.bio,
    location: profile.location,
    isVerified: profile.isVerified,
  );
});
