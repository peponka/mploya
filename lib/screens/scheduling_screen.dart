import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/scheduling_service.dart';

class SchedulingScreen extends StatefulWidget {
  final String? companyId;
  final String? companyName;
  final bool isCompany;
  const SchedulingScreen({super.key, this.companyId, this.companyName, this.isCompany = false});
  @override
  State<SchedulingScreen> createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends State<SchedulingScreen> {
  List<ScheduledInterview> _interviews = [];
  List<Map<String, dynamic>> _slots = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final interviews = await SchedulingService.instance.fetchMyInterviews();
    List<Map<String, dynamic>> slots = [];
    if (widget.isCompany) { slots = await SchedulingService.instance.fetchMySlots(); }
    else if (widget.companyId != null) { slots = await SchedulingService.instance.fetchAvailableSlots(widget.companyId!); }
    if (mounted) setState(() { _interviews = interviews; _slots = slots; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(middle: const Text('Entrevistas'), previousPageTitle: 'Atrás',
        trailing: widget.isCompany ? CupertinoButton(padding: EdgeInsets.zero,
          onPressed: _showAddSlot, child: const Icon(CupertinoIcons.plus_circle_fill, size: 24)) : null),
      child: _loading ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : SafeArea(child: ListView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(16), children: [
              // Upcoming interviews
              if (_interviews.isNotEmpty) ...[
                const Text('Próximas Entrevistas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
                const SizedBox(height: 10),
                ..._interviews.map((iv) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Container(
                  padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))]),
                  child: Row(children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(
                      color: iv.status == 'confirmed' ? const Color(0xFF34C759).withValues(alpha: 0.1) : const Color(0xFFFF9500).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                      child: Icon(CupertinoIcons.calendar, size: 22,
                        color: iv.status == 'confirmed' ? const Color(0xFF34C759) : const Color(0xFFFF9500))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${iv.date}  ${iv.time.substring(0, 5)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
                      Text('${iv.duration} min · ${iv.status}', style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
                    ])),
                    if (iv.status != 'cancelled')
                      CupertinoButton(padding: EdgeInsets.zero, minimumSize: Size.zero,
                        onPressed: () async { await SchedulingService.instance.cancelInterview(iv.id); _load(); },
                        child: const Icon(CupertinoIcons.xmark_circle, size: 22, color: Color(0xFFFF3B30))),
                  ])))),
                const SizedBox(height: 20),
              ],

              // Available slots (for candidates booking)
              if (!widget.isCompany && _slots.isNotEmpty) ...[
                Text('Horarios disponibles${widget.companyName != null ? ' — ${widget.companyName}' : ''}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
                const SizedBox(height: 10),
                ..._slots.map((s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: GestureDetector(
                  onTap: () => _bookSlot(s),
                  child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8)]),
                    child: Row(children: [
                      const Icon(CupertinoIcons.clock_fill, color: Color(0xFF007AFF), size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text('${s['slot_date']}  ${s['slot_time'].toString().substring(0, 5)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)))),
                      Text('${s['duration_minutes']} min', style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
                      const SizedBox(width: 8),
                      const Icon(CupertinoIcons.chevron_right, size: 16, color: Color(0xFFAEAEB2)),
                    ]))))),
              ],

              // Company slots management
              if (widget.isCompany && _slots.isNotEmpty) ...[
                const Text('Mis Horarios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
                const SizedBox(height: 10),
                ..._slots.map((s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Container(
                  padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8)]),
                  child: Row(children: [
                    Icon(CupertinoIcons.clock_fill, color: s['is_available'] == true ? const Color(0xFF34C759) : const Color(0xFF8E8E93), size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${s['slot_date']}  ${s['slot_time'].toString().substring(0, 5)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)))),
                    Text(s['is_available'] == true ? 'Libre' : 'Ocupado', style: TextStyle(fontSize: 12,
                      color: s['is_available'] == true ? const Color(0xFF34C759) : const Color(0xFF8E8E93), fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    CupertinoButton(padding: EdgeInsets.zero, minimumSize: Size.zero,
                      onPressed: () async { await SchedulingService.instance.deleteSlot(s['id'].toString()); _load(); },
                      child: const Icon(CupertinoIcons.trash, size: 18, color: Color(0xFFFF3B30))),
                  ])))),
              ],

              if (_interviews.isEmpty && _slots.isEmpty)
                Padding(padding: const EdgeInsets.all(40), child: Column(children: [
                  const Icon(CupertinoIcons.calendar, size: 48, color: Color(0xFFAEAEB2)),
                  const SizedBox(height: 12),
                  const Text('Sin entrevistas agendadas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93))),
                ])),
              const SizedBox(height: 100),
            ])),
    );
  }

  void _showAddSlot() {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    int selectedHour = 10;
    int selectedMin = 0;
    showCupertinoModalPopup(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(color: CupertinoColors.systemBackground.resolveFrom(context), height: 350,
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(children: [
            const Text('Agregar Horario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Expanded(child: CupertinoDatePicker(mode: CupertinoDatePickerMode.dateAndTime, minimumDate: DateTime.now(),
              initialDateTime: selectedDate.copyWith(hour: selectedHour, minute: selectedMin),
              onDateTimeChanged: (d) { selectedDate = d; selectedHour = d.hour; selectedMin = d.minute; })),
            SizedBox(width: double.infinity, child: CupertinoButton(color: MployaTheme.brandAccent, borderRadius: BorderRadius.circular(14),
              onPressed: () async {
                Navigator.pop(ctx);
                final date = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                final time = '${selectedHour.toString().padLeft(2, '0')}:${selectedMin.toString().padLeft(2, '0')}:00';
                await SchedulingService.instance.createSlot(date: date, time: time);
                _load();
              },
              child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)))),
          ])))));
  }

  Future<void> _bookSlot(Map<String, dynamic> slot) async {
    HapticFeedback.mediumImpact();
    final err = await SchedulingService.instance.scheduleInterview(
      companyId: widget.companyId ?? '', candidateId: '', slotId: slot['id'].toString(),
      date: slot['slot_date'].toString(), time: slot['slot_time'].toString());
    if (mounted) {
      if (err == null) { _load(); showCupertinoDialog(context: context, builder: (c) => CupertinoAlertDialog(
        title: const Text('¡Agendada!'), content: const Text('Tu entrevista fue confirmada.'),
        actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(c), child: const Text('OK'))])); }
    }
  }
}
