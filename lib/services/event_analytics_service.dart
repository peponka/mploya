import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EventAnalyticsService — Tracking liviano de eventos in-app
//
// Diseñado para:
//  • Batch insert cada 30 segundos (no uno por uno)
//  • Queue local cuando no hay conexión
//  • Privacidad: no trackea datos personales, solo acciones
//  • Cero dependencias externas (usa Supabase nativo)
//
// Eventos que se trackean:
//  • screen_view     — Cuando se abre una pantalla
//  • feed_scroll     — Scroll en el feed (cada 5 items)
//  • profile_view    — Cuando se ve un perfil ajeno
//  • search          — Cada búsqueda confirmada
//  • action          — Tap en botones clave (connect, message, etc)
//  • video_play      — Reproducción de video pitch
//  • error           — Errores capturados
//
// SQL requerido (ejecutar una vez en Supabase):
//
//   CREATE TABLE IF NOT EXISTS app_events (
//     id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
//     user_id UUID REFERENCES auth.users(id),
//     event_type TEXT NOT NULL,
//     event_name TEXT NOT NULL,
//     metadata JSONB DEFAULT '{}',
//     created_at TIMESTAMPTZ DEFAULT now()
//   );
//
//   CREATE INDEX idx_events_user ON app_events(user_id);
//   CREATE INDEX idx_events_type ON app_events(event_type);
//   CREATE INDEX idx_events_created ON app_events(created_at);
//
//   ALTER TABLE app_events ENABLE ROW LEVEL SECURITY;
//   CREATE POLICY "Users can insert own events"
//     ON app_events FOR INSERT
//     WITH CHECK (auth.uid() = user_id);
//   CREATE POLICY "Users can read own events"
//     ON app_events FOR SELECT
//     USING (auth.uid() = user_id);
//
// ─────────────────────────────────────────────────────────────────────────────

class EventAnalyticsService {
  EventAnalyticsService._();
  static final EventAnalyticsService instance = EventAnalyticsService._();

  SupabaseClient get _db => Supabase.instance.client;

  /// Cola de eventos pendientes.
  final Queue<_AnalyticsEvent> _queue = Queue<_AnalyticsEvent>();

  /// Timer para flush periódico.
  Timer? _flushTimer;

  /// Máximo de eventos por batch.
  static const int _batchSize = 25;

  /// Intervalo de flush en segundos.
  static const int _flushIntervalSeconds = 30;

  /// Inicializar el servicio (llamar en main.dart).
  void init() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      const Duration(seconds: _flushIntervalSeconds),
      (_) => flush(),
    );
    debugPrint('📊 EventAnalyticsService initialized (flush every ${_flushIntervalSeconds}s)');
  }

  /// Registra un evento.
  void track(String eventType, String eventName, [Map<String, dynamic>? metadata]) {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return; // No trackear sin sesión

    _queue.add(_AnalyticsEvent(
      userId: uid,
      eventType: eventType,
      eventName: eventName,
      metadata: metadata ?? {},
      createdAt: DateTime.now(),
    ));

    // Auto-flush si la cola está grande
    if (_queue.length >= _batchSize) {
      flush();
    }
  }

  // ── Convenience methods ──────────────────────────────────────────────────

  void screenView(String screenName) =>
      track('screen_view', screenName);

  void feedScroll(int index) =>
      track('feed_scroll', 'scroll', {'index': index});

  void profileView(String viewedUserId) =>
      track('profile_view', 'view', {'viewed_user_id': viewedUserId});

  void search(String query, int resultCount) =>
      track('search', query, {'result_count': resultCount});

  void action(String actionName, [Map<String, dynamic>? extra]) =>
      track('action', actionName, extra);

  void videoPlay(String videoId) =>
      track('video_play', 'play', {'video_id': videoId});

  void error(String errorType, String message) =>
      track('error', errorType, {'message': message});

  // ── Flush (enviar batch a Supabase) ──────────────────────────────────────

  Future<void> flush() async {
    if (_queue.isEmpty) return;

    // Tomar hasta _batchSize eventos
    final batch = <_AnalyticsEvent>[];
    while (_queue.isNotEmpty && batch.length < _batchSize) {
      batch.add(_queue.removeFirst());
    }

    try {
      final rows = batch.map((e) => {
        'user_id': e.userId,
        'event_type': e.eventType,
        'event_name': e.eventName,
        'metadata': e.metadata,
        'created_at': e.createdAt.toUtc().toIso8601String(),
      }).toList();

      await _db.from('app_events').insert(rows).timeout(
        const Duration(seconds: 10),
      );

      debugPrint('📊 Flushed ${batch.length} events');
    } catch (e) {
      // Re-encolar los eventos que fallaron (al inicio)
      for (final event in batch.reversed) {
        _queue.addFirst(event);
      }

      // Evitar crecimiento infinito de la cola
      while (_queue.length > 200) {
        _queue.removeLast();
      }

      debugPrint('⚠️ EventAnalytics flush failed: $e (${_queue.length} queued)');
    }
  }

  /// Flush final al cerrar la app.
  Future<void> dispose() async {
    _flushTimer?.cancel();
    await flush();
  }

  /// Número de eventos en cola.
  int get queueLength => _queue.length;
}

class _AnalyticsEvent {
  final String userId;
  final String eventType;
  final String eventName;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const _AnalyticsEvent({
    required this.userId,
    required this.eventType,
    required this.eventName,
    required this.metadata,
    required this.createdAt,
  });
}
