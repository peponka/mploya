import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../screens/onboarding_pitch_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReelVideoBackground — Video layer del TikTokReelCard
//
// Muestra: estado sin-video, error de reproducción, spinner, o el video.
// Extraído de tiktok_reel_card.dart para reducir el tamaño del god file.
// ─────────────────────────────────────────────────────────────────────────────

class ReelVideoBackground extends StatelessWidget {
  final NexUser author;
  final VideoPlayerController? controller;
  final bool isInitialized;
  final bool hasError;

  const ReelVideoBackground({
    super.key,
    required this.author,
    required this.controller,
    required this.isInitialized,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          (author.videoUrl == null || author.videoUrl!.isEmpty)
              ? _buildNoVideoState(context)
              : hasError
                  ? _buildErrorState()
                  : (!isInitialized || controller == null)
                      ? const Center(
                          child: CupertinoActivityIndicator(color: Colors.white),
                        )
                      : SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: controller!.value.size.width > 0
                                  ? controller!.value.size.width
                                  : MediaQuery.of(context).size.width,
                              height: controller!.value.size.height > 0
                                  ? controller!.value.size.height
                                  : MediaQuery.of(context).size.height,
                              child: VideoPlayer(controller!),
                            ),
                          ),
                        ),
        ],
      ),
    );
  }

  Widget _buildNoVideoState(BuildContext context) {
    final isOwnProfile = author.id == Supabase.instance.client.auth.currentUser?.id;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.video_camera, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              isOwnProfile
                  ? 'Tu perfil está silencioso 🙈'
                  : 'Este perfil es silencioso 🙈',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isOwnProfile
                  ? 'Para aparecer en el Feed de Mploya, debes grabar tu Video-Pitch obligatoriamente.'
                  : 'Este usuario aún no ha grabado su Pitch.',
              style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4, decoration: TextDecoration.none),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            if (isOwnProfile)
              GestureDetector(
                onTap: () {
                  final isCompany = author.accountType == 'empresa';
                  Navigator.of(context).pushReplacement(
                    CupertinoPageRoute(builder: (_) => OnboardingPitchScreen(isCompany: isCompany)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                  decoration: BoxDecoration(
                    color: MployaTheme.brandAccent,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: MployaTheme.brandAccent.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: const Text(
                    'Grabar mi Video-Pitch',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, decoration: TextDecoration.none),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.yellow, size: 48),
          SizedBox(height: 16),
          Text('Error de reproducción', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
          SizedBox(height: 8),
          Text('El video fue cargado pero tu navegador (CORS) bloqueó\nla reproducción del simulador externo.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}
