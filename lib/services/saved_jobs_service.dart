import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service para saved jobs + job alerts.
class SavedJobsService {
  SavedJobsService._();
  static final instance = SavedJobsService._();

  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> fetchSavedJobs() async {
    if (_uid == null) return [];
    try {
      final rows = await _supabase.from('saved_jobs').select().eq('user_id', _uid!).order('saved_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) { debugPrint('SavedJobs: $e'); return []; }
  }

  Future<bool> isJobSaved(String jobId) async {
    if (_uid == null) return false;
    try {
      final rows = await _supabase.from('saved_jobs').select('id').eq('user_id', _uid!).eq('job_id', jobId).limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) { return false; }
  }

  Future<void> toggleSave(String jobId) async {
    if (_uid == null) return;
    final saved = await isJobSaved(jobId);
    try {
      if (saved) {
        await _supabase.from('saved_jobs').delete().eq('user_id', _uid!).eq('job_id', jobId);
      } else {
        await _supabase.from('saved_jobs').insert({'user_id': _uid, 'job_id': jobId});
      }
    } catch (e) { debugPrint('SavedJobs toggle: $e'); }
  }

  Future<int> savedCount() async {
    if (_uid == null) return 0;
    try {
      final rows = await _supabase.from('saved_jobs').select('id').eq('user_id', _uid!);
      return (rows as List).length;
    } catch (_) { return 0; }
  }
}
