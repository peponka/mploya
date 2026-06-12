import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Barra térmica (Heatmap) que crea urgencia visual (FOMO).
/// Calcula la "frescura" de la publicación según [createdAt].
/// 
/// - < 24 hrs: "ALTA DEMANDA" (Rojo/Naranja ardiente) - 100% de barra.
/// - < 3 días: "CRECIENDO" (Amarillo intenso) - 70% de barra.
/// - < 7 días: "REGULAR" (Verde/Grisáceo) - 40% de barra.
/// - > 7 días: "ENFRIÁNDOSE" (Gris claro) - 15% de barra.
class JobHeatmapBar extends StatelessWidget {
  final DateTime createdAt;

  const JobHeatmapBar({
    super.key,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    final hours = difference.inHours;

    double fillRatio = 0.15;
    List<Color> gradientColors = [Colors.grey.shade400, Colors.grey.shade300];
    String labelText = 'Poco movimiento';
    IconData icon = CupertinoIcons.snow;
    Color iconColor = Colors.grey.shade600;

    if (hours <= 24) {
      fillRatio = 1.0;
      gradientColors = [const Color(0xFFFF3B30), const Color(0xFFFF9500)]; // Rojo intenso a Naranja
      labelText = '¡Muy reciente! Alta demanda';
      icon = CupertinoIcons.flame_fill;
      iconColor = const Color(0xFFFF3B30);
    } else if (hours <= 72) {
      fillRatio = 0.70;
      gradientColors = [const Color(0xFFFF9500), const Color(0xFFFFCC00)]; // Naranja a Amarillo
      labelText = 'En crecimiento';
      icon = CupertinoIcons.flame;
      iconColor = const Color(0xFFFF9500);
    } else if (hours <= 168) { // 7 días
      fillRatio = 0.40;
      gradientColors = [const Color(0xFF34C759), const Color(0xFF30D158)]; // Verde
      labelText = 'Regular';
      icon = CupertinoIcons.clock;
      iconColor = const Color(0xFF34C759);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              labelText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.textPrimary.withValues(alpha: 0.8),
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            Text(
              _formatTimeAgo(difference),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: context.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // La barra térmica (Background + Gradient Fill)
        Stack(
          children: [
            // Background bar
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            // Foreground bar (Animada para efecto UI)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: fillRatio),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutExpo,
              builder: (context, value, child) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      height: 6,
                      width: constraints.maxWidth * value,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: fillRatio > 0.6 ? [
                          BoxShadow(
                            color: gradientColors.first.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ] : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  String _formatTimeAgo(Duration diff) {
    if (diff.inHours < 1) return 'Hace instantes';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'Hace 1 día';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    final weeks = (diff.inDays / 7).floor();
    if (weeks == 1) return 'Hace 1 sem';
    return 'Hace $weeks sem';
  }
}
