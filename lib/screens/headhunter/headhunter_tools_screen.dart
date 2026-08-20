import 'package:flutter/cupertino.dart';

import '../../widgets/ds/mploya_ds.dart';
import '../jobs_screen.dart';
import '../messaging_screen.dart';
import '../saved_profiles_screen.dart';
import 'headhunter_interviews_screen.dart';
import 'headhunter_publish_job_screen.dart';
import 'headhunter_talent_pool_screen.dart';

/// Herramientas de Headhunter.
///
/// Migrada al sistema de diseño (18/8/2026), 10ª y última pantalla de
/// este rediseño — mismo patrón de `headhunter_dashboard_screen.dart`.
///
/// SIN mockup dedicado (accesos directos genéricos, sin composición
/// propia en FINAL_SCREENS). Patrón:
///
///   · Accesos rápidos (2 arriba) → [MpCard] + [MpIconTile] + label,
///     reemplazando el `Container` a mano.
///   · Grupos de herramientas → [MpRowGroup] de [MpListRow] (`leading`:
///     [MpIconTile], `subtitle`, chevron por defecto).
///   · Aviso de alcance ("IA, clientes, evaluaciones y plantillas...")
///     sin cambios de fondo, solo tokenizado.
class HeadhunterToolsScreen extends StatelessWidget {
  const HeadhunterToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: Builder(
        builder: (context) {
          final s = context.mp;
          return CupertinoPageScaffold(
            backgroundColor: s.bg,
            navigationBar: CupertinoNavigationBar(
              middle: const Text('Mis herramientas'),
              backgroundColor: s.card,
              border: null,
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  MpTokens.screenPadding,
                  MpTokens.space20,
                  MpTokens.screenPadding,
                  MpTokens.space40,
                ),
                children: [
                  Text('Gestiona tu reclutamiento', style: MpTokens.h1.copyWith(color: s.text)),
                  const SizedBox(height: MpTokens.space4),
                  Text(
                    'Accesos conectados a funciones reales de tu cuenta',
                    style: MpTokens.body.copyWith(color: s.textSecondary),
                  ),
                  const SizedBox(height: MpTokens.space24),
                  Row(
                    children: [
                      Expanded(
                        child: _quick(
                          context,
                          CupertinoIcons.calendar,
                          'Entrevistas',
                          MpTokens.catOrange,
                          const HeadhunterInterviewsScreen(),
                        ),
                      ),
                      const SizedBox(width: MpTokens.space12),
                      Expanded(
                        child: _quick(
                          context,
                          CupertinoIcons.bookmark_fill,
                          'Guardados',
                          MpTokens.success,
                          const SavedProfilesScreen(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MpTokens.space24),
                  MpSectionHeader(title: 'Talento y búsquedas'),
                  const SizedBox(height: MpTokens.space12),
                  MpRowGroup(
                    rows: [
                      MpListRow(
                        leading: const MpIconTile(icon: CupertinoIcons.person_2_fill, color: MpTokens.primary),
                        title: 'Talent Pool',
                        subtitle: 'Talento público disponible',
                        onTap: () => _push(context, const HeadhunterTalentPoolScreen()),
                      ),
                      MpListRow(
                        leading: const MpIconTile(icon: CupertinoIcons.briefcase_fill, color: MpTokens.catBlue),
                        title: 'Mis vacantes',
                        subtitle: 'Posiciones publicadas desde tu cuenta',
                        onTap: () => _push(context, const JobsScreen()),
                      ),
                      MpListRow(
                        leading: const MpIconTile(icon: CupertinoIcons.add_circled_solid, color: MpTokens.catPurple),
                        title: 'Publicar vacante',
                        subtitle: 'Crea una posición con campos reales',
                        onTap: () => _push(context, const HeadhunterPublishJobScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: MpTokens.space24),
                  MpSectionHeader(title: 'Comunicación'),
                  const SizedBox(height: MpTokens.space12),
                  MpRowGroup(
                    rows: [
                      MpListRow(
                        leading: const MpIconTile(icon: CupertinoIcons.chat_bubble_2_fill, color: MpTokens.catGreen),
                        title: 'Mensajes',
                        subtitle: 'Conversaciones activas',
                        onTap: () => _push(context, const MessagingScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: MpTokens.space20),
                  Text(
                    'Las herramientas de IA, clientes, evaluaciones y plantillas se habilitarán solo cuando exista soporte real.',
                    textAlign: TextAlign.center,
                    style: MpTokens.caption.copyWith(color: s.textTertiary, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _quick(BuildContext context, IconData icon, String label, Color color, Widget target) => MpCard(
    onTap: () => _push(context, target),
    padding: const EdgeInsets.all(MpTokens.space12),
    child: SizedBox(
      height: 88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MpIconTile(icon: icon, color: color, size: 36),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MpTokens.bodyStrong.copyWith(color: context.mp.text),
          ),
        ],
      ),
    ),
  );

  void _push(BuildContext context, Widget target) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => target));
  }
}
