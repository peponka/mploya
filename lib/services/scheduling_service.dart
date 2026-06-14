import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Interview scheduling service — slots + scheduled interviews.
class SchedulingService {
  SchedulingService._();
  static final instance = SchedulingService._();

  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  // ── Company: manage slots ──
  Future<List<Map<String, dynamic>>> fetchMySlots() async {
    if (_uid == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        await _supabase.from('interview_slots').select().eq('company_id', _uid!).order('slot_date').order('slot_time'));
    } catch (e) { debugPrint('Scheduling slots: $e'); return []; }
  }

  Future<void> createSlot({required String date, required String time, int duration = 30}) async {
    if (_uid == null) return;
    try {
      await _supabase.from('interview_slots').insert({
        'company_id': _uid, 'slot_date': date, 'slot_time': time, 'duration_minutes': duration,
      });
    } catch (e) { debugPrint('Scheduling create slot: $e'); }
  }

  Future<void> deleteSlot(String slotId) async {
    await _supabase.from('interview_slots').delete().eq('id', slotId);
  }

  // ── Company: view available slots for a company ──
  Future<List<Map<String, dynamic>>> fetchAvailableSlots(String companyId) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      return List<Map<String, dynamic>>.from(
        await _supabase.from('interview_slots').select()
            .eq('company_id', companyId).eq('is_available', true)
            .gte('slot_date', today).order('slot_date').order('slot_time'));
    } catch (e) { debugPrint('Scheduling available: $e'); return []; }
  }

  // ── Schedule an interview ──
  Future<String?> scheduleInterview({
    required String companyId,
    required String candidateId,
    required String slotId,
    required String date,
    required String time,
    int duration = 30,
    String? notes,
  }) async {
    try {
      await _supabase.from('scheduled_interviews').insert({
        'slot_id': slotId, 'company_id': companyId, 'candidate_id': candidateId,
        'scheduled_date': date, 'scheduled_time': time, 'duration_minutes': duration,
        'notes': notes, 'status': 'confirmed',
      });
      // Mark slot as taken
      await _supabase.from('interview_slots').update({'is_available': false}).eq('id', slotId);
      return null;
    } catch (e) { return e.toString(); }
  }

  // ── Fetch my upcoming interviews ──
  Future<List<ScheduledInterview>> fetchMyInterviews() async {
    if (_uid == null) return [];
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final rows = await _supabase.from('scheduled_interviews').select()
          .or('company_id.eq.$_uid,candidate_id.eq.$_uid')
          .gte('scheduled_date', today)
          .order('scheduled_date').order('scheduled_time');
      return rows.map((r) => ScheduledInterview.fromJson(r)).toList();
    } catch (e) { debugPrint('Scheduling interviews: $e'); return []; }
  }

  // ── Cancel interview ──
  Future<void> cancelInterview(String interviewId, {String? slotId}) async {
    await _supabase.from('scheduled_interviews').update({'status': 'cancelled'}).eq('id', interviewId);
    if (slotId != null) {
      await _supabase.from('interview_slots').update({'is_available': true}).eq('id', slotId);
    }
  }
}

class ScheduledInterview {
  final String id;
  final String companyId;
  final String candidateId;
  final String date;
  final String time;
  final int duration;
  final String status;
  final String? meetingUrl;
  final String? notes;

  const ScheduledInterview({required this.id, required this.companyId, required this.candidateId,
    required this.date, required this.time, this.duration = 30, this.status = 'pending',
    this.meetingUrl, this.notes});

  factory ScheduledInterview.fromJson(Map<String, dynamic> j) => ScheduledInterview(
    id: j['id']?.toString() ?? '',
    companyId: j['company_id']?.toString() ?? '',
    candidateId: j['candidate_id']?.toString() ?? '',
    date: j['scheduled_date']?.toString() ?? '',
    time: j['scheduled_time']?.toString() ?? '',
    duration: (j['duration_minutes'] as num?)?.toInt() ?? 30,
    status: j['status']?.toString() ?? 'pending',
    meetingUrl: j['meeting_url']?.toString(),
    notes: j['notes']?.toString(),
  );
}
