import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/nex_avatar.dart';
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
import '../widgets/web_ui.dart';

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

  static const _subtitle = 'Todo lo que usás vos para mostrarte y crecer, en un solo lugar.';
  static const _subtitleCompany = 'Todo lo que usás para reclutar y crecer, en un solo lugar.';

  @override
  Widget build(BuildContext context) {
    final wide = isWebWide(context);
    final sections = _isCompany ? _companySections(context) : _candidateSections(context);

    final body = ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(wide ? 0 : 16, wide ? 6 : 12, wide ? 0 : 16, 40),
      children: [
        if (!wide) ...[
          Text(_isCompany ? _subtitleCompany : _subtitle,
              style: TextStyle(fontSize: 14, color: context.textSecondary, height: 1.4)),
          const SizedBox(height: 16),
        ],
        ProfileCompletionBar(profile: profile),
        const SizedBox(height: 8),
        if (wide) WebGrid(children: sections) else ...sections,
        const SizedBox(height: 8),
        _accountSection(context),
      ],
    );

    if (wide) {
      return WebPage(
        title: 'Mis herramientas',
        subtitle: _isCompany ? _subtitleCompany : _subtitle,
        child: body,
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: context.isDark ? NexTheme.darkBg : const Color(0xFFF7F8FA),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Mis herramientas'),
        backgroundColor: context.isDark ? NexTheme.darkBg : CupertinoColors.white,
        border: null,
      ),
      child: SafeArea(child: body),
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

// ── Modo Confidencial: card con avatar difuminado + switch Normal/Confidential,
// para que el candidato active/desactive su propio perfil oculto. Vive en la
// pantalla principal de Perfil (no en un submenú) para que sea tan visible
// como en el mockup de referencia. ──
class ConfidentialModeCard extends StatefulWidget {
  final NexUser profile;
  const ConfidentialModeCard({super.key, required this.profile});

  @override
  State<ConfidentialModeCard> createState() => ConfidentialModeCardState();
}

class ConfidentialModeCardState extends State<ConfidentialModeCard> {
  late bool _isConfidential =
      widget.profile.accountType == 'confidencial' || widget.profile.accountType == 'stealth';
  bool _loading = false;

  // El switch cambia el modo al instante usando el nombre/titular que ya tiene
  // el perfil — no hace falta repetir un formulario, esa pantalla ("Tráiler
  // Confidencial") es el onboarding para cuentas NUEVAS tipo Candidato
  // Confidencial, no algo que un usuario existente deba volver a llenar.
  Future<void> _toggle(bool value) async {
    setState(() => _loading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        await Supabase.instance.client
            .from('users')
            .update({'account_type': value ? 'confidencial' : 'candidato'}).eq('id', uid);
      }
      if (mounted) setState(() => _isConfidential = value);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hairline = context.dividerColor.withValues(alpha: 0.3);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.isDark ? NexTheme.darkCard : CupertinoColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hairline, width: 0.5),
        boxShadow: [
          BoxShadow(color: CupertinoColors.black.withValues(alpha: 0.07), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipOval(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: NexAvatar(user: widget.profile, size: 64),
            ),
          ),
          const SizedBox(height: 10),
          Text(widget.profile.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
          const SizedBox(height: 2),
          Text(
            widget.profile.headline.isNotEmpty ? widget.profile.headline : 'Tu perfil',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: context.textTertiary),
          ),
          const SizedBox(height: 14),
          Divider(height: 0.5, thickness: 0.5, color: hairline),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                child: const Icon(CupertinoIcons.eye_slash_fill, color: MployaTheme.brandAccent, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Perfil Confidencial (Modo Oculto)',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Toggle "Normal | Confidential" con labels a los costados, como el mockup.
          Center(
            child: _loading
                ? const CupertinoActivityIndicator(radius: 10)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Normal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: !_isConfidential ? FontWeight.w800 : FontWeight.w500,
                            color: !_isConfidential ? context.textPrimary : context.textTertiary,
                          )),
                      const SizedBox(width: 12),
                      CupertinoSwitch(value: _isConfidential, activeTrackColor: MployaTheme.brandAccent, onChanged: _toggle),
                      const SizedBox(width: 12),
                      Text('Confidential',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _isConfidential ? FontWeight.w800 : FontWeight.w500,
                            color: _isConfidential ? MployaTheme.brandAccent : context.textTertiary,
                          )),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Divider(height: 0.5, thickness: 0.5, color: hairline),
          const SizedBox(height: 14),
          // Preview de qué se oculta: empresa/cargo actual tapado, para que se
          // entienda de un vistazo el efecto del modo confidencial.
          Row(
            children: [
              Text('Empresa actual', style: TextStyle(fontSize: 12, color: context.textTertiary)),
              const Spacer(),
              _isConfidential
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Text(
                          widget.profile.company?.isNotEmpty == true ? widget.profile.company! : 'Empresa S.A.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary),
                        ),
                      ),
                    )
                  : Text(
                      widget.profile.company?.isNotEmpty == true ? widget.profile.company! : '—',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary),
                    ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _isConfidential
                ? 'Tu identidad está oculta. Solo empresas premium pueden desbloquearte.'
                : 'Activá el modo oculto para aparecer solo ante empresas verificadas, sin revelar tu identidad.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.textTertiary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
