import 'dart:math' as math;
import '../utils/user_columns.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/profile_video_widgets.dart';
import 'chat_inmail_screen.dart';
import 'splash_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../services/profile_view_service.dart';
import '../services/video_preload_manager.dart';
import '../services/company_verification_service.dart';
import 'candidate_profile_form_screen.dart';
import 'company_profile_form_screen.dart';
import 'stealth_profile_form_screen.dart';
import 'interview_prep_screen.dart';
import '../services/hashtag_service.dart';
import '../services/share_service.dart';
import 'camera_screen.dart';
import 'mis_herramientas_screen.dart';

class ProfileScreen extends StatefulWidget {
  final NexUser? user;

  const ProfileScreen({super.key, this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>?>? _ownFuture;
  String _connectionStatus = 'none';
  bool _isLoadingConnection = false;
  int _selectedProfileTab = 0; // 0=Sobre mí, 1=Portfolio, 2=Herramientas
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _fetchConnectionStatus(widget.user!.id);
      // Registrar vista de perfil
      ProfileViewService.instance.recordView(widget.user!.id);
    } else {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        _ownFuture = Supabase.instance.client
            .from('users')
            .select(kUserColumns)
            .eq('id', uid)
            .maybeSingle();
        _checkAdmin(uid);
      }
    }
  }

  Future<void> _checkAdmin(String uid) async {
    try {
      final row = await Supabase.instance.client
          .from('users').select('is_admin').eq('id', uid).maybeSingle();
      if (mounted && row?['is_admin'] == true) setState(() => _isAdmin = true);
    } catch (_) {}
  }

  Future<void> _fetchConnectionStatus(String otherId) async {
    setState(() => _isLoadingConnection = true);
    try {
      final res = await Supabase.instance.client
          .rpc('get_connection_status', params: {'p_other_user_id': otherId});
      if (res != null && res['status'] != null) {
        setState(() => _connectionStatus = res['status'] as String);
      }
    } catch (e) {
      debugPrint('Error fetch connection: $e');
    } finally {
      if (mounted) setState(() => _isLoadingConnection = false);
    }
  }

  Future<void> _handleConnect(String otherId) async {
    setState(() => _isLoadingConnection = true);
    try {
      final res = await Supabase.instance.client
          .rpc('send_connection_request', params: {'p_addressee_id': otherId});
      if (res != null && res['status'] != null) {
        setState(() => _connectionStatus = res['status'] as String);
      }
    } catch (e) {
      debugPrint('Error send connection: $e');
    } finally {
      if (mounted) setState(() => _isLoadingConnection = false);
    }
  }

  Future<void> _pickAndUploadAvatar(NexUser profile) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 85,
    );
    if (picked == null) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    if (mounted) {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 18)),
      );
    }

    final url = await StorageService.instance.uploadAvatar(uid, picked);

    if (mounted) Navigator.of(context).pop();

    if (url != null) {
      await Supabase.instance.client.from('users').update({
        'avatar_url': url,
      }).eq('id', uid);

      if (mounted) {
        setState(() {
          _ownFuture = Supabase.instance.client
              .from('users')
              .select(kUserColumns)
              .eq('id', uid)
              .maybeSingle();
        });
      }
    } else {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(StorageService.instance.lastError ?? 'No se pudo subir la foto'),
            actions: [
              CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Perfil de otro usuario: render directo sin stream
    if (widget.user != null) {
      return _buildScaffold(context, widget.user!, false);
    }
    // Sin sesión activa: redirigir al splash para login
    if (_ownFuture == null) {
      return CupertinoPageScaffold(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.person_crop_circle, size: 64, color: context.textTertiary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text('Inicia sesión para ver tu perfil', style: TextStyle(fontSize: 16, color: context.textSecondary)),
              const SizedBox(height: 24),
              CupertinoButton(
                color: MployaTheme.brandAccent,
                child: const Text('Iniciar Sesión'),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    CupertinoPageRoute(builder: (_) => const SplashScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      );
    }
    // Perfil propio: fetch normal desde Supabase
    return FutureBuilder<Map<String, dynamic>?>(
      future: _ownFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return CupertinoPageScaffold(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CupertinoActivityIndicator(radius: 16),
                  const SizedBox(height: 24),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Cerrar Sesión (Si no carga)', style: TextStyle(fontSize: 13, color: CupertinoColors.destructiveRed)),
                    onPressed: () async {
                      VideoPreloadManager.instance.disposeAll();
                      await Supabase.instance.client.auth.signOut();
                      if (!ctx.mounted) return;
                      Navigator.of(ctx, rootNavigator: true).pushAndRemoveUntil(
                          CupertinoPageRoute(builder: (_) => const SplashScreen()), (route) => false);
                    },
                  )
                ],
              ),
            ),
          );
        }

        if (snap.hasError) {
          return CupertinoPageScaffold(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error de Red/DB:\n${snap.error}\nSi eres nuevo, verifica que completaste el Formulario de Perfil.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CupertinoColors.destructiveRed),
                ),
              ),
            ),
          );
        }

        if (!snap.hasData || snap.data == null) {
          return const CupertinoPageScaffold(
            child: Center(child: Text('Perfil vacío')),
          );
        }

        return _buildScaffold(context, NexUser.fromJson(snap.data!), true);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, NexUser profile, bool isOwnProfile) {
    // ── Rediseño 23/7: UNA sola columna centrada, idéntica en web y móvil.
    // Secciones limpias (header, video, sobre mí, experiencia, educación,
    // habilidades en chips, herramientas). Se quitó el layout de 2 columnas del
    // web, la top-bar redundante y las tarjetas recargadas (proyectos,
    // certificaciones, insights, barras de skills) para un look profesional.
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  // ── Barra de acciones (volver / compartir / ajustes) ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        if (!isOwnProfile)
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Icon(CupertinoIcons.chevron_back, size: 24, color: Color(0xFF0F172A)),
                          ),
                        const Spacer(),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => ShareService.instance.shareProfile(
                            name: profile.name, headline: profile.headline,
                            userId: profile.id, accountType: profile.accountType,
                          ),
                          child: const Icon(CupertinoIcons.square_arrow_up, size: 22, color: Color(0xFF0F172A)),
                        ),
                        if (isOwnProfile) ...[
                          const SizedBox(width: 14),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _showSettingsSheet(context, profile),
                            child: const Icon(CupertinoIcons.ellipsis, size: 22, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildWebProfileCard(context, profile, isOwnProfile),
                        const SizedBox(height: 16),
                        _buildWebVideoPitchCard(context, profile, isOwnProfile),
                        const SizedBox(height: 16),
                        _buildWebAboutMeCard(context, profile),
                        const SizedBox(height: 16),
                        _buildWebExperienceCard(context, profile),
                        const SizedBox(height: 16),
                        _buildWebEducationCard(context, profile),
                        const SizedBox(height: 16),
                        _buildSkillsChipsCard(context, profile),
                        if (isOwnProfile) ...[
                          const SizedBox(height: 16),
                          _buildToolsCard(context, profile),
                        ],
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Habilidades unificadas en chips (reemplaza la tarjeta con barras de progreso).
  Widget _buildSkillsChipsCard(BuildContext context, NexUser profile) {
    final skills = profile.skills.isNotEmpty
        ? profile.skills
        : const ['Flutter', 'Dart', 'Firebase', 'React', 'Node.js', 'AWS'];
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Habilidades',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills
                .map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F1FB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(s,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0C447C))),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WEB PREMIUM CARDS
  // ═══════════════════════════════════════════════════════════════════════════



  Widget _contactPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // Header rediseñado (23/7): cover azul + avatar montado encima + barra de stats,
  // en vez de la fila plana anterior. Mismo look que la maqueta aprobada.
  Widget _buildWebProfileCard(BuildContext context, NexUser profile, bool isOwnProfile) {
    const brand = Color(0xFF185FA5);
    final avatar = (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty)
        ? NetworkImage(profile.avatarUrl!)
        : const AssetImage('assets/images/avatar_juan_perez.jpg') as ImageProvider;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cover + avatar montado ──
          SizedBox(
            height: 118,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(height: 74, color: brand),
                Positioned(
                  left: 20,
                  top: 30,
                  child: GestureDetector(
                    onTap: isOwnProfile ? () => _pickAndUploadAvatar(profile) : null,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        image: DecorationImage(image: avatar, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Nombre / headline / ubicación ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(profile.name,
                          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ),
                    const SizedBox(width: 6),
                    const Icon(CupertinoIcons.checkmark_seal_fill, size: 18, color: brand),
                  ],
                ),
                const SizedBox(height: 2),
                Text(profile.headline,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(CupertinoIcons.location_solid, size: 12, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(profile.location ?? "São Paulo, Brazil",
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _contactPill(CupertinoIcons.envelope_fill, "Email"),
                    _contactPill(CupertinoIcons.link, "LinkedIn"),
                    _contactPill(CupertinoIcons.phone_fill, "Teléfono"),
                    _contactPill(CupertinoIcons.briefcase_fill, "Portfolio"),
                  ],
                ),
                // ── Acciones sobre el perfil de otra persona ──
                if (!isOwnProfile) ...[
                  const SizedBox(height: 16),
                  _buildProfileActions(context, profile),
                ],
              ],
            ),
          ),
          // ── Barra de stats ──
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEDF1F5))),
            ),
            child: Row(
              children: [
                _headerStat('248', 'Vistas', false),
                _headerStat('32', 'Matches', true),
                _headerStat('92%', 'Perfil', true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Acciones sobre el perfil de OTRA persona: conectar (con sus 3 estados) y
  /// mandar mensaje. El rediseño del 23/7 había dejado el header sin acciones,
  /// así que desde el perfil no se podía ni conectar ni escribir.
  Widget _buildProfileActions(BuildContext context, NexUser profile) {
    final connected = _connectionStatus == 'accepted';
    final pending = _connectionStatus == 'pending';
    final label = connected
        ? 'Conectados'
        : pending
            ? 'Pendiente'
            : 'Conectar';
    final icon = connected
        ? CupertinoIcons.checkmark_alt
        : pending
            ? CupertinoIcons.clock
            : CupertinoIcons.person_add_solid;
    final enabled = !connected && !pending && !_isLoadingConnection;

    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: enabled ? () => _handleConnect(profile.id) : null,
            child: Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: enabled ? const Color(0xFF185FA5) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isLoadingConnection
                  ? const CupertinoActivityIndicator(radius: 9)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 17, color: enabled ? Colors.white : const Color(0xFF64748B)),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: enabled ? Colors.white : const Color(0xFF64748B))),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => ChatInmailScreen(targetUser: profile)),
            ),
            child: Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.chat_bubble_fill, size: 17, color: Color(0xFF475569)),
                  SizedBox(width: 7),
                  Text('Mensaje',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerStat(String value, String label, bool divider) {
    return Expanded(
      child: Container(
        decoration: divider
            ? const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFFEDF1F5))))
            : null,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  Widget _buildWebAboutMeCard(BuildContext context, NexUser profile) {
    final isCompany =
        profile.accountType == 'empresa' || profile.accountType == 'headhunter';
    final about = profile.about?.trim() ?? '';
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCompany ? "Sobre la empresa" : "Sobre mí",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            about.isNotEmpty
                ? about
                : (isCompany
                    ? "Esta empresa todavía no agregó una descripción."
                    : "Todavía no agregaste una descripción. Editá tu perfil para contar sobre vos."),
            style: TextStyle(
              fontSize: 13,
              color: about.isNotEmpty ? const Color(0xFF475569) : const Color(0xFF94A3B8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebExperienceCard(BuildContext context, NexUser profile) {
    final list = profile.experience.isNotEmpty ? profile.experience : [
      const Experience(
        role: "Senior Software Engineer",
        company: "Globant",
        duration: "2021 - Actualidad",
        description: "• Lideré el desarrollo de features clave en apps de alto tráfico (+2M usuarios).\n• Coordiné un equipo de 5 ingenieros y mejoré el time-to-market un 30%.",
        location: "Buenos Aires, AR",
        isCurrent: true,
      ),
      const Experience(
        role: "Full Stack Developer",
        company: "MercadoLibre",
        duration: "2018 - 2021",
        description: "• Desarrollé microservicios en Node.js y nuevas features en React.\n• Implementé CI/CD, reduciendo los errores en producción un 40%.",
        location: "Buenos Aires, AR",
        isCurrent: false,
      ),
      const Experience(
        role: "Frontend Developer",
        company: "Auth0",
        duration: "2016 - 2018",
        description: "• Construí componentes reutilizables y mejoré la performance del dashboard.\n• Colaboré con diseño para elevar la experiencia de usuario.",
        location: "Remoto",
        isCurrent: false,
      ),
    ];

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                "Experiencia",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Icon(CupertinoIcons.ellipsis, size: 16, color: Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (ctx, index) {
              final exp = list[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        exp.duration,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == 0 ? const Color(0xFF185FA5) : const Color(0xFFCBD5E1),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (index < list.length - 1)
                        Container(
                          width: 2,
                          height: 100,
                          color: const Color(0xFFE2E8F0),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exp.role,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          exp.company,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF185FA5),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          exp.description ?? "",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF475569),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWebEducationCard(BuildContext context, NexUser profile) {
    final list = profile.education.isNotEmpty ? profile.education : [
      const Education(
        school: "Universidad de Buenos Aires (UBA)",
        degree: "Licenciatura en Ciencias de la Computación",
        field: "Ingeniería de Software",
        years: "2014 - 2018",
      ),
    ];

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                "Educación",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Icon(CupertinoIcons.ellipsis, size: 16, color: Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (ctx, index) {
              final edu = list[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    edu.degree,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    edu.school,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    edu.field ?? "",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                  Text(
                    edu.years,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  if (index < list.length - 1) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }











  Widget _buildWebVideoPitchCard(BuildContext context, NexUser profile, bool isOwnProfile) {
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Video Pitch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          _buildVideoPitchContent(context, profile, isOwnProfile),
        ],
      ),
    );
  }


  Widget _projectCardCompact(String title, String desc, ImageProvider image) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image(
            image: image,
            height: 80,
            width: 180,
            fit: BoxFit.cover,
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _coreStatMetric(String label, String value, bool showProgress, {bool isPositive = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: isPositive ? const Color(0xFF22C55E) : const Color(0xFF0F172A),
          ),
        ),
        if (showProgress) ...[
          const SizedBox(height: 4),
          Container(
            width: 50, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.7,
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
        ],
      ],
    );
  }




  Widget _certificationBadge(IconData icon, String name, Color color) {
    return Tooltip(
      message: name,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }





  Widget _buildVideoPitchContent(BuildContext context, NexUser profile, bool isOwnProfile) {
    final hasVideo = profile.videoUrl != null && profile.videoUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(14),
            image: const DecorationImage(
              image: AssetImage('assets/images/video_thumbnail_demo.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              Positioned(
                left: 16, right: 16, bottom: 24, top: 40,
                child: CustomPaint(painter: _WaveformPainter()),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF185FA5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF185FA5).withValues(alpha: 0.4), blurRadius: 12),
                    ],
                  ),
                  child: const Icon(CupertinoIcons.play_fill, size: 20, color: Colors.white),
                ),
              ),
              Positioned(
                bottom: 10, left: 10, right: 10,
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.play_circle_fill, size: 13, color: Colors.white),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.15,
                          child: Container(color: const Color(0xFF185FA5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '0:05 / 0:45',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  if (hasVideo) {
                    showCupertinoModalPopup<void>(context: context, builder: (_) => VideoPlayerModal(videoUrl: profile.videoUrl!, index: 0));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Ver Pitch Completo',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 4,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  if (isOwnProfile) {
                    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const CameraScreen()));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text(
                      'Regrabar',
                      style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 4,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  Navigator.of(context).push(CupertinoPageRoute(
                    builder: (_) => InterviewPrepScreen(
                      jobTitle: profile.headline,
                      candidateSkills: profile.skills,
                    ),
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text(
                      'Practicar',
                      style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }


  void _openEditProfile(BuildContext context, NexUser profile) {
    if (profile.accountType == 'empresa' || profile.accountType == 'headhunter') {
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const CompanyProfileFormScreen()));
    } else if (profile.accountType == 'confidencial' || profile.accountType == 'stealth') {
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const StealthProfileFormScreen()));
    } else {
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const CandidateProfileFormScreen(isEditing: true)));
    }
  }


  Widget _companyQuickTool(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.isDark ? const Color(0xFF222222) : const Color(0xFFEDEFF2)),
        ),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimary)),
          ],
        ),
      ),
    );
  }

  // ── Tarjeta "Mis herramientas" (hub privado: features secundarias) ─────────
  // Es el menú "Más" de la app: impulsar perfil, estadísticas, guardados,
  // validar skills, practicar entrevistas, retos, invitar, etc. Solo en el
  // perfil propio. Estilo _PremiumCard para integrarse con el resto del perfil.
  Widget _buildToolsCard(BuildContext context, NexUser profile) {
    final isCompany = profile.accountType == 'empresa' || profile.accountType == 'headhunter';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => MisHerramientasScreen(profile: profile, isAdmin: _isAdmin)),
      ),
      child: _PremiumCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF185FA5), Color(0xFF0C447C)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(CupertinoIcons.square_grid_2x2_fill, size: 22, color: CupertinoColors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mis herramientas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCompany
                        ? 'Impulsar, buscar talento, estadísticas, cuenta y más'
                        : 'Impulsar perfil, validar skills, entrevistas, guardados y más',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  // ── Settings Sheet ──────────────────────────────────────────────────────

  // ── Generar Bio con Claude AI ─────────────────────────────────────────────

  // Bio generation is now handled by showGenerarBioSheet() from profile_bio_generator.dart


  void _showSettingsSheet(BuildContext context, NexUser profile) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text(
          'Cuenta',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        message: const Text(
          'Gestioná tu cuenta y sesión',
          style: TextStyle(fontSize: 12.5),
        ),
        actions: [
          // ── Verificación de Empresa ──
          if (profile.accountType == 'empresa' || profile.accountType == 'headhunter')
            CupertinoActionSheetAction(
              child: const Text(
                'Verificar empresa',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final verified = await CompanyVerificationService.instance.autoVerifyEmail();
                if (context.mounted) {
                  showCupertinoDialog(
                    context: context,
                    builder: (d) => CupertinoAlertDialog(
                      title: Text(verified ? '¡Verificada!' : 'Verificación'),
                      content: Text(verified
                          ? 'Tu email corporativo fue verificado. Los candidatos verán un badge de confianza en tu perfil.'
                          : 'Para verificar tu empresa necesitás un email corporativo (no Gmail/Hotmail). Contactá soporte para verificación manual.'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('Entendido'),
                          onPressed: () => Navigator.pop(d),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          // ── Cerrar Sesión ──
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              VideoPreloadManager.instance.disposeAll();
              await Supabase.instance.client.auth.signOut();
              if (!context.mounted) return;
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                CupertinoPageRoute(builder: (_) => const SplashScreen()),
                (route) => false,
              );
            },
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          )
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'Cancelar',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  // ── Clean Profile Header (Avatar + Edit) ─────────────────────────────────



  // ── Name + Headline + Badges + Action Buttons ─────────────────────────────




  // ── Stat Column Helper ──────────────────────────────────────────────────────


  // ── Video Replies de Empresas ──────────────────────────────────────────────


  // ── Video-Pitch Section ─────────────────────────────────────────────────




  // ── Experience Clean (vertical timeline like reference) ─────────────────


  // ── Interactive Hashtags Section ──────────────────────────────────────────


  // ── AI Spotlight Cards — Feature Discovery Premium ────────────────────────


  // ── Quick Actions — Horizontal chips for growth features ──────────────────


  // ── Account Section — Compact settings ────────────────────────────────────


}

// ── Interactive Hashtag Pill Widget ────────────────────────────────────────────

class _InteractiveHashtagPill extends StatefulWidget {
  final String tag;
  final VoidCallback onTap;

  const _InteractiveHashtagPill({required this.tag, required this.onTap});

  @override
  State<_InteractiveHashtagPill> createState() => _InteractiveHashtagPillState();
}

class _InteractiveHashtagPillState extends State<_InteractiveHashtagPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  int? _count;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _loadCount();
  }

  Future<void> _loadCount() async {
    final count = await HashtagService.instance.getHashtagCount(widget.tag);
    if (mounted) setState(() => _count = count);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: MployaTheme.brandAccent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(MployaTheme.radiusPill),
            border: Border.all(
              color: MployaTheme.brandAccent.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '#${widget.tag}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              if (_count != null && _count! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MployaTheme.brandAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_count',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: MployaTheme.brandAccent,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_right,
                size: 10,
                color: context.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// _BioResultCard and _PersonalitySection are now in:
// - lib/widgets/profile_bio_generator.dart (BioResultCard)
// - lib/widgets/profile_personality_section.dart (ProfilePersonalitySection)

// ─────────────────────────────────────────────────────────────────────────────
// Profile Tab Button — Custom tab with icon + label + optional badge
// ─────────────────────────────────────────────────────────────────────────────

// ── Segmented Tab (iOS segmented control style) ───────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// Spotlight Card — Full-width gradient card for premium AI features
// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// Spotlight Card Compact — Half-width gradient card
// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// Quick Action Chip — Vertical icon chip for horizontal scroll
// ─────────────────────────────────────────────────────────────────────────────


// ── Waveform painter for video-pitch card ──
class _WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF185FA5).withValues(alpha: 0.35)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final midY = size.height / 2;
    final barCount = 40;
    final barWidth = size.width / barCount;
    for (var i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;
      final h = (midY * 0.3) + (midY * 0.7) * (0.5 + 0.5 * _wave(i, barCount));
      canvas.drawLine(Offset(x, midY - h / 2), Offset(x, midY + h / 2), paint);
    }
  }

  double _wave(int i, int count) {
    final t = i / count;
    return (0.5 * (1 + math.sin(2 * math.pi * t * 3))) * (1 - (t - 0.5).abs() * 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Custom Line Chart for Premium Profile Stats ──
class _ProfileLineChart extends StatelessWidget {
  final List<FlSpot> spots;
  final List<String> xLabels;
  final Color lineColor;
  final List<Color> gradientColors;

  const _ProfileLineChart({
    required this.spots,
    required this.xLabels,
    required this.lineColor,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < xLabels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      xLabels[index],
                      style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 8),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (xLabels.length - 1).toDouble(),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: gradientColors.map((color) => color.withValues(alpha: 0.15)).toList(),
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ── Collapsible Card for Mobile Acordeones ──
class _CollapsibleCard extends StatefulWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  const _CollapsibleCard({
    required this.title,
    required this.child,
  }) : initiallyExpanded = false;

  @override
  State<_CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<_CollapsibleCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Icon(
                  _expanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                  size: 16,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

// ── Premium Card for consistent mockup layout ──
class _PremiumCard extends StatelessWidget {
  final Widget child;

  const _PremiumCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Profile Radar Chart Painter ──
class ProfileRadarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;

  ProfileRadarChartPainter({required this.values, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.7;
    final int count = values.length;

    final paintLine = Paint()
      ..color = const Color(0xFFE2E8F0).withOpacity(0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final paintGrid = Paint()
      ..color = const Color(0xFFCBD5E1).withOpacity(0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final paintFill = Paint()
      ..color = const Color(0xFF185FA5).withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = const Color(0xFF185FA5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Concentric polygons
    for (int step = 1; step <= 3; step++) {
      final r = radius * (step / 3);
      final path = Path();
      for (int i = 0; i < count; i++) {
        final angle = (i * 2 * math.pi / count) - math.pi / 2;
        final pt = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, paintGrid);
    }

    // Axes & Labels
    for (int i = 0; i < count; i++) {
      final angle = (i * 2 * math.pi / count) - math.pi / 2;
      final pt = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
      canvas.drawLine(center, pt, paintLine);

      if (labels.isNotEmpty && i < labels.length) {
        final labelPt = Offset(
          center.dx + (radius + 20) * math.cos(angle),
          center.dy + (radius + 10) * math.sin(angle),
        );
        final textPainter = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: const TextStyle(color: Color(0xFF475569), fontSize: 8.5, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        
        textPainter.paint(
          canvas,
          Offset(labelPt.dx - textPainter.width / 2, labelPt.dy - textPainter.height / 2),
        );
      }
    }

    // Value shape
    final pathValue = Path();
    for (int i = 0; i < count; i++) {
      final angle = (i * 2 * math.pi / count) - math.pi / 2;
      final val = values[i].clamp(0.0, 1.0);
      final pt = Offset(center.dx + radius * val * math.cos(angle), center.dy + radius * val * math.sin(angle));
      if (i == 0) {
        pathValue.moveTo(pt.dx, pt.dy);
      } else {
        pathValue.lineTo(pt.dx, pt.dy);
      }
    }
    pathValue.close();
    canvas.drawPath(pathValue, paintFill);
    canvas.drawPath(pathValue, paintBorder);
  }

  @override
  bool shouldRepaint(covariant ProfileRadarChartPainter oldDelegate) => true;
}