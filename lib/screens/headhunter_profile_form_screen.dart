import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import 'onboarding_pitch_screen.dart';
import '../widgets/unsaved_changes_guard.dart';
import '../widgets/web_centered.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HeadhunterProfileFormScreen — Onboarding del headhunter (reclutador
// independiente / comisionista). A diferencia de la empresa, NO carga una marca
// institucional: solo su identidad, especialidad y sectores que cubre.
// ─────────────────────────────────────────────────────────────────────────────

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

        await Supabase.instance.client.from('users').update({
          'account_type': 'headhunter',
          'name': nombre,
          'headline': especialidad,
          if (ciudad.isNotEmpty) 'city': ciudad,
          'tags': cleanTags.isNotEmpty ? cleanTags : null,
          'onboarding_step': 2,
          'is_hiring': true,
        }).eq('id', uid);

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

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w600, fontSize: 15),
      );

  Widget _field(TextEditingController controller, String placeholder, {int maxLines = 1}) =>
      CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        maxLines: maxLines,
        placeholderStyle: const TextStyle(color: MployaTheme.lightTertiary),
        style: const TextStyle(color: MployaTheme.lightText),
        decoration: BoxDecoration(
          color: MployaTheme.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MployaTheme.lightDivider),
        ),
        padding: const EdgeInsets.all(16),
      );

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      hasUnsavedChanges: () =>
          _nombreController.text.trim().isNotEmpty || _especialidadController.text.trim().isNotEmpty,
      child: CupertinoPageScaffold(
        backgroundColor: MployaTheme.lightBg,
        navigationBar: const CupertinoNavigationBar(
          backgroundColor: MployaTheme.lightNavBar,
          border: null,
          middle: Text(
            'Perfil de Headhunter',
            style: TextStyle(color: MployaTheme.lightText, fontWeight: FontWeight.w700),
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CupertinoActivityIndicator(radius: 16))
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: webSidePad(context), vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: MployaTheme.brandAccent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.person_2_square_stack_fill,
                            size: 40,
                            color: MployaTheme.brandAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Reclutá talento y cobrá por cada contratación.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: MployaTheme.lightTertiary, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _label('Tu nombre o el de tu agencia'),
                      const SizedBox(height: 12),
                      _field(_nombreController, 'Ej: Laura Méndez · TalentLab'),
                      const SizedBox(height: 24),

                      _label('¿En qué te especializás?'),
                      const SizedBox(height: 12),
                      _field(_especialidadController, 'Ej: Headhunter IT & Tech, perfiles senior'),
                      const SizedBox(height: 24),

                      _label('Ciudad (opcional)'),
                      const SizedBox(height: 12),
                      _field(_ciudadController, 'Ej: Buenos Aires'),
                      const SizedBox(height: 24),

                      _label('Sectores que cubrís (separados por coma)'),
                      const SizedBox(height: 12),
                      _field(_sectoresController, 'Ej: #tech, #fintech, #ventas, marketing', maxLines: 2),
                      const SizedBox(height: 48),

                      SizedBox(
                        height: 52,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          color: MployaTheme.brandAccent,
                          borderRadius: BorderRadius.circular(14),
                          onPressed: _guardarYContinuar,
                          child: const Text(
                            'Siguiente paso: Video presentación →',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.white,
                              fontFamily: '.SF Pro Text',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
