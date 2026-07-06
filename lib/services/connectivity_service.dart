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

  // Cuántos chequeos seguidos deben fallar antes de declarar "sin conexión".
  // Con 1 daba falsos positivos: un hipo puntual de DNS en 4G (o que un host
  // esté lento/bloqueado por la operadora) mostraba la barra roja con internet
  // funcionando. Exigimos 2 fallas seguidas.
  int _consecutiveFailures = 0;
  static const int _failuresToGoOffline = 2;

  /// Verificación puntual de conectividad vía DNS lookup a varios hosts.
  Future<bool> checkConnectivity() async {
    if (kIsWeb) {
      _updateStatus(true); // En web, el browser maneja esto
      return true;
    }

    final online = await _probe();
    if (online) {
      _consecutiveFailures = 0;
      _updateStatus(true);
    } else {
      _consecutiveFailures++;
      if (_consecutiveFailures >= _failuresToGoOffline) {
        _updateStatus(false);
      }
    }
    return online;
  }

  // Estamos online si CUALQUIERA de estos hosts resuelve. Probar varios evita
  // depender de uno solo (dns.google a veces está throttleado en móvil).
  Future<bool> _probe() async {
    for (final host in const ['dns.google', 'one.one.one.one', 'supabase.com']) {
      try {
        final result = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 3));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) return true;
      } catch (_) {
        // probar el siguiente host
      }
    }
    return false;
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
        // AnimatedSize colapsa la altura a 0 cuando hay conexión (en vez de
        // solo ocultarlo con opacidad/slide, que dejaba el espacio reservado
        // y tapaba el título de la pantalla de abajo).
        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: isOnline
              ? const SizedBox(width: double.infinity)
              : Container(
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
        );
      },
    );
  }
}
