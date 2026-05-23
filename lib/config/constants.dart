/// Constantes globales de la aplicación mploya.
///
/// Centraliza todas las cadenas de texto, valores numéricos y rutas
/// que se reutilizan a lo largo de la aplicación.
library;

// ─────────────────────────────────────────────
// App
// ─────────────────────────────────────────────

/// Nombre visible de la aplicación.
const String kAppName = 'mploya';

/// Versión semántica de la app (sincronizada con pubspec.yaml).
const String kAppVersion = '0.1.0';

/// Build number de la app.
const int kAppBuildNumber = 1;

/// Descripción corta de la aplicación.
const String kAppDescription = 'Plataforma de empleo impulsada por IA';

/// Paquete de la app en Android / bundle ID en iOS.
const String kPackageName = 'com.mploya.ai';

// ─────────────────────────────────────────────
// Tablas de Supabase
// ─────────────────────────────────────────────

/// Clase contenedora de los nombres de tabla en Supabase.
///
/// Usar siempre estas constantes para evitar errores tipográficos
/// en las consultas a la base de datos.
abstract final class SupabaseTables {
  static const String users = 'users';
  static const String jobs = 'jobs';
  static const String applications = 'applications';
  static const String messages = 'messages';
  static const String conversations = 'conversations';
  static const String notifications = 'notifications';
  static const String savedJobs = 'saved_jobs';
  static const String companies = 'companies';
}

/// Nombres de los buckets de almacenamiento en Supabase Storage.
abstract final class SupabaseBuckets {
  static const String avatars = 'avatars';
  static const String resumes = 'resumes';
  static const String companyLogos = 'company_logos';
  static const String chatAttachments = 'chat_attachments';
}

// ─────────────────────────────────────────────
// Rutas de Assets
// ─────────────────────────────────────────────

abstract final class AssetPaths {
  // Imágenes
  static const String _imagesBase = 'assets/images';
  static const String logo = '$_imagesBase/logo.png';
  static const String logoWhite = '$_imagesBase/logo_white.png';
  static const String onboarding1 = '$_imagesBase/onboarding_1.png';
  static const String onboarding2 = '$_imagesBase/onboarding_2.png';
  static const String onboarding3 = '$_imagesBase/onboarding_3.png';
  static const String placeholderAvatar = '$_imagesBase/placeholder_avatar.png';
  static const String emptyState = '$_imagesBase/empty_state.png';

  // Íconos SVG
  static const String _iconsBase = 'assets/icons';
  static const String iconJobs = '$_iconsBase/ic_jobs.svg';
  static const String iconMessages = '$_iconsBase/ic_messages.svg';
  static const String iconMap = '$_iconsBase/ic_map.svg';
  static const String iconSaved = '$_iconsBase/ic_saved.svg';
  static const String iconProfile = '$_iconsBase/ic_profile.svg';

  // Animaciones Lottie / Rive
  static const String _animationsBase = 'assets/animations';
  static const String loadingAnimation = '$_animationsBase/loading.json';
  static const String successAnimation = '$_animationsBase/success.json';
  static const String errorAnimation = '$_animationsBase/error.json';
}

// AnimDurations ahora vive en theme.dart

// ─────────────────────────────────────────────
// Paginación
// ─────────────────────────────────────────────

abstract final class Pagination {
  /// Cantidad de elementos por página por defecto.
  static const int defaultPageSize = 20;

  /// Cantidad de elementos por página en listas de chat.
  static const int chatPageSize = 30;

  /// Cantidad de elementos por página en búsqueda de empleos.
  static const int jobsPageSize = 15;
}

// ─────────────────────────────────────────────
// Mapa
// ─────────────────────────────────────────────

abstract final class MapDefaults {
  /// Latitud central predeterminada (Ciudad de México).
  static const double centerLatitude = 19.4326;

  /// Longitud central predeterminada (Ciudad de México).
  static const double centerLongitude = -99.1332;

  /// Nivel de zoom inicial del mapa.
  static const double initialZoom = 12.0;

  /// Zoom mínimo permitido.
  static const double minZoom = 5.0;

  /// Zoom máximo permitido.
  static const double maxZoom = 18.0;

  /// Radio de búsqueda predeterminado en kilómetros.
  static const double defaultSearchRadiusKm = 25.0;
}

// ─────────────────────────────────────────────
// Validaciones
// ─────────────────────────────────────────────

abstract final class Validators {
  /// Longitud mínima para contraseñas.
  static const int minPasswordLength = 8;

  /// Tamaño máximo de archivo para CV/currículum (5 MB).
  static const int maxResumeFileSizeBytes = 5 * 1024 * 1024;

  /// Tamaño máximo de imagen de avatar (2 MB).
  static const int maxAvatarFileSizeBytes = 2 * 1024 * 1024;

  /// Extensiones permitidas para CV.
  static const List<String> allowedResumeExtensions = ['pdf', 'doc', 'docx'];
}

// ─────────────────────────────────────────────
// Realtime channels
// ─────────────────────────────────────────────

abstract final class RealtimeChannels {
  static const String messages = 'realtime:messages';
  static const String notifications = 'realtime:notifications';
  static const String onlineStatus = 'realtime:online_status';
}
