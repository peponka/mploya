import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

// ─────────────────────────────────────────────────────────────────────────────
// ImageCompressor — Compresión de imágenes antes de subir a Supabase Storage
//
// Optimizaciones:
//  • Limita ancho máximo a 1080px (suficiente para móvil)
//  • Comprime JPEG al 80% de calidad (buen balance tamaño/calidad)
//  • Ejecuta en isolate via compute() para no bloquear la UI
//  • Convierte PNG/WebP a JPEG para menor tamaño
//  • Compatible con Flutter Web (trabaja con Uint8List en lugar de File)
// ─────────────────────────────────────────────────────────────────────────────

class ImageCompressor {
  ImageCompressor._();

  /// Ancho máximo en píxeles para imágenes de perfil/feed.
  static const int maxWidth = 1080;

  /// Calidad JPEG (0-100). 80 es un buen balance.
  static const int jpegQuality = 80;

  /// Comprime bytes de imagen. Compatible con web y mobile.
  /// Se ejecuta en un isolate separado para no congelar la UI.
  static Future<Uint8List?> compressBytes(
    Uint8List bytes, {
    int? maxW,
    int? quality,
  }) async {
    try {
      return compute(
        _compressBytes,
        _CompressParams(
          bytes: bytes,
          maxWidth: maxW ?? maxWidth,
          quality: quality ?? jpegQuality,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ ImageCompressor.compressBytes: $e');
      return null;
    }
  }

  /// Comprime bytes de imagen en un isolate.
  static Uint8List? _compressBytes(_CompressParams params) {
    try {
      final image = img.decodeImage(params.bytes);
      if (image == null) return null;

      // Resize si excede el máximo
      final resized = image.width > params.maxWidth
          ? img.copyResize(image, width: params.maxWidth)
          : image;

      // Encode como JPEG
      final compressed = img.encodeJpg(resized, quality: params.quality);
      return Uint8List.fromList(compressed);
    } catch (e) {
      return null;
    }
  }

  /// Calcula el ratio de compresión para logging.
  static String compressionRatio(int originalSize, int compressedSize) {
    if (originalSize == 0) return '0%';
    final ratio =
        ((1 - compressedSize / originalSize) * 100).toStringAsFixed(1);
    return '$ratio% reducido (${_formatBytes(originalSize)} → ${_formatBytes(compressedSize)})';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class _CompressParams {
  final Uint8List bytes;
  final int maxWidth;
  final int quality;

  const _CompressParams({
    required this.bytes,
    required this.maxWidth,
    required this.quality,
  });
}
