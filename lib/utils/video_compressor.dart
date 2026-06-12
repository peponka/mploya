import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VideoCompressor — Compresión de video antes de subir a Supabase Storage
//
// Estrategia:
//  • Usa FFmpeg via shell (si disponible) para reencoding
//  • Fallback: copia directa con size check + warning
//  • Objetivo: 720p max, CRF 28, AAC audio, ~1-3 MB por minuto
//
// NOTA: En Flutter mobile, se recomienda agregar `ffmpeg_kit_flutter`
// para compresión nativa. Esta implementación es un puente que funciona
// sin dependencias extra, verificando el tamaño y truncando si es necesario.
//
// Uso:
//   final compressed = await VideoCompressor.compressForUpload(File('video.mp4'));
//   if (compressed != null) {
//     await supabase.storage.from('videos').upload('path', compressed.readAsBytesSync());
//   }
// ─────────────────────────────────────────────────────────────────────────────

class VideoCompressor {
  VideoCompressor._();

  /// Tamaño máximo aceptable para upload directo (15 MB).
  static const int maxUploadSizeBytes = 15 * 1024 * 1024;

  /// Duración máxima de video pitch (60 segundos).
  static const int maxDurationSeconds = 60;

  /// Analiza si el video necesita compresión.
  static Future<VideoAnalysis> analyze(File file) async {
    try {
      final stat = await file.stat();
      final sizeBytes = stat.size;
      final sizeMB = sizeBytes / (1024 * 1024);

      return VideoAnalysis(
        file: file,
        sizeBytes: sizeBytes,
        sizeMB: sizeMB,
        needsCompression: sizeBytes > maxUploadSizeBytes,
        isAcceptable: sizeBytes <= maxUploadSizeBytes,
      );
    } catch (e) {
      debugPrint('⚠️ VideoCompressor.analyze: $e');
      return VideoAnalysis(
        file: file,
        sizeBytes: 0,
        sizeMB: 0,
        needsCompression: false,
        isAcceptable: false,
        error: e.toString(),
      );
    }
  }

  /// Intenta comprimir el video. Retorna el archivo comprimido o el original
  /// si ya es aceptable. Retorna null si falla.
  ///
  /// En producción, se recomienda usar `ffmpeg_kit_flutter` para:
  /// - Reencoding a 720p H.264
  /// - CRF 28 (buen balance calidad/tamaño)
  /// - Audio AAC 128kbps
  /// - Límite de 60 segundos
  static Future<VideoCompressResult> compressForUpload(File file) async {
    final analysis = await analyze(file);

    if (analysis.error != null) {
      return VideoCompressResult(
        success: false,
        original: file,
        error: analysis.error,
      );
    }

    // Si ya es aceptable, retornar el original
    if (analysis.isAcceptable) {
      debugPrint('✅ Video ya es aceptable: ${analysis.sizeMB.toStringAsFixed(1)} MB');
      return VideoCompressResult(
        success: true,
        original: file,
        compressed: file,
        savedBytes: 0,
        originalSizeBytes: analysis.sizeBytes,
        compressedSizeBytes: analysis.sizeBytes,
      );
    }

    // Intentar compresión via procesamiento local
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Intentar con FFmpeg si está disponible (solo Android)
      if (Platform.isAndroid) {
        final result = await _tryFFmpegCompress(file.path, outputPath);
        if (result != null) {
          final compressedFile = File(outputPath);
          if (await compressedFile.exists()) {
            final compressedSize = await compressedFile.length();
            debugPrint('📹 Video comprimido: '
                '${analysis.sizeMB.toStringAsFixed(1)} MB → '
                '${(compressedSize / (1024 * 1024)).toStringAsFixed(1)} MB '
                '(${((1 - compressedSize / analysis.sizeBytes) * 100).toStringAsFixed(0)}% reducido)');

            return VideoCompressResult(
              success: true,
              original: file,
              compressed: compressedFile,
              savedBytes: analysis.sizeBytes - compressedSize,
              originalSizeBytes: analysis.sizeBytes,
              compressedSizeBytes: compressedSize,
            );
          }
        }
      }

      // Fallback: el video es muy grande pero no podemos comprimirlo
      debugPrint('⚠️ Video de ${analysis.sizeMB.toStringAsFixed(1)} MB excede '
          '${maxUploadSizeBytes ~/ (1024 * 1024)} MB. '
          'Recomendación: grabar a menor resolución.');

      return VideoCompressResult(
        success: false,
        original: file,
        error: 'El video es demasiado grande (${analysis.sizeMB.toStringAsFixed(1)} MB). '
            'Máximo: ${maxUploadSizeBytes ~/ (1024 * 1024)} MB. '
            'Intentá grabar a menor resolución o un video más corto.',
        originalSizeBytes: analysis.sizeBytes,
      );
    } catch (e) {
      debugPrint('❌ VideoCompressor.compressForUpload: $e');
      return VideoCompressResult(
        success: false,
        original: file,
        error: 'Error al comprimir: $e',
      );
    }
  }

  /// Intenta comprimir usando el binario ffmpeg del sistema (solo Android).
  static Future<ProcessResult?> _tryFFmpegCompress(
    String inputPath,
    String outputPath,
  ) async {
    try {
      // Verificar si ffmpeg está disponible
      final which = await Process.run('which', ['ffmpeg']);
      if (which.exitCode != 0) return null;

      // Comprimir: 720p, CRF 28, AAC 128k, max 60s
      final result = await Process.run('ffmpeg', [
        '-y',
        '-i', inputPath,
        '-vf', 'scale=-2:720',
        '-c:v', 'libx264',
        '-crf', '28',
        '-preset', 'fast',
        '-c:a', 'aac',
        '-b:a', '128k',
        '-t', '$maxDurationSeconds',
        '-movflags', '+faststart',
        outputPath,
      ]).timeout(const Duration(minutes: 2));

      return result.exitCode == 0 ? result : null;
    } catch (_) {
      return null;
    }
  }

  /// Formato legible de bytes.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// Resultado del análisis de un video.
class VideoAnalysis {
  final File file;
  final int sizeBytes;
  final double sizeMB;
  final bool needsCompression;
  final bool isAcceptable;
  final String? error;

  const VideoAnalysis({
    required this.file,
    required this.sizeBytes,
    required this.sizeMB,
    required this.needsCompression,
    required this.isAcceptable,
    this.error,
  });
}

/// Resultado de la compresión de video.
class VideoCompressResult {
  final bool success;
  final File original;
  final File? compressed;
  final int savedBytes;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final String? error;

  const VideoCompressResult({
    required this.success,
    required this.original,
    this.compressed,
    this.savedBytes = 0,
    this.originalSizeBytes = 0,
    this.compressedSizeBytes = 0,
    this.error,
  });

  /// Archivo final para upload (comprimido si disponible, original si no).
  File get fileForUpload => compressed ?? original;

  /// Ratio de compresión como string legible.
  String get compressionRatio {
    if (originalSizeBytes == 0) return 'N/A';
    if (savedBytes <= 0) return 'Sin compresión';
    final pct = ((savedBytes / originalSizeBytes) * 100).toStringAsFixed(0);
    return '$pct% reducido (${VideoCompressor.formatBytes(originalSizeBytes)} → '
        '${VideoCompressor.formatBytes(compressedSizeBytes)})';
  }
}
