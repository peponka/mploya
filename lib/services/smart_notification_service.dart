import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Smart Notifications — notification digests + weekly summaries.
class SmartNotificationService {
  SmartNotificationService._();
  static final instance = SmartNotificationService._();

  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  /// Fetch unread smart notifications
  Future<List<SmartNotification>> fetchUnread() async {
    if (_uid == null) return [];
    try {
      final rows = await _supabase.from('notification_digests').select()
          .eq('user_id', _uid!).eq('is_read', false)
          .order('created_at', ascending: false).limit(20);
      return rows.map((r) => SmartNotification.fromJson(r)).toList();
    } catch (e) { debugPrint('SmartNotif: $e'); return []; }
  }

  /// Fetch all digests
  Future<List<SmartNotification>> fetchAll({int limit = 50}) async {
    if (_uid == null) return [];
    try {
      final rows = await _supabase.from('notification_digests').select()
          .eq('user_id', _uid!).order('created_at', ascending: false).limit(limit);
      return rows.map((r) => SmartNotification.fromJson(r)).toList();
    } catch (e) { debugPrint('SmartNotif: $e'); return []; }
  }

  /// Mark as read
  Future<void> markRead(String id) async {
    await _supabase.from('notification_digests').update({'is_read': true}).eq('id', id);
  }

  /// Mark all as read
  Future<void> markAllRead() async {
    if (_uid == null) return;
    await _supabase.from('notification_digests').update({'is_read': true}).eq('user_id', _uid!).eq('is_read', false);
  }

  /// Create a digest notification (typically called server-side, but available for local use)
  Future<void> createDigest({
    required String title,
    required String body,
    String digestType = 'insight',
    Map<String, dynamic>? data,
  }) async {
    if (_uid == null) return;
    try {
      await _supabase.from('notification_digests').insert({
        'user_id': _uid, 'title': title, 'body': body,
        'digest_type': digestType, 'data': data ?? {},
      });
    } catch (e) { debugPrint('SmartNotif create: $e'); }
  }

  /// Unread count
  Future<int> unreadCount() async {
    if (_uid == null) return 0;
    try {
      final rows = await _supabase.from('notification_digests').select('id').eq('user_id', _uid!).eq('is_read', false);
      return (rows as List).length;
    } catch (_) { return 0; }
  }
}

class SmartNotification {
  final String id;
  final String title;
  final String body;
  final String digestType;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  const SmartNotification({required this.id, required this.title, required this.body,
    this.digestType = 'weekly', this.isRead = false, required this.createdAt, this.data = const {}});

  factory SmartNotification.fromJson(Map<String, dynamic> j) => SmartNotification(
    id: j['id']?.toString() ?? '',
    title: j['title']?.toString() ?? '',
    body: j['body']?.toString() ?? '',
    digestType: j['digest_type']?.toString() ?? 'weekly',
    isRead: j['is_read'] == true,
    createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
    data: (j['data'] as Map<String, dynamic>?) ?? {},
  );
}
