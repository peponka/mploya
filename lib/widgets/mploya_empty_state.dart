import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MployaEmptyState — Premium illustrated empty state widget
//
// Usage:
//   MployaEmptyState.inbox(onAction: () => navigateToFeed())
//   MployaEmptyState.savedJobs(onAction: () => Navigator.pop(context))
//   MployaEmptyState.notifications()
//   MployaEmptyState.custom(title: '...', subtitle: '...', image: '...', ...)
// ─────────────────────────────────────────────────────────────────────────────

class MployaEmptyState extends StatelessWidget {
  final String? imagePath;
  final IconData? fallbackIcon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MployaEmptyState({
    super.key,
    this.imagePath,
    this.fallbackIcon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  /// Empty inbox state.
  factory MployaEmptyState.inbox({VoidCallback? onAction}) {
    return MployaEmptyState(
      imagePath: 'assets/images/empty_states/empty_inbox.png',
      fallbackIcon: CupertinoIcons.chat_bubble_2_fill,
      title: 'Inbox Vacío',
      subtitle: 'Explora el feed inmersivo y haz match con profesionales increíbles para iniciar una conversación.',
      actionLabel: 'Ir al Feed',
      onAction: onAction,
    );
  }

  /// Empty saved jobs state.
  factory MployaEmptyState.savedJobs({VoidCallback? onAction}) {
    return MployaEmptyState(
      imagePath: 'assets/images/empty_states/empty_saved_jobs.png',
      fallbackIcon: CupertinoIcons.bookmark,
      title: 'Sin vacantes guardadas',
      subtitle: 'Tocá el ícono 🔖 en las vacantes que te interesen para guardarlas aquí.',
      actionLabel: 'Explorar vacantes',
      onAction: onAction,
    );
  }

  /// Empty notifications state.
  factory MployaEmptyState.notifications() {
    return MployaEmptyState(
      imagePath: 'assets/images/empty_states/empty_notifications.png',
      fallbackIcon: CupertinoIcons.bell,
      title: 'Todo tranquilo',
      subtitle: 'No tenés notificaciones nuevas. Seguí explorando el feed y conectando con profesionales.',
    );
  }

  /// Fully custom empty state.
  factory MployaEmptyState.custom({
    required String title,
    required String subtitle,
    IconData? icon,
    String? imagePath,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return MployaEmptyState(
      imagePath: imagePath,
      fallbackIcon: icon ?? CupertinoIcons.tray,
      title: title,
      subtitle: subtitle,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration or fallback icon
            _buildIllustration(context),
            const SizedBox(height: 28),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: context.textTertiary,
                height: 1.4,
              ),
            ),

            // Action button
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 28),
              CupertinoButton(
                color: MployaTheme.brandAccent,
                borderRadius: BorderRadius.circular(16),
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration(BuildContext context) {
    if (imagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          imagePath!,
          width: 140,
          height: 140,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallbackIcon(context),
        ),
      );
    }
    return _buildFallbackIcon(context);
  }

  Widget _buildFallbackIcon(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: context.brandAccent.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(
        fallbackIcon ?? CupertinoIcons.tray,
        size: 40,
        color: context.brandAccent.withValues(alpha: 0.4),
      ),
    );
  }
}
