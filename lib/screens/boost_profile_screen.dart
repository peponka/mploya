import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/profile_view_service.dart';
import '../services/my_profile_service.dart';

class BoostProfileScreen extends ConsumerStatefulWidget {
  /// Las empresas pagan un poco más (mayor valor: un buen candidato vale miles).
  final bool isCompany;

  const BoostProfileScreen({super.key, this.isCompany = false});

  @override
  ConsumerState<BoostProfileScreen> createState() => _BoostProfileScreenState();
}

class _BoostProfileScreenState extends ConsumerState<BoostProfileScreen> {
  int _selectedOption = 0;

  // ── Resultados del boost activo (prueba de impacto) ──
  int? _daysLeft;     // días que faltan; null = sin boost activo
  int? _boostViews;   // vistas desde que arrancó el boost; null = sin dato

  @override
  void initState() {
    super.initState();
    _loadBoostResults();
  }

  /// Carga el estado del boost activo y cuántas vistas generó. Tolera que la
  /// columna boost_started_at no exista todavía (degrada sin romper).
  Future<void> _loadBoostResults() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await loadMyProfileEntitlements();
      final endsRaw = row?['boost_ends_at'];
      final ends = endsRaw != null ? DateTime.tryParse(endsRaw.toString()) : null;
      if (ends == null || !ends.isAfter(DateTime.now())) return;

      final daysLeft = ends.difference(DateTime.now()).inDays;

      // boost_started_at puede no existir aún (falta correr boost_setup.sql).
      int? views;
      try {
        final startRaw = row?['boost_started_at'];
        final start = startRaw != null ? DateTime.tryParse(startRaw.toString()) : null;
        if (start != null) {
          views = await ProfileViewService.instance.getViewCountSince(start);
        }
      } catch (_) {/* columna ausente: seguimos sin el desglose de vistas */}

      if (mounted) {
        setState(() {
          _daysLeft = daysLeft;
          _boostViews = views;
        });
      }
    } catch (e) {
      debugPrint('Boost results load: $e');
    }
  }

  void _processPayment() {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Próximamente'),
        content: const Text(
          'Los Boosts estarán disponibles cuando podamos validar la compra y '
          'la activación de forma segura.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  /// Tarjeta que muestra el impacto del boost activo: vistas generadas + días
  /// restantes. Es la "prueba de que funcionó" que impulsa la recompra.
  Widget _buildBoostResultsCard(BuildContext context) {
    final daysLeft = _daysLeft ?? 0;
    final views = _boostViews;
    final daysText = daysLeft <= 0
        ? 'Termina hoy'
        : (daysLeft == 1 ? 'Termina mañana' : 'Termina en $daysLeft días');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9500), Color(0xFFFF5E3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x33FF9500), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.flame_fill, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Boost activo',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                daysText,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (views != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$views',
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, height: 1),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    views == 1 ? 'vista desde que lo activaste' : 'vistas desde que lo activaste',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              views == 0
                  ? 'Tu perfil ya está destacado — las vistas empiezan a llegar.'
                  : 'Tu perfil destacado ya está generando visitas. ¡Seguí así!',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.3),
            ),
          ] else
            Text(
              'Tu perfil está destacado en el feed. Renová antes de que termine para no perder visibilidad.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, height: 1.35),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // userAsync available via ref.watch(currentUserProvider) for future use
    
    // Tiers Fase 10: Local / Remote / Passport.
    // Las empresas pagan un poco más (~+33%) por mayor valor de contratación.
    final bool isCompany = widget.isCompany;
    final List<Map<String, dynamic>> options = [
      {
        'title': 'Boost Local',
        'price': isCompany ? r'$3.99' : r'$2.99',
        'duration': '1 Semana',
        'desc': isCompany
            ? 'Destacá tu empresa ante candidatos de tu ciudad. Ideal para búsquedas presenciales.'
            : 'Destaca localmente en tu ciudad. Ideal para trabajos presenciales.',
        'gradient': const [Color(0xFF007AFF), Color(0xFF0055B3)],
        'icon': CupertinoIcons.location_solid,
      },
      {
        'title': 'Boost Remoto',
        'price': isCompany ? r'$6.99' : r'$4.99',
        'duration': '2 Semanas',
        'desc': isCompany
            ? 'Alcance nacional para atraer talento remoto o de IT.'
            : 'Alcance nacional para oportunidades de trabajo remoto u oficinas de IT.',
        'gradient': const [Color(0xFFFF9500), Color(0xFFCC7700)],
        'icon': CupertinoIcons.house_fill,
      },
      {
        'title': 'Passport',
        'price': isCompany ? r'$11.99' : r'$8.99',
        'duration': '1 Mes',
        'desc': isCompany
            ? 'Visibilidad Global VIP. Atraé candidatos Elite de todo el mundo.'
            : 'Alcance Global VIP. Visibilidad Mundial 10x para candidatos Elite.',
        'gradient': const [Color(0xFFDAA520), Color(0xFFB8860B)],
        'icon': CupertinoIcons.globe,
      }
    ];

    return CupertinoPageScaffold(
      backgroundColor: context.isDark ? NexTheme.darkBg : Colors.white,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Destacar Perfil',
          style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        backgroundColor: context.isDark ? NexTheme.darkBg : Colors.white,
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF5E5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.flame_fill, color: Color(0xFFFF9500), size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                isCompany ? 'Multiplicá tus Postulantes' : 'Multiplica tus Entrevistas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isCompany
                    ? 'Destacá tu empresa en el feed de los candidatos por tiempo limitado y recibí más postulaciones.'
                    : 'Destaca tu perfil en el feed de las empresas por tiempo limitado y recibe ofertas urgentes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
              // ── Tarjeta de resultados: prueba de impacto del boost activo ──
              if (_daysLeft != null) ...[
                const SizedBox(height: 28),
                _buildBoostResultsCard(context),
              ],

              const SizedBox(height: 40),

              // Opciones
              ...List.generate(options.length, (index) {
                final opt = options[index];
                final isSelected = _selectedOption == index;
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedOption = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7))
                          : context.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected ? MployaTheme.brandAccent : context.dividerColor,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [const BoxShadow(color: Color(0x1A34C759), blurRadius: 16, offset: Offset(0, 4))]
                          : [],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: opt['gradient'] as List<Color>,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(opt['icon'] as IconData, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt['title'] as String,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                opt['desc'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              opt['price'] as String,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              opt['duration'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: MployaTheme.brandAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 40),
              
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _processPayment,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: MployaTheme.brandAccent,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(color: Color(0x4034C759), blurRadius: 16, offset: Offset(0, 8))
                    ],
                  ),
                  child: Center(
                    child: const Text(
                      'Próximamente',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'El cargo se realizará a tu cuenta de Apple ID / Google Play. Puedes cancelar en cualquier momento desde los ajustes de tu teléfono.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
