import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Profile analytics — tracks views, matches, video plays per day.
class ProfileAnalyticsService {
  ProfileAnalyticsService._();
  static final instance = ProfileAnalyticsService._();

  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  /// Fetch last N days of analytics
  Future<List<DailyAnalytics>> fetchAnalytics({int days = 30}) async {
    if (_uid == null) return [];
    try {
      final since = DateTime.now().subtract(Duration(days: days)).toIso8601String().substring(0, 10);
      final rows = await _supabase.from('profile_analytics').select()
          .eq('user_id', _uid!).gte('date', since).order('date', ascending: true);
      return rows.map((r) => DailyAnalytics.fromJson(r)).toList();
    } catch (e) { debugPrint('Analytics: $e'); return []; }
  }

  /// Get totals for current week
  Future<AnalyticsSummary> weekSummary() async {
    final data = await fetchAnalytics(days: 7);
    return AnalyticsSummary(
      totalViews: data.fold(0, (sum, d) => sum + d.views),
      totalMatches: data.fold(0, (sum, d) => sum + d.matches),
      totalVideoPlays: data.fold(0, (sum, d) => sum + d.videoPlays),
      totalMessages: data.fold(0, (sum, d) => sum + d.messagesReceived),
      totalSearchAppearances: data.fold(0, (sum, d) => sum + d.searchAppearances),
      days: data,
    );
  }

  /// Increment a stat (called from various places in the app)
  Future<void> increment(String field) async {
    if (_uid == null) return;
    try {
      await _supabase.rpc('increment_profile_stat', params: {'p_user_id': _uid, 'p_field': field});
    } catch (e) { debugPrint('Analytics increment: $e'); }
  }
}

class DailyAnalytics {
  final DateTime date;
  final int views;
  final int searchAppearances;
  final int videoPlays;
  final int matches;
  final int messagesReceived;

  const DailyAnalytics({required this.date, this.views = 0, this.searchAppearances = 0,
    this.videoPlays = 0, this.matches = 0, this.messagesReceived = 0});

  factory DailyAnalytics.fromJson(Map<String, dynamic> j) => DailyAnalytics(
    date: DateTime.tryParse(j['date']?.toString() ?? '') ?? DateTime.now(),
    views: (j['views'] as num?)?.toInt() ?? 0,
    searchAppearances: (j['search_appearances'] as num?)?.toInt() ?? 0,
    videoPlays: (j['video_plays'] as num?)?.toInt() ?? 0,
    matches: (j['matches'] as num?)?.toInt() ?? 0,
    messagesReceived: (j['messages_received'] as num?)?.toInt() ?? 0,
  );
}

class AnalyticsSummary {
  final int totalViews;
  final int totalMatches;
  final int totalVideoPlays;
  final int totalMessages;
  final int totalSearchAppearances;
  final List<DailyAnalytics> days;
  const AnalyticsSummary({required this.totalViews, required this.totalMatches,
    required this.totalVideoPlays, required this.totalMessages,
    required this.totalSearchAppearances, required this.days});
}
