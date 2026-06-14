import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/claude_ai_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Profile Bio Generator — Sheet de generación de bio con Claude IA
//
// Extraído de profile_screen.dart para reducir el god file.
// ─────────────────────────────────────────────────────────────────────────────

/// Muestra el bottom sheet de generación de bio con IA.
void showGenerarBioSheet(BuildContext context, NexUser profile) {
  String selectedTone = 'profesional';
  bool isLoading = false;
  ClaudeBioResult? result;

  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: result != null
              ? _buildBioResultView(ctx, result!, profile)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF6C3FC8), Color(0xFF9B6FE8)]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Generar Bio con IA',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: CupertinoTheme.of(context).textTheme.textStyle.color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Claude generará una bio profesional a partir de tu perfil.',
                      style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'TONO',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final t in ['profesional', 'creativo', 'conciso'])
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => selectedTone = t),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: selectedTone == t ? const Color(0xFF6C3FC8) : CupertinoColors.tertiarySystemFill.resolveFrom(context),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    t[0].toUpperCase() + t.substring(1),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selectedTone == t ? Colors.white : CupertinoTheme.of(context).textTheme.textStyle.color,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: const Color(0xFF6C3FC8),
                        borderRadius: BorderRadius.circular(14),
                        onPressed: isLoading
                            ? null
                            : () async {
                                setModalState(() => isLoading = true);
                                try {
                                  final bio = await ClaudeAIService.instance.generarBio(
                                    candidato: {
                                      'nombre': profile.name,
                                      'habilidades': [...profile.skills, ...profile.tags],
                                      'experiencia_anios': profile.experience.length * 2,
                                      'ciudad': profile.location ?? 'Paraguay',
                                      'educacion': profile.education.isNotEmpty ? profile.education.first.degree : null,
                                      'idiomas': ['Español'],
                                    },
                                    tono: selectedTone,
                                  );
                                  setModalState(() {
                                    result = bio;
                                    isLoading = false;
                                  });
                                } catch (e) {
                                  setModalState(() => isLoading = false);
                                  if (ctx.mounted) {
                                    showCupertinoDialog(
                                      context: ctx,
                                      builder: (_) => CupertinoAlertDialog(
                                        title: const Text('Error'),
                                        content: Text('No se pudo generar la bio: $e'),
                                        actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(ctx))],
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isLoading
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : const Text('Generar Bio', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}

Widget _buildBioResultView(BuildContext ctx, ClaudeBioResult result, NexUser profile) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(CupertinoIcons.checkmark_circle_fill, color: NexTheme.premiumEnd, size: 22),
          const SizedBox(width: 10),
          Text(
            'Bio generada',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: CupertinoTheme.of(ctx).textTheme.textStyle.color),
          ),
        ],
      ),
      const SizedBox(height: 20),
      BioResultCard(label: 'TITULAR', text: result.titularProfesional),
      const SizedBox(height: 12),
      BioResultCard(label: 'BIO CORTA', text: result.bioCorta),
      const SizedBox(height: 12),
      BioResultCard(label: 'BIO COMPLETA', text: result.bioCompleta),
      if (result.palabrasClave.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          'PALABRAS CLAVE',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: CupertinoColors.secondaryLabel.resolveFrom(ctx)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: result.palabrasClave
              .map((k) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C3FC8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF6C3FC8).withValues(alpha: 0.3), width: 0.5),
                    ),
                    child: Text(k, style: const TextStyle(fontSize: 12, color: Color(0xFF6C3FC8), fontWeight: FontWeight.w600)),
                  ))
              .toList(),
        ),
      ],
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'Cerrar',
            style: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(ctx)),
          ),
        ),
      ),
    ],
  );
}

/// Card reutilizable para mostrar resultados de bio generada.
class BioResultCard extends StatelessWidget {
  final String label;
  final String text;

  const BioResultCard({super.key, required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.separator.resolveFrom(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: CupertinoColors.secondaryLabel.resolveFrom(context))),
              GestureDetector(
                onTap: () {
                  // Copy to clipboard
                },
                child: const Icon(CupertinoIcons.doc_on_doc, size: 14, color: Color(0xFF6C3FC8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(fontSize: 14, height: 1.5, color: CupertinoTheme.of(context).textTheme.textStyle.color)),
        ],
      ),
    );
  }
}
