import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Un desbloqueo versionado que devuelve `get_stealth_catalog()`.
@immutable
class DesbloqueoRealizado {
  final String candidatoId;
  final DateTime? cuando;

  /// Titular del candidato desbloqueado. Se puede mostrar: la empresa ya pagó
  /// por ver ese perfil.
  final String? nombre;
  final String? headline;
  final String? avatarUrl;

  const DesbloqueoRealizado({
    required this.candidatoId,
    this.cuando,
    this.nombre,
    this.headline,
    this.avatarUrl,
  });
}

@immutable
class CreditosData {
  final int creditos;
  final String? plan;

  /// No existe una fila en `company_wallets`, por lo que la empresa todavía
  /// puede ejecutar una vez `claim_welcome_credits()`.
  final bool puedeReclamarBienvenida;

  /// `company_wallets` no respondió.
  final bool billeteraNoDisponible;

  final List<DesbloqueoRealizado> desbloqueos;

  /// `profile_unlocks` no respondió.
  final bool historialNoDisponible;

  const CreditosData({
    this.creditos = 0,
    this.plan,
    this.puedeReclamarBienvenida = false,
    this.billeteraNoDisponible = false,
    this.desbloqueos = const [],
    this.historialNoDisponible = false,
  });

  static const empty = CreditosData();

  int get totalDesbloqueos => desbloqueos.length;

  /// Desbloqueos del mes en curso.
  int get desbloqueosDelMes {
    final ahora = DateTime.now();
    return desbloqueos.where((d) {
      final c = d.cuando;
      if (c == null) return false;
      return c.year == ahora.year && c.month == ahora.month;
    }).length;
  }

  /// Cada desbloqueo cuesta 1 crédito (lo fija `unlock_stealth_profile`), así
  /// que los créditos gastados son exactamente la cantidad de desbloqueos.
  int get creditosGastados => totalDesbloqueos;
}

enum ResultadoCreditosBienvenida { reclamados, yaReclamados, error }

/// Activa el bono inicial que ya implementa el backend.
Future<ResultadoCreditosBienvenida> reclamarCreditosBienvenida() async {
  try {
    final raw =
        await Supabase.instance.client.rpc('claim_welcome_credits');
    final res = raw is Map ? raw : <String, dynamic>{};
    return switch (res['status']?.toString()) {
      'success' => ResultadoCreditosBienvenida.reclamados,
      'already_claimed' => ResultadoCreditosBienvenida.yaReclamados,
      _ => ResultadoCreditosBienvenida.error,
    };
  } catch (e) {
    debugPrint('creditos · claim_welcome_credits: $e');
    return ResultadoCreditosBienvenida.error;
  }
}

/// Saldo, plan e historial real de desbloqueos.
Future<CreditosData> loadCreditos() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return CreditosData.empty;

  var creditos = 0;
  String? plan;
  var puedeReclamarBienvenida = false;
  var billeteraNoDisponible = false;

  try {
    final fila = await client
        .from('company_wallets')
        .select('credits_balance, subscription_tier')
        .eq('company_id', uid)
        .maybeSingle();

    if (fila != null) {
      creditos = (fila['credits_balance'] as num?)?.toInt() ?? 0;
      final tier = fila['subscription_tier']?.toString() ?? '';
      plan = tier.isEmpty ? null : tier;
    } else {
      puedeReclamarBienvenida = true;
    }
    // Sin fila la billetera todavía no se creó: el saldo real es 0.
  } catch (e) {
    debugPrint('creditos · company_wallets: $e');
    billeteraNoDisponible = true;
  }

  final desbloqueos = <DesbloqueoRealizado>[];
  var historialNoDisponible = false;

  try {
    final filas = await client.rpc('get_stealth_catalog') as List<dynamic>;
    for (final raw in filas) {
      final perfil = raw as Map;
      if (perfil['is_unlocked'] != true) continue;
      final candidatoId = perfil['candidate_id']?.toString() ?? '';
      if (candidatoId.isEmpty) continue;

      desbloqueos.add(
        DesbloqueoRealizado(
          candidatoId: candidatoId,
          cuando: DateTime.tryParse(
            perfil['unlocked_at']?.toString() ?? '',
          ),
          nombre: perfil['real_name']?.toString(),
          headline: (perfil['headline']?.toString().isNotEmpty ?? false)
              ? perfil['headline'].toString()
              : null,
        ),
      );
    }
    desbloqueos.sort((a, b) {
      final left = a.cuando, right = b.cuando;
      if (left == null || right == null) return 0;
      return right.compareTo(left);
    });
  } catch (e) {
    debugPrint('creditos · get_stealth_catalog: $e');
    historialNoDisponible = true;
  }

  return CreditosData(
    creditos: creditos,
    plan: plan,
    puedeReclamarBienvenida: puedeReclamarBienvenida,
    billeteraNoDisponible: billeteraNoDisponible,
    desbloqueos: desbloqueos,
    historialNoDisponible: historialNoDisponible,
  );
}
