import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/feed_service.dart';
import '../services/social_algorithm_service.dart';
import '../providers/user_provider.dart';

class FeedState {
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final bool isInitialLoading;
  final bool hasMore;
  final String? error;

  FeedState({
    this.items = const [],
    this.isLoading = false,
    this.isInitialLoading = false,
    this.hasMore = true,
    this.error,
  });

  FeedState copyWith({
    List<Map<String, dynamic>>? items,
    bool? isLoading,
    bool? isInitialLoading,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return FeedState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// Migrated from StateNotifier (Riverpod 2.x) to Notifier (Riverpod 3.x)
class FeedNotifier extends Notifier<FeedState> {
  /// Tamaño de página — debe coincidir con el range() en FeedService.
  static const int _pageSize = 20;

  @override
  FeedState build() => FeedState();

  Future<void> loadInitial() async {
    if (state.items.isNotEmpty) return;
    await refreshFeed();
  }

  Future<void> refreshFeed() async {
    state = state.copyWith(isInitialLoading: true, error: null, clearError: true);
    FeedService.instance.invalidateCache();
    SocialAlgorithmService.instance.clearViewedSession();
    // Pre-load engagement data in parallel
    SocialAlgorithmService.instance.preloadEngagementHistory();
    
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        NexUser? currentUserData;
        try {
          currentUserData = ref.read(currentUserProvider).value;
          currentUserData ??= await ref.read(manualUserRefreshProvider.future);
        } catch (e) {
          debugPrint('⚠️ FeedProvider: no se pudo leer currentUser ($e)');
          currentUserData = null;
        }
        final myTags = currentUserData?.tags ?? <String>[];
        final myType = currentUserData?.accountType ?? 'candidato';
        final mySkills = currentUserData?.skills ?? <String>[];

        final rows = await FeedService.instance.getFeedUsers(
          offset: 0,
          forceRefresh: true,
          myAccountType: myType,
          myTags: myTags,
          mySkills: mySkills,
        );

        state = state.copyWith(
          items: rows,
          hasMore: rows.length >= _pageSize,
          isInitialLoading: false,
          clearError: true,
        );
        return;
      } catch (e) {
        debugPrint('⚠️ FeedNotifier.refreshFeed attempt ${attempt + 1}/3: $e');
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 1500 * (attempt + 1)));
        } else {
          state = state.copyWith(
            isInitialLoading: false,
            items: [],
            clearError: true,
          );
        }
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.isInitialLoading) return;
    
    state = state.copyWith(isLoading: true);
    try {
      var currentUserData = ref.read(currentUserProvider).value;
      currentUserData ??= await ref.read(manualUserRefreshProvider.future);
      final myTags = currentUserData?.tags ?? <String>[];
      final myType = currentUserData?.accountType ?? 'candidato';

      final newRows = await FeedService.instance.getFeedUsers(
        offset: state.items.length,
        myAccountType: myType,
        myTags: myTags,
      );

      // Deduplicar por ID antes de agregar
      final existingIds = state.items.map((r) => r['id']?.toString()).toSet();
      final uniqueNew = newRows.where((r) => !existingIds.contains(r['id']?.toString())).toList();

      state = state.copyWith(
        items: [...state.items, ...uniqueNew],
        hasMore: newRows.length >= _pageSize,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('❌ FeedNotifier.loadMore error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final feedProvider = NotifierProvider<FeedNotifier, FeedState>(FeedNotifier.new);
