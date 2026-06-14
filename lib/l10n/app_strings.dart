// ─────────────────────────────────────────────────────────────────────────────
// Strings centralizados — Mploya
//
// Todos los textos de UI que estaban hardcodeados en español se centralizan
// aquí como paso previo a la migración completa a flutter_localizations/ARB.
//
// Uso:  import '../l10n/app_strings.dart';
//       Text(AppStrings.loginButton)
// ─────────────────────────────────────────────────────────────────────────────

class AppStrings {
  AppStrings._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const sessionExpired = 'Tu sesión expiró. Por favor, iniciá sesión nuevamente.';
  static const emailNotConfirmed = 'Email no confirmado. Revisa tu bandeja de entrada.';
  static const invalidCredentials = 'Email o contraseña incorrectos.';
  static const rateLimitExceeded = 'Demasiados intentos seguidos. Espera unos minutos e inténtalo de nuevo.';
  static const emailAlreadyRegistered = 'Ese email ya está registrado. Prueba a iniciar sesión.';
  static const signupDisabled = 'El registro está desactivado temporalmente. Contacta al equipo de SocialMploya.';
  static const weakPassword = 'La contraseña debe tener al menos 6 caracteres.';
  static const networkError = 'Error de conexión. Verifica tu internet o los permisos de API en tu panel de Supabase.';
  static const noInternet = 'Sin conexión a internet. Activa los datos móviles o el Wi-Fi e inténtalo de nuevo.';
  static const requestTimeout = 'La solicitud tardó demasiado. Comprueba tu conexión e inténtalo de nuevo.';
  static const noSession = 'Sin sesión activa.';
  static const loginButton = 'Iniciar Sesión';
  static const logoutButton = 'Cerrar Sesión';
  static const logoutIfNotLoading = 'Cerrar Sesión (Si no carga)';

  // ── Password Validation ──────────────────────────────────────────────────
  static const passwordTooShort = 'La contraseña debe tener al menos 8 caracteres.';
  static const passwordNeedsUppercase = 'La contraseña debe incluir al menos una mayúscula.';
  static const passwordNeedsNumber = 'La contraseña debe incluir al menos un número.';

  // ── Account Deletion (Apple 5.1.1 + GDPR Art. 17) ───────────────────────
  static const deleteAccountFailed = 'No se pudo eliminar la cuenta. '
      'Contactá a soporte@mploya.ai para completar el proceso.';
  static const deleteServiceUnavailable = 'El servicio de eliminación no está disponible. '
      'Contactá a soporte@mploya.ai para eliminar tu cuenta.';

  // ── Profile ──────────────────────────────────────────────────────────────
  static const loginToViewProfile = 'Inicia sesión para ver tu perfil';
  static const emptyProfile = 'Perfil vacío';
  static const editProfile = 'Editar Perfil';
  static const showInterest = 'Mostrar Interés';
  static const pending = 'Pendiente';
  static const contacts = 'Contactos';
  static const myProfile = 'Mi Perfil';
  static const profileSettings = 'Ajustes de Perfil';
  static const boostProfile = 'Destacar Perfil (Boost)';
  static const pitchChallenge = '🏆 Pitch Challenge Semanal';
  static const verifyCompany = '✅ Verificar Empresa';
  static const whoViewedProfile = 'Quién vio tu perfil →';
  static const connectionsLabel = 'conexiones';
  static const aboutSection = 'Acerca de';
  static const skillsSection = 'Habilidades';
  static const educationSection = 'Formación';
  static const myPortfolio = 'Mi Portfolio';
  static const viewAll = 'Ver todo';
  static const tapToValidate = 'Toca una habilidad para validar sus talentos 🌟';
  static const tapToDiscover = 'Toca un hashtag para descubrir quién más lo tiene 🔍';

  // ── Feed ──────────────────────────────────────────────────────────────────
  static const feedEmpty = 'No hay publicaciones aún';
  static const feedError = 'Error al cargar el feed';
  static const pullToRefresh = 'Desliza hacia abajo para actualizar';

  // ── Messaging ────────────────────────────────────────────────────────────
  static const inbox = 'Inbox';
  static const inboxEmpty = 'Inbox Vacío';
  static const inboxEmptySubtitle = 'Explora el feed inmersivo y haz match con profesionales increíbles para iniciar una conversación.';
  static const searchConnections = 'Buscar conexiones, mensajes...';
  static const recentMessages = 'Mensajes Recientes';
  static const newMatches = 'Nuevos Matches';
  static const startConversation = 'Inicia la conversación...';
  static const goToFeed = 'Ir al Feed';
  static const noSearchResults = 'Sin resultados para';
  static const dataProtected = 'Datos protegidos';
  static const noContactInfoAllowed = 'No podés compartir emails ni teléfonos por chat. '
      'Usá las herramientas de Mploya para coordinar entrevistas.';

  // ── Notifications ────────────────────────────────────────────────────────
  static const aiPanel = 'Panel IA';
  static const weeklyReport = 'Tu resumen semanal';
  static const recentActivity = 'Actividad reciente';
  static const markAsRead = 'Marcar leídas';
  static const allQuiet = 'Todo tranquilo por aquí.';
  static const views = 'Vistas';
  static const matches = 'Matches';
  static const replies = 'Replies';

  // ── Explore ──────────────────────────────────────────────────────────────
  static const gettingLocation = 'Obteniendo tu ubicación…';
  static const locationUnavailable = 'Ubicación no disponible';
  static const locationPermissionNeeded = 'Mploya necesita acceso a tu ubicación para mostrar profesionales cercanos.';
  static const openSettings = 'Abrir Ajustes';

  // ── Premium ──────────────────────────────────────────────────────────────
  static const tryPremium = 'Prueba Nexwork Pro Premium';
  static const multiplyMatches = 'Multiplica tus matches y vistas';
  static const paymentNotConfigured = 'Pasarela de pagos no configurada';

  // ── Moderation ───────────────────────────────────────────────────────────
  static const contentNotAllowed = 'Contenido no permitido';
  static const understood = 'Entendido';
  static const cancel = 'Cancelar';
  static const accept = 'Aceptar';
  static const reject = 'Rechazar';
  static const error = 'Error';
  static const ok = 'OK';

  // ── Story Viewer ─────────────────────────────────────────────────────────
  static const flashUpdate = 'Flash Update';
  static const sendMessage = 'Enviar un mensaje...';

  // ── Generic / Unexpected ─────────────────────────────────────────────────
  static String unexpectedError(String context) =>
      'Error inesperado ($context). Inténtalo de nuevo o contacta soporte.';
  static String authError(String message) =>
      'Error de autenticación: $message';
  static String dbError(String error) =>
      'Error de Red/DB:\n$error\nSi eres nuevo, verifica que completaste el Formulario de Perfil.';

  // ── Onboarding Tour (Candidate) ──────────────────────────────────────────
  static const tourCandidateTitle1 = 'Tu Video-Pitch';
  static const tourCandidateBody1 = 'Graba un video de 60 segundos contando quién sos y qué buscás. Los reclutadores lo verán primero.';
  static const tourCandidateTitle2 = 'Explora Oportunidades';
  static const tourCandidateBody2 = 'Desliza para descubrir empresas, startups y headhunters que buscan talento como vos.';
  static const tourCandidateTitle3 = 'Matches Inteligentes';
  static const tourCandidateBody3 = 'Nuestra IA conecta tu perfil con las oportunidades que mejor encajan con tu experiencia.';
  static const tourCandidateTitle4 = 'Tu Red Profesional';
  static const tourCandidateBody4 = 'Conecta, chatea y construí relaciones que impulsen tu carrera.';

  // ── Onboarding Tour (Company) ────────────────────────────────────────────
  static const tourCompanyTitle1 = 'Publica Vacantes';
  static const tourCompanyBody1 = 'Crea publicaciones atractivas y llega a miles de candidatos calificados.';
  static const tourCompanyTitle2 = 'Descubre Talento';
  static const tourCompanyBody2 = 'Explora perfiles, video-pitches y portfolios de candidatos en tiempo real.';
  static const tourCompanyTitle3 = 'Gestiona tu Pipeline';
  static const tourCompanyBody3 = 'Organiza candidatos, agenda entrevistas y colabora con tu equipo de hiring.';
  static const tourCompanyTitle4 = 'Employer Branding';
  static const tourCompanyBody4 = 'Mostrá la cultura de tu empresa y atraé al mejor talento con tu marca empleadora.';

  // ── Unsaved Changes Guard ────────────────────────────────────────────────
  static const unsavedChangesTitle = 'Cambios sin guardar';
  static const unsavedChangesBody = '¿Estás seguro que querés salir? Los cambios no guardados se perderán.';
  static const unsavedChangesDiscard = 'Descartar';
  static const unsavedChangesKeep = 'Seguir editando';

  // ── Feature Hints ────────────────────────────────────────────────────────
  static const hintDoubleTap = 'Toca dos veces para dar like';
  static const hintLongPressReactions = 'Mantené presionado para reaccionar';
  static const hintSwipeRefresh = 'Desliza hacia abajo para actualizar';
  static const hintLongPressNexus = 'Mantené presionado para ver opciones';
  static const hintSwipeDelete = 'Desliza para eliminar';
}
