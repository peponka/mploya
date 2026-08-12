import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Estado de una vacante, derivado SOLO de lo que el modelo soporta hoy.
///
/// `public.jobs.is_active` existe y es BOOLEAN — verificado el 10/8 contra la
/// base real. Ojo: `schema.sql` y las migraciones del repo NO lo declaran, así
/// que el repo no es fuente confiable para el esquema de `jobs`.
///
/// Por eso el estado igual se resuelve en tiempo de ejecución, que es lo que
/// sobrevive a que el esquema cambie sin pasar por una migración:
///
///   · `is_active = true`  → Activa
///   · `is_active = false` → Pausada
///   · columna ausente     → [desconocido] y la UI no muestra chip
///
/// "Cerrada" no existe en ningún campo, así que no se ofrece.
enum VacanteEstado { activa, pausada, desconocido }

@immutable
class Vacante {
  final String id;
  final String titulo;
  final String? ubicacion;
  final String? salario;

  /// Jornada declarada ('Completa', 'Parcial', 'Por horas').
  final String? jornada;

  /// Modalidad deducida de los tags ('Remoto', 'Híbrido', 'Presencial').
  final String? modalidad;

  final List<String> tags;
  final DateTime? creada;
  final VacanteEstado estado;

  /// Postulaciones reales asociadas.
  final int candidatos;

  /// Vacante confidencial (`jobs.type = 'Stealth'`).
  final bool confidencial;

  const Vacante({
    required this.id,
    required this.titulo,
    required this.estado,
    required this.candidatos,
    this.ubicacion,
    this.salario,
    this.jornada,
    this.modalidad,
    this.tags = const [],
    this.creada,
    this.confidencial = false,
  });

  /// "Hace 2 días". Null si no hay fecha.
  String? get antiguedad {
    if (creada == null) return null;
    final diff = DateTime.now().difference(creada!);
    if (diff.inDays >= 30) {
      final meses = (diff.inDays / 30).floor();
      return 'Hace $meses ${meses == 1 ? 'mes' : 'meses'}';
    }
    if (diff.inDays >= 7) {
      final semanas = (diff.inDays / 7).floor();
      return 'Hace $semanas ${semanas == 1 ? 'semana' : 'semanas'}';
    }
    if (diff.inDays >= 1) {
      return 'Hace ${diff.inDays} ${diff.inDays == 1 ? 'día' : 'días'}';
    }
    if (diff.inHours >= 1) return 'Hace ${diff.inHours} h';
    return 'Recién publicada';
  }
}

@immutable
class VacantesData {
  final List<Vacante> vacantes;

  /// `true` si la base expone un campo de estado. Cuando es `false`, la UI
  /// oculta los chips de estado en vez de inventarlos.
  final bool soportaEstados;

  /// La consulta de postulaciones falló (p. ej. por permisos). La UI muestra
  /// "—" en vez de un 0 que mentiría.
  final bool conteoNoDisponible;

  const VacantesData({
    required this.vacantes,
    required this.soportaEstados,
    this.conteoNoDisponible = false,
  });

  static const empty = VacantesData(vacantes: [], soportaEstados: false);

  int get total => vacantes.length;
  int get activas =>
      vacantes.where((v) => v.estado == VacanteEstado.activa).length;
  int get pausadas =>
      vacantes.where((v) => v.estado == VacanteEstado.pausada).length;

  /// Total de postulaciones sobre todas las vacantes.
  int get candidatos =>
      vacantes.fold<int>(0, (sum, v) => sum + v.candidatos);
}

/// Las tres modalidades que el alta de vacante ofrece, tal como se guardan.
const _modalidades = {
  'remoto': 'Remoto',
  'hibrido': 'Híbrido',
  'presencial': 'Presencial',
};

/// Sin tildes ni mayúsculas, para que "Híbrido" y "hibrido" sean lo mismo.
String _normalizar(String v) {
  const con = 'áàäâãéèëêíìïîóòöôõúùüûñ';
  const sin = 'aaaaaeeeeiiiiooooouuuun';
  var r = v.toLowerCase().trim();
  for (var i = 0; i < con.length; i++) {
    r = r.replaceAll(con[i], sin[i]);
  }
  return r;
}

/// Modalidad de la vacante.
///
/// ORDEN DELIBERADO: primero el TAG, después `is_remote`.
///
/// La modalidad que el usuario elige en el alta se guarda como tag —el esquema
/// no tiene columna para ella y un booleano no puede distinguir presencial de
/// híbrido—, así que el tag es la elección explícita y manda. `is_remote` sólo
/// se consulta cuando no hay tag de modalidad: sirve para las vacantes que no
/// declararon ninguna.
///
/// Y la coincidencia es EXACTA, no por subcadena. Antes se buscaba `'presen'`
/// dentro de cada tag, así que una vacante con la habilidad "Presentaciones"
/// —o "Presencia ejecutiva"— se anunciaba como Presencial sin que nadie lo
/// hubiera dicho. Lo mismo con `'remot'`.
String? _modalidad(Object? isRemote, List<String> tags) {
  for (final tag in tags) {
    final modalidad = _modalidades[_normalizar(tag)];
    if (modalidad != null) return modalidad;
  }

  // Sin tag de modalidad, `is_remote` sólo puede afirmar el caso positivo:
  // `false` es el valor por defecto de la columna y no significa "presencial".
  if (isRemote == true) return 'Remoto';

  return null;
}

/// Convierte una fila cruda de `public.jobs` en [Vacante].
///
/// Vive suelta —y no dentro del loader— porque el detalle de una vacante lee la
/// MISMA fila por `id`: si el mapeo estuviera duplicado, la lista y el detalle
/// podrían mostrar cosas distintas de la misma vacante.
Vacante vacanteDesdeFila(
  Map<String, dynamic> fila, {
  required bool soportaEstados,
  required int candidatos,
}) {
  final tags = <String>[];
  final rawTags = fila['tags'];
  if (rawTags is List) {
    for (final tag in rawTags) {
      final value = tag?.toString().replaceAll('#', '').trim() ?? '';
      if (value.isNotEmpty) tags.add(value);
    }
  }

  late final VacanteEstado estado;
  if (!soportaEstados) {
    estado = VacanteEstado.desconocido;
  } else {
    estado = fila['is_active'] == false
        ? VacanteEstado.pausada
        : VacanteEstado.activa;
  }

  return Vacante(
    id: fila['id'].toString(),
    titulo: fila['title']?.toString() ?? 'Vacante sin título',
    ubicacion: (fila['location']?.toString().isNotEmpty ?? false)
        ? fila['location'].toString()
        : null,
    salario: (fila['salary_range']?.toString().isNotEmpty ?? false)
        ? fila['salary_range'].toString()
        : null,
    jornada: (fila['employment_type']?.toString().isNotEmpty ?? false)
        ? fila['employment_type'].toString()
        : null,
    modalidad: _modalidad(fila['is_remote'], tags),
    tags: tags,
    creada: DateTime.tryParse(fila['created_at']?.toString() ?? ''),
    estado: estado,
    candidatos: candidatos,
    confidencial: fila['type']?.toString().toLowerCase() == 'stealth',
  );
}

/// Carga las vacantes de la empresa autenticada con su conteo real de
/// postulaciones.
///
/// Se consulta con `select()` sin lista de columnas a propósito: es lo que hace
/// hoy la pantalla que funciona, y permite descubrir en runtime qué campos
/// existe realmente en la base (que difiere de `schema.sql`).
Future<VacantesData> loadEmpresaVacantes() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return VacantesData.empty;

  var filas = <Map<String, dynamic>>[];
  try {
    filas = List<Map<String, dynamic>>.from(
      await client
          .from('jobs')
          .select()
          .eq('company_id', uid)
          .order('created_at', ascending: false),
    );
  } catch (e) {
    debugPrint('vacantes · jobs: $e');
    return VacantesData.empty;
  }

  // ¿La base expone un campo de estado? Se mira la primera fila real.
  final soportaEstados =
      filas.isNotEmpty && filas.first.containsKey('is_active');

  // Conteo real de postulaciones por vacante.
  final conteos = <String, int>{};
  var conteoNoDisponible = false;
  final ids = filas.map((f) => f['id'].toString()).toList();
  if (ids.isNotEmpty) {
    try {
      final apps = await client
          .from('job_applications')
          .select('job_id')
          .inFilter('job_id', ids);
      for (final app in apps as List) {
        final jid = app['job_id']?.toString() ?? '';
        if (jid.isEmpty) continue;
        conteos[jid] = (conteos[jid] ?? 0) + 1;
      }
    } catch (e) {
      debugPrint('vacantes · job_applications: $e');
      conteoNoDisponible = true;
    }
  }

  final vacantes = <Vacante>[];
  for (final fila in filas) {
    vacantes.add(
      vacanteDesdeFila(
        fila,
        soportaEstados: soportaEstados,
        candidatos: conteos[fila['id'].toString()] ?? 0,
      ),
    );
  }

  return VacantesData(
    vacantes: vacantes,
    soportaEstados: soportaEstados,
    conteoNoDisponible: conteoNoDisponible,
  );
}
