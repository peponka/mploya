import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VideoCompressor — Compresión de video antes de subir a Supabase Storage
//
// Estrategia:
//  • En plataformas nativas: usa FFmpeg via shell si está disponible
//  • En web: opera sobre Uint8List (bytes), sin dart:io
//  • Objetivo: 720p max, CRF 28, AAC audio, ~1-3 MB por minuto
// ─────────────────────────────────────────────────────────────────────────────

class VideoCompressor {
  VideoCompressor._();

  /// Tamaño máximo aceptable para upload directo (15 MB).
  static const int maxUploadSizeBytes = 15 * 1024 * 1024;

  /// Duración máxima de video pitch (60 segundos).
  static const int maxDurationSeconds = 60;

  /// Formato legible de bytes.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// Resultado del análisis de un video.
class VideoAnalysis {
  final int sizeBytes;
  final double sizeMB;
  final bool needsCompression;
  final bool isAcceptable;
  final String? error;

  const VideoAnalysis({
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
  final int savedBytes;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final String? error;
  final dynamic compressed; // File on native, Uint8List on web

  const VideoCompressResult({
    required this.success,
    this.savedBytes = 0,
    this.originalSizeBytes = 0,
    this.compressedSizeBytes = 0,
    this.error,
    this.compressed,
  });

  /// Ratio de compresión como string legible.
  String get compressionRatio {
    if (originalSizeBytes == 0) return 'N/A';
    if (savedBytes <= 0) return 'Sin compresión';
    final pct = ((savedBytes / originalSizeBytes) * 100).toStringAsFixed(0);
    return '$pct% reducido (${VideoCompressor.formatBytes(originalSizeBytes)} → '
        '${VideoCompressor.formatBytes(compressedSizeBytes)})';
  }
}
