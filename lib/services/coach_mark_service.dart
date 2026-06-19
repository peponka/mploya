import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

// ── GlobalKeys accesibles desde cualquier widget ──────────────────────────────

// Navegación (sidebar web / tab bar mobile — misma key, un solo entorno a la vez)
final GlobalKey cmNavFeedKey    = GlobalKey(debugLabel: 'cm_nav_feed');
final GlobalKey cmNavExploreKey = GlobalKey(debugLabel: 'cm_nav_explore');
final GlobalKey cmNavMatchKey   = GlobalKey(debugLabel: 'cm_nav_match');
final GlobalKey cmNavAlertsKey  = GlobalKey(debugLabel: 'cm_nav_alerts');
final GlobalKey cmNavProfileKey = GlobalKey(debugLabel: 'cm_nav_profile');
final GlobalKey cmNavJobsKey    = GlobalKey(debugLabel: 'cm_nav_jobs');

// Feed — se asignan en el primer TikTokReelCard (isFirstCard == true)
final GlobalKey cmFeedActionsKey   = GlobalKey(debugLabel: 'cm_feed_actions');
final GlobalKey cmFeedMatchBadgeKey = GlobalKey(debugLabel: 'cm_feed_match_badge');
final GlobalKey cmFeedJobsBtnKey   = GlobalKey(debugLabel: 'cm_feed_jobs_btn');
final GlobalKey cmFeedMsgBtnKey    = GlobalKey(debugLabel: 'cm_feed_msg_btn');
final GlobalKey cmFeedBellBtnKey   = GlobalKey(debugLabel: 'cm_feed_bell_btn');

// ── Servicio ──────────────────────────────────────────────────────────────────

class CoachMarkService {
  CoachMarkService._();

  static String get _uid =>
      Supabase.instance.client.auth.currentUser?.id ?? 'anon';

  static String get _navKey  => 'coach_nav_v1_$_uid';
  static String get _feedKey => 'coach_feed_v1_$_uid';

  static Future<bool> _done(String k) async {
    try {
      return (await SharedPreferences.getInstance()).getBool(k) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> _mark(String k) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(k, true);
    } catch (_) {}
  }

  static bool _alive(GlobalKey k) => k.currentContext != null;

  // ── Nav Tour (sidebar web / tab bar mobile) ───────────────────────────────
  static Future<void> showNavTour(BuildContext context) async {
    if (await _done(_navKey)) return;
    if (!context.mounted) return;
    await _mark(_navKey);

    final web  = kIsWeb;
    final side = web ? ContentAlign.right : ContentAlign.top;

    final targets = <TargetFocus>[
      if (_alive(cmNavFeedKey))
        _t(cmNavFeedKey, 'Feed 🎬',
            'Videos TikTok-style de candidatos y empresas.\nDeslizá para descubrir perfiles.',
            side),
      if (_alive(cmNavExploreKey))
        _t(cmNavExploreKey, 'Explorar 🔍',
            'Buscá profesionales y empresas por nombre, rol o habilidad.',
            side),
      if (_alive(cmNavMatchKey))
        _t(cmNavMatchKey, 'Matches ⚡',
            'Tus conexiones mutuas. Cuando los dos se dan like, ¡es un match!',
            side),
      if (_alive(cmNavAlertsKey))
        _t(cmNavAlertsKey, 'Alertas 🔔',
            'Notificaciones de matches, mensajes e invitaciones a entrevistas.',
            side),
      if (_alive(cmNavProfileKey))
        _t(cmNavProfileKey, 'Perfil 👤',
            'Tu presencia profesional. Grabá tu video-pitch y completá tu información.',
            side),
      if (web && _alive(cmNavJobsKey))
        _t(cmNavJobsKey, 'Vacantes 💼',
            'Ofertas de trabajo personalizadas.\nLa pestaña "Para ti" usa IA para mostrarte las más relevantes.',
            ContentAlign.right),
    ];

    if (targets.isEmpty || !context.mounted) return;
    _show(context, targets);
  }

  // ── Feed Tour (match badge + acciones + botones header mobile) ────────────
  static Future<void> showFeedTour(BuildContext context) async {
    if (await _done(_feedKey)) return;
    if (!context.mounted) return;
    await _mark(_feedKey);

    await Future.delayed(const Duration(milliseconds: 700));
    if (!context.mounted) return;

    final targets = <TargetFocus>[
      if (_alive(cmFeedMatchBadgeKey))
        _t(cmFeedMatchBadgeKey, 'Match Score ⚡',
            '¿Qué tan compatible sos con este perfil?\nTocá para ver el análisis completo generado por IA.',
            ContentAlign.bottom),
      if (_alive(cmFeedActionsKey))
        _t(cmFeedActionsKey, 'Acciones 👆',
            'Me interesa · Conectar · Comentar · Guardar.\nInteractuá con el perfil desde acá.',
            ContentAlign.left),
      if (_alive(cmFeedJobsBtnKey))
        _t(cmFeedJobsBtnKey, 'Vacantes 💼',
            'Accedé a las ofertas de trabajo disponibles.',
            ContentAlign.bottom),
      if (_alive(cmFeedMsgBtnKey))
        _t(cmFeedMsgBtnKey, 'Mensajes 💬',
            'Tus conversaciones con matches y empresas.',
            ContentAlign.bottom),
      if (_alive(cmFeedBellBtnKey))
        _t(cmFeedBellBtnKey, 'Notificaciones 🔔',
            'Nuevos matches, mensajes e invitaciones a entrevistas.',
            ContentAlign.bottom),
    ];

    if (targets.isEmpty || !context.mounted) return;
    _show(context, targets);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static TargetFocus _t(
      GlobalKey key, String title, String body, ContentAlign align) {
    return TargetFocus(
      identify: title,
      keyTarget: key,
      shape: ShapeLightFocus.RRect,
      radius: 14,
      paddingFocus: 8,
      contents: [
        TargetContent(
          align: align,
          builder: (ctx, ctrl) => _CoachCard(
            title: title,
            body: body,
            onNext: ctrl.next,
            onSkip: ctrl.skip,
          ),
        ),
      ],
    );
  }

  static void _show(BuildContext context, List<TargetFocus> targets) {
    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.82,
      paddingFocus: 8,
      textSkip: 'Saltar tour',
      hideSkip: false,
      textStyleSkip: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      onFinish: () {},
      onSkip: () => true,
    ).show(context: context);
  }
}

// ── Card visual del coach mark ────────────────────────────────────────────────

class _CoachCard extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _CoachCard({
    required this.title,
    required this.body,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra naranja decorativa
          Container(
            width: 32, height: 3,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 0,
                onPressed: onSkip,
                child: const Text(
                  'Saltar',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                minSize: 0,
                color: const Color(0xFFF97316),
                borderRadius: BorderRadius.circular(12),
                onPressed: onNext,
                child: const Text(
                  'Siguiente →',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
