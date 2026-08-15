import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GUARDIÁN ESTRUCTURAL DE LA TANDA 1 DE CANDIDATO.
///
/// ⚠️ NO SON TESTS FUNCIONALES. Igual que `candidato_navegacion_test.dart` y
/// `empresa_navegacion_legacy_test.dart`, leen el CÓDIGO FUENTE y verifican
/// invariantes. No montan widgets: las cinco pantallas consultan Supabase al
/// montarse, así que probarlas de verdad exige una red simulada.
///
/// Lo que estos guardas SÍ garantizan: que no vuelva a aparecer contenido
/// inventado presentado como real, que no vuelva la navegación a la pantalla
/// empresarial, y que los accesos agregados no se pierdan en un refactor.
///
/// QUEDA PENDIENTE la prueba widget con Supabase mockeado, que es la única que
/// puede verificar render, taps, estados vacíos reales y responsive.
void main() {
  final raiz = Directory.current.path;

  String fuenteDe(String rutaRelativa) {
    final f = File('$raiz/$rutaRelativa');
    expect(f.existsSync(), isTrue, reason: 'No se encontró $rutaRelativa');
    return f
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
  }

  group('Vacantes', () {
    test('no navega a la pantalla empresarial VacantesScreen', () {
      // `vacantes_screen.dart` es la pantalla de GESTIÓN de la empresa: crea
      // vacantes con create_job_with_postgis y cuenta postulantes. Un candidato
      // no debe aterrizar ahí desde ninguna pantalla suya.
      final fugas = <String>[];
      for (final ruta in const [
        'lib/screens/explore_screen.dart',
        'lib/screens/jobs_screen.dart',
        'lib/screens/network_screen.dart',
        'lib/screens/home_feed_screen.dart',
        'lib/screens/messaging_screen.dart',
        'lib/screens/profile_screen.dart',
      ]) {
        if (RegExp(r'(?<![A-Za-z])VacantesScreen\s*\(').hasMatch(fuenteDe(ruta))) {
          fugas.add(ruta);
        }
      }
      expect(fugas, isEmpty, reason: 'Abren VacantesScreen empresarial: $fugas');
    });

    test('la postulación normal inserta exactamente dos columnas', () {
      // Regresión del commit b04215c. Si alguien agrega `status` acá, la
      // migración 029 lo rechaza con "permission denied for column".
      final fuente = fuenteDe('lib/screens/jobs_screen.dart');
      final marca = fuente.indexOf("from('job_applications').insert(");
      expect(marca, greaterThan(-1), reason: 'Se perdió el INSERT de postulación.');

      final cierre = fuente.indexOf('});', marca);
      final payload = fuente.substring(marca, cierre);

      expect(payload.contains("'job_id'"), isTrue);
      expect(payload.contains("'candidate_id'"), isTrue);
      for (final prohibida in const [
        "'status'",
        "'created_at'",
        "'hired_at'",
        "'stage_changed_at'",
        "'is_favorite'",
      ]) {
        expect(
          payload.contains(prohibida),
          isFalse,
          reason: 'El INSERT no debe nombrar $prohibida (GRANT por columna).',
        );
      }
    });

    test('no reintroduce create_system_notification en el camino normal', () {
      final fuente = fuenteDe('lib/screens/jobs_screen.dart');
      expect(
        fuente.contains("rpc('create_system_notification'"),
        isFalse,
        reason:
            'El aviso a la empresa lo emite el trigger trg_notify_job_application. '
            'Llamarlo desde acá duplica la notificación.',
      );
    });

    test('expone Guardados y "Empresas cerca tuyo"', () {
      final fuente = fuenteDe('lib/screens/jobs_screen.dart');
      expect(fuente.contains('SavedJobsScreen()'), isTrue);
      expect(
        fuente.contains("ExploreScreen(filtroInicial: 'empresa')"),
        isTrue,
        reason: 'Explorar se abre desde Vacantes ya filtrado a empresas.',
      );
    });
  });

  group('Explorar', () {
    test('no cae a pines demo cuando la consulta viene vacía', () {
      final fuente = fuenteDe('lib/screens/explore_screen.dart');
      expect(
        fuente.contains('simCandidates'),
        isFalse,
        reason:
            'El mapa no debe rellenarse con personas inventadas: si no hay '
            'pines reales, se muestra el estado vacío.',
      );
    });

    test('tiene estado vacío y de error propios', () {
      final fuente = fuenteDe('lib/screens/explore_screen.dart');
      expect(fuente.contains('_avisoSinPines'), isTrue);
      expect(fuente.contains('_errorPines'), isTrue);
      expect(fuente.contains('_cargandoPines'), isTrue);
    });

    test('acepta filtro inicial', () {
      final fuente = fuenteDe('lib/screens/explore_screen.dart');
      expect(fuente.contains('this.filtroInicial'), isTrue);
      expect(fuente.contains('_selectedTypeFilter = widget.filtroInicial'), isTrue);
    });
  });

  group('Mensajes', () {
    test('la bandeja vacía no muestra conversaciones inventadas', () {
      final fuente = fuenteDe('lib/screens/messaging_screen.dart');
      expect(
        fuente.contains('_demoUsers'),
        isFalse,
        reason: 'Los seis usuarios demo se presentaban como conversaciones reales.',
      );
      expect(fuente.contains('_demoMatchAvatar'), isFalse);
    });

    test('el estado vacío es honesto', () {
      final fuente = fuenteDe('lib/screens/messaging_screen.dart');
      expect(fuente.contains('Todavía no tenés mensajes'), isTrue);
    });
  });

  group('Red', () {
    test('no navega escribiendo currentMainTabNotifier', () {
      // MainNavigation sólo ESCRIBE ese notifier; nunca lo escucha. Usarlo como
      // router deja botones muertos, y el índice 1 ya no es Explorar.
      final fuente = fuenteDe('lib/screens/network_screen.dart');
      expect(
        fuente.contains('currentMainTabNotifier'),
        isFalse,
        reason: 'Los destinos secundarios se abren con Navigator.push.',
      );
    });

    test('sus accesos rápidos navegan de verdad', () {
      // Antes esto vigilaba los botones de «Primeros pasos», que incluían
      // «Mirá vacantes». Esa tarjeta desapareció con la composición aprobada de
      // la Tanda 1: Vacantes es hoy uno de los cinco destinos de la barra, así
      // que duplicarlo dentro de Red era ruido. Lo que sí tiene que seguir
      // existiendo son los accesos propios de la pantalla, y todos por `push`.
      final fuente = fuenteDe('lib/screens/network_screen.dart');
      expect(
        fuente.contains('ExploreScreen()'),
        isTrue,
        reason: 'Descubrir gente e invitar contactos abren Explorar.',
      );
      expect(
        fuente.contains('ProfileScreen(user:'),
        isTrue,
        reason: 'Cada tarjeta de la red abre el perfil de esa persona.',
      );
      expect(
        fuente.contains('ChatDetailScreen(otherUser:'),
        isTrue,
        reason: 'El acceso a mensajes desde una conexión debe conservarse.',
      );
    });
  });

  group('Notificaciones', () {
    test('"Ver perfil" abre Perfil y no cambia de pestaña', () {
      final fuente = fuenteDe('lib/screens/notifications_screen.dart');
      expect(
        fuente.contains('currentMainTabNotifier'),
        isFalse,
        reason: 'Apuntaba al índice 2, que hoy es Red, y además no navegaba.',
      );
    });
  });

  group('Perfil', () {
    test('expone Mis Herramientas y Guardados', () {
      final fuente = fuenteDe('lib/screens/profile_screen.dart');
      expect(
        fuente.contains('ToolsHubEntryScreen()'),
        isTrue,
        reason:
            'Sin esta entrada, todo el hub de herramientas queda inalcanzable '
            'para el candidato.',
      );
      expect(fuente.contains('SavedJobsScreen()'), isTrue);
      expect(fuente.contains('Mis Herramientas'), isTrue);
      expect(fuente.contains('Guardados'), isTrue);
    });

    test('conserva el acceso a Configuración', () {
      final fuente = fuenteDe('lib/screens/profile_screen.dart');
      expect(fuente.contains('SettingsScreen()'), isTrue);
    });
  });
}
