/// Servicio singleton para gestionar archivos en Supabase Storage.
///
/// Soporta subida y eliminación de avatars, videos y thumbnails.
/// Usa patrón singleton igual que [MessagingService].
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mploya/config/constants.dart';

/// Servicio centralizado de almacenamiento.
///
/// ```dart
/// final url = await StorageService.instance.uploadAvatar(userId, bytes, 'jpg');
/// ```
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  SupabaseClient get _client => Supabase.instance.client;

  // Bucket names are centralized in SupabaseBuckets (constants.dart).

  // ─── Subida de archivos ──────────────────────────────────────────

  /// Sube un avatar para el usuario y retorna la URL pública.
  ///
  /// El archivo se almacena en `avatars/{userId}/avatar.{ext}`.
  /// Si ya existe un avatar previo, se sobrescribe (upsert).
  Future<String> uploadAvatar(
    String userId,
    Uint8List bytes,
    String ext,
  ) async {
    final path = '$userId/avatar.$ext';
    return _uploadFile(
      bucket: SupabaseBuckets.avatars,
      path: path,
      bytes: bytes,
      ext: ext,
      upsert: true,
    );
  }

  /// Sube un video para el usuario y retorna la URL pública.
  ///
  /// El archivo se almacena en `videos/{userId}/{timestamp}.{ext}`.
  Future<String> uploadVideo(
    String userId,
    Uint8List bytes,
    String ext,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId/$timestamp.$ext';
    return _uploadFile(
      bucket: SupabaseBuckets.videos,
      path: path,
      bytes: bytes,
      ext: ext,
    );
  }

  /// Sube un thumbnail para un video y retorna la URL pública.
  ///
  /// El archivo se almacena en `thumbnails/{userId}/{videoId}.{ext}`.
  /// Se usa el userId como carpeta raíz para cumplir las políticas
  /// de Storage que verifican `foldername[1] == auth.uid()`.
  Future<String> uploadThumbnail(
    String userId,
    String videoId,
    Uint8List bytes,
    String ext,
  ) async {
    final path = '$userId/$videoId.$ext';
    return _uploadFile(
      bucket: SupabaseBuckets.thumbnails,
      path: path,
      bytes: bytes,
      ext: ext,
      upsert: true,
    );
  }

  // ─── Eliminación de archivos ─────────────────────────────────────

  /// Elimina un archivo de un bucket específico.
  ///
  /// [bucket] es el nombre del bucket (e.g. 'videos', 'avatars').
  /// [path] es la ruta relativa del archivo dentro del bucket.
  Future<void> deleteFile(String bucket, String path) async {
    try {
      await _client.storage.from(bucket).remove([path]);
      debugPrint('🗑️ Archivo eliminado: $bucket/$path');
    } catch (e, st) {
      debugPrint('Error eliminando archivo $bucket/$path: $e\n$st');
      rethrow;
    }
  }

  // ─── Helpers privados ────────────────────────────────────────────

  /// Sube un archivo al bucket indicado y retorna la URL pública.
  Future<String> _uploadFile({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String ext,
    bool upsert = false,
  }) async {
    // Validate file size (max 50 MB).
    if (bytes.lengthInBytes > Validators.maxStorageFileSizeBytes) {
      final sizeMB = (bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
      throw StateError(
        'El archivo excede el tamaño máximo permitido '
        '(${sizeMB}MB > ${Validators.maxStorageFileSizeBytes ~/ (1024 * 1024)}MB).',
      );
    }

    // Validate file extension.
    final normalizedExt = ext.toLowerCase();
    if (!Validators.allowedStorageExtensions.contains(normalizedExt)) {
      throw StateError(
        'Extensión ".$ext" no permitida. '
        'Extensiones válidas: ${Validators.allowedStorageExtensions.join(", ")}.',
      );
    }

    try {
      final contentType = _resolveContentType(ext);

      await _client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: upsert,
            ),
          );

      final publicUrl = _client.storage.from(bucket).getPublicUrl(path);

      debugPrint('✅ Archivo subido: $bucket/$path');
      return publicUrl;
    } catch (e, st) {
      debugPrint('Error subiendo archivo a $bucket/$path: $e\n$st');
      rethrow;
    }
  }

  /// Resuelve el content-type a partir de la extensión del archivo.
  String _resolveContentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg' || 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
  }
}
