import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Manager singleton que pre-inicializa VideoPlayerControllers
/// para los próximos videos del feed, eliminando el spinner al hacer swipe.
///
/// Estrategia: mantiene hasta [_maxCache] controllers inicializados.
/// Cuando el usuario está en el card N, pre-carga N+1 y N+2.
/// Los controllers más de [_maxCache] posiciones atrás se disponen.
class VideoPreloadManager {
  VideoPreloadManager._();
  static final instance = VideoPreloadManager._();

  /// Máximo de controllers en caché simultáneos (actual + ahead + 1 atrás)
  static const _maxCache = 6;

  /// Cuántos videos pre-cargar adelante.
  /// Valor por defecto: 2 (WiFi). Reducir a 1 en datos móviles para ahorrar ancho de banda.
  int _preloadAhead = 2;

  /// Ajustar la agresividad de pre-carga según el tipo de conexión.
  /// Llamar desde el feed cuando se detecte WiFi/cellular.
  void setPreloadAhead(int count) {
    _preloadAhead = count.clamp(1, 3);
  }

  /// Pool de controllers indexados por URL
  final Map<String, _CachedController> _cache = {};

  /// Orden de URLs para saber cuáles descartar (LRU)
  final List<String> _accessOrder = [];

  /// Índice actual del feed (se actualiza desde el PageView)
  int _currentIndex = 0;

  /// Lista de URLs del feed actual (se actualiza cuando cambian los rows)
  List<String> _feedUrls = [];

  /// Actualiza la lista de URLs del feed. Llamar cuando _allRows cambie.
  void updateFeedUrls(List<String> urls) {
    _feedUrls = urls;
    _preloadAround(_currentIndex);
  }

  /// Notifica que el usuario cambió a este índice.
  /// Pre-carga los próximos videos y libera los lejanos.
  void onPageChanged(int index) {
    _currentIndex = index;
    _preloadAround(index);
  }

  /// Obtiene un controller ya inicializado (o null si no está listo).
  /// Si no existe, lo crea y devuelve null (el card mostrará spinner
  /// mientras se inicializa, pero esto solo pasa en el primer card).
  VideoPlayerController? getController(String url) {
    final cached = _cache[url];
    if (cached != null && cached.isReady) {
      _touchUrl(url);
      return cached.controller;
    }
    // Si no está en caché, iniciarlo
    if (cached == null) {
      _startPreload(url);
    }
    return null;
  }

  /// Verifica si un controller está listo para reproducir.
  bool isReady(String url) {
    return _cache[url]?.isReady ?? false;
  }

  /// Registra un callback para cuando el controller esté listo.
  void onReady(String url, VoidCallback callback) {
    final cached = _cache[url];
    if (cached != null) {
      if (cached.isReady) {
        callback();
      } else {
        cached.onReadyCallbacks.add(callback);
      }
    } else {
      // Crear y esperar
      _startPreload(url, onReady: callback);
    }
  }

  /// Detiene todos los videos (ej: cuando se cambia de tab).
  void pauseAll() {
    for (final c in _cache.values) {
      if (c.isReady && c.controller.value.isPlaying) {
        c.controller.pause();
      }
    }
  }

  /// Reanuda el video del índice actual del feed.
  void resumeCurrent() {
    if (_currentIndex < _feedUrls.length) {
      final url = _feedUrls[_currentIndex];
      final cached = _cache[url];
      if (cached != null && cached.isReady && !cached.controller.value.isPlaying) {
        cached.controller.play();
      }
    }
  }

  /// Libera todos los controllers. Llamar en dispose del feed.
  void disposeAll() {
    for (final c in _cache.values) {
      if (c.isReady) c.controller.pause();
      c.controller.dispose();
    }
    _cache.clear();
    _accessOrder.clear();
    _feedUrls.clear();
  }

  // ── Internals ──────────────────────────────────────────────────────────

  void _preloadAround(int index) {
    // Pre-cargar: actual + _preloadAhead videos adelante
    final toPreload = <String>[];
    for (int i = index; i <= index + _preloadAhead && i < _feedUrls.length; i++) {
      final url = _feedUrls[i];
      if (url.isNotEmpty) toPreload.add(url);
    }

    for (final url in toPreload) {
      if (!_cache.containsKey(url)) {
        _startPreload(url);
      }
    }

    // Limpiar controllers lejanos
    _evictOldEntries(toPreload);
  }

  void _startPreload(String url, {VoidCallback? onReady}) {
    if (_cache.containsKey(url)) {
      if (onReady != null) _cache[url]!.onReadyCallbacks.add(onReady);
      return;
    }

    final VideoPlayerController controller;
    if (url.startsWith('asset:')) {
      controller = VideoPlayerController.asset(url.replaceAll('asset:', ''));
    } else {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
    }

    final cached = _CachedController(controller);
    if (onReady != null) cached.onReadyCallbacks.add(onReady);
    _cache[url] = cached;
    _touchUrl(url);

    controller.initialize().then((_) {
      if (!_cache.containsKey(url)) return; // evicteado mientras inicializaba
      controller.setLooping(true);
      cached.isReady = true;
      for (final cb in cached.onReadyCallbacks) {
        cb();
      }
      cached.onReadyCallbacks.clear();
    }).catchError((e) {
      debugPrint('⚠️ Preload error for $url: $e');
      cached.hasError = true;
    });
  }

  void _touchUrl(String url) {
    _accessOrder.remove(url);
    _accessOrder.add(url);
  }

  void _evictOldEntries(List<String> keepUrls) {
    while (_cache.length > _maxCache) {
      // Encontrar el más antiguo que no esté en keepUrls
      String? toRemove;
      for (final url in _accessOrder) {
        if (!keepUrls.contains(url)) {
          toRemove = url;
          break;
        }
      }
      if (toRemove == null) break; // Todos son necesarios

      final removed = _cache.remove(toRemove);
      _accessOrder.remove(toRemove);
      if (removed != null && removed.isReady) {
        removed.controller.pause();
      }
      removed?.controller.dispose();
    }
  }
}

class _CachedController {
  final VideoPlayerController controller;
  bool isReady = false;
  bool hasError = false;
  final List<VoidCallback> onReadyCallbacks = [];

  _CachedController(this.controller);
}
