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

// ─── Router ──────────────────────────────────────────────────────────

final router = GoRouter(
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

    // Allow public routes, onboarding, and /home (for demo)
    // Only block if user manually navigates to a deep route without auth
    if (!isLoggedIn && !isPublicRoute && !isOnboardingRoute && path != RoutePaths.home) {
      // Allow most routes for demo — only block edit/settings without login
      final isProtectedRoute = [
        RoutePaths.editProfile,
        RoutePaths.settings,
      ].contains(path);
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
      builder: (context, state) => const SkillAssessmentScreen(),
    ),
    GoRoute(
      path: RoutePaths.aiResume,
      builder: (context, state) => const AiResumeScreen(),
    ),
    GoRoute(
      path: RoutePaths.interviewPrep,
      builder: (context, state) => const InterviewPrepScreen(),
    ),
    GoRoute(
      path: RoutePaths.pitchChallenge,
      builder: (context, state) => const PitchChallengeScreen(),
    ),
    GoRoute(
      path: RoutePaths.boost,
      builder: (context, state) => const BoostScreen(),
    ),
    GoRoute(
      path: RoutePaths.analytics,
      builder: (context, state) => const AnalyticsScreen(),
    ),
    GoRoute(
      path: RoutePaths.vistas,
      builder: (context, state) => const ProfileViewsScreen(),
    ),
    GoRoute(
      path: RoutePaths.invite,
      builder: (context, state) => const InviteFriendsScreen(),
    ),

    // ─── Payment ─────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.payment,
      builder: (context, state) => PaymentScreen(
        product: state.extra as PaymentProduct?,
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
      builder: (context, state) {
        final conversationId = state.pathParameters['conversationId'] ?? '';
        return ChatScreen(conversationId: conversationId);
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
      builder: (context, state) => const EditProfileScreen(),
    ),

    // User Profile (other user)
    GoRoute(
      path: RoutePaths.userProfile,
      builder: (context, state) {
        final userId = state.uri.queryParameters['id'];
        return UserProfileScreen(userId: userId);
      },
    ),

    // Reviews
    GoRoute(
      path: RoutePaths.reviews,
      builder: (context, state) {
        final name = state.uri.queryParameters['company'] ?? 'Empresa';
        return ReviewsScreen(userName: name);
      },
    ),

    // ─── Map ──────────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.mapStandalone,
      builder: (context, state) => const MapScreen(),
    ),

    // ─── Settings ─────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.settings,
      builder: (context, state) => const SettingsScreen(),
    ),

    // ─── Profile Analysis (placeholder) ──────────────────────────
    GoRoute(
      path: RoutePaths.profileAnalysis,
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Análisis de Perfil')),
        body: const Center(
          child: Text('Análisis detallado de tu perfil — Próximamente'),
        ),
      ),
    ),

    // ─── Hashtags Edit (placeholder) ─────────────────────────────
    GoRoute(
      path: RoutePaths.hashtagsEdit,
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Editar Hashtags')),
        body: const Center(
          child: Text('Editar tus hashtags — Próximamente'),
        ),
      ),
    ),
  ],
);
