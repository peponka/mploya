/// Providers de Riverpod para el perfil del usuario.
///
/// Gestiona datos del perfil, tabs activos, estadísticas,
/// items de portfolio, hashtags y porcentaje de completitud.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mploya/core/models/video_model.dart';
import 'package:mploya/core/models/hashtag_model.dart';

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

final profileStatsProvider = Provider<ProfileStats>((ref) {
  return const ProfileStats(
    conexiones: 24,
    vistas: 156,
    matches: 12,
  );
});

// ─── Portfolio Items Provider ──────────────────────────────────────

final List<VideoModel> _mockPortfolioItems = [
  VideoModel(
    id: 'p1',
    userId: 'current_user',
    url: 'https://example.com/portfolio1.mp4',
    thumbnailUrl: 'https://picsum.photos/300/300?random=10',
    duration: 28,
    type: VideoType.portfolio,
    title: 'Proyecto de Dashboard Financiero',
    description:
        'Dashboard interactivo con KPIs financieros en Power BI. Incluye modelos predictivos de flujo de caja.',
    score: 82,
    hashtags: ['powerbi', 'finanzas', 'dashboard'],
    viewCount: 340,
    likeCount: 28,
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
  VideoModel(
    id: 'p2',
    userId: 'current_user',
    url: 'https://example.com/portfolio2.mp4',
    thumbnailUrl: 'https://picsum.photos/300/300?random=11',
    duration: 30,
    type: VideoType.portfolio,
    title: 'Modelo de Valuación DCF',
    description:
        'Modelo de valuación de empresas con flujos descontados en Excel avanzado.',
    score: 90,
    hashtags: ['excel', 'valuación', 'dcf'],
    viewCount: 520,
    likeCount: 45,
    createdAt: DateTime.now().subtract(const Duration(days: 12)),
  ),
  VideoModel(
    id: 'p3',
    userId: 'current_user',
    url: 'https://example.com/portfolio3.mp4',
    thumbnailUrl: 'https://picsum.photos/300/300?random=12',
    duration: 25,
    type: VideoType.portfolio,
    title: 'Análisis de Mercado LATAM',
    description:
        'Estudio de mercado fintech en Latinoamérica con proyecciones 2024-2026.',
    score: 75,
    hashtags: ['fintech', 'latam', 'mercado'],
    viewCount: 210,
    likeCount: 18,
    createdAt: DateTime.now().subtract(const Duration(days: 20)),
  ),
];

class PortfolioItemsNotifier
    extends StateNotifier<AsyncValue<List<VideoModel>>> {
  PortfolioItemsNotifier() : super(const AsyncValue.loading()) {
    loadPortfolio();
  }

  Future<void> loadPortfolio() async {
    state = const AsyncValue.loading();
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      state = AsyncValue.data(List.from(_mockPortfolioItems));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addItem(VideoModel item) async {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([item, ...current]);
  }

  Future<void> removeItem(String itemId) async {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((v) => v.id != itemId).toList());
  }
}

final portfolioItemsProvider =
    StateNotifierProvider<PortfolioItemsNotifier, AsyncValue<List<VideoModel>>>(
  (ref) => PortfolioItemsNotifier(),
);

// ─── User Hashtags Provider ────────────────────────────────────────

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

final profileProgressProvider = Provider<ProfileProgress>((ref) {
  return const ProfileProgress(
    percentage: 65,
    completedItems: [
      'Foto de perfil',
      'Información básica',
      'Ubicación',
      'Habilidades',
      'Experiencia',
    ],
    pendingItems: [
      'Video pitch (60s)',
      'Portfolio (al menos 1 video)',
      'Skill Assessment',
      'Educación',
    ],
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

final currentProfileDataProvider = Provider<ProfileData>((ref) {
  return const ProfileData(
    name: 'Usuario Mploya',
    headline: 'Profesional en búsqueda activa',
    avatarUrl: 'https://i.pravatar.cc/150?img=32',
    bio:
        'Apasionado por las finanzas y la tecnología. Busco oportunidades en fintech donde pueda combinar mi experiencia en análisis financiero con mi interés por la innovación.',
    location: 'CDMX, México',
    isVerified: false,
    aiPersonalityAnalysis:
        'Perfil analítico con fuerte orientación a resultados. Demuestra liderazgo situacional y habilidades de comunicación efectiva. Potencial alto para roles de consultoría y análisis estratégico.',
  );
});
