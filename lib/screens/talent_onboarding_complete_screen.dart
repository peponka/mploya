import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator, Divider;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/my_profile_service.dart';

import '../models/models.dart';
import '../widgets/ds/mploya_ds.dart';
import 'onboarding_tour_screen.dart';

/// "Tu perfil está listo" — Asistente A10, cierre del onboarding de candidato.
/// Referencia: design-reference/FINAL_SCREENS_CODEX/.../perfil listo.png.
///
/// CANDIDATO — TANDA 3: la versión anterior era un `StatelessWidget` 100%
/// hardcodeado — "95% Perfil completado", "IA Score 8.7/10" y 3
/// "recomendaciones de la IA" fijas, ninguna leía datos reales. Esta versión:
///   · calcula el % de completitud con la MISMA fórmula de 6 campos que
///     `ProfileCompletionBar` (widgets/profile_section_widgets.dart) — no la
///     importa como widget porque esa es una barra, acá hace falta un anillo,
///     pero es la fórmula, no una reinvención.
///   · NO muestra ningún "IA Score": no existe una fuente real de un puntaje
///     de calidad de perfil. Se prefirió no mostrar nada antes que inventar.
///   · las "recomendaciones" ahora salen de los campos que de verdad faltan
///     (si falta video, sugiere grabar video; si falta about, sugiere
///     completarlo) — antes eran 3 líneas fijas sin relación con el perfil.
///   · la tarjeta de confidencialidad sólo aparece si `account_type` es
///     realmente confidencial/stealth.
class TalentOnboardingCompleteScreen extends StatefulWidget {
  const TalentOnboardingCompleteScreen({super.key, this.previewData});

  /// Sólo para tests/capturas — si llega, la pantalla NO consulta Supabase.
  final NexUser? previewData;

  @override
  State<TalentOnboardingCompleteScreen> createState() =>
      _TalentOnboardingCompleteScreenState();
}

class _TalentOnboardingCompleteScreenState
    extends State<TalentOnboardingCompleteScreen> {
  NexUser? _perfil;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    if (widget.previewData != null) {
      _perfil = widget.previewData;
      _cargando = false;
      return;
    }
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) setState(() => _cargando = false);
        return;
      }
      final row = await loadMyProfile();
      if (!mounted) return;
      setState(() {
        _perfil = row != null ? NexUser.fromJson(row) : null;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('Perfil listo · error cargando perfil: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  // Misma fórmula de 6 campos que `ProfileCompletionBar`
  // (widgets/profile_section_widgets.dart:299) — no se reinventa el cálculo.
  ({int filled, int total, List<String> faltantes}) _completitud(NexUser p) {
    final campos = <String, bool>{
      'video': p.videoUrl != null && p.videoUrl!.isNotEmpty,
      'habilidades': p.tags.isNotEmpty,
      'titular': p.headline.isNotEmpty && p.headline != 'Directivo Stealth',
      'foto': p.avatarUrl != null && p.avatarUrl!.isNotEmpty,
      'sobre_mi': p.about != null && p.about!.isNotEmpty,
      'empresa_actual': p.company != null && p.company!.isNotEmpty,
    };
    final filled = campos.values.where((v) => v).length;
    final faltantes = campos.entries.where((e) => !e.value).map((e) => e.key).toList();
    return (filled: filled, total: campos.length, faltantes: faltantes);
  }

  static const _tips = {
    'video': (
      icon: CupertinoIcons.video_camera,
      titulo: 'Grabá tu video pitch',
      subtitulo: 'Los perfiles con video reciben muchas más visitas.',
    ),
    'habilidades': (
      icon: CupertinoIcons.tag,
      titulo: 'Agregá tus habilidades',
      subtitulo: 'Ayuda a que el matching te encuentre mejor.',
    ),
    'titular': (
      icon: CupertinoIcons.person_crop_circle,
      titulo: 'Completá tu titular profesional',
      subtitulo: 'Es lo primero que ven de vos en el feed.',
    ),
    'foto': (
      icon: CupertinoIcons.photo,
      titulo: 'Sumá una foto de perfil',
      subtitulo: 'Los perfiles con foto generan más confianza.',
    ),
    'sobre_mi': (
      icon: CupertinoIcons.doc_text,
      titulo: 'Contanos sobre vos',
      subtitulo: 'Un resumen breve mejora tu presentación.',
    ),
    'empresa_actual': (
      icon: CupertinoIcons.briefcase,
      titulo: 'Agregá tu experiencia actual',
      subtitulo: 'Le da contexto real a tu perfil.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    return MpScaffold(
      surface: MpSurfaceKind.light,
      child: _cargando
          ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    children: [
                      _TopBar(onClose: () => Navigator.of(context).maybePop()),
                      const SizedBox(height: 18),
                      Expanded(child: _buildCuerpo(context)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: MpButton(
                              label: 'Regrabar',
                              variant: MpButtonVariant.outline,
                              size: MpButtonSize.large,
                              expand: true,
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: MpButton(
                              label: 'Ir al Feed',
                              size: MpButtonSize.large,
                              expand: true,
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  CupertinoPageRoute(
                                    builder: (_) => const OnboardingTourScreen(
                                      accountType: 'candidato',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCuerpo(BuildContext context) {
    final s = context.mp;
    final perfil = _perfil;

    if (perfil == null) {
      // Sin perfil que leer (p. ej. sesión no disponible): no se inventa
      // contenido — se muestra el cierre sin métricas.
      return SingleChildScrollView(
        child: Column(
          children: [
            _titulo(),
            const SizedBox(height: 28),
            _icono(),
          ],
        ),
      );
    }

    final calc = _completitud(perfil);
    final pct = (calc.filled / calc.total * 100).round();
    final esConfidencial = perfil.isConfidential;

    return SingleChildScrollView(
      child: Column(
        children: [
          _titulo(),
          const SizedBox(height: 28),
          _icono(),
          const SizedBox(height: 28),
          _CompletionRing(pct: pct, filled: calc.filled, total: calc.total),
          if (calc.faltantes.isNotEmpty) ...[
            const SizedBox(height: 18),
            _TipsCard(faltantes: calc.faltantes, tips: _tips),
          ],
          if (esConfidencial) ...[
            const SizedBox(height: 18),
            _ConfidentialCard(color: s.accent),
          ],
        ],
      ),
    );
  }

  Widget _titulo() => const Column(
        children: [
          Text(
            'Tu perfil está listo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              height: 1.05,
              color: MpTokens.lightText,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Completaste tu perfil y ya estás listo para recibir oportunidades.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: MpTokens.lightTextSecondary, height: 1.5),
          ),
        ],
      );

  Widget _icono() => Container(
        width: 132,
        height: 132,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: MpTokens.primaryGradient,
          boxShadow: [
            BoxShadow(color: MpTokens.primary.withValues(alpha: 0.24), blurRadius: 28, offset: const Offset(0, 14)),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: CupertinoColors.white),
          child: const Icon(CupertinoIcons.checkmark_alt, size: 56, color: MpTokens.primary),
        ),
      );
}

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(gradient: s.accentGradient, borderRadius: BorderRadius.circular(14)),
          child: const Text(
            'Asistente A10',
            style: TextStyle(color: CupertinoColors.white, fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        const Spacer(),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: onClose,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: s.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: s.cardShadow,
            ),
            child: Icon(CupertinoIcons.xmark, color: s.text),
          ),
        ),
      ],
    );
  }
}

class _CompletionRing extends StatelessWidget {
  const _CompletionRing({required this.pct, required this.filled, required this.total});
  final int pct;
  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(MpTokens.radiusLG),
        border: Border.all(color: s.border),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: pct / 100,
                  strokeWidth: 10,
                  backgroundColor: s.fill,
                  valueColor: AlwaysStoppedAnimation<Color>(s.accent),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$pct%', style: MpTokens.stat.copyWith(color: s.text)),
                      const SizedBox(height: 2),
                      Text('Perfil completado', style: MpTokens.caption.copyWith(color: s.textTertiary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('$filled de $total secciones completas', style: MpTokens.caption.copyWith(color: s.textTertiary)),
        ],
      ),
    );
  }
}

typedef _Tip = ({IconData icon, String titulo, String subtitulo});

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.faltantes, required this.tips});
  final List<String> faltantes;
  final Map<String, _Tip> tips;

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(MpTokens.radiusLG),
        border: Border.all(color: s.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Para completar tu perfil', style: MpTokens.title.copyWith(color: s.text)),
          const SizedBox(height: 14),
          for (int i = 0; i < faltantes.length; i++) ...[
            if (i > 0) Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: s.border),
            ),
            _fila(s, tips[faltantes[i]]!),
          ],
        ],
      ),
    );
  }

  Widget _fila(MpSurfaceStyle s, _Tip tip) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: s.tint(s.accent), shape: BoxShape.circle),
          child: Icon(tip.icon, color: s.accent, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tip.titulo, style: MpTokens.bodyStrong.copyWith(color: s.text)),
              const SizedBox(height: 2),
              Text(tip.subtitulo, style: MpTokens.caption.copyWith(color: s.textTertiary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfidentialCard extends StatelessWidget {
  const _ConfidentialCard({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(MpTokens.radiusLG),
        border: Border.all(color: s.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: MpTokens.success.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(CupertinoIcons.shield_lefthalf_fill, color: MpTokens.success),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tu perfil es confidencial', style: MpTokens.bodyStrong.copyWith(color: s.text)),
                const SizedBox(height: 4),
                Text(
                  'Solo empresas que vos apruebes podrán ver tu información completa.',
                  style: MpTokens.caption.copyWith(color: s.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
