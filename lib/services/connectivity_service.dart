import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ConnectivityService — Detección de conectividad + Cola offline
//
// Provee:
//  • isOnline           — Estado actual de conectividad
//  • onlineStream       — Stream reactivo de cambios
//  • checkConnectivity  — Verificación puntual (DNS lookup)
//  • enqueue()          — Encola acción para ejecutar cuando haya red
//  • OfflineBanner      — Widget para mostrar barra de "Sin conexión"
//
// Arquitectura:
//  • Timer periódico (15s) hace DNS lookup a Supabase
//  • Cuando vuelve la conexión, procesa la cola de acciones pendientes
//  • No depende de connectivity_plus (requiere permisos extra en iOS)
// ─────────────────────────────────────────────────────────────────────────────

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _timer;
  final _controller = StreamController<bool>.broadcast();

  /// Stream reactivo de cambios de conectividad.
  Stream<bool> get onlineStream => _controller.stream;

  /// Cola de acciones pendientes para cuando vuelva la conexión.
  final List<Future<void> Function()> _offlineQueue = [];

  /// Inicia el monitoreo periódico de conectividad.
  void initialize() {
    // Check inicial
    checkConnectivity();
    // Timer periódico
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkConnectivity();
    });
  }

  /// Verificación puntual de conectividad vía DNS lookup.
  Future<bool> checkConnectivity() async {
    if (kIsWeb) {
      _updateStatus(true); // En web, el browser maneja esto
      return true;
    }

    try {
      final result = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 5));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _updateStatus(online);
      return online;
    } on SocketException catch (_) {
      _updateStatus(false);
      return false;
    } on TimeoutException catch (_) {
      _updateStatus(false);
      return false;
    } catch (_) {
      _updateStatus(false);
      return false;
    }
  }

  void _updateStatus(bool online) {
    if (online != _isOnline) {
      _isOnline = online;
      _controller.add(online);
      debugPrint(online ? '🟢 Online' : '🔴 Offline');

      // Procesar cola cuando vuelve la conexión
      if (online && _offlineQueue.isNotEmpty) {
        _processQueue();
      }
    }
  }

  /// Encola una acción para ejecutar cuando haya conexión.
  /// Si ya hay conexión, la ejecuta inmediatamente.
  void enqueue(Future<void> Function() action) {
    if (_isOnline) {
      action().catchError((e) => debugPrint('⚠️ Queued action error: $e'));
    } else {
      _offlineQueue.add(action);
      debugPrint('📦 Acción encolada (${_offlineQueue.length} pendientes)');
    }
  }

  Future<void> _processQueue() async {
    debugPrint('📤 Procesando ${_offlineQueue.length} acciones pendientes...');
    final actions = List<Future<void> Function()>.from(_offlineQueue);
    _offlineQueue.clear();

    for (final action in actions) {
      try {
        await action();
      } catch (e) {
        debugPrint('⚠️ Error procesando acción offline: $e');
        // Re-encolar si falla por red
        if (!_isOnline) {
          _offlineQueue.add(action);
          break;
        }
      }
    }
  }

  /// Liberar recursos.
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OfflineBanner — Widget que muestra una barra cuando no hay conexión
// ─────────────────────────────────────────────────────────────────────────────

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService.instance.onlineStream,
      initialData: ConnectivityService.instance.isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        return AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          offset: isOnline ? const Offset(0, -1) : Offset.zero,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isOnline ? 0 : 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: const Color(0xFFFF3B30),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.wifi_slash, size: 14, color: CupertinoColors.white),
                  SizedBox(width: 6),
                  Text(
                    'Sin conexión a internet',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: '.SF Pro Text',
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
