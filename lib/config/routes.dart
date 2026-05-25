/// Configuración de rutas de navegación de mploya.ai usando GoRouter.
///
/// Define todas las rutas de la aplicación, incluyendo el flujo de
/// autenticación, onboarding por rol, navegación principal, tools,
/// hashtags, video recording y messaging.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Auth & Onboarding
import 'package:mploya/features/auth/screens/splash_screen.dart';
import 'package:mploya/features/auth/screens/landing_screen.dart';
import 'package:mploya/features/auth/screens/login_screen.dart';
import 'package:mploya/features/auth/screens/register_screen.dart';
import 'package:mploya/features/auth/screens/forgot_password_screen.dart';
import 'package:mploya/features/onboarding/screens/candidate_form_screen.dart';
import 'package:mploya/features/onboarding/screens/confidential_form_screen.dart';
import 'package:mploya/features/onboarding/screens/company_form_screen.dart';
import 'package:mploya/features/onboarding/screens/video_intro_screen.dart';

// Home
import 'package:mploya/features/home/screens/home_shell.dart';

// Hashtags
import 'package:mploya/features/hashtags/screens/trending_hashtags_screen.dart';
import 'package:mploya/features/hashtags/screens/hashtag_detail_screen.dart';

// Tools
import 'package:mploya/features/tools/screens/skill_assessment_screen.dart';
import 'package:mploya/features/tools/screens/ai_resume_screen.dart';
import 'package:mploya/features/tools/screens/interview_prep_screen.dart';
import 'package:mploya/features/tools/screens/pitch_challenge_screen.dart';
import 'package:mploya/features/tools/screens/boost_screen.dart';
import 'package:mploya/features/tools/screens/analytics_screen.dart';
import 'package:mploya/features/tools/screens/profile_views_screen.dart';
import 'package:mploya/features/tools/screens/invite_friends_screen.dart';

// Payment
import 'package:mploya/features/payment/screens/payment_screen.dart';

// Video
import 'package:mploya/features/video/screens/video_reply_screen.dart';
import 'package:mploya/features/video/screens/new_story_screen.dart';

// Messaging
import 'package:mploya/features/messaging/screens/chat_screen.dart';
import 'package:mploya/features/messaging/screens/video_call_lobby_screen.dart';

// Profile
import 'package:mploya/features/profile/screens/edit_profile_screen.dart';
import 'package:mploya/features/profile/screens/user_profile_screen.dart';

// Reviews
import 'package:mploya/features/reviews/screens/reviews_screen.dart';

// Settings
import 'package:mploya/features/settings/screens/settings_screen.dart';

// Maps
import 'package:mploya/features/maps/screens/map_screen.dart';

// ─── Route Paths ─────────────────────────────────────────────────────

abstract final class RoutePaths {
  static const splash = '/';
  static const landing = '/landing';

  // Auth
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  // Onboarding
  static const onboardingCandidato = '/onboarding/candidato';
  static const onboardingConfidencial = '/onboarding/confidencial';
  static const onboardingEmpresa = '/onboarding/empresa';
  static const onboardingVideo = '/onboarding/video';

  // Main App
  static const home = '/home';
  static const feed = '/home/feed';
  static const map = '/home/map';
  static const chat = '/home/chat';
  static const profile = '/home/profile';

  // Hashtags
  static const trendingHashtags = '/hashtags/trending';
  static const hashtagDetail = '/hashtags/detail';

  // Tools
  static const skillAssessment = '/tools/skill-assessment';
  static const aiResume = '/tools/ai-resume';
  static const interviewPrep = '/tools/interview-prep';
  static const pitchChallenge = '/tools/pitch-challenge';
  static const boost = '/tools/boost';
  static const analytics = '/tools/analytics';
  static const vistas = '/tools/vistas';
  static const invite = '/tools/invite';

  // Payment
  static const payment = '/payment';

  // Video
  static const videoReply = '/video/reply';
  static const newStory = '/video/new-story';

  // Messaging
  static const chatConversation = '/chat/:conversationId';
  static const videoCallLobby = '/video-call/lobby';

  // Profile
  static const editProfile = '/profile/edit';
  static const userProfile = '/profile/user';

  // Reviews
  static const reviews = '/reviews';

  // Settings
  static const settings = '/settings';
  static const mapStandalone = '/map';

  // Profile extras
  static const profileAnalysis = '/profile/analysis';
  static const hashtagsEdit = '/hashtags/edit';
}

// ─── Navigator Key ───────────────────────────────────────────────────

/// Global navigator key for navigation from outside the widget tree
/// (e.g., notification taps).
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

// ─── Page Transition Helper ──────────────────────────────────────────

/// Builds a [CustomTransitionPage] with a fade transition for GoRouter routes.
CustomTransitionPage<void> buildPageWithFadeTransition({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

// ─── Router ──────────────────────────────────────────────────────────

final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: RoutePaths.splash,
  debugLogDiagnostics: false,
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final path = state.matchedLocation;

    // Public routes that never need auth
    final isPublicRoute = [
      RoutePaths.splash,
      RoutePaths.landing,
      RoutePaths.login,
      RoutePaths.register,
      RoutePaths.forgotPassword,
    ].contains(path);

    final isOnboardingRoute = path.startsWith('/onboarding');

    // When logged in, skip auth screens (except splash)
    if (isLoggedIn && isPublicRoute && path != RoutePaths.splash) {
      return RoutePaths.home;
    }

    // Allow public routes, onboarding, and /home (for demo).
    // Block protected routes when not authenticated.
    if (!isLoggedIn && !isPublicRoute && !isOnboardingRoute && path != RoutePaths.home) {
      // Routes that require authentication:
      const protectedPrefixes = [
        '/profile/edit',
        '/settings',
        '/payment',
        '/chat',
        '/video-call',
        '/tools',
        '/video/reply',
      ];
      final isProtectedRoute =
          protectedPrefixes.any((prefix) => path.startsWith(prefix));
      if (isProtectedRoute) return RoutePaths.landing;
    }

    return null;
  },
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Página no encontrada')),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.explore_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('404 — Esta página no existe', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Ir al inicio'),
          ),
        ],
      ),
    ),
  ),
  routes: [
    // ─── Auth & Splash ───────────────────────────────────────────
    GoRoute(
      path: RoutePaths.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: RoutePaths.landing,
      builder: (context, state) => const LandingScreen(),
    ),
    GoRoute(
      path: RoutePaths.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: RoutePaths.register,
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: RoutePaths.forgotPassword,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    // ─── Onboarding ──────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.onboardingCandidato,
      builder: (context, state) => const CandidateFormScreen(),
    ),
    GoRoute(
      path: RoutePaths.onboardingConfidencial,
      builder: (context, state) => const ConfidentialFormScreen(),
    ),
    GoRoute(
      path: RoutePaths.onboardingEmpresa,
      builder: (context, state) => const CompanyFormScreen(),
    ),
    GoRoute(
      path: RoutePaths.onboardingVideo,
      builder: (context, state) => const VideoIntroScreen(),
    ),

    // ─── Home (shell con tabs) ───────────────────────────────────
    GoRoute(
      path: RoutePaths.home,
      builder: (context, state) => const HomeShell(),
    ),

    // ─── Hashtags ────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.trendingHashtags,
      builder: (context, state) => const TrendingHashtagsScreen(),
    ),
    GoRoute(
      path: RoutePaths.hashtagDetail,
      builder: (context, state) {
        final hashtag = state.uri.queryParameters['name'] ??
            state.uri.queryParameters['tag'] ??
            'wealth';
        return HashtagDetailScreen(hashtag: hashtag);
      },
    ),

    // ─── Tools ───────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.skillAssessment,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context, state: state, child: const SkillAssessmentScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.aiResume,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context, state: state, child: const AiResumeScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.interviewPrep,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context, state: state, child: const InterviewPrepScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.pitchChallenge,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context, state: state, child: const PitchChallengeScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.boost,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context, state: state, child: const BoostScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.analytics,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context, state: state, child: const AnalyticsScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.vistas,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context, state: state, child: const ProfileViewsScreen(),
      ),
    ),
    GoRoute(
      path: RoutePaths.invite,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context, state: state, child: const InviteFriendsScreen(),
      ),
    ),

    // ─── Payment ─────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.payment,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context,
        state: state,
        child: PaymentScreen(product: state.extra as PaymentProduct?),
      ),
    ),

    // ─── Video Recording ─────────────────────────────────────────
    GoRoute(
      path: RoutePaths.videoReply,
      pageBuilder: (context, state) {
        final recipientName =
            state.uri.queryParameters['name'] ?? 'Usuario';
        return MaterialPage(
          fullscreenDialog: true,
          child: VideoReplyScreen(recipientName: recipientName),
        );
      },
    ),
    GoRoute(
      path: RoutePaths.newStory,
      pageBuilder: (context, state) => const MaterialPage(
        fullscreenDialog: true,
        child: NewStoryScreen(),
      ),
    ),

    // ─── Messaging ───────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.chatConversation,
      pageBuilder: (context, state) {
        final conversationId = state.pathParameters['conversationId'] ?? '';
        return buildPageWithFadeTransition(
          context: context,
          state: state,
          child: ChatScreen(conversationId: conversationId),
        );
      },
    ),
    GoRoute(
      path: RoutePaths.videoCallLobby,
      pageBuilder: (context, state) {
        final title =
            state.uri.queryParameters['title'] ?? 'Entrevista Mploya';
        return MaterialPage(
          fullscreenDialog: true,
          child: VideoCallLobbyScreen(meetingTitle: title),
        );
      },
    ),

    // ─── Profile ─────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.editProfile,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context, state: state, child: const EditProfileScreen(),
      ),
    ),

    // User Profile (other user)
    GoRoute(
      path: RoutePaths.userProfile,
      pageBuilder: (context, state) {
        final userId = state.uri.queryParameters['id'];
        return buildPageWithFadeTransition(
          context: context,
          state: state,
          child: UserProfileScreen(userId: userId),
        );
      },
    ),

    // Reviews
    GoRoute(
      path: RoutePaths.reviews,
      pageBuilder: (context, state) {
        final name = state.uri.queryParameters['company'] ?? 'Empresa';
        return buildPageWithFadeTransition(
          context: context,
          state: state,
          child: ReviewsScreen(userName: name),
        );
      },
    ),

    // ─── Map ──────────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.mapStandalone,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context, state: state, child: const MapScreen(),
      ),
    ),

    // ─── Settings ─────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.settings,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context, state: state, child: const SettingsScreen(),
      ),
    ),

    // ─── Profile Analysis (placeholder) ──────────────────────────
    GoRoute(
      path: RoutePaths.profileAnalysis,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context,
        state: state,
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.pop()),
            title: const Text('Análisis de Perfil'),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: Colors.orange.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'Análisis de Perfil',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'El análisis detallado de tu perfil estará disponible pronto. '
                    'Aquí podrás ver métricas de visibilidad, engagement y recomendaciones personalizadas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),

    // ─── Hashtags Edit (placeholder) ─────────────────────────────
    GoRoute(
      path: RoutePaths.hashtagsEdit,
      pageBuilder: (context, state) => buildPageWithFadeTransition(
        context: context,
        state: state,
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.pop()),
            title: const Text('Editar Hashtags'),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tag_rounded, size: 64, color: Colors.orange.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'Editar Hashtags',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La edición de hashtags estará disponible pronto. '
                    'Podrás agregar, eliminar y reordenar tus hashtags profesionales.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ],
);
