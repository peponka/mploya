import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CompanyCultureService — "Cultura de la Empresa"
//
// Construida el 29/8/2026 a pedido explícito de Pedro ("quiero construirla en
// serio"), después de confirmar en `empresa_perfil_screen.dart` y
// `empresa_editar_perfil_screen.dart` que esta pantalla se había dejado
// afuera A PROPÓSITO porque `public.users` no tenía dónde guardar nada de
// esto. Ver migración `046_company_culture.sql` para el modelo de datos.
//
// Dos entidades:
//   • `CompanyCulture`       — una fila por empresa: video institucional +
//                              hasta 4 valores con ícono.
//   • `CompanyCultureStory`  — N historias en video de integrantes del
//                              equipo, independientes entre sí.
//
// Mismo patrón que PortfolioService: caché corta en memoria, upload directo
// a Storage (bucket "videos", prefijo "culture/" vía
// `StorageService.uploadCultureVideo`), sin inventar moderación ni campos
// que la base no tiene.
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class CompanyCultureValor {
  final String iconKey;
  final String titulo;
  final String descripcion;

  const CompanyCultureValor({
    required this.iconKey,
    required this.titulo,
    required this.descripcion,
  });

  factory CompanyCultureValor.fromJson(Map<String, dynamic> json) {
    return CompanyCultureValor(
      iconKey: json['icon_key']?.toString() ?? 'star',
      titulo: json['titulo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'icon_key': iconKey,
    'titulo': titulo,
    'descripcion': descripcion,
  };
}

@immutable
class CompanyCulture {
  final String id;
  final String userId;
  final String? introVideoUrl;
  final int? introVideoDurationSeconds;
  final List<CompanyCultureValor> valores;
  final int? foundedYear;
  final int? employeeCount;
  final double? growthPercentage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CompanyCulture({
    required this.id,
    required this.userId,
    this.introVideoUrl,
    this.introVideoDurationSeconds,
    this.valores = const [],
    this.foundedYear,
    this.employeeCount,
    this.growthPercentage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyCulture.fromJson(Map<String, dynamic> json) {
    final rawValores = json['valores'];
    return CompanyCulture(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      introVideoUrl: json['intro_video_url']?.toString(),
      introVideoDurationSeconds:
          (json['intro_video_duration_seconds'] as num?)?.toInt(),
      valores: rawValores is List
          ? rawValores
                .whereType<Map>()
                .map((e) => CompanyCultureValor.fromJson(
                      Map<String, dynamic>.from(e),
                    ))
                .toList()
          : const [],
      foundedYear: (json['founded_year'] as num?)?.toInt(),
      employeeCount: (json['employee_count'] as num?)?.toInt(),
      growthPercentage: (json['growth_percentage'] as num?)?.toDouble(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  bool get tieneVideo => (introVideoUrl?.isNotEmpty ?? false);
  bool get tieneContenido =>
      tieneVideo ||
      valores.isNotEmpty ||
      foundedYear != null ||
      employeeCount != null ||
      growthPercentage != null;
}

@immutable
class CompanyCultureStory {
  final String id;
  final String companyUserId;
  final String memberName;
  final String? memberRole;
  final String? quote;
  final String videoUrl;
  final int? videoDurationSeconds;
  final int sortOrder;
  final DateTime createdAt;

  const CompanyCultureStory({
    required this.id,
    required this.companyUserId,
    required this.memberName,
    this.memberRole,
    this.quote,
    required this.videoUrl,
    this.videoDurationSeconds,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory CompanyCultureStory.fromJson(Map<String, dynamic> json) {
    return CompanyCultureStory(
      id: json['id']?.toString() ?? '',
      companyUserId: json['company_user_id']?.toString() ?? '',
      memberName: json['member_name']?.toString() ?? '',
      memberRole: json['member_role']?.toString(),
      quote: json['quote']?.toString(),
      videoUrl: json['video_url']?.toString() ?? '',
      videoDurationSeconds: (json['video_duration_seconds'] as num?)?.toInt(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class CompanyCultureService {
  CompanyCultureService._();
  static final CompanyCultureService instance = CompanyCultureService._();

  /// Hasta 4 historias del equipo, igual que el mockup ("Cultura de la
  /// Empresa" muestra un héroe + 4 testimonios).
  static const int maxStories = 4;

  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  // ── Caché corta (misma duración que PortfolioService) ──
  final Map<String, CompanyCulture?> _cultureCache = {};
  final Map<String, List<CompanyCultureStory>> _storiesCache = {};
  final Map<String, DateTime> _cacheTime = {};
  static const _cacheDuration = Duration(minutes: 3);

  bool _isCacheValid(String key) {
    final t = _cacheTime[key];
    return t != null && DateTime.now().difference(t) < _cacheDuration;
  }

  void _invalidate(String userId) {
    _cultureCache.remove(userId);
    _storiesCache.remove(userId);
    _cacheTime.remove(userId);
  }

  // ── Leer cultura de una empresa (propia o ajena — lectura es pública) ──
  Future<CompanyCulture?> getCultureFor(
    String userId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _isCacheValid(userId) &&
        _cultureCache.containsKey(userId)) {
      return _cultureCache[userId];
    }
    try {
      final row = await _supabase
          .from('company_culture')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      final culture = row == null ? null : CompanyCulture.fromJson(row);
      _cultureCache[userId] = culture;
      _cacheTime[userId] = DateTime.now();
      return culture;
    } catch (e) {
      debugPrint('❌ CompanyCultureService.getCultureFor: $e');
      return _cultureCache[userId];
    }
  }

  Future<CompanyCulture?> getMyCulture({bool forceRefresh = false}) {
    if (_uid == null) return Future.value(null);
    return getCultureFor(_uid!, forceRefresh: forceRefresh);
  }

  // ── Leer historias de una empresa ──
  Future<List<CompanyCultureStory>> getStoriesFor(
    String userId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _isCacheValid(userId) &&
        _storiesCache.containsKey(userId)) {
      return _storiesCache[userId]!;
    }
    try {
      final res = await _supabase
          .from('company_culture_stories')
          .select()
          .eq('company_user_id', userId)
          .order('sort_order', ascending: true);
      final stories = List<Map<String, dynamic>>.from(
        res,
      ).map((e) => CompanyCultureStory.fromJson(e)).toList();
      _storiesCache[userId] = stories;
      _cacheTime[userId] = DateTime.now();
      return stories;
    } catch (e) {
      debugPrint('❌ CompanyCultureService.getStoriesFor: $e');
      return _storiesCache[userId] ?? [];
    }
  }

  Future<List<CompanyCultureStory>> getMyStories({bool forceRefresh = false}) {
    if (_uid == null) return Future.value(const []);
    return getStoriesFor(_uid!, forceRefresh: forceRefresh);
  }

  // ── Guardar (crear o actualizar) la fila de cultura de la empresa actual ──
  ///
  /// Escribe SÓLO los campos pasados; los `null` no tocan lo que ya había
  /// (para eso siempre se lee `getMyCulture()` antes de abrir el editor y se
  /// mandan los valores actuales, igual que hace `guardarPerfilEmpresa`).
  Future<bool> saveMyCulture({
    String? introVideoUrl,
    int? introVideoDurationSeconds,
    List<CompanyCultureValor>? valores,
    int? foundedYear,
    int? employeeCount,
    double? growthPercentage,
  }) async {
    final uid = _uid;
    if (uid == null) return false;
    if (valores != null && valores.length > maxStories) {
      debugPrint('❌ CompanyCultureService.saveMyCulture: máximo $maxStories valores');
      return false;
    }
    try {
      final payload = <String, dynamic>{'user_id': uid};
      if (introVideoUrl != null) payload['intro_video_url'] = introVideoUrl;
      if (introVideoDurationSeconds != null) {
        payload['intro_video_duration_seconds'] = introVideoDurationSeconds;
      }
      if (valores != null) {
        payload['valores'] = valores.map((v) => v.toJson()).toList();
      }
      if (foundedYear != null) payload['founded_year'] = foundedYear;
      if (employeeCount != null) payload['employee_count'] = employeeCount;
      if (growthPercentage != null) {
        payload['growth_percentage'] = growthPercentage;
      }

      await _supabase
          .from('company_culture')
          .upsert(payload, onConflict: 'user_id');

      _invalidate(uid);
      return true;
    } catch (e) {
      debugPrint('❌ CompanyCultureService.saveMyCulture: $e');
      return false;
    }
  }

  // ── Agregar una historia del equipo ──
  Future<CompanyCultureStory?> addStory({
    required String memberName,
    String? memberRole,
    String? quote,
    required String videoUrl,
    int? videoDurationSeconds,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    final actuales = await getMyStories();
    if (actuales.length >= maxStories) {
      debugPrint('❌ CompanyCultureService.addStory: máximo $maxStories historias');
      return null;
    }

    try {
      final res = await _supabase
          .from('company_culture_stories')
          .insert({
            'company_user_id': uid,
            'member_name': memberName,
            'member_role': memberRole,
            'quote': quote,
            'video_url': videoUrl,
            'video_duration_seconds': videoDurationSeconds,
            'sort_order': actuales.length,
          })
          .select()
          .single();

      _invalidate(uid);
      return CompanyCultureStory.fromJson(res);
    } catch (e) {
      debugPrint('❌ CompanyCultureService.addStory: $e');
      return null;
    }
  }

  // ── Editar una historia existente ──
  Future<bool> updateStory({
    required String storyId,
    String? memberName,
    String? memberRole,
    String? quote,
  }) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final updates = <String, dynamic>{};
      if (memberName != null) updates['member_name'] = memberName;
      if (memberRole != null) updates['member_role'] = memberRole;
      if (quote != null) updates['quote'] = quote;
      if (updates.isEmpty) return true;

      await _supabase
          .from('company_culture_stories')
          .update(updates)
          .eq('id', storyId)
          .eq('company_user_id', uid);

      _invalidate(uid);
      return true;
    } catch (e) {
      debugPrint('❌ CompanyCultureService.updateStory: $e');
      return false;
    }
  }

  // ── Eliminar una historia ──
  Future<bool> deleteStory(String storyId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _supabase
          .from('company_culture_stories')
          .delete()
          .eq('id', storyId)
          .eq('company_user_id', uid);

      _invalidate(uid);
      return true;
    } catch (e) {
      debugPrint('❌ CompanyCultureService.deleteStory: $e');
      return false;
    }
  }
}
