import 'package:flutter/cupertino.dart';

import '../jobs_screen.dart';
import '../messaging_screen.dart';
import '../saved_profiles_screen.dart';
import 'headhunter_interviews_screen.dart';
import 'headhunter_pipeline_screen.dart';
import 'headhunter_publish_job_screen.dart';
import 'headhunter_talent_pool_screen.dart';

class HeadhunterToolsScreen extends StatelessWidget {
  const HeadhunterToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Mis herramientas'),
        backgroundColor: CupertinoColors.white,
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          children: [
            const Text(
              'Gestiona tu reclutamiento',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Accesos conectados a funciones reales de tu cuenta',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B778C)),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _quick(
                    context,
                    CupertinoIcons.person_3_fill,
                    'Pipeline',
                    const Color(0xFF4C2CF3),
                    const HeadhunterPipelineScreen(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quick(
                    context,
                    CupertinoIcons.calendar,
                    'Entrevistas',
                    const Color(0xFFFF8A00),
                    const HeadhunterInterviewsScreen(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quick(
                    context,
                    CupertinoIcons.bookmark_fill,
                    'Guardados',
                    const Color(0xFF24A66A),
                    const SavedProfilesScreen(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            const Text(
              'Talento y busquedas',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),
            const SizedBox(height: 10),
            _group([
              _ToolItem(
                CupertinoIcons.person_2_fill,
                const Color(0xFF4C2CF3),
                'Talent Pool',
                'Talento publico disponible',
                const HeadhunterTalentPoolScreen(),
              ),
              _ToolItem(
                CupertinoIcons.briefcase_fill,
                const Color(0xFF1677FF),
                'Mis vacantes',
                'Posiciones publicadas desde tu cuenta',
                const JobsScreen(),
              ),
              _ToolItem(
                CupertinoIcons.add_circled_solid,
                const Color(0xFF8B5CF6),
                'Publicar vacante',
                'Crea una posicion con campos reales',
                const HeadhunterPublishJobScreen(),
              ),
            ], context),
            const SizedBox(height: 24),
            const Text(
              'Comunicacion',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),
            const SizedBox(height: 10),
            _group([
              _ToolItem(
                CupertinoIcons.chat_bubble_2_fill,
                const Color(0xFF12A594),
                'Mensajes',
                'Conversaciones activas',
                const MessagingScreen(),
              ),
            ], context),
            const SizedBox(height: 18),
            const Text(
              'Las herramientas de IA, clientes, evaluaciones y plantillas se habilitaran solo cuando exista soporte real.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF7C879A),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quick(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    Widget target,
  ) => GestureDetector(
    onTap: () => _push(context, target),
    child: Container(
      height: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE5E9F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF172033),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _group(List<_ToolItem> items, BuildContext context) => Container(
    decoration: BoxDecoration(
      color: CupertinoColors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFE5E9F0)),
    ),
    child: Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _push(context, items[index].target),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: items[index].color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      items[index].icon,
                      color: items[index].color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[index].title,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF172033),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[index].subtitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF7C879A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: Color(0xFF9AA4B5),
                  ),
                ],
              ),
            ),
          ),
          if (index < items.length - 1)
            const Padding(
              padding: EdgeInsets.only(left: 66),
              child: SizedBox(
                height: 1,
                child: ColoredBox(color: Color(0xFFE9EDF3)),
              ),
            ),
        ],
      ],
    ),
  );

  void _push(BuildContext context, Widget target) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => target));
  }
}

class _ToolItem {
  const _ToolItem(
    this.icon,
    this.color,
    this.title,
    this.subtitle,
    this.target,
  );

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget target;
}
