import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Referral system — invite friends, earn rewards.
class ReferralService {
  ReferralService._();
  static final instance = ReferralService._();

  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  /// Get or create referral code for current user
  Future<String?> getMyCode() async {
    if (_uid == null) return null;
    try {
      final row = await _supabase.from('referral_codes').select().eq('user_id', _uid!).maybeSingle();
      if (row != null) return row['code']?.toString();
      // Create new code
      final code = 'MPL-${_uid!.substring(0, 6).toUpperCase()}';
      await _supabase.from('referral_codes').insert({'user_id': _uid, 'code': code});
      return code;
    } catch (e) { debugPrint('Referral: $e'); return null; }
  }

  /// Count referrals made by current user
  Future<int> myReferralCount() async {
    if (_uid == null) return 0;
    try {
      final rows = await _supabase.from('referrals').select('id').eq('referrer_id', _uid!);
      return (rows as List).length;
    } catch (_) { return 0; }
  }

  /// Apply a referral code (called during signup)
  Future<bool> applyCode(String code) async {
    if (_uid == null) return false;
    try {
      final ref = await _supabase.from('referral_codes').select().eq('code', code).maybeSingle();
      if (ref == null) return false;
      final referrerId = ref['user_id']?.toString();
      if (referrerId == null || referrerId == _uid) return false;
      await _supabase.from('referrals').insert({
        'referrer_id': referrerId, 'referred_id': _uid, 'referral_code': code,
      });
      await _supabase.from('referral_codes').update({
        'uses_count': (ref['uses_count'] as int? ?? 0) + 1,
      }).eq('code', code);
      return true;
    } catch (e) { debugPrint('Referral apply: $e'); return false; }
  }

  /// Get share link
  String getShareLink(String code) => 'https://mploya.ai/invite/$code';
}
