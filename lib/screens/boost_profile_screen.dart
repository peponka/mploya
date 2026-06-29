import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/profile_view_service.dart';

class BoostProfileScreen extends ConsumerStatefulWidget {
  /// Las empresas pagan un poco más (mayor valor: un buen candidato vale miles).
  final bool isCompany;

  const BoostProfileScreen({super.key, this.isCompany = false});

  @override
  ConsumerState<BoostProfileScreen> createState() => _BoostProfileScreenState();
}

class _BoostProfileScreenState extends ConsumerState<BoostProfileScreen> {
  int _selectedOption = 0;
  bool _isLoading = false;

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
      // boost_ends_at siempre existe → días restantes.
      final row = await Supabase.instance.client
          .from('users')
          .select('boost_ends_at')
          .eq('id', uid)
          .maybeSingle();
      final endsRaw = row?['boost_ends_at'];
      final ends = endsRaw != null ? DateTime.tryParse(endsRaw.toString()) : null;
      if (ends == null || !ends.isAfter(DateTime.now())) return;

      final daysLeft = ends.difference(DateTime.now()).inDays;

      // boost_started_at puede no existir aún (falta correr boost_setup.sql).
      int? views;
      try {
        final s = await Supabase.instance.client
            .from('users')
            .select('boost_started_at')
            .eq('id', uid)
            .maybeSingle();
        final startRaw = s?['boost_started_at'];
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

  // ══════════════════════════════════════════════════════════════════════════
  // 🚀 MODO FUNDADOR — Boost gratis para todos hasta tener masa crítica.
  //
  // true  → botón "Activar Boost GRATIS"; activa sin cobrar (estrategia de
  //         lanzamiento: que lo usen, vean que funciona, y recién después cobrar).
  // false → botón "Pagar $X".
  //
  // ⚠️ PARA COBRAR DE VERDAD NO ALCANZA CON PONER ESTO EN FALSE. Hoy la rama de
  //    pago (abajo, en _processPayment) es un BYPASS que igual activa gratis
  //    ("solo para TestFlight"). Antes de cobrar hay que, en ese orden:
  //    1) Configurar los productos/precios en RevenueCat (1sem/2sem/1mes, y la
  //       variante empresa más cara). El IAP de Apple/Google es SOLO MÓVIL: en
  //       web NO se puede cobrar con Apple Pay/Play — para web haría falta Stripe.
  //    2) Reemplazar el bypass por la compra real (RevenueCatService.purchase…)
  //       y recién escribir boost_ends_at si el pago fue exitoso.
  //    3) Subir fuerte el precio de empresa (un buen candidato vale miles).
  //    Hasta tener eso, dejá _founderMode = true.
  // ══════════════════════════════════════════════════════════════════════════
  static const _founderMode = true;
  // ignore: unused_field
  static const _founderBoostDays = 30; // Duración del boost gratis

  void _processPayment() async {
    setState(() => _isLoading = true);

    final uid = Supabase.instance.client.auth.currentUser?.id;
    int durationDays = 7;
    if (_selectedOption == 1) durationDays = 14;
    if (_selectedOption == 2) durationDays = 30;

    if (_founderMode && uid != null) {
      // Modo Fundador: activar boost gratis directamente en la DB
      final boostEnd = DateTime.now().add(Duration(days: durationDays));
      try {
        await Supabase.instance.client.from('users').update({
          'boost_ends_at': boostEnd.toUtc().toIso8601String(),
        }).eq('id', uid);
      } catch (e) {
        debugPrint('Error activando boost fundador: $e');
      }
    } else {
      // ⚠️⚠️ BYPASS DE PAGO — NO COBRA. Activa el boost gratis igual (TestFlight).
      // ANTES DE LANZAR PAGO: reemplazar este bloque por la compra real de
      // RevenueCat (móvil) o Stripe (web) y escribir boost_ends_at SOLO si el
      // pago fue exitoso. Ver el comentario de _founderMode arriba.
      try {
        final boostEnd = DateTime.now().add(Duration(days: durationDays));
        if (uid != null) {
          await Supabase.instance.client.from('users').update({
            'boost_ends_at': boostEnd.toUtc().toIso8601String(),
          }).eq('id', uid);
        }
      } catch (e) {
        debugPrint('Error activando boost fallback: $e');
      }
      await Future.delayed(const Duration(seconds: 1));
    }

    // Guardar inicio del boost para medir su impacto (vistas generadas). Si la
    // columna no existe todavía (falta correr boost_setup.sql) se ignora sin
    // romper la activación.
    if (uid != null) {
      try {
        await Supabase.instance.client.from('users').update({
          'boost_started_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', uid);
      } catch (_) {}
    }

    setState(() => _isLoading = false);

    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (c) => CupertinoAlertDialog(
          title: const Text('¡Boost Activado!'),
          content: Text(
            '🎁 Boost activado con éxito por $durationDays días. Tu perfil ahora es top tier en el feed correspondiente.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Increíble'),
              onPressed: () {
                Navigator.pop(c);
                Navigator.pop(context);
              },
            )
          ],
        ),
      );
    }
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
                onPressed: _isLoading ? null : _processPayment,
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
                    child: _isLoading 
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : Text(
                          _founderMode
                              ? '🎁 Activar Boost GRATIS'
                              : 'Pagar ${options[_selectedOption]['price']}',
                          style: const TextStyle(
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