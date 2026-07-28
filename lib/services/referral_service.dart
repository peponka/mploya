import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Canjea un código de referido (se llama después del registro).
  ///
  /// Usa la RPC `redeem_referral_code` en vez de tocar las tablas: la política
  /// RLS de `referral_codes` es `auth.uid() = user_id`, así que el INVITADO no
  /// puede leer el código de otra persona — con acceso directo esto devolvía
  /// null siempre y nunca se registraba el referido (6 códigos, 0 referidos).
  /// La RPC además valida autorreferido y canje duplicado, y notifica a quien
  /// invitó.
  Future<bool> applyCode(String code) async {
    if (_uid == null || code.trim().isEmpty) return false;
    try {
      final res = await _supabase.rpc('redeem_referral_code', params: {'p_code': code.trim()});
      final ok = res is Map && res['ok'] == true;
      if (!ok) debugPrint('Referral apply rechazado: ${res is Map ? res['error'] : res}');
      return ok;
    } catch (e) { debugPrint('Referral apply: $e'); return false; }
  }

  /// Get share link
  String getShareLink(String code) => 'https://mploya.ai/invite/$code';

  // ── Código pendiente (viene del link de invitación) ───────────────────────
  // La landing mploya.ai/invite/<code> manda a /app/?ref=<code>. Se guarda el
  // código hasta que el usuario termine de registrarse y recién ahí se canjea.

  static const _kPendingKey = 'mploya_pending_referral';

  /// Lee `?ref=` de la URL (web) y lo deja guardado. Llamar al iniciar la app.
  Future<void> captureCodeFromUrl() async {
    try {
      final code = Uri.base.queryParameters['ref']?.trim();
      if (code == null || code.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingKey, code);
      debugPrint('🎟️ Código de referido capturado: $code');
    } catch (e) { debugPrint('Referral capture: $e'); }
  }

  /// Canjea el código pendiente si hay sesión. Llamar después del login/registro.
  /// Es idempotente: la RPC rechaza el canje duplicado y acá se borra igual.
  Future<bool> applyPendingCode() async {
    if (_uid == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_kPendingKey);
      if (code == null || code.isEmpty) return false;
      final ok = await applyCode(code);
      await prefs.remove(_kPendingKey);
      return ok;
    } catch (e) { debugPrint('Referral pending: $e'); return false; }
  }
}
