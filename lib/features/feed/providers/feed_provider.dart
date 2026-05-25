/// Providers de Riverpod para el feed de videos y stories.
///
/// Gestiona la lista de videos tipo TikTok, acciones de feed
/// (like, save, apply) y las stories del usuario.
/// Conectado al backend real via [VideoService].
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mploya/core/models/video_model.dart';
import 'package:mploya/core/services/video_service.dart';

// ─── Mock Stories (efímeras, no se persisten) ──────────────────────

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

  final VideoService _videoService = VideoService.instance;
  int _currentOffset = 0;
  static const _pageSize = 20;

  /// Carga el feed de videos desde Supabase.
  ///
  /// Obtiene videos tipo pitch paginados con datos de perfil
  /// del creador resueltos via join.
  Future<void> loadFeed() async {
    state = const AsyncValue.loading();
    try {
      _currentOffset = 0;
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final videos = await _videoService.getFeedVideos(
        limit: _pageSize,
        offset: 0,
        currentUserId: currentUserId,
      );
      state = AsyncValue.data(videos);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Carga más videos (paginación infinita).
  Future<void> loadMore() async {
    final currentVideos = state.valueOrNull ?? [];
    try {
      final nextOffset = _currentOffset + _pageSize;
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final moreVideos = await _videoService.getFeedVideos(
        limit: _pageSize,
        offset: nextOffset,
        currentUserId: currentUserId,
      );
      if (moreVideos.isNotEmpty) {
        _currentOffset = nextOffset;
        state = AsyncValue.data([...currentVideos, ...moreVideos]);
      }
    } catch (e, st) {
      // No perder los videos actuales si falla la paginación.
      // Offset stays unchanged so the next retry fetches the same page.
      state = AsyncValue.data(currentVideos);
      debugPrint('Error cargando más videos: $e\n$st');
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
  final VideoService _videoService = VideoService.instance;

  /// Da o quita like a un video en Supabase.
  ///
  /// Actualiza el estado local de forma optimista y luego
  /// sincroniza con el backend.
  Future<void> likeVideo(String videoId) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    // Actualización optimista del UI
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

    // Sincronizar con el backend
    try {
      final video = videos.firstWhere((v) => v.id == videoId);
      if (video.isLiked) {
        await _videoService.unlikeVideo(videoId, currentUserId);
      } else {
        await _videoService.likeVideo(videoId, currentUserId);
      }
    } catch (e) {
      // Revertir si falla la operación en el backend
      ref.read(feedVideosProvider.notifier).state = AsyncValue.data(videos);
      debugPrint('Error sincronizando like: $e');
    }
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

    // TODO: Persist saved state to backend via VideoService
    // (e.g. _videoService.saveVideo / unsaveVideo).
    try {
      final video = videos.firstWhere((v) => v.id == videoId);
      if (video.isSaved) {
        // Was saved, now unsaving — call backend unsave when available.
        debugPrint('📌 Video $videoId unsaved (local only, persist pending).');
      } else {
        // Was not saved, now saving — call backend save when available.
        debugPrint('📌 Video $videoId saved (local only, persist pending).');
      }
    } catch (e) {
      // Revert on failure
      ref.read(feedVideosProvider.notifier).state = AsyncValue.data(videos);
      debugPrint('Error persisting save state for video $videoId: $e');
    }
  }

  Future<void> applyToVideo(String videoId) async {
    try {
      // Mark as applied locally (optimistic update)
      state = {...state, 'applied_$videoId': true};
      debugPrint('📋 Applied to video $videoId (local state updated).');

      // TODO: Persist application to backend via MatchService
      // await _matchService.applyToVideo(videoId, currentUserId);
    } catch (e) {
      // Revert on failure
      final reverted = Map<String, dynamic>.from(state);
      reverted.remove('applied_$videoId');
      state = reverted;
      debugPrint('Error applying to video $videoId: $e');
    }
  }

  /// Registra una vista para un video.
  Future<void> viewVideo(String videoId) async {
    try {
      await _videoService.incrementViewCount(videoId);
    } catch (e) {
      debugPrint('Error registering view for video $videoId: $e');
    }
  }
}

final feedActionsProvider =
    StateNotifierProvider<FeedActionsNotifier, Map<String, dynamic>>(
  (ref) => FeedActionsNotifier(ref),
);

// ─── Stories Provider ──────────────────────────────────────────────
// Las stories son efímeras y no se persisten en Supabase por ahora.
// Se mantienen como mock data.

class StoriesNotifier extends StateNotifier<AsyncValue<List<VideoModel>>> {
  StoriesNotifier() : super(const AsyncValue.loading()) {
    loadStories();
  }

  Future<void> loadStories() async {
    state = const AsyncValue.loading();
    try {
      // Load stories immediately from cached mock data (no artificial delay).
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

/// Path del video de historia publicada (null = sin historia).
final storyPublishedProvider = StateProvider<String?>((ref) => null);
