import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider;
import '../theme/app_theme.dart';
import '../models/models.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Componentes reutilizables del sistema de diseño de Mploya.
///
/// Regla de disciplina de color (la que da la sensación de "limpio"):
///   naranja  = marca / acción principal
///   violeta  = "esto lo hace la IA"  (MployaTheme.aiAccent)
///   gris     = utilidad / secundario
///   verde/rojo/azul = solo estado (disponible, error, info)
///
/// Todo lo demás: blanco con texto negro/gris. Nada de gradientes ni colores
/// decorativos. Estos widgets encapsulan ese patrón para no repetirlo a mano
/// en cada pantalla.
/// ─────────────────────────────────────────────────────────────────────────

/// Tarjeta blanca contenedora (superficie de sección).
class MployaSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const MployaSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.isDark ? NexTheme.darkSurface : CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.isDark ? const Color(0xFF222222) : const Color(0xFFEDEFF2)),
      ),
      child: child,
    );
  }
}

/// Fila estándar: ícono + etiqueta (+ subtítulo) + trailing opcional + chevron.
/// El patrón escaneable de JobToday. Usar el mismo en todas las pantallas de
/// utilidad da la consistencia.
class MployaListRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback? onTap;
  final bool showChevron;

  const MployaListRow({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
    this.subtitle,
    this.trailingText,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 21, color: iconColor ?? context.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 15.5, color: context.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!, style: TextStyle(fontSize: 12.5, color: context.textTertiary)),
                  ],
                ],
              ),
            ),
            if (trailingText != null) ...[
              Text(trailingText!, style: TextStyle(fontSize: 13, color: context.textTertiary)),
              const SizedBox(width: 8),
            ],
            if (showChevron) Icon(CupertinoIcons.chevron_right, size: 16, color: context.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Agrupa varias [MployaListRow] en una sola tarjeta con divisores finos.
class MployaRowGroup extends StatelessWidget {
  final List<MployaListRow> rows;
  const MployaRowGroup({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return MployaSectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              Divider(height: 0.5, thickness: 0.5, indent: 51, color: context.dividerColor),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta de progreso prominente — el motivador estilo JobToday
/// ("Lo que te falta para que te descubran"). Muestra % + barra segmentada +
/// el próximo paso que falta, con acción. Se oculta sola al 100%.
class MployaProgressCard extends StatelessWidget {
  final NexUser profile;
  final VoidCallback? onTap;
  const MployaProgressCard({super.key, required this.profile, this.onTap});

  bool get _isCompany =>
      profile.accountType == 'empresa' || profile.accountType == 'headhunter';

  /// Devuelve la lista de pasos (label del paso, si está completo).
  List<({String pending, bool done})> _steps() {
    final v = profile.videoUrl?.isNotEmpty == true;
    final avatar = profile.avatarUrl?.isNotEmpty == true;
    final headline = profile.headline.isNotEmpty && profile.headline != 'Directivo Stealth';
    final tags = profile.tags.isNotEmpty;
    final about = profile.about?.isNotEmpty == true;
    final company = profile.company?.isNotEmpty == true;
    return [
      (pending: 'grabá tu video-pitch', done: v),
      (pending: 'agregá una foto de perfil', done: avatar),
      (pending: _isCompany ? 'escribí qué busca tu empresa' : 'escribí tu titular', done: headline),
      (pending: 'agregá tus skills o hashtags', done: tags),
      (pending: 'completá tu bio', done: about),
      if (_isCompany) (pending: 'agregá el nombre de tu empresa', done: company),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps();
    final total = steps.length;
    final done = steps.where((s) => s.done).length;
    if (done >= total) return const SizedBox.shrink();

    final nextPending = steps.firstWhere((s) => !s.done, orElse: () => steps.first).pending;
    const accent = MployaTheme.brandAccent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MployaSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isCompany ? 'Lo que te falta para atraer talento' : 'Lo que te falta para que te descubran',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Completá estos pasos y las empresas empiezan a verte.',
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (int i = 0; i < total; i++) ...[
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < done ? accent : (context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0)),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  if (i < total - 1) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Siguiente: $nextPending',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: MployaTheme.accentDark),
                  ),
                ),
                const Icon(CupertinoIcons.arrow_right, size: 15, color: MployaTheme.accentDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
