/// Providers de Riverpod para el sistema de matches/conexiones.
///
/// Gestiona matches agrupados por status, acciones de conexión,
/// y filtro activo.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mploya/core/models/match_model.dart';

// ─── Mock Data ─────────────────────────────────────────────────────

final List<MatchModel> _mockMatches = [
  MatchModel(
    id: 'm1',
    userId: 'current_user',
    targetUserId: 'u1',
    status: MatchStatus.active,
    type: MatchType.candidate,
    matchPercentage: 92,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    targetUserName: 'María García',
    targetUserAvatarUrl: 'https://i.pravatar.cc/150?img=1',
    targetUserHeadline: 'Analista Financiero Sr.',
    targetUserLocation: 'CDMX, México',
    targetUserIsVerified: true,
    targetUserHashtags: ['finanzas', 'excel', 'analista'],
  ),
  MatchModel(
    id: 'm2',
    userId: 'current_user',
    targetUserId: 'u2',
    status: MatchStatus.active,
    type: MatchType.candidate,
    matchPercentage: 87,
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    targetUserName: 'Carlos Mendoza',
    targetUserAvatarUrl: 'https://i.pravatar.cc/150?img=3',
    targetUserHeadline: 'Mobile Developer',
    targetUserLocation: 'Guadalajara, México',
    targetUserIsVerified: true,
    targetUserHashtags: ['flutter', 'mobile', 'dart'],
  ),
  MatchModel(
    id: 'm3',
    userId: 'current_user',
    targetUserId: 'u3',
    status: MatchStatus.connected,
    type: MatchType.company,
    matchPercentage: 95,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    targetUserName: 'Ana Rodríguez',
    targetUserAvatarUrl: 'https://i.pravatar.cc/150?img=5',
    targetUserHeadline: 'Product Manager',
    targetUserLocation: 'Monterrey, México',
    targetUserIsVerified: true,
    targetUserHashtags: ['fintech', 'product', 'lider'],
  ),
  MatchModel(
    id: 'm4',
    userId: 'current_user',
    targetUserId: 'u4',
    status: MatchStatus.connected,
    type: MatchType.candidate,
    matchPercentage: 81,
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    targetUserName: 'Diego Fernández',
    targetUserAvatarUrl: 'https://i.pravatar.cc/150?img=8',
    targetUserHeadline: 'Data Engineer',
    targetUserLocation: 'Buenos Aires, Argentina',
    targetUserIsVerified: false,
    targetUserHashtags: ['ia', 'data', 'python'],
  ),
  MatchModel(
    id: 'm5',
    userId: 'current_user',
    targetUserId: 'u5',
    status: MatchStatus.pending,
    type: MatchType.candidate,
    matchPercentage: 78,
    createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    targetUserName: 'Laura Pérez',
    targetUserAvatarUrl: 'https://i.pravatar.cc/150?img=10',
    targetUserHeadline: 'UX Designer',
    targetUserLocation: 'Bogotá, Colombia',
    targetUserIsVerified: false,
    targetUserHashtags: ['ux', 'diseño', 'figma'],
  ),
  MatchModel(
    id: 'm6',
    userId: 'current_user',
    targetUserId: 'u6',
    status: MatchStatus.pending,
    type: MatchType.company,
    matchPercentage: 74,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    targetUserName: 'TechStartup MX',
    targetUserAvatarUrl: 'https://i.pravatar.cc/150?img=12',
    targetUserHeadline: 'Startup de FinTech',
    targetUserLocation: 'CDMX, México',
    targetUserIsVerified: true,
    targetUserHashtags: ['fintech', 'startup', 'cripto'],
  ),
];

// ─── Match Filter ──────────────────────────────────────────────────

enum MatchFilter {
  activos,
  conectados,
  pendientes;

  String get displayName {
    switch (this) {
      case MatchFilter.activos:
        return 'Activos';
      case MatchFilter.conectados:
        return 'Conectados';
      case MatchFilter.pendientes:
        return 'Pendientes';
    }
  }

  MatchStatus get correspondingStatus {
    switch (this) {
      case MatchFilter.activos:
        return MatchStatus.active;
      case MatchFilter.conectados:
        return MatchStatus.connected;
      case MatchFilter.pendientes:
        return MatchStatus.pending;
    }
  }
}

final matchFilterProvider = StateProvider<MatchFilter>(
  (ref) => MatchFilter.activos,
);

// ─── Matches Provider ──────────────────────────────────────────────

class MatchesNotifier extends StateNotifier<AsyncValue<List<MatchModel>>> {
  MatchesNotifier() : super(const AsyncValue.loading()) {
    loadMatches();
  }

  Future<void> loadMatches() async {
    state = const AsyncValue.loading();
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      state = AsyncValue.data(List.from(_mockMatches));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async => loadMatches();
}

final matchesProvider =
    StateNotifierProvider<MatchesNotifier, AsyncValue<List<MatchModel>>>(
  (ref) => MatchesNotifier(),
);

/// Filtered matches by current filter tab
final filteredMatchesProvider = Provider<List<MatchModel>>((ref) {
  final filter = ref.watch(matchFilterProvider);
  final matches = ref.watch(matchesProvider).valueOrNull ?? [];
  return matches
      .where((m) => m.status == filter.correspondingStatus)
      .toList();
});

/// Match counts per status
final matchCountsProvider = Provider<Map<MatchFilter, int>>((ref) {
  final matches = ref.watch(matchesProvider).valueOrNull ?? [];
  return {
    MatchFilter.activos:
        matches.where((m) => m.status == MatchStatus.active).length,
    MatchFilter.conectados:
        matches.where((m) => m.status == MatchStatus.connected).length,
    MatchFilter.pendientes:
        matches.where((m) => m.status == MatchStatus.pending).length,
  };
});

// ─── Match Actions Provider ────────────────────────────────────────

class MatchActionsNotifier extends StateNotifier<AsyncValue<void>> {
  MatchActionsNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> connectWith(String matchId) async {
    state = const AsyncValue.loading();
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final matches = ref.read(matchesProvider).valueOrNull ?? [];
      final updated = matches.map((m) {
        if (m.id == matchId) {
          return m.copyWith(status: MatchStatus.connected);
        }
        return m;
      }).toList();
      ref.read(matchesProvider.notifier).state = AsyncValue.data(updated);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> acceptMatch(String matchId) async {
    state = const AsyncValue.loading();
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final matches = ref.read(matchesProvider).valueOrNull ?? [];
      final updated = matches.map((m) {
        if (m.id == matchId) {
          return m.copyWith(status: MatchStatus.active);
        }
        return m;
      }).toList();
      ref.read(matchesProvider.notifier).state = AsyncValue.data(updated);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> rejectMatch(String matchId) async {
    state = const AsyncValue.loading();
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final matches = ref.read(matchesProvider).valueOrNull ?? [];
      final updated =
          matches.where((m) => m.id != matchId).toList();
      ref.read(matchesProvider.notifier).state = AsyncValue.data(updated);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final matchActionsProvider =
    StateNotifierProvider<MatchActionsNotifier, AsyncValue<void>>(
  (ref) => MatchActionsNotifier(ref),
);
