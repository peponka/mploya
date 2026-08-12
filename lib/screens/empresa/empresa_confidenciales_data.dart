import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Un candidato confidencial del catálogo.
///
/// Sale de la RPC `get_stealth_catalog()`, que devuelve el perfil con el nombre
/// ENMASCARADO salvo que esta empresa ya lo haya desbloqueado. La máscara la
/// aplica la base, no la UI: el cliente nunca recibe el nombre de alguien que no
/// desbloqueó.
@immutable
class CandidatoConfidencial {
  final String id;
  final String? headline;
  final String? about;
  final List<String> tags;

  /// Ya desbloqueado por esta empresa.
  final bool desbloqueado;

  /// Nombre real si está desbloqueado; si no, la máscara que manda la RPC.
  final String nombre;

  const CandidatoConfidencial({
    required this.id,
    required this.nombre,
    required this.desbloqueado,
    this.headline,
    this.about,
    this.tags = const [],
  });
}

/// Billetera de créditos de la empresa (`public.company_wallets`).
@immutable
class BilleteraEmpresa {
  final int creditos;
  final String? plan;

  /// La tabla no respondió (puede no existir o no haber fila).
  final bool noDisponible;

  const BilleteraEmpresa({
    this.creditos = 0,
    this.plan,
    this.noDisponible = false,
  });
}

@immutable
class ConfidencialesData {
  final List<CandidatoConfidencial> candidatos;
  final BilleteraEmpresa billetera;
  final bool error;

  const ConfidencialesData({
    required this.candidatos,
    this.billetera = const BilleteraEmpresa(),
    this.error = false,
  });

  static const empty = ConfidencialesData(candidatos: []);

  int get total => candidatos.length;
  int get desbloqueados =>
      candidatos.where((c) => c.desbloqueado).length;
  int get bloqueados => total - desbloqueados;
}

/// Catálogo confidencial + saldo de créditos.
Future<ConfidencialesData> loadConfidenciales() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return ConfidencialesData.empty;

  // ── Billetera ──
  var billetera = const BilleteraEmpresa(noDisponible: true);
  try {
    final fila = await client
        .from('company_wallets')
        .select('credits_balance, subscription_tier')
        .eq('company_id', uid)
        .maybeSingle();

    if (fila != null) {
      billetera = BilleteraEmpresa(
        creditos: (fila['credits_balance'] as num?)?.toInt() ?? 0,
        plan: (fila['subscription_tier']?.toString().isNotEmpty ?? false)
            ? fila['subscription_tier'].toString()
            : null,
      );
    } else {
      // Sin fila todavía: el saldo real es 0, no "desconocido".
      billetera = const BilleteraEmpresa(creditos: 0);
    }
  } catch (e) {
    debugPrint('confidenciales · company_wallets: $e');
  }

  // ── Catálogo ──
  final candidatos = <CandidatoConfidencial>[];
  try {
    final filas = await client.rpc('get_stealth_catalog') as List<dynamic>;
    for (final raw in filas) {
      final m = raw as Map;
      final id = m['candidate_id']?.toString() ?? '';
      if (id.isEmpty) continue;

      candidatos.add(
        CandidatoConfidencial(
          id: id,
          nombre: m['real_name']?.toString() ?? 'Confidencial',
          desbloqueado: m['is_unlocked'] == true,
          headline: (m['headline']?.toString().isNotEmpty ?? false)
              ? m['headline'].toString()
              : null,
          about: (m['about']?.toString().isNotEmpty ?? false)
              ? m['about'].toString()
              : null,
          tags: [
            for (final t in (m['tags'] as List? ?? const []))
              t.toString().replaceAll('#', '').trim(),
          ]..removeWhere((t) => t.isEmpty),
        ),
      );
    }
  } catch (e) {
    debugPrint('confidenciales · get_stealth_catalog: $e');
    return ConfidencialesData(
      candidatos: const [],
      billetera: billetera,
      error: true,
    );
  }

  // Primero los que ya desbloqueó: son los accionables.
  candidatos.sort((a, b) {
    if (a.desbloqueado != b.desbloqueado) return a.desbloqueado ? -1 : 1;
    return a.nombre.compareTo(b.nombre);
  });

  return ConfidencialesData(candidatos: candidatos, billetera: billetera);
}

/// Resultado del intento de desbloqueo, tal como lo devuelve la RPC.
enum ResultadoDesbloqueo {
  exito,
  yaDesbloqueado,
  sinCreditos,
  noPermitido,
  error,
}

/// Desbloquea un perfil confidencial gastando un crédito.
///
/// La RPC `unlock_stealth_profile` es transaccional: bloquea la billetera,
/// verifica saldo, descuenta y registra en `profile_unlocks`. Acá NO se
/// descuenta nada del lado del cliente ni se asume éxito: se lee lo que
/// respondió la base.
Future<({ResultadoDesbloqueo resultado, int? saldo})> desbloquearCandidato(
  String candidatoId,
) async {
  try {
    final res = await Supabase.instance.client.rpc(
      'unlock_stealth_profile',
      params: {'p_candidate_id': candidatoId},
    );

    final mapa = res is Map ? res : <String, dynamic>{};
    final estado = mapa['status']?.toString();
    final error = mapa['error']?.toString();
    final saldo = (mapa['remaining_balance'] as num?)?.toInt() ??
        (mapa['balance'] as num?)?.toInt();

    if (estado == 'success') {
      return (resultado: ResultadoDesbloqueo.exito, saldo: saldo);
    }
    if (estado == 'already_unlocked') {
      return (resultado: ResultadoDesbloqueo.yaDesbloqueado, saldo: saldo);
    }
    if (error == 'insufficient_funds') {
      return (resultado: ResultadoDesbloqueo.sinCreditos, saldo: saldo);
    }
    if (error == 'cannot_unlock_self' || error == 'not_authenticated') {
      return (resultado: ResultadoDesbloqueo.noPermitido, saldo: saldo);
    }
    return (resultado: ResultadoDesbloqueo.error, saldo: saldo);
  } catch (e) {
    debugPrint('confidenciales · unlock_stealth_profile: $e');
    return (resultado: ResultadoDesbloqueo.error, saldo: null);
  }
}
