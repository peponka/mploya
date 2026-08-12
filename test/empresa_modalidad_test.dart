import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_vacantes_data.dart';

/// La modalidad de una vacante es el dato que más veces se mostró mal.
///
/// `public.jobs` no tiene columna de modalidad: sólo `is_remote` (boolean, con
/// DEFAULT false, confirmado contra la base el 11/8/2026). La modalidad elegida
/// en el alta se guarda como TAG, y `is_remote` se escribe aparte sólo cuando
/// el usuario eligió.
///
/// Estos tests fijan las dos reglas que hacían falta:
///   1. La coincidencia de tag es EXACTA. Antes bastaba con que el tag
///      CONTUVIERA "presen" o "remot", así que "Presentaciones" convertía la
///      vacante en presencial sin que nadie lo hubiera declarado.
///   2. `is_remote == false` NO significa "presencial": es el valor por
///      defecto de la columna. Sólo el `true` afirma algo.
Vacante _vacante({Object? isRemote, List<String> tags = const []}) {
  return vacanteDesdeFila(
    {
      'id': 'j1',
      'title': 'Vacante',
      'is_remote': isRemote,
      'tags': tags,
    },
    soportaEstados: false,
    candidatos: 0,
  );
}

void main() {
  group('la modalidad sale del tag elegido', () {
    test('Remoto', () {
      expect(_vacante(tags: ['Remoto']).modalidad, 'Remoto');
    });

    test('Presencial', () {
      expect(_vacante(tags: ['Presencial']).modalidad, 'Presencial');
    });

    test('Híbrido, con y sin tilde', () {
      expect(_vacante(tags: ['Híbrido']).modalidad, 'Híbrido');
      expect(_vacante(tags: ['hibrido']).modalidad, 'Híbrido');
      expect(_vacante(tags: ['HÍBRIDO']).modalidad, 'Híbrido');
    });

    test('el tag de modalidad gana sobre is_remote', () {
      // El usuario eligió Presencial: que la columna diga lo contrario no
      // puede pisar una elección explícita.
      expect(
        _vacante(isRemote: true, tags: ['Presencial']).modalidad,
        'Presencial',
      );
    });
  });

  group('no se inventa modalidad', () {
    test('sin tags ni is_remote no hay modalidad', () {
      expect(_vacante().modalidad, isNull);
      expect(_vacante(isRemote: false).modalidad, isNull);
    });

    test('is_remote en false NO significa presencial', () {
      // Es el DEFAULT de la columna: no lo declaró nadie.
      expect(_vacante(isRemote: false, tags: ['Flutter']).modalidad, isNull);
    });

    test('is_remote en true sí afirma remoto', () {
      expect(_vacante(isRemote: true).modalidad, 'Remoto');
    });

    test('habilidades que CONTIENEN la palabra no cuentan', () {
      // El bug real: "Presentaciones" contiene "presen".
      for (final tag in [
        'Presentaciones',
        'Presencia ejecutiva',
        'PresentaciónEjecutiva',
        'RemotoFirst',
        'Hibridación',
      ]) {
        expect(
          _vacante(tags: [tag]).modalidad,
          isNull,
          reason: 'El tag "$tag" no declara modalidad',
        );
      }
    });

    test('una habilidad real no convierte la vacante en presencial', () {
      final v = _vacante(
        tags: ['GestiónDeProyectos', 'Presentaciones', 'Liderazgo'],
      );
      expect(v.modalidad, isNull);
      // Y las habilidades se conservan intactas.
      expect(v.tags.length, 3);
    });
  });

  group('filas reales de public.jobs', () {
    // Datos verificados contra Supabase el 11/8/2026:
    //   SELECT title, is_remote, tags FROM public.jobs ORDER BY created_at DESC
    // Las cinco filas tienen is_remote = false. Sólo una declara modalidad, y
    // lo hace por tag. Este grupo fija exactamente eso.

    test('"producto de manajer" declara Remoto por tag', () {
      expect(
        _vacante(isRemote: false, tags: ['Remoto']).modalidad,
        'Remoto',
      );
    });

    test('"desarrollador" no declara modalidad', () {
      expect(
        _vacante(
          isRemote: false,
          tags: ['JavaScript', 'Python', 'React', 'NodeJS', 'SQL', 'Git'],
        ).modalidad,
        isNull,
      );
    });

    test('"proto manajer" no declara modalidad', () {
      expect(
        _vacante(
          isRemote: false,
          tags: [
            'GestiónDeProyectos',
            'Innovación',
            'Liderazgo',
            'MVP',
            'DesarrolloDeProducto',
            'MetodologíasÁgiles',
          ],
        ).modalidad,
        isNull,
      );
    });

    test('"buscamos senior" y "buscamos ing senior": sin tags, sin modalidad',
        () {
      expect(_vacante(isRemote: false, tags: const []).modalidad, isNull);
    });
  });
}
