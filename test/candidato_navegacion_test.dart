import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GUARDIÁN ESTRUCTURAL DE LA NAVEGACIÓN CANÓNICA DE CANDIDATO.
///
/// ⚠️ ESTOS TESTS NO SON FUNCIONALES. No montan `MainNavigation`, no tocan
/// botones y no comprueban que la barra se dibuje: leen el CÓDIGO FUENTE de
/// `main_navigation.dart` y verifican invariantes de estructura. Sirven para
/// que un cambio futuro no vuelva a desincronizar la barra de los índices
/// permitidos, no para demostrar que la navegación funciona.
///
/// Por qué se revisa el fuente: es el mismo motivo que documenta
/// `empresa_navegacion_legacy_test.dart`. `MainNavigation` consulta Supabase al
/// montarse (`_fetchAccountType`, contadores en tiempo real) y
/// `_navItemsForAccount` / `_isIndexAllowedForAccount` son privados, así que no
/// se pueden invocar desde otra librería.
///
/// QUEDA PENDIENTE la prueba widget con Supabase mockeado, que es la única capaz
/// de verificar de verdad: que la barra dibuja cinco botones, que tocarlos deja
/// el `IndexedStack` en 0/1/2/5/9, que ninguna pestaña queda en blanco, y que
/// mobile y web publican la misma lista. Estos guardas cubren la estructura;
/// esa prueba cubriría el comportamiento.
void main() {
  final raiz = Directory.current.path;
  final archivo = File('$raiz/lib/navigation/main_navigation.dart');

  /// Quita comentarios de línea para no acusar a la documentación, que nombra
  /// ranuras y roles justamente para explicar por qué están como están.
  String sinComentarios(String fuente) {
    return fuente
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
  }

  late String fuente;

  setUpAll(() {
    expect(
      archivo.existsSync(),
      isTrue,
      reason: 'No se encontró lib/navigation/main_navigation.dart',
    );
    fuente = sinComentarios(archivo.readAsStringSync());
  });

  /// Aísla el bloque `return const [...]` final de `_navItemsForAccount`, que
  /// es el de Candidato: los de Empresa y Headhunter viven dentro de sus `if`.
  String bloqueCandidato() {
    final marca = fuente.lastIndexOf('return const [');
    expect(
      marca,
      greaterThan(-1),
      reason: 'No se encontró la lista de ítems de Candidato.',
    );
    final cierre = fuente.indexOf('];', marca);
    expect(cierre, greaterThan(marca));
    return fuente.substring(marca, cierre);
  }

  /// Extrae el cuerpo de una lista literal contando corchetes, para no depender
  /// del formato ni de números de línea.
  String cuerpoDeLista(String desde) {
    final marca = fuente.indexOf(desde);
    expect(marca, greaterThan(-1), reason: 'No se encontró: $desde');
    final abre = fuente.indexOf('[', marca);
    var profundidad = 0;
    for (var i = abre; i < fuente.length; i++) {
      final c = fuente[i];
      if (c == '[') profundidad++;
      if (c == ']') {
        profundidad--;
        if (profundidad == 0) return fuente.substring(abre + 1, i);
      }
    }
    fail('Lista sin cerrar a partir de: $desde');
  }

  /// Cuenta los elementos de nivel superior de una lista literal: comas a
  /// profundidad cero, ignorando las que van dentro de cadenas o paréntesis.
  int contarElementos(String cuerpo) {
    var profundidad = 0;
    var elementos = 0;
    var enCadena = false;
    for (var i = 0; i < cuerpo.length; i++) {
      final c = cuerpo[i];
      if (enCadena) {
        if (c == "'") enCadena = false;
        continue;
      }
      if (c == "'") {
        enCadena = true;
        continue;
      }
      if (c == '(' || c == '[' || c == '{') profundidad++;
      if (c == ')' || c == ']' || c == '}') profundidad--;
      if (c == ',' && profundidad == 0) elementos++;
    }
    return elementos;
  }

  test('_onTabTap consulta el rol ANTES de mover el índice', () {
    final inicio = fuente.indexOf('void _onTabTap(int index) {');
    expect(inicio, greaterThan(-1), reason: '_onTabTap desapareció.');
    final cuerpo = fuente.substring(inicio, fuente.indexOf('\n  }', inicio));

    final guarda = cuerpo.indexOf('_isIndexAllowedForAccount');
    final asigna = cuerpo.indexOf('_currentIndex = index');
    final notifica = cuerpo.indexOf('currentMainTabNotifier.value = index');

    expect(
      guarda,
      greaterThan(-1),
      reason:
          '_onTabTap debe validar el rol; sin eso, un llamador nuevo puede '
          'dejar a Candidato en una ranura neutralizada (pantalla en blanco).',
    );
    expect(asigna, greaterThan(-1));
    expect(notifica, greaterThan(-1));
    expect(guarda, lessThan(asigna), reason: 'La guarda va antes de asignar.');
    expect(guarda, lessThan(notifica), reason: 'La guarda va antes de notificar.');
  });

  test('el build consume _navItemsForAccount(_accountType)', () {
    // Si la barra dejara de leer esta lista, todos los demás guardas de este
    // archivo seguirían en verde mientras la navegación real queda rota.
    expect(
      fuente.contains('_navItemsForAccount(_accountType)'),
      isTrue,
      reason: 'La barra debe construirse desde _navItemsForAccount.',
    );
  });

  test('_screens conserva exactamente 10 ranuras', () {
    // La numeración es un contrato compartido: Empresa usa 0-8 y Headhunter
    // {0,1,2,3,5,6,7,8}. Perder o agregar una ranura los desplaza a todos, y
    // un índice fuera de rango hace explotar el IndexedStack en runtime.
    final ranuras = contarElementos(cuerpoDeLista('List<Widget> get _screens'));
    expect(ranuras, 10, reason: 'Se esperaban 10 ranuras y hay $ranuras.');
  });

  test('Candidato publica exactamente cinco destinos', () {
    final bloque = bloqueCandidato();
    final items = RegExp(r'_NavItemData\(').allMatches(bloque).length;

    expect(
      items,
      5,
      reason: 'Candidato debe tener 5 destinos, se encontraron $items.',
    );
  });

  test('los índices de Candidato son exactamente {0, 1, 2, 5, 9}', () {
    final bloque = bloqueCandidato();
    final indices = RegExp(r'index:\s*(\d+)')
        .allMatches(bloque)
        .map((m) => int.parse(m.group(1)!))
        .toList();

    expect(indices, [0, 1, 2, 5, 9]);
  });

  test('las etiquetas de Candidato son las canónicas y en orden', () {
    final bloque = bloqueCandidato();
    final labels = RegExp(r"label:\s*'([^']+)'")
        .allMatches(bloque)
        .map((m) => m.group(1)!)
        .toList();

    expect(labels, ['Inicio', 'Vacantes', 'Red', 'Mensajes', 'Perfil']);
  });

  test('las ranuras 3, 4, 6, 7 y 8 no son destinos permitidos para Candidato', () {
    // `_isIndexAllowedForAccount` — la rama `default` es la de Candidato.
    expect(
      fuente.contains('return const {0, 1, 2, 5, 9}.contains(index);'),
      isTrue,
      reason:
          'Candidato debe permitir exactamente {0,1,2,5,9}. Si la barra y los '
          'índices permitidos se desincronizan, vuelven a aparecer pantallas '
          'inalcanzables.',
    );
  });

  test('las ranuras 4, 7 y 8 quedan neutralizadas para Candidato', () {
    // Un `IndexedStack` construye todos sus hijos: dejar una pantalla real en
    // una ranura inalcanzable la monta igual y dispara sus consultas.
    expect(
      fuente.contains(
        "_accountType == 'empresa' ? const EmpresaPerfilScreen() : const SizedBox.shrink()",
      ),
      isTrue,
      reason: 'La ranura 4 debe quedar vacía salvo para Empresa.',
    );

    // Las ranuras 7 y 8 sólo deben montar algo real para empresa o headhunter.
    // Se mira la ÚLTIMA aparición de cada nombre —el uso dentro de `_screens`—
    // y no la primera, que es la declaración del campo o el import.
    for (final pantalla in ['EmpresaPanelHubScreen', '_tools']) {
      final indice = fuente.lastIndexOf(pantalla);
      expect(indice, greaterThan(-1), reason: '$pantalla desapareció.');
      final contexto = fuente.substring(
        (indice - 220).clamp(0, fuente.length),
        indice,
      );
      expect(
        contexto.contains("'headhunter'"),
        isTrue,
        reason:
            '$pantalla debe quedar condicionada a headhunter; si Candidato la '
            'monta, vuelve el problema de la ranura inalcanzable.',
      );
    }

    // Cuatro ranuras neutralizadas para Candidato: 4, 6, 7 y 8.
    final vacias = RegExp(r'const SizedBox\.shrink\(\)').allMatches(fuente).length;
    expect(
      vacias,
      4,
      reason: 'Se esperaban 4 ranuras neutralizadas y hay $vacias.',
    );
  });

  test('Vacantes de Candidato monta JobsScreen y no se monta dos veces', () {
    // JobsScreen debe aparecer en la ranura 1 (Candidato) y en la 6
    // (Headhunter). Dos ocurrencias: ni una —se perdió— ni tres —se duplicó
    // para Candidato, que dispararía dos cargas de vacantes—.
    final usos = RegExp(r'const JobsScreen\(\)').allMatches(fuente).length;

    expect(
      usos,
      2,
      reason:
          'Se esperaban 2 usos de JobsScreen (ranura 1 Candidato, ranura 6 '
          'Headhunter) y hay $usos.',
    );
  });

  test('Empresa conserva sus índices actuales', () {
    expect(
      fuente.contains(
        'return const {0, 1, 2, 3, 4, 5, 6, 7, 8}.contains(index);',
      ),
      isTrue,
      reason: 'Empresa debe seguir permitiendo {0..8}.',
    );

    // Sus ítems, con los índices de siempre. Son DIEZ, no seis: el bloque de
    // Empresa define dos grupos (la barra principal y el resto de sus
    // destinos). Se fija el orden completo para que cualquier reordenamiento
    // accidental falle acá y no en producción.
    final bloqueEmpresa = fuente.substring(
      fuente.indexOf('if (isCompany)'),
      fuente.indexOf('if (isHeadhunter)'),
    );
    final indices = RegExp(r'index:\s*(\d+)')
        .allMatches(bloqueEmpresa)
        .map((m) => int.parse(m.group(1)!))
        .toList();

    expect(indices, [7, 0, 6, 5, 8, 4, 6, 1, 2, 3]);
  });

  test('Headhunter conserva sus índices actuales', () {
    expect(
      fuente.contains('return const {0, 1, 2, 3, 5, 6, 7, 8}.contains(index);'),
      isTrue,
      reason: 'Headhunter debe seguir permitiendo {0,1,2,3,5,6,7,8}.',
    );

    final inicio = fuente.indexOf('if (isHeadhunter)');
    final bloqueHeadhunter = fuente.substring(
      inicio,
      fuente.lastIndexOf('return const ['),
    );
    final indices = RegExp(r'index:\s*(\d+)')
        .allMatches(bloqueHeadhunter)
        .map((m) => int.parse(m.group(1)!))
        .toList();

    expect(indices, [7, 1, 6, 2]);
  });
}
