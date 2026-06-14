import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class StealthProfileBuilder extends StatefulWidget {
  const StealthProfileBuilder({super.key});

  @override
  State<StealthProfileBuilder> createState() => _StealthProfileBuilderState();
}

class _StealthProfileBuilderState extends State<StealthProfileBuilder> {
  final _supabase = Supabase.instance.client;
  
  final _headlineCtrl = TextEditingController();
  final _sectorCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _achievementsCtrl = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    
    final res = await _supabase.from('users').select('headline, about').eq('id', uid).maybeSingle();
    if (res != null && mounted) {
      _headlineCtrl.text = (res['headline'] ?? '').toString();
      
      final about = res['about']?.toString() ?? '';
      if (about.contains('||')) {
        final parts = about.split('||');
        if (parts.length >= 3) {
          _sectorCtrl.text = parts[0].trim();
          _budgetCtrl.text = parts[1].trim();
          _achievementsCtrl.text = parts[2].trim();
        }
      } else if (about.contains('Logros Clave:')) {
        final logrosMatch = RegExp(r'Logros Clave:\n(.+?)(?:\n|$)').firstMatch(about);
        _achievementsCtrl.text = logrosMatch?.group(1)?.trim() ?? about;
        final ubicMatch = RegExp(r'Ubicación:\s*(.+?)(?:\s*\n|$)').firstMatch(about);
        _sectorCtrl.text = ubicMatch?.group(1)?.trim() ?? '';
        final budgetMatch = RegExp(r'Presupuesto manejado:\s*(.+?)(?:\s*\||$)').firstMatch(about);
        _budgetCtrl.text = budgetMatch?.group(1)?.trim() ?? '';
      } else {
        _achievementsCtrl.text = about;
      }
      setState(() {});
    }
  }

  Future<void> _saveBoveda() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    if (_headlineCtrl.text.isEmpty || _achievementsCtrl.text.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final blindCv = '${_sectorCtrl.text} || ${_budgetCtrl.text} || ${_achievementsCtrl.text}';
      
      await _supabase.from('users').update({
        'headline': _headlineCtrl.text,
        'about': blindCv,
      }).eq('id', uid);

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Bóveda Actualizada'),
            content: const Text('Tu "CV Ciego" ahora es visible para las empresas. Necesitarán gastar 1 Token para ver tu identidad corporativa y tu Video-Pitch.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('Excelente'),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
              )
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.bgColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: context.bgColor,
        middle: Text('Constructor de Bóveda', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.clear, color: context.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MployaTheme.brandAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.lock_shield_fill, color: MployaTheme.brandAccent, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tu Identidad está Protegida', style: TextStyle(color: MployaTheme.brandAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('Las empresas solo verán estos datos ciegos. Es tu "carnada" corporativa.', style: TextStyle(color: context.textSecondary, fontSize: 13, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              Text('Cargo Actual (Ej. VP of Engineering)', style: TextStyle(color: context.textSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildField(_headlineCtrl, 'Ej. C-Level Ejecutivo en SaaS B2B'),
              
              const SizedBox(height: 24),
              Text('Industria / Sector', style: TextStyle(color: context.textSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildField(_sectorCtrl, 'Ej. Fintech, Proptech, Health...'),

              const SizedBox(height: 24),
              Text('Presupuesto Gestionado (Optional)', style: TextStyle(color: context.textSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildField(_budgetCtrl, 'Ej. \$5M - \$10M USD Anuales'),

              const SizedBox(height: 24),
              Text('CV Ciego / Logros de Rentabilidad', style: TextStyle(color: context.textSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _achievementsCtrl,
                placeholder: 'Resume en viñetas tu historial (Sin delatar tu empresa actual): \n- Crecimiento de ARR en 40% \n- Liderazgo de equipo de 120 devs \n- Cierre de Serie B',
                minLines: 5,
                maxLines: 8,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: MployaTheme.brandAccent,
                  borderRadius: BorderRadius.circular(30),
                  onPressed: _isSaving ? null : _saveBoveda,
                  child: _isSaving 
                      ? const CupertinoActivityIndicator(color: Colors.white) 
                      : const Text('Blindar y Publicar Bóveda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String placeholder) {
    return CupertinoTextField(
      controller: ctrl,
      placeholder: placeholder,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}