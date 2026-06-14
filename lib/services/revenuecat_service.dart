import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RevenueCatService — Gestión de suscripciones Premium
//
// Responsabilidades:
//  • Verificar si el usuario es Premium vía Supabase (fuente de verdad)
//  • Sincronizar estado premium con Supabase
//
// ⚠️ NOTA: RevenueCat SDK fue REMOVIDO del proyecto.
//    Todo el estado premium se lee desde Supabase (is_premium).
//    Para integrar una pasarela de pago real en el futuro,
//    reemplazar este servicio con la integración correspondiente.
// ─────────────────────────────────────────────────────────────────────────────

class RevenueCatService {
  RevenueCatService._();
  static final RevenueCatService instance = RevenueCatService._();

  bool _isInitialized = false;
  bool _isPremium = false;
  Future<void>? _initFuture;

  bool get isPremium => _isPremium;
  bool get isInitialized => _isInitialized;

  // ── Inicialización (Singleton) ──────────────────────────────────────────

  Future<void> initialize(String userId) async {
    if (_isInitialized) return;
    if (_initFuture != null) return _initFuture!;
    _initFuture = _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    await _checkSupabasePremium();
    _isInitialized = true;
    debugPrint('💰 Premium (Supabase): $_isPremium');
  }

  // ── Método legacy estático (backward compat) ───────────────────────────

  static Future<void> init(String userId) async {
    await instance.initialize(userId);
  }

  // ── Premium Check ──────────────────────────────────────────────────────

  Future<bool> refreshPremiumStatus() async {
    await _checkSupabasePremium();
    return _isPremium;
  }

  // ── Comprar (placeholder → muestra "próximamente") ─────────────────────

  Future<bool> processPurchase() async {
    debugPrint('💰 Pasarela de pagos no configurada');
    return false;
  }

  // ── Restaurar Compras ──────────────────────────────────────────────────

  Future<bool> restorePurchases() async {
    await _checkSupabasePremium();
    return _isPremium;
  }

  // ── Logout ─────────────────────────────────────────────────────────────

  Future<void> logout() async {
    _isPremium = false;
  }

  // ── Check Premium desde Supabase (fuente de verdad) ───────────────────

  Future<void> _checkSupabasePremium() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('is_premium')
          .eq('id', uid)
          .maybeSingle();
      _isPremium = res?['is_premium'] == true;
    } catch (e) {
      debugPrint('Error checking Supabase premium: $e');
    }
  }

  /// Fuerza re-lectura de premium desde Supabase (útil tras bypass debug)
  Future<void> forceRefreshFromSupabase() async {
    await _checkSupabasePremium();
  }
}
