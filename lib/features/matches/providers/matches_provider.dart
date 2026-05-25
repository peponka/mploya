/// Providers de Riverpod para el sistema de matches/conexiones.
///
/// Gestiona matches agrupados por status, acciones de conexión,
/// y filtro activo. Conectado al backend real via [MatchService].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mploya/core/models/match_model.dart';
import 'package:mploya/core/services/match_service.dart';

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
    _init();
  }

  final MatchService _matchService = MatchService.instance;
  StreamSubscription<List<MatchModel>>? _streamSubscription;

  /// Inicializa la carga de matches y la suscripción en tiempo real.
  void _init() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    // Suscribirse al stream en tiempo real
    _streamSubscription = _matchService.matchesStream(userId).listen(
      (matches) {
        if (mounted) {
          state = AsyncValue.data(matches);
        }
      },
      onError: (Object e, StackTrace st) {
        debugPrint('Error en stream de matches: $e\n$st');
        if (mounted) {
          state = AsyncValue.error(e, st);
        }
      },
    );
  }

  /// Recarga los matches desde Supabase.
  Future<void> loadMatches() async {
    state = const AsyncValue.loading();
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }
      final matches = await _matchService.getMatches(userId);
      state = AsyncValue.data(matches);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async => loadMatches();

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}

final matchesProvider =
    StateNotifierProvider<MatchesNotifier, AsyncValue<List<MatchModel>>>(
  (ref) => MatchesNotifier(),
);

/// Matches filtrados por la tab activa.
final filteredMatchesProvider = Provider<List<MatchModel>>((ref) {
  final filter = ref.watch(matchFilterProvider);
  final matches = ref.watch(matchesProvider).valueOrNull ?? [];
  return matches
      .where((m) => m.status == filter.correspondingStatus)
      .toList();
});

/// Conteo de matches por status.
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
  final MatchService _matchService = MatchService.instance;

  /// Conectar con un match (cambia status a connected y crea conexión).
  Future<void> connectWith(String matchId) async {
    state = const AsyncValue.loading();
    try {
      await _matchService.connectWith(matchId);

      // Actualizar estado local de forma optimista
      _updateMatchStatus(matchId, MatchStatus.connected);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Aceptar un match pendiente (cambia status a active).
  Future<void> acceptMatch(String matchId) async {
    state = const AsyncValue.loading();
    try {
      await _matchService.acceptMatch(matchId);

      _updateMatchStatus(matchId, MatchStatus.active);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Rechazar un match (lo elimina de la lista local).
  Future<void> rejectMatch(String matchId) async {
    state = const AsyncValue.loading();
    try {
      await _matchService.rejectMatch(matchId);

      // Eliminar de la lista local
      final matches = ref.read(matchesProvider).valueOrNull ?? [];
      final updated = matches.where((m) => m.id != matchId).toList();
      ref.read(matchesProvider.notifier).state = AsyncValue.data(updated);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Helper para actualizar el status de un match localmente.
  void _updateMatchStatus(String matchId, MatchStatus newStatus) {
    final matches = ref.read(matchesProvider).valueOrNull ?? [];
    final updated = matches.map((m) {
      if (m.id == matchId) {
        return m.copyWith(status: newStatus);
      }
      return m;
    }).toList();
    ref.read(matchesProvider.notifier).state = AsyncValue.data(updated);
  }
}

final matchActionsProvider =
    StateNotifierProvider<MatchActionsNotifier, AsyncValue<void>>(
  (ref) => MatchActionsNotifier(ref),
);
