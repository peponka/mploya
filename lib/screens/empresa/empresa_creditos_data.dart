import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/user_columns.dart';

/// Un desbloqueo realmente hecho por la empresa (`public.profile_unlocks`).
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

  /// `company_wallets` no respondió.
  final bool billeteraNoDisponible;

  final List<DesbloqueoRealizado> desbloqueos;

  /// `profile_unlocks` no respondió.
  final bool historialNoDisponible;

  const CreditosData({
    this.creditos = 0,
    this.plan,
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

/// Saldo, plan e historial real de desbloqueos.
Future<CreditosData> loadCreditos() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return CreditosData.empty;

  var creditos = 0;
  String? plan;
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
    }
    // Sin fila la billetera todavía no se creó: el saldo real es 0.
  } catch (e) {
    debugPrint('creditos · company_wallets: $e');
    billeteraNoDisponible = true;
  }

  final desbloqueos = <DesbloqueoRealizado>[];
  var historialNoDisponible = false;

  try {
    final filas = await client
        .from('profile_unlocks')
        .select('candidate_id, created_at')
        .eq('company_id', uid)
        .order('created_at', ascending: false) as List<dynamic>;

    final fechaPorId = <String, DateTime?>{};
    for (final f in filas) {
      final m = f as Map;
      final id = m['candidate_id']?.toString();
      if (id == null || id.isEmpty) continue;
      fechaPorId[id] = DateTime.tryParse(m['created_at']?.toString() ?? '');
    }

    // Los perfiles se traen aparte: la empresa ya los desbloqueó, así que puede
    // verlos con nombre.
    final perfiles = <String, Map<String, dynamic>>{};
    if (fechaPorId.isNotEmpty) {
      try {
        final filasPerfiles = await client
            .from('users')
            .select(kUserColumns)
            .inFilter('id', fechaPorId.keys.toList()) as List<dynamic>;
        for (final p in filasPerfiles) {
          final m = Map<String, dynamic>.from(p as Map);
          perfiles[m['id'].toString()] = m;
        }
      } catch (e) {
        debugPrint('creditos · users: $e');
      }
    }

    for (final entrada in fechaPorId.entries) {
      final perfil = perfiles[entrada.key];
      desbloqueos.add(
        DesbloqueoRealizado(
          candidatoId: entrada.key,
          cuando: entrada.value,
          nombre: perfil?['name']?.toString(),
          headline: (perfil?['headline']?.toString().isNotEmpty ?? false)
              ? perfil!['headline'].toString()
              : null,
          avatarUrl: (perfil?['avatar_url']?.toString().isNotEmpty ?? false)
              ? perfil!['avatar_url'].toString()
              : null,
        ),
      );
    }
  } catch (e) {
    debugPrint('creditos · profile_unlocks: $e');
    historialNoDisponible = true;
  }

  return CreditosData(
    creditos: creditos,
    plan: plan,
    billeteraNoDisponible: billeteraNoDisponible,
    desbloqueos: desbloqueos,
    historialNoDisponible: historialNoDisponible,
  );
}
