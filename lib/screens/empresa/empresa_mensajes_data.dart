import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/user_columns.dart';

/// Una conversación: el otro participante + el último mensaje.
@immutable
class Conversacion {
  final String otroId;
  final String nombre;
  final String headline;
  final String? avatar;

  /// Texto del último mensaje intercambiado.
  final String ultimoMensaje;
  final DateTime? fecha;

  /// Mensajes recibidos sin leer.
  final int sinLeer;

  /// El último mensaje lo mandé yo.
  final bool ultimoEsMio;

  const Conversacion({
    required this.otroId,
    required this.nombre,
    required this.ultimoMensaje,
    this.headline = '',
    this.avatar,
    this.fecha,
    this.sinLeer = 0,
    this.ultimoEsMio = false,
  });

  /// "14:28" si es de hoy, "Ayer", o "12 May".
  String get hora {
    if (fecha == null) return '';
    final ahora = DateTime.now();
    final f = fecha!;
    if (f.year == ahora.year && f.month == ahora.month && f.day == ahora.day) {
      return '${f.hour.toString().padLeft(2, '0')}:'
          '${f.minute.toString().padLeft(2, '0')}';
    }
    final ayer = ahora.subtract(const Duration(days: 1));
    if (f.year == ayer.year && f.month == ayer.month && f.day == ayer.day) {
      return 'Ayer';
    }
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return '${f.day} ${meses[f.month - 1]}';
  }
}

@immutable
class MensajesData {
  final List<Conversacion> conversaciones;
  final bool error;

  const MensajesData({required this.conversaciones, this.error = false});

  static const empty = MensajesData(conversaciones: []);

  int get totalSinLeer =>
      conversaciones.fold<int>(0, (sum, c) => sum + c.sinLeer);
}

/// Carga las conversaciones reales del usuario autenticado.
///
/// Se arma desde `messages` (sender_id / receiver_id / text / is_read /
/// created_at), agrupando por interlocutor y quedándose con el último mensaje.
/// Los datos del otro participante salen de `users`.
///
/// No hay conversaciones de relleno: si no hay mensajes, la lista vuelve vacía.
Future<MensajesData> loadEmpresaConversaciones() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return MensajesData.empty;

  try {
    final filas = List<Map<String, dynamic>>.from(
      await client
          .from('messages')
          .select('sender_id, receiver_id, text, is_read, created_at')
          .or('sender_id.eq.$uid,receiver_id.eq.$uid')
          .order('created_at', ascending: false)
          .limit(400),
    );

    if (filas.isEmpty) return MensajesData.empty;

    // Primer mensaje de cada interlocutor = el último, porque vienen ordenados
    // de más nuevo a más viejo.
    final ultimos = <String, Map<String, dynamic>>{};
    final sinLeer = <String, int>{};

    for (final fila in filas) {
      final emisor = fila['sender_id']?.toString() ?? '';
      final receptor = fila['receiver_id']?.toString() ?? '';
      final otro = emisor == uid ? receptor : emisor;
      if (otro.isEmpty || otro == uid) continue;

      ultimos.putIfAbsent(otro, () => fila);

      // Sin leer = recibidos por mí que siguen sin marcar.
      if (receptor == uid && fila['is_read'] != true) {
        sinLeer[otro] = (sinLeer[otro] ?? 0) + 1;
      }
    }

    if (ultimos.isEmpty) return MensajesData.empty;

    // Datos de los interlocutores.
    final perfiles = <String, Map<String, dynamic>>{};
    try {
      final usuarios = List<Map<String, dynamic>>.from(
        await client
            .from('users')
            .select(kUserColumns)
            .inFilter('id', ultimos.keys.toList()),
      );
      for (final u in usuarios) {
        perfiles[u['id'].toString()] = u;
      }
    } catch (e) {
      // Si users no se puede leer (permisos), igual mostramos la conversación
      // con el texto real; sólo faltará el nombre.
      debugPrint('mensajes · users: $e');
    }

    final conversaciones = <Conversacion>[];
    ultimos.forEach((otro, fila) {
      final perfil = perfiles[otro];
      conversaciones.add(
        Conversacion(
          otroId: otro,
          nombre: (perfil?['name']?.toString().isNotEmpty ?? false)
              ? perfil!['name'].toString()
              : 'Candidato',
          headline: perfil?['headline']?.toString() ?? '',
          avatar: (perfil?['avatar_url']?.toString().isNotEmpty ?? false)
              ? perfil!['avatar_url'].toString()
              : null,
          ultimoMensaje: fila['text']?.toString() ?? '',
          fecha: DateTime.tryParse(fila['created_at']?.toString() ?? ''),
          sinLeer: sinLeer[otro] ?? 0,
          ultimoEsMio: fila['sender_id']?.toString() == uid,
        ),
      );
    });

    conversaciones.sort((a, b) {
      final fa = a.fecha;
      final fb = b.fecha;
      if (fa == null || fb == null) return 0;
      return fb.compareTo(fa);
    });

    return MensajesData(conversaciones: conversaciones);
  } catch (e) {
    debugPrint('mensajes · messages: $e');
    return const MensajesData(conversaciones: [], error: true);
  }
}
