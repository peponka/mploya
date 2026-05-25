/// Pantalla de AI Resume / CV con IA en mploya.
///
/// Muestra un CV generado por IA con resumen profesional,
/// fortalezas clave y opciones de copiar/regenerar.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mploya/config/theme.dart';

// ─── Constants ─────────────────────────────────────────────────────

const _purple = Color(0xFF7C3AED);
const _purpleLight = Color(0xFFF3E8FF);

// ─── Screen ────────────────────────────────────────────────────────

class AiResumeScreen extends ConsumerStatefulWidget {
  const AiResumeScreen({super.key});

  @override
  ConsumerState<AiResumeScreen> createState() => _AiResumeScreenState();
}

class _AiResumeScreenState extends ConsumerState<AiResumeScreen> {
  bool _isRegenerating = false;
  int _variationIndex = 0;

  static const _resumeVariations = [
    'Profesional con 5+ años de experiencia en análisis financiero y '
        'gestión de inversiones. Especializado en modelos de valuación DCF, '
        'análisis de estados financieros y proyecciones de flujo de caja. '
        'Experiencia liderando equipos multidisciplinarios en entornos '
        'fintech de alto crecimiento. Competencias sólidas en Excel avanzado, '
        'Power BI y herramientas de análisis de datos.',
    'Líder de equipos financieros con track record comprobado en la '
        'optimización de procesos operativos y reducción de costos del 30%. '
        'Experto en gestión de proyectos ágiles aplicados a finanzas '
        'corporativas. Capacidad para traducir datos complejos en estrategias '
        'accionables. MBA con especialización en Corporate Finance y '
        'certificación CFA Nivel II.',
    'Analista financiero orientado a resultados con expertise en '
        'modelado predictivo y machine learning aplicado a mercados. '
        'Desarrolló algoritmos de scoring crediticio que mejoraron la '
        'precisión en un 25%. Dominio de Python, R y SQL para análisis '
        'de grandes volúmenes de datos. Experiencia en banca de inversión '
        'y consultoría estratégica para empresas Fortune 500.',
    'Profesional innovador en finanzas con visión estratégica y '
        'capacidad para impulsar transformación digital en áreas financieras. '
        'Implementó dashboards automatizados que ahorraron 200+ horas/mes. '
        'Experiencia en due diligence, M&A y fundraising para startups. '
        'Habilidades excepcionales de comunicación y presentación ante '
        'directorios y comités de inversión.',
  ];

  static const _strengthVariations = [
    [
      'Análisis financiero avanzado y modelos de valuación',
      'Dominio de Excel (macros, VBA, tablas dinámicas)',
      'Visualización de datos con Power BI y Tableau',
      'Liderazgo de equipos de 5-10 personas',
      'Comunicación efectiva con stakeholders C-level',
      'Experiencia en startups fintech de LATAM',
    ],
    [
      'Gestión de proyectos ágiles (Scrum, Kanban)',
      'Reducción de costos operativos hasta 30%',
      'Certificación CFA Nivel II',
      'Negociación y cierre de acuerdos estratégicos',
      'Planificación financiera a largo plazo',
      'Mentoría y desarrollo de talento junior',
    ],
    [
      'Machine Learning aplicado a finanzas',
      'Python, R y SQL avanzado para análisis de datos',
      'Modelado predictivo y scoring crediticio',
      'Experiencia en banca de inversión',
      'Consultoría estratégica empresarial',
      'Automatización de reportes financieros',
    ],
    [
      'Transformación digital en áreas financieras',
      'Due diligence y procesos de M&A',
      'Fundraising y relación con inversores',
      'Dashboards automatizados (ahorro 200+ hrs/mes)',
      'Presentación ante directorios ejecutivos',
      'Innovación en procesos de control interno',
    ],
  ];

  String get _resumenProfesional => _resumeVariations[_variationIndex];
  List<String> get _fortalezas => _strengthVariations[_variationIndex];

  Future<void> _regenerate() async {
    if (_isRegenerating) return;
    setState(() => _isRegenerating = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _variationIndex = (_variationIndex + 1) % _resumeVariations.length;
        _isRegenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CV regenerado con IA ✨'),
          backgroundColor: MployaColors.orange,
        ),
      );
    }
  }

  void _copyCV() {
    final fullCV =
        'RESUMEN PROFESIONAL\n\n$_resumenProfesional\n\nFORTALEZAS CLAVE\n\n${_fortalezas.map((f) => '• $f').join('\n')}';
    Clipboard.setData(ClipboardData(text: fullCV));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CV copiado al portapapeles 📋'),
        backgroundColor: MployaColors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MployaColors.background,
      appBar: AppBar(
        backgroundColor: MployaColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.chevron_left,
                  color: MployaColors.orange,
                  size: 24,
                ),
                Text(
                  'Perfil',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MployaColors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),
        leadingWidth: 100,
        title: Text(
          'AI Resume',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MployaColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, size: 22, color: MployaColors.textPrimary),
            onPressed: _copyCV,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── Header Card ───────────────────────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  // Avatar circle with initial
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: MployaColors.orange,
                    child: Text(
                      'U',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Usuario Mploya',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Analista Financiero Sr.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── Resumen Profesional ───────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: MployaColors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: MployaColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Purple sparkle icon
                      const Text('✨', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Resumen Profesional',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: MployaColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      // Purple outlined 'IA' badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _purpleLight,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: _purple.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'IA',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _purple,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_isRegenerating)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: CircularProgressIndicator(
                          color: MployaColors.orange,
                        ),
                      ),
                    )
                  else
                    Text(
                      _resumenProfesional,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: MployaColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  // Regenerar link with refresh icon - orange
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _regenerate,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.refresh,
                            size: 16,
                            color: MployaColors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Regenerar',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: MployaColors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ─── Fortalezas Clave ──────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: MployaColors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: MployaColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Orange lightning icon
                      const Icon(
                        Icons.bolt,
                        color: MployaColors.orange,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Fortalezas Clave',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: MployaColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ..._fortalezas.map(
                    (fortaleza) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Orange checkmarks per spec
                          const Icon(
                            Icons.check_circle,
                            size: 18,
                            color: MployaColors.orange,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              fortaleza,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: MployaColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ─── Copy Button ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: MployaButton(
                label: 'Copiar CV completo',
                icon: Icons.copy,
                onPressed: _copyCV,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ─── Regenerate Button - Purple ────────────────────────
            Center(
              child: TextButton.icon(
                onPressed: _isRegenerating ? null : _regenerate,
                icon: const Text('✨', style: TextStyle(fontSize: 16)),
                label: Text(
                  'Regenerar con IA',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _purple,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
