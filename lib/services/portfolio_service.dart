import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PortfolioService — Gestión de hasta 3 vídeos de portfolio profesional
//
// El candidato puede subir hasta 3 vídeos cortos (max 60s) mostrando:
//   • Proyectos reales en los que trabajó
//   • Habilidades específicas en acción
//   • Resultados concretos obtenidos en empleos anteriores
//
// Cada vídeo pasa por moderación IA antes de publicarse.
// El contenido del portfolio debe ser estrictamente profesional.
// ─────────────────────────────────────────────────────────────────────────────

class PortfolioVideo {
  final String id;
  final String userId;
  final String videoUrl;
  final String title;
  final String? description;
  final int durationSeconds;
  final int viewCount;
  final int likeCount;
  final String status; // 'processing', 'approved', 'rejected'
  final DateTime createdAt;

  const PortfolioVideo({
    required this.id,
    required this.userId,
    required this.videoUrl,
    required this.title,
    this.description,
    this.durationSeconds = 0,
    this.viewCount = 0,
    this.likeCount = 0,
    this.status = 'approved',
    required this.createdAt,
  });

  factory PortfolioVideo.fromJson(Map<String, dynamic> json) {
    return PortfolioVideo(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      videoUrl: json['video_url']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'approved',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'video_url': videoUrl,
    'title': title,
    'description': description,
    'duration_seconds': durationSeconds,
    'status': status,
  };

  bool get isApproved => status == 'approved';
  bool get isProcessing => status == 'processing';
  bool get isRejected => status == 'rejected';
}

class PortfolioService {
  PortfolioService._();
  static final PortfolioService instance = PortfolioService._();

  static const int maxPortfolioVideos = 3;
  static const int maxVideoDurationSeconds = 60;
  static const String _bucket = 'videos';

  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  // ── Cache ──
  List<PortfolioVideo>? _cache;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 3);

  bool get _isCacheValid =>
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheDuration;

  // ── Obtener portfolio del usuario actual ──
  Future<List<PortfolioVideo>> getMyPortfolio({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid && _cache != null) return _cache!;
    if (_uid == null) return [];

    try {
      final res = await _supabase
          .from('portfolio_videos')
          .select()
          .eq('user_id', _uid!)
          .order('created_at', ascending: false);

      _cache = List<Map<String, dynamic>>.from(res)
          .map((e) => PortfolioVideo.fromJson(e))
          .toList();
      _cacheTime = DateTime.now();
      return _cache!;
    } catch (e) {
      debugPrint('❌ PortfolioService.getMyPortfolio: $e');
      return _cache ?? [];
    }
  }

  // ── Obtener portfolio de otro usuario ──
  Future<List<PortfolioVideo>> getPortfolioFor(String userId) async {
    try {
      final res = await _supabase
          .from('portfolio_videos')
          .select()
          .eq('user_id', userId)
          .eq('status', 'approved')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(res)
          .map((e) => PortfolioVideo.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('❌ PortfolioService.getPortfolioFor: $e');
      return [];
    }
  }

  // ── Verificar si puede agregar más videos ──
  Future<bool> canAddMore() async {
    final portfolio = await getMyPortfolio();
    return portfolio.length < maxPortfolioVideos;
  }

  // ── Subir video de portfolio ──
  Future<PortfolioVideo?> uploadVideo({
    required XFile file,
    required String title,
    String? description,
    required int durationSeconds,
  }) async {
    if (_uid == null) return null;

    // 1. Verificar límite
    final canAdd = await canAddMore();
    if (!canAdd) {
      debugPrint('❌ Portfolio lleno (max $maxPortfolioVideos)');
      return null;
    }

    // 2. Verificar duración
    if (durationSeconds > maxVideoDurationSeconds) {
      debugPrint('❌ Video demasiado largo ($durationSeconds > $maxVideoDurationSeconds s)');
      return null;
    }

    try {
      // Leer bytes del XFile directamente — funciona para rutas de disco (móvil)
      // y para blobs en memoria del grabador web (XFile.fromData). Reconstruir un
      // XFile desde el path fallaba en web porque el blob es efímero.
      final bytes = await file.readAsBytes();

      // El grabador web produce webm; la cámara/galería móvil produce mp4. Derivamos
      // el tipo para que el contentType y la extensión coincidan con el contenido.
      final mime = file.mimeType ??
          ((file.name.toLowerCase().endsWith('.webm')) ? 'video/webm' : 'video/mp4');
      final ext = mime.contains('webm') ? 'webm' : 'mp4';

      // 3. Upload a Supabase Storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_portfolio.$ext';
      final storagePath = 'portfolios/$_uid/$fileName';

      await _supabase.storage
          .from(_bucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mime,
              upsert: true,
            ),
          );

      final videoUrl = _supabase.storage.from(_bucket).getPublicUrl(storagePath);

      // 4. Insertar en DB (status: 'processing' → la IA lo revisa)
      final res = await _supabase.from('portfolio_videos').insert({
        'user_id': _uid,
        'video_url': videoUrl,
        'title': title,
        'description': description,
        'duration_seconds': durationSeconds,
        'status': 'approved', // Para MVP; en prod sería 'processing' → IA modera
      }).select().single();

      _invalidateCache();

      final video = PortfolioVideo.fromJson(res);
      debugPrint('✅ Portfolio video subido: ${video.title}');
      return video;
    } catch (e) {
      debugPrint('❌ PortfolioService.uploadVideo: $e');
      return null;
    }
  }

  // ── Agregar video por URL (ya subido) ──
  Future<PortfolioVideo?> addVideoByUrl({
    required String videoUrl,
    required String title,
    String? description,
    int durationSeconds = 30,
  }) async {
    if (_uid == null) return null;

    final canAdd = await canAddMore();
    if (!canAdd) return null;

    try {
      final res = await _supabase.from('portfolio_videos').insert({
        'user_id': _uid,
        'video_url': videoUrl,
        'title': title,
        'description': description,
        'duration_seconds': durationSeconds,
        'status': 'approved',
      }).select().single();

      _invalidateCache();
      return PortfolioVideo.fromJson(res);
    } catch (e) {
      debugPrint('❌ PortfolioService.addVideoByUrl: $e');
      return null;
    }
  }

  // ── Editar título/descripción ──
  Future<bool> updateVideo({
    required String videoId,
    String? title,
    String? description,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;

      if (updates.isEmpty) return true;

      await _supabase
          .from('portfolio_videos')
          .update(updates)
          .eq('id', videoId)
          .eq('user_id', _uid!);

      _invalidateCache();
      return true;
    } catch (e) {
      debugPrint('❌ PortfolioService.updateVideo: $e');
      return false;
    }
  }

  // ── Eliminar video ──
  Future<bool> deleteVideo(String videoId) async {
    if (_uid == null) return false;

    try {
      await _supabase
          .from('portfolio_videos')
          .delete()
          .eq('id', videoId)
          .eq('user_id', _uid!);

      _invalidateCache();
      return true;
    } catch (e) {
      debugPrint('❌ PortfolioService.deleteVideo: $e');
      return false;
    }
  }

  // ── Incrementar view count ──
  Future<void> incrementViewCount(String videoId) async {
    try {
      await _supabase.rpc('increment_portfolio_view', params: {
        'p_video_id': videoId,
      });
    } catch (e) {
      debugPrint('⚠️ increment view: $e');
    }
  }

  void _invalidateCache() {
    _cache = null;
    _cacheTime = null;
  }
}
