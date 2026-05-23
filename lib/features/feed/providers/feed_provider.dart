/// Providers de Riverpod para el feed de videos y stories.
///
/// Gestiona la lista de videos tipo TikTok, acciones de feed
/// (like, save, apply) y las stories del usuario.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mploya/core/models/video_model.dart';

// ─── Mock Data ─────────────────────────────────────────────────────

final List<VideoModel> _mockFeedVideos = [
  VideoModel(
    id: 'v1',
    userId: 'u1',
    url: 'https://example.com/video1.mp4',
    thumbnailUrl: 'https://picsum.photos/400/700?random=1',
    duration: 45,
    type: VideoType.pitch,
    title: 'Mi pitch como Analista Financiero',
    description:
        '5 años de experiencia en análisis financiero, modelos DCF y valuación de empresas.',
    score: 85,
    hashtags: ['finanzas', 'analista', 'excel'],
    viewCount: 1240,
    likeCount: 89,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    userName: 'María García',
    userAvatarUrl: 'https://i.pravatar.cc/150?img=1',
    userHeadline: 'Analista Financiero Sr.',
    matchPercentage: 92,
  ),
  VideoModel(
    id: 'v2',
    userId: 'u2',
    url: 'https://example.com/video2.mp4',
    thumbnailUrl: 'https://picsum.photos/400/700?random=2',
    duration: 58,
    type: VideoType.pitch,
    title: 'Flutter Developer con pasión por UX',
    description:
        'Desarrollo apps móviles con Flutter y Dart. +20 apps publicadas.',
    score: 78,
    hashtags: ['flutter', 'mobile', 'dart'],
    viewCount: 2300,
    likeCount: 156,
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    userName: 'Carlos Mendoza',
    userAvatarUrl: 'https://i.pravatar.cc/150?img=3',
    userHeadline: 'Mobile Developer',
    matchPercentage: 87,
  ),
  VideoModel(
    id: 'v3',
    userId: 'u3',
    url: 'https://example.com/video3.mp4',
    thumbnailUrl: 'https://picsum.photos/400/700?random=3',
    duration: 40,
    type: VideoType.pitch,
    title: 'Product Manager con visión estratégica',
    description:
        'Lideré el lanzamiento de 3 productos fintech en LATAM. MBA + experiencia startup.',
    score: 91,
    hashtags: ['fintech', 'product', 'lider'],
    viewCount: 890,
    likeCount: 67,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    userName: 'Ana Rodríguez',
    userAvatarUrl: 'https://i.pravatar.cc/150?img=5',
    userHeadline: 'Product Manager',
    matchPercentage: 95,
  ),
  VideoModel(
    id: 'v4',
    userId: 'u4',
    url: 'https://example.com/video4.mp4',
    thumbnailUrl: 'https://picsum.photos/400/700?random=4',
    duration: 55,
    type: VideoType.pitch,
    title: 'Ingeniero de datos & IA',
    description:
        'Pipelines de datos, ML models en producción, Python/Spark/AWS.',
    score: 88,
    hashtags: ['ia', 'data', 'python'],
    viewCount: 3100,
    likeCount: 234,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    userName: 'Diego Fernández',
    userAvatarUrl: 'https://i.pravatar.cc/150?img=8',
    userHeadline: 'Data Engineer',
    matchPercentage: 81,
  ),
];

final List<VideoModel> _mockStories = [
  VideoModel(
    id: 's1',
    userId: 'u1',
    url: 'https://example.com/story1.mp4',
    thumbnailUrl: 'https://i.pravatar.cc/150?img=1',
    duration: 15,
    type: VideoType.story,
    title: 'Mi día como analista',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    userName: 'María G.',
  ),
  VideoModel(
    id: 's2',
    userId: 'u2',
    url: 'https://example.com/story2.mp4',
    thumbnailUrl: 'https://i.pravatar.cc/150?img=3',
    duration: 20,
    type: VideoType.story,
    title: 'Code review en vivo',
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    userName: 'Carlos M.',
  ),
  VideoModel(
    id: 's3',
    userId: 'u5',
    url: 'https://example.com/story3.mp4',
    thumbnailUrl: 'https://i.pravatar.cc/150?img=10',
    duration: 25,
    type: VideoType.story,
    title: 'Workshop de liderazgo',
    createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    userName: 'Laura P.',
  ),
  VideoModel(
    id: 's4',
    userId: 'u3',
    url: 'https://example.com/story4.mp4',
    thumbnailUrl: 'https://i.pravatar.cc/150?img=5',
    duration: 18,
    type: VideoType.story,
    title: 'Nuevo producto fintech',
    createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    userName: 'Ana R.',
  ),
];

// ─── Feed Videos Provider ──────────────────────────────────────────

class FeedVideosNotifier extends StateNotifier<AsyncValue<List<VideoModel>>> {
  FeedVideosNotifier() : super(const AsyncValue.loading()) {
    loadFeed();
  }

  Future<void> loadFeed() async {
    state = const AsyncValue.loading();
    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 800));
      state = AsyncValue.data(List.from(_mockFeedVideos));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async => loadFeed();
}

final feedVideosProvider =
    StateNotifierProvider<FeedVideosNotifier, AsyncValue<List<VideoModel>>>(
  (ref) => FeedVideosNotifier(),
);

// ─── Feed Actions Provider ─────────────────────────────────────────

class FeedActionsNotifier extends StateNotifier<Map<String, dynamic>> {
  FeedActionsNotifier(this.ref) : super({});

  final Ref ref;

  Future<void> likeVideo(String videoId) async {
    final videos = ref.read(feedVideosProvider).valueOrNull ?? [];
    final updated = videos.map((v) {
      if (v.id == videoId) {
        return v.copyWith(
          isLiked: !v.isLiked,
          likeCount: v.isLiked ? v.likeCount - 1 : v.likeCount + 1,
        );
      }
      return v;
    }).toList();
    ref.read(feedVideosProvider.notifier).state = AsyncValue.data(updated);
  }

  Future<void> saveVideo(String videoId) async {
    final videos = ref.read(feedVideosProvider).valueOrNull ?? [];
    final updated = videos.map((v) {
      if (v.id == videoId) {
        return v.copyWith(isSaved: !v.isSaved);
      }
      return v;
    }).toList();
    ref.read(feedVideosProvider.notifier).state = AsyncValue.data(updated);
  }

  Future<void> applyToVideo(String videoId) async {
    // In production, this would create a match request
    state = {...state, 'applied_$videoId': true};
  }
}

final feedActionsProvider =
    StateNotifierProvider<FeedActionsNotifier, Map<String, dynamic>>(
  (ref) => FeedActionsNotifier(ref),
);

// ─── Stories Provider ──────────────────────────────────────────────

class StoriesNotifier extends StateNotifier<AsyncValue<List<VideoModel>>> {
  StoriesNotifier() : super(const AsyncValue.loading()) {
    loadStories();
  }

  Future<void> loadStories() async {
    state = const AsyncValue.loading();
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      state = AsyncValue.data(List.from(_mockStories));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final storiesProvider =
    StateNotifierProvider<StoriesNotifier, AsyncValue<List<VideoModel>>>(
  (ref) => StoriesNotifier(),
);

// ─── Current Feed Index ────────────────────────────────────────────

final currentFeedIndexProvider = StateProvider<int>((ref) => 0);

// ─── Video Published State ─────────────────────────────────────────

/// URL del blob del video publicado (null si no publicó).
final videoPublishedProvider = StateProvider<String?>((ref) => null);

// ─── User Profile from Confidential Form ───────────────────────────

/// Hashtags/keywords del formulario confidencial.
final userHashtagsProvider = StateProvider<List<String>>((ref) => []);

/// Titular blind del formulario confidencial (ej: 'VP Engineering').
final userStealthTitleProvider = StateProvider<String>((ref) => '');

/// Seudónimo del formulario confidencial.
final userStealthNameProvider = StateProvider<String>((ref) => '');

/// Empresa referencia del formulario confidencial.
final userCompanyProvider = StateProvider<String>((ref) => '');
