/// Servicio abstracto de cámara multiplataforma.
///
/// Define la interfaz común para acceso a cámara, grabación de video
/// y reproducción. Usa conditional imports para seleccionar la
/// implementación correcta (web / mobile / stub).
library;

import 'package:flutter/widgets.dart';

import 'package:mploya/core/services/camera/camera_service_stub.dart'
    if (dart.library.html) 'package:mploya/core/services/camera/camera_service_web.dart'
    if (dart.library.io) 'package:mploya/core/services/camera/camera_service_mobile.dart';

/// Interfaz abstracta del servicio de cámara.
///
/// Encapsula acceso a cámara, grabación de video y creación de
/// widgets de preview/playback para cualquier plataforma.
abstract class CameraService {
  /// Crea la implementación correcta según la plataforma.
  factory CameraService() = CameraServiceImpl;

  /// Inicializa la cámara con las opciones dadas.
  ///
  /// [frontCamera] — usar cámara frontal (por defecto `true`).
  /// [audio] — capturar audio (por defecto `true`).
  Future<void> initialize({bool frontCamera = true, bool audio = true});

  /// Indica si la cámara ya está lista para mostrar preview.
  bool get isReady;

  /// `true` si el usuario denegó los permisos de cámara/micrófono.
  bool get permissionDenied;

  /// Construye el widget de preview de la cámara en vivo.
  ///
  /// [viewId] es un identificador único para la platform view.
  Widget buildPreview(String viewId);

  /// Inicia la grabación de video.
  Future<void> startRecording();

  /// Detiene la grabación y devuelve la URL del blob (web) o la
  /// ruta del archivo (mobile). Retorna `null` si falla.
  Future<String?> stopRecording();

  /// Construye un widget de reproducción de video.
  ///
  /// [viewId] — identificador único para la platform view.
  /// [url] — blob URL (web) o ruta de archivo (mobile).
  /// [objectFit] — CSS object-fit equivalente ('cover', 'contain').
  /// [mirror] — si se debe espejar horizontalmente.
  /// [loop] — si el video debe repetirse.
  /// [autoplay] — si el video debe iniciar automáticamente.
  /// [muted] — si el video debe iniciar silenciado.
  /// [controls] — si se muestran controles nativos.
  /// [borderRadius] — radio de borde CSS (solo web).
  /// [background] — color de fondo CSS (solo web).
  Widget buildPlayback(
    String viewId,
    String url, {
    String objectFit = 'cover',
    bool mirror = true,
    bool loop = true,
    bool autoplay = true,
    bool muted = false,
    bool controls = false,
    String? borderRadius,
    String background = '#000',
  });

  /// Habilita/deshabilita las pistas de audio del stream.
  void setAudioEnabled(bool enabled);

  /// Habilita/deshabilita las pistas de video del stream.
  void setVideoEnabled(bool enabled);

  /// Establece el modo de flash/linterna de la cámara.
  ///
  /// [enabled] — `true` para encender flash (torch), `false` para apagar.
  Future<void> setFlashMode(bool enabled);

  /// Libera todos los recursos (stream, cámara, etc.).
  void dispose();
}
