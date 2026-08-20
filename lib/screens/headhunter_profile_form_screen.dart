import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/my_profile_service.dart';
import '../widgets/ds/mploya_ds.dart';
import 'onboarding_pitch_screen.dart';
import '../widgets/unsaved_changes_guard.dart';
import '../widgets/web_centered.dart';

/// Onboarding del Headhunter (reclutador independiente / comisionista).
///
/// Migrada al sistema de diseño (18/8/2026), 9ª pantalla — mismo patrón de
/// `headhunter_dashboard_screen.dart`. A diferencia de la empresa, NO
/// carga una marca institucional: solo identidad, especialidad y
/// sectores que cubre.
///
/// SIN sibling ya rediseñado para comparar: verifiqué
/// `company_profile_form_screen.dart` (el onboarding de Empresa) y
/// TAMBIÉN sigue en `MployaTheme` (el sistema viejo), no en
/// `mploya_ds`/`MpTokens` — no hay a quién imitar acá todavía.
///
/// SIN mockup 1:1: `contanos sobre tu rol de headhunter.png` es un paso
/// "2 de 3" con selector de industrias (chips múltiples), nivel de
/// experiencia (tarjetas), países operados y checkbox de términos — nada
/// de eso existe en el formulario real (4 campos de texto simples, un
/// solo paso). Se migró el patrón de campo/CTA, no la composición.
///
/// Patrón: [MpIconTile] circular para el ícono de encabezado,
/// [MpFieldLabel] + [MpTextField] por campo, [MpButton] (`variant:
/// primary, expand: true, trailingArrow: true`) para el CTA. Se
/// preservaron sin cambios: `UnsavedChangesGuard`, `webSidePad(context)`
/// y el flujo de guardado/validación (sólo visual, no funcional).
class HeadhunterProfileFormScreen extends StatefulWidget {
  const HeadhunterProfileFormScreen({super.key});

  @override
  State<HeadhunterProfileFormScreen> createState() => _HeadhunterProfileFormScreenState();
}

class _HeadhunterProfileFormScreenState extends State<HeadhunterProfileFormScreen> {
  final _nombreController = TextEditingController();
  final _especialidadController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _sectoresController = TextEditingController();

  bool _isLoading = false;

  Future<void> _guardarYContinuar() async {
    final nombre = _nombreController.text.trim();
    final especialidad = _especialidadController.text.trim();
    final ciudad = _ciudadController.text.trim();
    final sectoresStr = _sectoresController.text.trim();

    if (nombre.isEmpty || especialidad.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Faltan datos'),
          content: const Text('Ingresá tu nombre (o el de tu agencia) y tu especialidad.'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Completar'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final cleanTags = sectoresStr
            .split(',')
            .map((t) => t.trim().replaceAll('#', ''))
            .where((t) => t.isNotEmpty)
            .toList();

        await updateMyHeadhunterProfile(
          name: nombre,
          headline: especialidad,
          city: ciudad,
          tags: cleanTags.isNotEmpty ? cleanTags : null,
        );

        if (!mounted) return;
        // El headhunter graba un pitch breve presentándose (lado reclutador).
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const OnboardingPitchScreen(isCompany: true)),
        );
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error guardando perfil de headhunter: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _especialidadController.dispose();
    _ciudadController.dispose();
    _sectoresController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      hasUnsavedChanges: () =>
          _nombreController.text.trim().isNotEmpty || _especialidadController.text.trim().isNotEmpty,
      child: MpSurface(
        style: MpSurfaceStyle.light,
        child: Builder(
          builder: (context) {
            final s = context.mp;
            return CupertinoPageScaffold(
              backgroundColor: s.bg,
              navigationBar: CupertinoNavigationBar(
                backgroundColor: s.card,
                border: null,
                middle: Text(
                  'Perfil de Headhunter',
                  style: TextStyle(color: s.text, fontWeight: FontWeight.w700),
                ),
              ),
              child: SafeArea(
                child: _isLoading
                    ? const Center(child: CupertinoActivityIndicator(radius: 16))
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: webSidePad(context),
                          vertical: MpTokens.space24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(
                              child: MpIconTile(
                                icon: CupertinoIcons.person_2_square_stack_fill,
                                color: MpTokens.primary,
                                size: 72,
                                circular: true,
                              ),
                            ),
                            const SizedBox(height: MpTokens.space8),
                            Center(
                              child: Text(
                                'Reclutá talento y cobrá por cada contratación.',
                                textAlign: TextAlign.center,
                                style: MpTokens.body.copyWith(color: s.textTertiary),
                              ),
                            ),
                            const SizedBox(height: MpTokens.space24),

                            const MpFieldLabel('Tu nombre o el de tu agencia'),
                            MpTextField(
                              controller: _nombreController,
                              placeholder: 'Ej: Laura Méndez · TalentLab',
                            ),
                            const SizedBox(height: MpTokens.space20),

                            const MpFieldLabel('¿En qué te especializás?'),
                            MpTextField(
                              controller: _especialidadController,
                              placeholder: 'Ej: Headhunter IT & Tech, perfiles senior',
                            ),
                            const SizedBox(height: MpTokens.space20),

                            const MpFieldLabel('Ciudad (opcional)'),
                            MpTextField(controller: _ciudadController, placeholder: 'Ej: Buenos Aires'),
                            const SizedBox(height: MpTokens.space20),

                            const MpFieldLabel('Sectores que cubrís (separados por coma)'),
                            MpTextField(
                              controller: _sectoresController,
                              placeholder: 'Ej: #tech, #fintech, #ventas, marketing',
                              maxLines: 2,
                            ),
                            const SizedBox(height: MpTokens.space40),

                            MpButton(
                              label: 'Siguiente paso: Video presentación',
                              variant: MpButtonVariant.primary,
                              size: MpButtonSize.large,
                              expand: true,
                              trailingArrow: true,
                              onPressed: _guardarYContinuar,
                            ),
                            const SizedBox(height: MpTokens.space24),
                          ],
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
