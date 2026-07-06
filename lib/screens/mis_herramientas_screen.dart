import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider;
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/profile_section_widgets.dart';
import 'boost_profile_screen.dart';
import 'profile_viewers_screen.dart';
import 'profile_analytics_dashboard_screen.dart';
import 'saved_profiles_screen.dart';
import 'skill_assessment_screen.dart';
import 'interview_prep_screen.dart';
import 'pitch_challenge_screen.dart';
import 'referral_screen.dart';
import 'resume_builder_screen.dart';
import 'scheduling_screen.dart';
import 'ats_dashboard_screen.dart';
import 'onboarding_pitch_screen.dart';
import 'settings_screen.dart';
import 'admin_dashboard_screen.dart';

/// Pantalla privada del usuario: todas las herramientas que usa él mismo,
/// separadas de su perfil público. Agrupadas por los mismos 4 pilares que la
/// landing (Mostrate / Que te descubran / Preparate y crecé / Conectá) para
/// que app y web hablen el mismo idioma.
class MisHerramientasScreen extends StatelessWidget {
  final NexUser profile;
  final bool isAdmin;
  const MisHerramientasScreen({super.key, required this.profile, this.isAdmin = false});

  bool get _isCompany =>
      profile.accountType == 'empresa' || profile.accountType == 'headhunter';

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.isDark ? NexTheme.darkBg : const Color(0xFFF7F8FA),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Mis herramientas'),
        backgroundColor: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Text(
              _isCompany
                  ? 'Todo lo que usás para reclutar y crecer, en un solo lugar.'
                  : 'Todo lo que usás vos para mostrarte y crecer, en un solo lugar.',
              style: TextStyle(fontSize: 14, color: context.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            ProfileCompletionBar(profile: profile),
            const SizedBox(height: 8),
            if (_isCompany) ..._companySections(context) else ..._candidateSections(context),
          ],
        ),
      ),
    );
  }

  // ── Candidato / Confidencial ───────────────────────────────────────────────
  List<Widget> _candidateSections(BuildContext context) => [
        _PillarSection(
          title: 'Mostrate',
          subtitle: 'Tu carta de presentación',
          tiles: [
            _ToolTile(
              icon: CupertinoIcons.videocam_fill,
              color: const Color(0xFFF97316),
              title: 'Actualizar mi pitch',
              subtitle: 'Grabá o reemplazá tu video de 60s',
              onTap: () => _push(context, const OnboardingPitchScreen(isCompany: false)),
            ),
            _ToolTile(
              icon: CupertinoIcons.doc_text_fill,
              color: const Color(0xFFD97706),
              title: 'CV con IA',
              subtitle: 'Generá un CV de respaldo automático',
              onTap: () => _push(context, const ResumeBuilderScreen()),
            ),
          ],
        ),
        _PillarSection(
          title: 'Que te descubran',
          subtitle: 'Aparecé ante más empresas',
          tiles: [
            _ToolTile(
              icon: CupertinoIcons.rocket_fill,
              color: MployaTheme.brandAccent,
              title: 'Impulsar mi perfil',
              subtitle: 'Multiplicá tu alcance en el feed',
              onTap: () => _push(context, const BoostProfileScreen(isCompany: false)),
            ),
            _ToolTile(
              icon: CupertinoIcons.eye_fill,
              color: const Color(0xFF0EA5E9),
              title: 'Quién vio mi perfil',
              onTap: () => _push(context, const ProfileViewersScreen()),
            ),
            _ToolTile(
              icon: CupertinoIcons.chart_bar_fill,
              color: const Color(0xFF8B5CF6),
              title: 'Estadísticas de mi perfil',
              onTap: () => _push(context, const ProfileAnalyticsDashboardScreen()),
            ),
            _ToolTile(
              icon: CupertinoIcons.bookmark_fill,
              color: const Color(0xFFEAB308),
              title: 'Guardados',
              subtitle: 'Empresas y ofertas que marcaste',
              onTap: () => _push(context, const SavedProfilesScreen()),
            ),
          ],
        ),
        _PillarSection(
          title: 'Preparate y crecé',
          subtitle: 'Llegá listo a la entrevista',
          tiles: [
            _ToolTile(
              icon: CupertinoIcons.checkmark_seal_fill,
              color: const Color(0xFF059669),
              title: 'Validá tus skills',
              subtitle: 'Certificá tus habilidades con IA',
              onTap: () => _push(context, const SkillAssessmentScreen()),
            ),
            _ToolTile(
              icon: CupertinoIcons.lightbulb_fill,
              color: const Color(0xFF2563EB),
              title: 'Practicá entrevistas',
              subtitle: 'Simulá una entrevista con IA',
              onTap: () => _push(
                context,
                InterviewPrepScreen(
                  jobTitle: profile.headline,
                  candidateSkills: profile.skills,
                ),
              ),
            ),
            _ToolTile(
              icon: CupertinoIcons.flame_fill,
              color: const Color(0xFFFF6B35),
              title: 'Reto de pitch',
              subtitle: 'Mejorá tu pitch con desafíos',
              onTap: () => _push(context, const PitchChallengeScreen()),
            ),
          ],
        ),
        _PillarSection(
          title: 'Conectá',
          subtitle: 'Hacé crecer tu red',
          tiles: [
            _ToolTile(
              icon: CupertinoIcons.person_2_fill,
              color: const Color(0xFF14B8A6),
              title: 'Invitá y sumá contactos',
              subtitle: 'Compartí Mploya con tu red',
              onTap: () => _push(context, const ReferralScreen()),
            ),
          ],
        ),
        _accountSection(context),
      ];

  // ── Empresa / Headhunter ───────────────────────────────────────────────────
  List<Widget> _companySections(BuildContext context) => [
        _PillarSection(
          title: 'Descubrí talento',
          subtitle: 'Encontrá a la persona indicada',
          tiles: [
            _ToolTile(
              icon: CupertinoIcons.bookmark_fill,
              color: const Color(0xFFEAB308),
              title: 'Candidatos guardados',
              subtitle: 'Perfiles que marcaste para revisar',
              onTap: () => _push(context, const SavedProfilesScreen()),
            ),
          ],
        ),
        _PillarSection(
          title: 'Publicá y atraé',
          subtitle: 'Aumentá tu visibilidad',
          tiles: [
            _ToolTile(
              icon: CupertinoIcons.rocket_fill,
              color: MployaTheme.brandAccent,
              title: 'Impulsar mi presencia',
              subtitle: 'Que más candidatos te vean',
              onTap: () => _push(context, const BoostProfileScreen(isCompany: true)),
            ),
          ],
        ),
        _PillarSection(
          title: 'Gestioná el proceso',
          subtitle: 'Seguí a cada candidato',
          tiles: [
            _ToolTile(
              icon: CupertinoIcons.briefcase_fill,
              color: const Color(0xFF2563EB),
              title: 'Tablero de contratación',
              subtitle: 'Seguí tus candidatos por etapa',
              onTap: () => _push(context, const AtsDashboardScreen()),
            ),
            _ToolTile(
              icon: CupertinoIcons.calendar,
              color: const Color(0xFFD97706),
              title: 'Agenda de entrevistas',
              onTap: () => _push(context, const SchedulingScreen(isCompany: true)),
            ),
          ],
        ),
        _PillarSection(
          title: 'Datos',
          subtitle: 'Medí tus resultados',
          tiles: [
            _ToolTile(
              icon: CupertinoIcons.chart_bar_fill,
              color: const Color(0xFF8B5CF6),
              title: 'Estadísticas',
              subtitle: 'Vistas, engagement y conversión',
              onTap: () => _push(context, const ProfileAnalyticsDashboardScreen()),
            ),
          ],
        ),
        _accountSection(context),
      ];

  Widget _accountSection(BuildContext context) => _PillarSection(
        title: 'Cuenta',
        subtitle: 'Ajustes y sesión',
        tiles: [
          _ToolTile(
            icon: CupertinoIcons.gear_solid,
            color: const Color(0xFF6B7280),
            title: 'Configuración',
            subtitle: 'Privacidad, notificaciones y más',
            onTap: () => _push(context, const SettingsScreen()),
          ),
          if (isAdmin)
            _ToolTile(
              icon: CupertinoIcons.shield_lefthalf_fill,
              color: const Color(0xFF6B7280),
              title: 'Panel de administración',
              subtitle: 'Usuarios, ofertas, reportes y métricas',
              onTap: () => _push(context, const AdminDashboardScreen()),
            ),
        ],
      );

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => screen));
  }
}

// ── Sección de pilar ──────────────────────────────────────────────────────────
class _PillarSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> tiles;
  const _PillarSection({required this.title, required this.subtitle, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary, letterSpacing: -0.3),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 13, color: context.textTertiary)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.isDark ? NexTheme.darkSurface : CupertinoColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.isDark ? const Color(0xFF222222) : const Color(0xFFEDEFF2)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                tiles[i],
                if (i < tiles.length - 1)
                  Divider(height: 0.5, thickness: 0.5, indent: 60, color: context.dividerColor),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Fila de herramienta ───────────────────────────────────────────────────────
class _ToolTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _ToolTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: context.textPrimary),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 12.5, color: context.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 15, color: context.textTertiary),
          ],
        ),
      ),
    );
  }
}
