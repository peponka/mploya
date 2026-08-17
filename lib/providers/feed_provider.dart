import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../providers/user_provider.dart';
import '../services/feed_service.dart';
import '../services/my_profile_service.dart';
import '../services/social_algorithm_service.dart';

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

class FeedNotifier extends Notifier<FeedState> {
  static const int _pageSize = 20;
  static const Duration _userResolveTimeout = Duration(seconds: 8);
  static const Duration _feedLoadTimeout = Duration(seconds: 18);

  @override
  FeedState build() => FeedState();

  Future<void> loadInitial() async {
    if (state.items.isNotEmpty) return;
    await refreshFeed();
  }

  Future<String> _resolveMyAccountType(NexUser? user) async {
    final type = user?.accountType;
    if (type != null && type.isNotEmpty) return type;
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final row = await loadMyProfile().timeout(const Duration(seconds: 8));
        final dbType = row?['account_type']?.toString();
        if (dbType != null && dbType.isNotEmpty) return dbType;
      }
    } catch (e) {
      debugPrint(
        'FeedProvider: no se pudo resolver account_type desde DB: $e',
      );
    }
    return 'candidato';
  }

  Future<NexUser?> _resolveCurrentUser() async {
    try {
      final streamed = ref.read(currentUserProvider).value;
      if (streamed != null) return streamed;
      return await ref
          .read(manualUserRefreshProvider.future)
          .timeout(_userResolveTimeout);
    } catch (e) {
      debugPrint('FeedProvider: no se pudo leer currentUser ($e)');
      return null;
    }
  }

  Future<void> refreshFeed() async {
    state = state.copyWith(
      isInitialLoading: true,
      error: null,
      clearError: true,
    );
    FeedService.instance.invalidateCache();
    SocialAlgorithmService.instance.clearViewedSession();
    SocialAlgorithmService.instance.preloadEngagementHistory();

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final currentUserData = await _resolveCurrentUser();
        final myTags = currentUserData?.tags ?? <String>[];
        final mySkills = currentUserData?.skills ?? <String>[];
        final myType = await _resolveMyAccountType(currentUserData);

        final rows = await FeedService.instance
            .getFeedUsers(
              offset: 0,
              forceRefresh: true,
              myAccountType: myType,
              myTags: myTags,
              mySkills: mySkills,
            )
            .timeout(_feedLoadTimeout);

        state = state.copyWith(
          items: rows,
          hasMore: rows.length >= _pageSize,
          isInitialLoading: false,
          clearError: true,
        );
        return;
      } catch (e) {
        debugPrint('FeedNotifier.refreshFeed attempt ${attempt + 1}/3: $e');
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 1500 * (attempt + 1)));
        } else {
          state = state.copyWith(
            isInitialLoading: false,
            items: [],
            error: 'No pudimos cargar el feed en este momento. Reintenta.',
          );
        }
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.isInitialLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final currentUserData = await _resolveCurrentUser();
      final myTags = currentUserData?.tags ?? <String>[];
      final myType = await _resolveMyAccountType(currentUserData);

      final newRows = await FeedService.instance
          .getFeedUsers(
            offset: state.items.length,
            myAccountType: myType,
            myTags: myTags,
          )
          .timeout(_feedLoadTimeout);

      final existingIds = state.items.map((r) => r['id']?.toString()).toSet();
      final uniqueNew = newRows
          .where((r) => !existingIds.contains(r['id']?.toString()))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...uniqueNew],
        hasMore: newRows.length >= _pageSize,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('FeedNotifier.loadMore error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'No pudimos cargar mas contenido.',
      );
    }
  }
}

final feedProvider = NotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);
