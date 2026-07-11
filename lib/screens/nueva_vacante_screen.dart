import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../services/ai_match_service.dart';

/// Página web-friendly para crear una vacante.
///
/// En pantalla ancha (web/desktop) se muestra como una PÁGINA de dos columnas:
/// formulario a la izquierda + vista previa en vivo a la derecha, con una barra
/// de página (breadcrumb + acciones). En pantalla angosta (móvil) cae a una sola
/// columna scrolleable. Reemplaza al bottom-sheet mobile cuando estamos en web.
class NuevaVacanteScreen extends StatefulWidget {
  const NuevaVacanteScreen({super.key});

  @override
  State<NuevaVacanteScreen> createState() => _NuevaVacanteScreenState();
}

class _NuevaVacanteScreenState extends State<NuevaVacanteScreen> {
  final _supabase = Supabase.instance.client;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _scheduleCtrl = TextEditingController();
  final _extrasCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  String? _employmentType;
  String? _experienceLevel;
  bool _isConfidential = false;
  bool _isGenerating = false;
  bool _isPublishing = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _salaryCtrl.dispose();
    _scheduleCtrl.dispose();
    _extrasCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  List<String> get _tags =>
      _tagsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _generateWithAI() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _isGenerating) return;
    setState(() => _isGenerating = true);
    final res = await AIMatchService.instance.generateJobPosting(title);
    if (mounted && res != null) {
      final desc = (res['description'] ?? '').toString().trim();
      final reqs = (res['requirements'] as List?)?.map((e) => '• $e').join('\n') ?? '';
      final salary = (res['salary_range'] ?? '').toString().trim();
      final tags = (res['tags'] as List?)?.map((t) => t.toString().replaceAll('#', '')).join(', ') ?? '';
      setState(() {
        _descCtrl.text = [
          if (desc.isNotEmpty) desc,
          if (reqs.isNotEmpty) 'Requisitos:\n$reqs',
        ].join('\n\n');
        if (salary.isNotEmpty) _salaryCtrl.text = salary;
        if (tags.isNotEmpty) _tagsCtrl.text = tags;
      });
    }
    if (mounted) setState(() => _isGenerating = false);
  }

  Future<void> _publish() async {
    if (_titleCtrl.text.trim().isEmpty || _isPublishing) return;
    setState(() => _isPublishing = true);
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _isPublishing = false);
      return;
    }
    try {
      double? lat, lng;
      if (await Geolocator.isLocationServiceEnabled()) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
          );
          lat = pos.latitude;
          lng = pos.longitude;
        }
      }
      String? nn(String s) => s.trim().isEmpty ? null : s.trim();
      final jobId = await _supabase.rpc('create_job_with_postgis', params: {
        'p_title': _titleCtrl.text,
        'p_salary': _salaryCtrl.text,
        'p_tags': _tags,
        'p_is_stealth': _isConfidential,
        'p_lat': lat,
        'p_lng': lng,
        'p_description': nn(_descCtrl.text),
        'p_employment_type': _employmentType,
        'p_schedule': nn(_scheduleCtrl.text),
        'p_experience_level': _experienceLevel,
        'p_extras': nn(_extrasCtrl.text),
      });
      // Vectorizar para el matching (best-effort).
      if (jobId is String) {
        AIMatchService.instance.generateJobEmbedding(jobId);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error creando vacante: $e');
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 860;
    return CupertinoPageScaffold(
      backgroundColor: context.bgColor,
      child: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 18, vertical: 24),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 16, child: _form(context)),
                                const SizedBox(width: 28),
                                Expanded(flex: 10, child: _aside(context)),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _form(context),
                                const SizedBox(height: 24),
                                _aside(context),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Barra de página: logo + breadcrumb + acciones ──
  Widget _topBar(BuildContext context) {
    final hairline = context.dividerColor.withValues(alpha: 0.5);
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(bottom: BorderSide(color: hairline, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: MployaTheme.brandAccent, borderRadius: BorderRadius.circular(7)),
            alignment: Alignment.center,
            child: const Text('m', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Text('Vacantes', style: TextStyle(color: context.textTertiary, fontSize: 13)),
          Text('  /  ', style: TextStyle(color: context.textTertiary, fontSize: 13)),
          Text('Nueva vacante', style: TextStyle(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 34,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: hairline, width: 0.5),
              ),
              child: Text('Cancelar', style: TextStyle(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _publish,
            child: Container(
              height: 34,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(color: MployaTheme.brandAccent, borderRadius: BorderRadius.circular(9)),
              child: _isPublishing
                  ? const CupertinoActivityIndicator(radius: 8, color: Colors.white)
                  : const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(CupertinoIcons.briefcase_fill, size: 15, color: Colors.white),
                      SizedBox(width: 7),
                      Text('Publicar', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Columna izquierda: el formulario (dentro de una tarjeta con profundidad) ──
  Widget _form(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.35), width: 0.5),
        boxShadow: context.cardShadow,
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nueva vacante', style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Publicá una posición y recibí video-pitches de los mejores perfiles.',
            style: TextStyle(color: context.textTertiary, fontSize: 13.5)),
        const SizedBox(height: 26),

        _sectionLabel(context, 'Lo esencial'),
        _label(context, 'Puesto'),
        _input(context, _titleCtrl, 'Ej. Desarrollador Flutter Senior'),
        const SizedBox(height: 12),
        Row(
          children: [
            GestureDetector(
              onTap: _generateWithAI,
              child: Container(
                height: 40,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: MployaTheme.brandAccent, borderRadius: BorderRadius.circular(9)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_isGenerating)
                    const CupertinoActivityIndicator(radius: 8, color: Colors.white)
                  else
                    const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 16),
                  const SizedBox(width: 7),
                  Text(_isGenerating ? 'Generando…' : 'Generar con IA',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Completa descripción, salario y skills desde el título',
                  style: TextStyle(color: context.textTertiary, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _label(context, 'Descripción'),
        _input(context, _descCtrl, 'Qué va a hacer la persona…', maxLines: 5),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label(context, 'Rango salarial'),
              _input(context, _salaryCtrl, 'Ej. USD 3.000 - 5.500 / mes'),
            ])),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label(context, 'Horario'),
              _input(context, _scheduleCtrl, 'Ej. Lun a Vie'),
            ])),
          ],
        ),
        const SizedBox(height: 16),
        _label(context, 'Skills / hashtags'),
        _input(context, _tagsCtrl, 'Ej. flutter, react, fintech'),

        const SizedBox(height: 24),
        Divider(height: 0.5, thickness: 0.5, color: context.dividerColor.withValues(alpha: 0.5)),
        const SizedBox(height: 20),
        _sectionLabel(context, 'Condiciones'),
        _pills(context, 'Jornada', const ['Completa', 'Parcial', 'Por horas'], _employmentType, (v) => setState(() => _employmentType = v)),
        const SizedBox(height: 18),
        _pills(context, 'Experiencia', const ['Sin experiencia', 'Se valora', 'Imprescindible'], _experienceLevel, (v) => setState(() => _experienceLevel = v)),
        const SizedBox(height: 16),
        _label(context, 'Extras'),
        _input(context, _extrasCtrl, 'Ej. Plus propinas, auto de empresa'),
      ],
      ),
    );
  }

  // ── Columna derecha: vista previa en vivo + Radar C-Level ──
  Widget _aside(BuildContext context) {
    final hairline = context.dividerColor.withValues(alpha: 0.5);
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final salary = _salaryCtrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'Vista previa'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: hairline, width: 0.5),
            boxShadow: context.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(CupertinoIcons.briefcase_fill, color: MployaTheme.brandAccent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title.isEmpty ? 'Título de la vacante' : title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: title.isEmpty ? context.textTertiary : context.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(_employmentType == null ? 'Remoto' : 'Remoto · $_employmentType',
                        style: TextStyle(color: context.textTertiary, fontSize: 12)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Text(desc.isEmpty ? 'La descripción aparecerá acá a medida que la escribís (o la generás con IA).' : desc,
                  maxLines: 4, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.5)),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: _tags.take(6).map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: MployaTheme.brandAccent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(7)),
                  child: Text('#${t.replaceAll('#', '')}', style: const TextStyle(color: MployaTheme.brandAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                )).toList()),
              ],
              const SizedBox(height: 14),
              Divider(height: 0.5, thickness: 0.5, color: hairline),
              const SizedBox(height: 12),
              Text(salary.isEmpty ? 'Salario a convenir' : salary,
                  style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── Radar C-Level ──
        GestureDetector(
          onTap: () => setState(() => _isConfidential = !_isConfidential),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isConfidential ? MployaTheme.brandAccent.withValues(alpha: 0.08) : context.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isConfidential ? MployaTheme.brandAccent.withValues(alpha: 0.5) : hairline,
                width: _isConfidential ? 1 : 0.5,
              ),
              boxShadow: context.cardShadow,
            ),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: MployaTheme.brandAccent, borderRadius: BorderRadius.circular(9)),
                child: const Icon(CupertinoIcons.dot_radiowaves_left_right, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Radar C-Level', style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Búsqueda confidencial para perfiles senior', style: TextStyle(color: context.textTertiary, fontSize: 12)),
                ]),
              ),
              CupertinoSwitch(
                value: _isConfidential,
                activeTrackColor: MployaTheme.brandAccent,
                onChanged: (v) => setState(() => _isConfidential = v),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Icon(CupertinoIcons.location_solid, size: 12, color: context.textTertiary),
          const SizedBox(width: 5),
          Expanded(child: Text('Se publica con tu ubicación GPS', style: TextStyle(color: context.textTertiary, fontSize: 12))),
        ]),
      ],
    );
  }

  // ── Helpers de UI ──
  Widget _sectionLabel(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t.toUpperCase(),
            style: TextStyle(color: context.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
      );

  Widget _label(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: TextStyle(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _input(BuildContext context, TextEditingController c, String placeholder, {int maxLines = 1}) {
    return CupertinoTextField(
      controller: c,
      placeholder: placeholder,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      style: TextStyle(color: context.textPrimary, fontSize: 14),
      placeholderStyle: TextStyle(color: context.textTertiary, fontSize: 14),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.5), width: 0.5),
      ),
    );
  }

  Widget _pills(BuildContext context, String label, List<String> options, String? value, ValueChanged<String> onPick) {
    final hairline = context.dividerColor.withValues(alpha: 0.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, label),
        Wrap(spacing: 8, runSpacing: 8, children: options.map((o) {
          final active = o == value;
          return GestureDetector(
            onTap: () => onPick(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? MployaTheme.brandAccent : context.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: active ? Colors.transparent : hairline, width: 0.5),
              ),
              child: Text(o, style: TextStyle(color: active ? Colors.white : context.textSecondary, fontWeight: active ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
            ),
          );
        }).toList()),
      ],
    );
  }
}
