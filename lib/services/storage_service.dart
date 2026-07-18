import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StorageService — Singleton para subida de archivos a Supabase Storage.
//
// Responsabilidades:
//  • Sube el Video-Pitch del usuario al bucket "videos" (ruta: pitches/<uid>.mp4)
//  • Funciona en Web (XFile → readAsBytes) y en Móvil (mismo mecanismo)
//  • Detecta y clasifica errores de red, permisos y almacenamiento
//  • Expone lastError para que la UI muestre un mensaje legible tras un fallo
//
// Requisitos en Supabase Dashboard:
//  • Storage → Buckets → Crear bucket llamado "videos" → activar "Public bucket"
//  • Storage → Policies → añadir política: INSERT para authenticated users
//    con  (bucket_id = 'videos') AND (name LIKE 'pitches/' || auth.uid() || '%')
// ─────────────────────────────────────────────────────────────────────────────

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  // Getter diferido para que Supabase.initialize() ya haya corrido
  SupabaseClient get _client => Supabase.instance.client;

  /// Último error registrado. Se limpia al inicio de cada llamada.
  String? _lastError;
  String? get lastError => _lastError;

  // ── Upload principal ───────────────────────────────────────────────────────

  /// Sube el Video-Pitch al bucket "videos" en la ruta `pitches/<userId>.mp4`.
  ///
  /// Retorna:
  ///  • `String` — URL pública del vídeo si la subida fue exitosa.
  ///  • `null`   — la subida falló; consulta [lastError] para el mensaje.
  Future<String?> uploadPitchVideo(String userId, XFile file) async {
    _lastError = null;

    try {
      // ── 1. Leer como bytes (compatible Web + móvil) ──
      final bytes = await file.readAsBytes();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // En Chrome web el package `camera` graba WebM (no MP4); detectar el
      // formato real para no subir bytes WebM etiquetados como MP4 (eso
      // congelaba el <video> en el primer frame).
      final fmt = _videoFormat(file, bytes);
      final storagePath = 'pitches/${userId}_$timestamp.${fmt.ext}';

      // ── 2. Subir con upsert para sobrescribir si ya existe ──
      await _client.storage.from('videos').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: fmt.contentType,
              upsert: true,
            ),
          );

      // ── 3. Obtener URL pública (el bucket debe ser público) ──
      final publicUrl =
          _client.storage.from('videos').getPublicUrl(storagePath);

      return publicUrl;
    } on StorageException catch (e) {
      _lastError = _translateStorageError(e.message, e.statusCode);
      return null;
    } catch (e) {
      _lastError = _classifyNetworkError(e);
      return null;
    }
  }

  // ── Upload de Micro-Pitch (Nexus) ──────────────────────────────────────────

  /// Sube un micro-pitch al bucket "videos" en ruta `nexus/<senderId>_<receiverId>_<ts>.mp4`.
  /// NO toca la ruta `pitches/` del video-pitch principal.
  Future<String?> uploadMicroPitch(String senderId, String receiverId, XFile file) async {
    _lastError = null;
    try {
      final bytes = await file.readAsBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fmt = _videoFormat(file, bytes); // WebM en Chrome web, MP4 en móvil
      final storagePath = 'nexus/${senderId}_${receiverId}_$timestamp.${fmt.ext}';

      await _client.storage.from('videos').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: fmt.contentType,
              upsert: true,
            ),
          );

      return _client.storage.from('videos').getPublicUrl(storagePath);
    } on StorageException catch (e) {
      _lastError = _translateStorageError(e.message, e.statusCode);
      return null;
    } catch (e) {
      _lastError = _classifyNetworkError(e);
      return null;
    }
  }

  // ── Upload de Avatar (Foto de Perfil) ────────────────────────────────────

  /// Sube la foto de perfil al bucket "videos" en ruta `avatars/<userId>.jpg`.
  /// Retorna la URL pública o null si falla.
  Future<String?> uploadAvatar(String userId, XFile file) async {
    _lastError = null;
    try {
      final bytes = await file.readAsBytes();
      final storagePath = 'avatars/$userId.jpg';

      await _client.storage.from('videos').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      return _client.storage.from('videos').getPublicUrl(storagePath);
    } on StorageException catch (e) {
      _lastError = _translateStorageError(e.message, e.statusCode);
      return null;
    } catch (e) {
      _lastError = _classifyNetworkError(e);
      return null;
    }
  }
  // ── Upload de Story Video ──────────────────────────────────────────────────

  /// Sube un video de historia al bucket "videos" en ruta `stories/<userId>_<ts>.<ext>`.
  /// Detecta formato automáticamente (WebM en Chrome, MP4 en móvil).
  Future<String?> uploadStoryVideo(String userId, XFile file) async {
    _lastError = null;
    try {
      final bytes = await file.readAsBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Detectar el formato REAL del archivo. En Chrome web el package `camera`
      // graba con MediaRecorder => los bytes son WebM (VP8/VP9), NO MP4.
      // Antes se subía SIEMPRE como .mp4 con contentType 'video/mp4': el
      // navegador recibía bytes WebM etiquetados como MP4 y el <video> se
      // quedaba en el primer frame (imagen congelada, audio sonando).
      final mime = (file.mimeType ?? '').toLowerCase();
      final isWebm = mime.contains('webm') ||
          file.path.toLowerCase().contains('.webm') ||
          file.name.toLowerCase().endsWith('.webm') ||
          // Magic header EBML (1A 45 DF A3) => Matroska / WebM
          (bytes.length >= 4 &&
              bytes[0] == 0x1A &&
              bytes[1] == 0x45 &&
              bytes[2] == 0xDF &&
              bytes[3] == 0xA3);

      final ext = isWebm ? 'webm' : 'mp4';
      final contentType = isWebm ? 'video/webm' : 'video/mp4';
      final storagePath = 'stories/${userId}_$timestamp.$ext';

      await _client.storage.from('videos').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      return _client.storage.from('videos').getPublicUrl(storagePath);
    } on StorageException catch (e) {
      _lastError = _translateStorageError(e.message, e.statusCode);
      return null;
    } catch (e) {
      _lastError = _classifyNetworkError(e);
      return null;
    }
  }

  // ── Upload de Video de Entrevista IA ───────────────────────────────────────

  /// Sube un video de respuesta de entrevista al bucket "videos" en la ruta `interviews/<interviewId>_<questionId>.<ext>`.
  /// Detecta formato automáticamente (WebM en Chrome, MP4 en móvil).
  Future<String?> uploadInterviewVideo(String interviewId, String questionId, XFile file) async {
    _lastError = null;
    try {
      final bytes = await file.readAsBytes();
      final fmt = _videoFormat(file, bytes);
      final storagePath = 'interviews/${interviewId}_$questionId.${fmt.ext}';

      await _client.storage.from('videos').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: fmt.contentType,
              upsert: true,
            ),
          );

      return _client.storage.from('videos').getPublicUrl(storagePath);
    } on StorageException catch (e) {
      _lastError = _translateStorageError(e.message, e.statusCode);
      return null;
    } catch (e) {
      _lastError = _classifyNetworkError(e);
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers privados
  // ─────────────────────────────────────────────────────────────────────────

  /// Detecta el formato real de un video. En Chrome web el package `camera`
  /// graba con MediaRecorder => bytes WebM (VP8/VP9), NO MP4. Devuelve la
  /// extensión y el Content-Type correctos para no subir WebM disfrazado de MP4
  /// (eso hacía que el <video> se quedara congelado en el primer frame).
  ({String ext, String contentType}) _videoFormat(XFile file, List<int> bytes) {
    final mime = (file.mimeType ?? '').toLowerCase();
    final isWebm = mime.contains('webm') ||
        file.path.toLowerCase().contains('.webm') ||
        file.name.toLowerCase().endsWith('.webm') ||
        // Magic header EBML (1A 45 DF A3) => Matroska / WebM
        (bytes.length >= 4 &&
            bytes[0] == 0x1A &&
            bytes[1] == 0x45 &&
            bytes[2] == 0xDF &&
            bytes[3] == 0xA3);
    return isWebm
        ? (ext: 'webm', contentType: 'video/webm')
        : (ext: 'mp4', contentType: 'video/mp4');
  }

  String _translateStorageError(String message, String? statusCode) {
    final m = message.toLowerCase();

    if (m.contains('row-level security') || m.contains('rls') ||
        m.contains('not authorized') || statusCode == '403') {
      return 'Sin permisos para subir archivos. Verifica las políticas RLS del bucket "videos" en Supabase.';
    }
    if (m.contains('bucket not found') || m.contains('does not exist') ||
        statusCode == '404') {
      return 'El bucket "videos" no existe. Créalo en Supabase → Storage y actívalo como público.';
    }
    if (m.contains('payload too large') || m.contains('too large') ||
        statusCode == '413') {
      return 'El archivo es demasiado grande. El límite por defecto en Supabase es 50 MB.';
    }
    if (m.contains('duplicate') || m.contains('already exists')) {
      return 'Ya existe un archivo con ese nombre. Activa "upsert" o elimina el anterior.';
    }
    if (m.contains('invalid') && m.contains('mime')) {
      return 'Formato de archivo no válido. Solo se aceptan vídeos MP4.';
    }
    return 'Error de almacenamiento: $message';
  }

  String _classifyNetworkError(Object e) {
    final raw = e.toString().toLowerCase();

    if (raw.contains('failed to fetch') ||
        raw.contains('xmlhttprequest') ||
        raw.contains('cors')) {
      return 'Error de conexión. Verifica tu internet o los permisos de API en tu panel de Supabase.';
    }
    if (raw.contains('clientexception')) {
      return 'Error de conexión. Verifica tu internet o los permisos de API en tu panel de Supabase.';
    }
    if (raw.contains('socketexception') ||
        raw.contains('connection refused') ||
        raw.contains('network is unreachable')) {
      return 'Sin conexión a internet. Activa los datos móviles o el Wi-Fi e inténtalo de nuevo.';
    }
    if (raw.contains('timeout') || raw.contains('timed out')) {
      return 'La subida tardó demasiado. Comprueba tu conexión o intenta con un vídeo más corto.';
    }
    if (raw.contains('out of memory') || raw.contains('memory')) {
      return 'El vídeo es demasiado pesado para cargarlo en memoria. Elige un archivo más corto.';
    }
    return 'Error inesperado al subir el vídeo. Inténtalo de nuevo.';
  }
}
