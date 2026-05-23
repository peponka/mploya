/// Pantalla de notificaciones / alertas.
///
/// Muestra un banner de completar perfil, sección de notificaciones
/// recientes con ítems de conexión y match.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

// ─── Modelos mock ────────────────────────────────────────────────────

enum _NotificationType { connect, matchInterest, view }

class _NotificationItem {
  const _NotificationItem({
    required this.title,
    required this.timeAgo,
    required this.type,
    this.hasEmoji = false,
  });

  final String title;
  final String timeAgo;
  final _NotificationType type;
  final bool hasEmoji;
}

const _mockNotifications = [
  _NotificationItem(
    title: 'Tagua quiere conectar contigo',
    timeAgo: '3d',
    type: _NotificationType.connect,
  ),
  _NotificationItem(
    title: '⚡ Tagua mostró interés en tu perfil.',
    timeAgo: '3d',
    type: _NotificationType.matchInterest,
    hasEmoji: true,
  ),
];

// ─── Screen ──────────────────────────────────────────────────────────

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  final Set<int> _acceptedIndices = {};
  final Set<int> _declinedIndices = {};
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ──
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Text(
                  'Notificaciones',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: MployaColors.textPrimary,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms),

              // ── Amber banner ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE68A),
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Center(
                          child: Text(
                            '💡',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Completá tu perfil y grabá un video pitch para aumentar tu visibilidad.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF92400E),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms)
                  .slideY(begin: 0.05, curve: Curves.easeOut),

              const SizedBox(height: AppSpacing.xl),

              // ── Section header ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  'Recientes',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MployaColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Notification items ──
              ...List.generate(_mockNotifications.length, (i) {
                final notif = _mockNotifications[i];
                return Column(
                  children: [
                    _NotificationTile(
                      notification: notif,
                      isAccepted: _acceptedIndices.contains(i),
                      isDeclined: _declinedIndices.contains(i),
                      onAccept: notif.type == _NotificationType.connect
                          ? () {
                              setState(() => _acceptedIndices.add(i));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Conexión aceptada ✅'),
                                  backgroundColor: MployaColors.teal,
                                ),
                              );
                            }
                          : null,
                      onDecline: notif.type == _NotificationType.connect
                          ? () {
                              setState(() => _declinedIndices.add(i));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Conexión rechazada'),
                                  backgroundColor: MployaColors.textSecondary,
                                ),
                              );
                            }
                          : null,
                      onTap: () {
                        context.push('/profile/user?id=tagua');
                      },
                    )
                        .animate()
                        .fadeIn(
                          delay: Duration(milliseconds: 150 + i * 60),
                          duration: 400.ms,
                        )
                        .slideX(
                          begin: 0.03,
                          curve: Curves.easeOut,
                        ),
                    if (i < _mockNotifications.length - 1)
                      const Divider(
                        indent: AppSpacing.md + 48 + AppSpacing.md,
                        endIndent: AppSpacing.md,
                        height: 1,
                        color: MployaColors.borderLight,
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Notification tile ───────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    this.isAccepted = false,
    this.isDeclined = false,
    this.onAccept,
    this.onDecline,
    this.onTap,
  });
  final _NotificationItem notification;
  final bool isAccepted;
  final bool isDeclined;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _iconColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: MployaColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.timeAgo,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MployaColors.textTertiary,
                    ),
                  ),
                  // Accept/Decline buttons for connect notifications
                  if (onAccept != null && !isAccepted && !isDeclined) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            onPressed: onAccept,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              backgroundColor: MployaColors.teal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Aceptar',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: MployaColors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 28,
                          child: OutlinedButton(
                            onPressed: onDecline,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              side: const BorderSide(color: MployaColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                            child: Text(
                              'Rechazar',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: MployaColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isAccepted)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Conectado ✅',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MployaColors.teal,
                        ),
                      ),
                    ),
                  if (isDeclined)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Rechazado',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MployaColors.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    switch (notification.type) {
      case _NotificationType.connect:
        return Icons.person_add_outlined;
      case _NotificationType.matchInterest:
        return Icons.bolt_rounded;
      case _NotificationType.view:
        return Icons.visibility_outlined;
    }
  }

  Color get _iconColor {
    switch (notification.type) {
      case _NotificationType.connect:
        return MployaColors.teal;
      case _NotificationType.matchInterest:
        return MployaColors.orange;
      case _NotificationType.view:
        return MployaColors.blue;
    }
  }

  Color get _bgColor {
    switch (notification.type) {
      case _NotificationType.connect:
        return MployaColors.tealLight;
      case _NotificationType.matchInterest:
        return MployaColors.orangeSurface;
      case _NotificationType.view:
        return const Color(0xFFDBEAFE);
    }
  }
}
