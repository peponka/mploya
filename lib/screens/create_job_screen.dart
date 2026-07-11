import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../navigation/main_navigation.dart';
import '../widgets/unsaved_changes_guard.dart';
import '../services/ai_match_service.dart';

class CreateJobScreen extends StatefulWidget {
  final bool fromOnboarding;
  const CreateJobScreen({super.key, this.fromOnboarding = false});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _salaryController = TextEditingController();
  final _locationController = TextEditingController(text: 'Remoto');
  final _tagController = TextEditingController();

  String _modality = 'remote';
  String _seniority = 'mid';
  final List<String> _tags = [];
  bool _isSubmitting = false;
  bool _isGenerating = false;

  final Map<String, String> _modalityLabels = {
    'remote': 'Remoto',
    'hybrid': 'Híbrido',
    'onsite': 'Presencial',
  };

  final Map<String, String> _seniorityLabels = {
    'junior': 'Junior',
    'mid': 'Mid-Level',
    'senior': 'Senior',
    'lead': 'Lead / Manager',
    'clevel': 'C-Level / Director',
  };

  void _addTag() {
    final tag = _tagController.text.trim().toLowerCase();
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 8) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  // Genera con IA (Gemini) descripción + salario + tags a partir del título.
  Future<void> _generateWithAI() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showAlert('Escribí primero el título del puesto.');
      return;
    }
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    final res = await AIMatchService.instance.generateJobPosting(
      title,
      notes: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
    );
    if (mounted && res != null) {
      final desc = (res['description'] ?? '').toString().trim();
      final reqs = (res['requirements'] as List?)?.map((e) => '• $e').join('\n') ?? '';
      setState(() {
        _descriptionController.text = [
          if (desc.isNotEmpty) desc,
          if (reqs.isNotEmpty) 'Requisitos:\n$reqs',
        ].join('\n\n');
        final salary = (res['salary_range'] ?? '').toString().trim();
        if (salary.isNotEmpty) _salaryController.text = salary;
        for (final t in (res['tags'] as List?) ?? []) {
          final clean = t.toString().replaceAll('#', '').trim().toLowerCase();
          if (clean.isNotEmpty && !_tags.contains(clean) && _tags.length < 8) {
            _tags.add(clean);
          }
        }
      });
    } else if (mounted) {
      _showAlert('No se pudo generar con IA. Probá de nuevo en unos segundos.');
    }
    if (mounted) setState(() => _isGenerating = false);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showAlert('El título es obligatorio');
      return;
    }

    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _isSubmitting = true);

    try {
      final inserted = await _supabase.from('jobs').insert({
        'company_id': uid,
        'title': title,
        'description': _descriptionController.text.trim(),
        'salary_range': _salaryController.text.trim(),
        'location': _locationController.text.trim(),
        'modality': _modality,
        'seniority': _seniority,
        'tags': _tags,
      }).select('id').single();

      // Generar el embedding de la vacante para el AI Matching (migración 005).
      // Best-effort: no bloquea la navegación ni falla la creación si el
      // servicio de embeddings no responde.
      final jobId = inserted['id']?.toString();
      if (jobId != null) {
        AIMatchService.instance.generateJobEmbedding(jobId);
      }

      if (mounted) {
        if (widget.fromOnboarding) {
          Navigator.of(context, rootNavigator: true).pushReplacement(
            CupertinoPageRoute(builder: (_) => const MainNavigation()),
          );
        } else {
          Navigator.pop(context, true); // true = job creado
        }
      }
    } catch (e) {
      debugPrint('Error creating job: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showAlert('Error al publicar: $e');
      }
    }
  }

  void _showAlert(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Atención'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _salaryController.dispose();
    _locationController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      hasUnsavedChanges: () => _titleController.text.trim().isNotEmpty || _descriptionController.text.trim().isNotEmpty,
      child: CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Nueva Vacante'),
        automaticallyImplyLeading: !widget.fromOnboarding,
        leading: widget.fromOnboarding
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pushReplacement(
                    CupertinoPageRoute(builder: (_) => const MainNavigation()),
                  );
                },
                child: const Text('Omitir', style: TextStyle(color: CupertinoColors.systemGrey)),
              )
            : null,
        trailing: _isSubmitting
            ? const CupertinoActivityIndicator(radius: 10)
            : CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: _submit,
                child: const Text(
                  'Publicar',
                  style: TextStyle(
                    color: MployaTheme.brandAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
              children: [
                // ── Título ──
                const _SectionLabel(label: 'Título del puesto *'),
                const SizedBox(height: 8),
                _StyledTextField(
                  controller: _titleController,
                  placeholder: 'ej: Senior Flutter Developer',
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                // ── Generar con IA: completa descripción, salario y tags ──
                GestureDetector(
                  onTap: _generateWithAI,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: MployaTheme.brandAccent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MployaTheme.brandAccent.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isGenerating)
                          const CupertinoActivityIndicator(radius: 9, color: MployaTheme.brandAccent)
                        else
                          const Icon(CupertinoIcons.sparkles, color: MployaTheme.brandAccent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _isGenerating ? 'Generando…' : 'Generar con IA ✨',
                          style: const TextStyle(
                            color: MployaTheme.brandAccent,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Descripción ──
                const _SectionLabel(label: 'Descripción'),
                const SizedBox(height: 8),
                _StyledTextField(
                  controller: _descriptionController,
                  placeholder: 'Responsabilidades, cultura, requisitos...',
                  maxLines: 5,
                ),
                const SizedBox(height: 24),

                // ── Salario ──
                const _SectionLabel(label: 'Rango salarial'),
                const SizedBox(height: 8),
                _StyledTextField(
                  controller: _salaryController,
                  placeholder: 'ej: USD 3K-5K/mes',
                ),
                const SizedBox(height: 24),

                // ── Ubicación ──
                const _SectionLabel(label: 'Ubicación'),
                const SizedBox(height: 8),
                _StyledTextField(
                  controller: _locationController,
                  placeholder: 'ej: Buenos Aires, Argentina',
                ),
                const SizedBox(height: 24),

                // ── Modalidad ──
                const _SectionLabel(label: 'Modalidad'),
                const SizedBox(height: 10),
                _ChipSelector<String>(
                  options: _modalityLabels,
                  selected: _modality,
                  onSelect: (v) => setState(() => _modality = v),
                ),
                const SizedBox(height: 24),

                // ── Seniority ──
                const _SectionLabel(label: 'Seniority'),
                const SizedBox(height: 10),
                _ChipSelector<String>(
                  options: _seniorityLabels,
                  selected: _seniority,
                  onSelect: (v) => setState(() => _seniority = v),
                ),
                const SizedBox(height: 24),

                // ── Tags / Skills ──
                const _SectionLabel(label: 'Skills / Tags'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StyledTextField(
                        controller: _tagController,
                        placeholder: 'ej: flutter, react, fintech',
                        onSubmitted: (_) => _addTag(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    CupertinoButton(
                      padding: const EdgeInsets.all(10),
                      color: MployaTheme.brandAccent,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: _addTag,
                      child: const Icon(CupertinoIcons.add, size: 18, color: Colors.white),
                    ),
                  ],
                ),
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags
                        .map((tag) => GestureDetector(
                              onTap: () => _removeTag(tag),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5F3DC4).withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF5F3DC4).withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '#$tag',
                                      style: const TextStyle(
                                        color: Color(0xFF5F3DC4),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(CupertinoIcons.xmark_circle_fill,
                                        size: 14, color: const Color(0xFF5F3DC4).withValues(alpha: 0.5)),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 40),

                // ── Submit Button ──
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: MployaTheme.brandAccent,
                    borderRadius: BorderRadius.circular(14),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.briefcase_fill, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Publicar Vacante',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 60),
              ],
        ),
      ),
      ),
    );
  }
}

// ─── Helper Widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  const _StyledTextField({
    required this.controller,
    required this.placeholder,
    this.maxLines = 1,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      autofocus: autofocus,
      maxLines: maxLines,
      onSubmitted: onSubmitted,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        
      ),
      style: TextStyle(
        color: context.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      placeholderStyle: TextStyle(
        color: context.textTertiary,
        fontSize: 15,
      ),
    );
  }
}

class _ChipSelector<T> extends StatelessWidget {
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onSelect;

  const _ChipSelector({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries.map((e) {
        final isActive = e.key == selected;
        return GestureDetector(
          onTap: () => onSelect(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              gradient: isActive
                  ? const LinearGradient(colors: [NexTheme.brandAccent, NexTheme.premiumEnd])
                  : null,
              color: isActive ? null : context.cardColor,
              borderRadius: BorderRadius.circular(12),
              
            ),
            child: Text(
              e.value,
              style: TextStyle(
                color: isActive ? Colors.white : context.textSecondary,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}