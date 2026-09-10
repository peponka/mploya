import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../theme/mploya_tokens.dart';

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

// Dashboard de Empresa — reemplaza al tour de 5 pantallas (29/8/2026): en vez
// de una pantalla aparte al arrancar, señala los dos accesos rápidos reales
// del dashboard la primera vez que la empresa entra.
final GlobalKey cmEmpresaPublicarKey = GlobalKey(debugLabel: 'cm_empresa_publicar');
final GlobalKey cmEmpresaBuscarKey   = GlobalKey(debugLabel: 'cm_empresa_buscar');

// Feed de talento de Empresa (Match IA) — agregado el 29/8/2026 después de
// que a Pedro le costó entender que el Match IA necesita una vacante
// elegida (probamos con "Lucas Martínez" y pensamos que el feed estaba
// roto, cuando en realidad faltaba elegir vacante). Se ancla en el primer
// TalentReelCard (isFirstCard == true).
final GlobalKey cmEmpresaFeedMatchKey = GlobalKey(debugLabel: 'cm_empresa_feed_match');

// Vacantes de Candidato (JobsScreen) — agregado el 29/8/2026, explica cómo
// buscar y postularse. Se ancla en el buscador de la pantalla.
final GlobalKey cmCandVacantesBuscarKey = GlobalKey(debugLabel: 'cm_cand_vacantes_buscar');

// Botón "+" de la barra inferior — agregado el 10/9/2026: la auditoría de
// navegabilidad mostró que en Empresa/Headhunter ese botón es en la práctica
// el menú principal del rol (Vacantes, Pipeline, Perfil, etc. viven ahí
// adentro), no solo "crear". Se ancla en el botón central de MpBottomNav.
final GlobalKey cmPlusButtonKey = GlobalKey(debugLabel: 'cm_plus_button');

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
    if (kIsWeb) return; // Coach marks only on native app
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
    if (kIsWeb) return; // Coach marks only on native app
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

  // ── Dashboard de Empresa (reemplaza el tour de 5 pantallas) ────────────────
  static Future<void> showEmpresaDashboardTour(BuildContext context) async {
    if (kIsWeb) return; // Coach marks only on native app
    final key = 'coach_empresa_dash_v1_$_uid';
    if (await _done(key)) return;
    if (!context.mounted) return;
    await _mark(key);

    await Future.delayed(const Duration(milliseconds: 700));
    if (!context.mounted) return;

    final targets = <TargetFocus>[
      if (_alive(cmEmpresaPublicarKey))
        _t(cmEmpresaPublicarKey, 'Publicá vacantes 📣',
            'Creá una búsqueda y empezá a recibir candidatos con video-pitch.',
            ContentAlign.bottom),
      if (_alive(cmEmpresaBuscarKey))
        _t(cmEmpresaBuscarKey, 'Buscá candidatos 🎬',
            'Descubrí talento por video, un candidato a la vez — deslizá como en el feed.',
            ContentAlign.bottom),
    ];

    if (targets.isEmpty || !context.mounted) return;
    _show(context, targets);
  }

  // ── Feed de talento de Empresa (Match IA) ──────────────────────────────────
  static Future<void> showEmpresaTalentFeedTour(BuildContext context) async {
    if (kIsWeb) return; // Coach marks only on native app
    final key = 'coach_empresa_talent_feed_v1_$_uid';
    if (await _done(key)) return;
    if (!context.mounted) return;
    await _mark(key);

    await Future.delayed(const Duration(milliseconds: 700));
    if (!context.mounted) return;

    final targets = <TargetFocus>[
      if (_alive(cmEmpresaFeedMatchKey))
        _t(cmEmpresaFeedMatchKey, 'Elegí una vacante 🎯',
            'El Match IA se calcula siempre contra una vacante concreta.\nTocá acá para elegir una y ver el % de cada candidato.',
            ContentAlign.left),
    ];

    if (targets.isEmpty || !context.mounted) return;
    _show(context, targets);
  }

  // ── Vacantes de Candidato ───────────────────────────────────────────────────
  static Future<void> showCandVacantesTour(BuildContext context) async {
    if (kIsWeb) return; // Coach marks only on native app
    final key = 'coach_cand_vacantes_v1_$_uid';
    if (await _done(key)) return;
    if (!context.mounted) return;
    await _mark(key);

    await Future.delayed(const Duration(milliseconds: 700));
    if (!context.mounted) return;

    final targets = <TargetFocus>[
      if (_alive(cmCandVacantesBuscarKey))
        _t(cmCandVacantesBuscarKey, 'Buscá tu próximo trabajo 🔍',
            'Filtrá por puesto, ubicación o modalidad.\nTocá una vacante para ver el detalle y postularte.',
            ContentAlign.bottom),
    ];

    if (targets.isEmpty || !context.mounted) return;
    _show(context, targets);
  }

  // ── Intro de "Cómo publicar" (antes del wizard de Publicar vacante) ────────
  // Agregado el 10/9/2026, inspirado en el explicador de 3 pasos que muestra
  // JobToday antes de dejar entrar a la empresa al flujo de publicar — pero
  // con los 3 pasos reales de Mploya (video, no texto). Es una intro de
  // pantalla completa, no un coach mark de `TutorialCoachMark`, así que no
  // usa `_show`/`_t`: la pantalla de Publicar vacante la muestra ella misma
  // y sólo le pide a este servicio si corresponde mostrarla y que quede
  // marcada como vista.
  static Future<bool> shouldShowPublicarIntro() async {
    if (kIsWeb) return false;
    return !(await _done('coach_empresa_publicar_intro_v1_$_uid'));
  }

  static Future<void> markPublicarIntroShown() async {
    await _mark('coach_empresa_publicar_intro_v1_$_uid');
  }

  // ── Botón "+" de la barra inferior ──────────────────────────────────────────
  static Future<void> showPlusButtonTour(
      BuildContext context, String accountType) async {
    if (kIsWeb) return; // Coach marks only on native app
    final key = 'coach_plus_button_v1_$_uid';
    if (await _done(key)) return;
    if (!context.mounted) return;
    await _mark(key);

    await Future.delayed(const Duration(milliseconds: 700));
    if (!context.mounted) return;

    final body = switch (accountType) {
      'empresa' =>
        'Publicá una vacante o entrá a Vacantes, Pipeline, Mapa, Alertas y más — todo vive acá.',
      'headhunter' =>
        'Publicá una búsqueda o entrá a Talent Pool, Mensajes y tu perfil — todo vive acá.',
      _ =>
        'Creá contenido o abrí tu Red y tu Perfil — todo vive acá.',
    };

    final targets = <TargetFocus>[
      if (_alive(cmPlusButtonKey))
        _t(cmPlusButtonKey, 'Tu menú principal 📋', body, ContentAlign.top),
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
          // Barra decorativa — color de marca (antes un azul suelto que no
          // era ninguno de los tokens; Pedro señaló que el tour viejo no
          // pegaba con el resto de la app por esto mismo, 29/8/2026).
          Container(
            width: 32, height: 3,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: MpTokens.primary,
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
                color: MpTokens.primary,
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
