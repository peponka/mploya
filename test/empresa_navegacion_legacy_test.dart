import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// GUARDIÁN DE LA FASE DE CIERRE DE LEGACY.
///
/// Empresa Mobile no debe navegar a una pantalla legacy cuando ya existe una
/// pantalla Empresa que cubre esa función. Este test lee el CÓDIGO FUENTE y
/// falla si alguien vuelve a introducir una de esas fugas.
///
/// Por qué se revisa el fuente y no el árbol de widgets: la mayoría de estas
/// pantallas cargan de Supabase al montarse, así que probar la navegación real
/// exigiría una red simulada en cada caso. El destino de un `push`, en cambio,
/// es una decisión estática y se puede verificar leyendo el archivo. Un test
/// así no se rompe por timing ni por datos.
void main() {
  final raiz = Directory.current.path;

  /// Archivos que forman Empresa Mobile.
  List<File> archivosEmpresa() {
    final dirs = [
      Directory('$raiz/lib/screens/empresa'),
      Directory('$raiz/lib/widgets/empresa'),
    ];
    return [
      for (final d in dirs)
        if (d.existsSync())
          ...d.listSync().whereType<File>().where(
            (f) => f.path.endsWith('.dart'),
          ),
    ];
  }

  /// Quita comentarios de línea para no acusar a la documentación, que nombra
  /// las pantallas legacy justamente para explicar por qué NO se usan.
  String sinComentarios(String fuente) {
    return fuente
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
  }

  /// Legacy prohibido en Empresa → con qué se reemplaza.
  const prohibidos = <String, String>{
    'AtsKanbanScreen': 'EmpresaPipelineScreen',
    'AtsDashboardScreen': 'EmpresaPipelineScreen / EmpresaRendimientoScreen',
    'NuevaVacanteScreen': 'EmpresaPublicarVacanteScreen',
    'CompanyProfileFormScreen':
        'EmpresaEditarPerfilScreen / EmpresaPerfilScreen',
    'AnalyticsDashboardScreen': 'EmpresaRendimientoScreen',
    'SavedProfilesScreen': 'EmpresaGuardadosScreen',
    'MessagingScreen': 'EmpresaMensajesScreen',
  };

  test('ninguna pantalla de Empresa navega a legacy con equivalente nuevo', () {
    final fugas = <String>[];

    for (final archivo in archivosEmpresa()) {
      final fuente = sinComentarios(archivo.readAsStringSync());
      final nombre = archivo.path.split(RegExp(r'[/\\]')).last;

      for (final entrada in prohibidos.entries) {
        if (fuente.contains(entrada.key)) {
          fugas.add('$nombre → ${entrada.key} (usar ${entrada.value})');
        }
      }
    }

    expect(
      fugas,
      isEmpty,
      reason: 'Fugas legacy desde Empresa Mobile:\n${fugas.join('\n')}',
    );
  });

  test('Empresa no abre el ProfileScreen legacy', () {
    // `ProfileScreen` es el perfil personal del rol candidato. Empresa usa
    // `EmpresaCandidatoPerfilScreen` para ver a un candidato y
    // `EmpresaPerfilScreen` para su propia ficha.
    final fugas = <String>[];

    for (final archivo in archivosEmpresa()) {
      final fuente = sinComentarios(archivo.readAsStringSync());
      final nombre = archivo.path.split(RegExp(r'[/\\]')).last;

      // `ProfileScreen(` sin prefijo: excluye EmpresaCandidatoPerfilScreen y
      // EmpresaPerfilScreen, que terminan distinto.
      if (RegExp(r'(?<![A-Za-z])ProfileScreen\s*\(').hasMatch(fuente)) {
        fugas.add(nombre);
      }
    }

    expect(fugas, isEmpty, reason: 'Abren ProfileScreen legacy: $fugas');
  });

  test('el bloque de Empresa de main_navigation usa pantallas Empresa', () {
    final fuente = sinComentarios(
      File('$raiz/lib/navigation/main_navigation.dart').readAsStringSync(),
    );

    // La ranura de Perfil y el menú "+" son los dos puntos que llevaban al
    // sistema viejo.
    expect(
      RegExp(
        r"_accountType\s*==\s*'empresa'\s*\?\s*const EmpresaPerfilScreen\(\)",
      ).hasMatch(fuente),
      isTrue,
      reason: 'La ranura de Perfil de Empresa debe abrir EmpresaPerfilScreen.',
    );

    // El menú "+" de Empresa publica con el asistente nuevo. `NuevaVacanteScreen`
    // sigue existiendo para headhunter ("Nueva búsqueda"), así que se comprueba
    // que el asistente esté presente, no que la clase vieja desaparezca.
    expect(
      fuente.contains('EmpresaPublicarVacanteScreen'),
      isTrue,
      reason: 'El menú + de Empresa debe publicar con el asistente nuevo.',
    );
  });

  test('Empresa Mobile no puede alcanzar datos demo', () {
    // El ATS legacy abre `InterviewReportScreen(interviewId: 'demo-completed')`.
    // La única vía desde Empresa era el Kanban; cerrada ésa, ninguna pantalla
    // de Empresa debe nombrar al ATS ni a un id demo.
    final sospechosos = <String>[];

    for (final archivo in archivosEmpresa()) {
      final fuente = sinComentarios(archivo.readAsStringSync());
      final nombre = archivo.path.split(RegExp(r'[/\\]')).last;

      for (final marca in [
        'demo-completed',
        'demoId',
        'AtsKanbanScreen',
        'AtsDashboardScreen',
      ]) {
        if (fuente.contains(marca)) sospechosos.add('$nombre → $marca');
      }
    }

    expect(
      sospechosos,
      isEmpty,
      reason: 'Rutas de Empresa hacia datos demo:\n${sospechosos.join('\n')}',
    );
  });

  test('SchedulingScreen sigue permitido: no tiene equivalente nuevo', () {
    // Gestiona `interview_slots`, que ninguna pantalla nueva cubre. Este test
    // documenta que su presencia es deliberada, no una fuga olvidada.
    final usos = <String>[];

    for (final archivo in archivosEmpresa()) {
      final fuente = sinComentarios(archivo.readAsStringSync());
      if (fuente.contains('SchedulingScreen')) {
        usos.add(archivo.path.split(RegExp(r'[/\\]')).last);
      }
    }

    expect(
      usos,
      isNotEmpty,
      reason: 'Si ya nadie la usa, revisar si conviene retirar el import.',
    );
  });

  test('Match IA recibe el contexto real desde la Shortlist', () {
    final fuente = File(
      '$raiz/lib/screens/empresa/empresa_shortlist_screen.dart',
    ).readAsStringSync();

    expect(fuente, contains("import 'empresa_match_ia_screen.dart';"));
    expect(fuente, contains("label: 'Ver Match IA'"));
    expect(fuente, contains('EmpresaMatchIaScreen('));
    expect(fuente, contains('jobId: widget.vacante.id'));
    expect(fuente, contains('candidatoId: c.id'));

    final destino = File(
      '$raiz/lib/screens/empresa/empresa_match_ia_screen.dart',
    ).readAsStringSync();
    expect(destino, contains('Navigator.of(context).maybePop()'));
  });

  test('Contrataciones se abre desde Herramientas sin datos simulados', () {
    final fuente = File(
      '$raiz/lib/screens/empresa/empresa_herramientas_screen.dart',
    ).readAsStringSync();

    expect(fuente, contains("titulo: 'Contrataciones'"));
    expect(fuente, contains('const EmpresaContratacionesScreen()'));
    expect(fuente, isNot(contains('previewData:')));

    final destino = File(
      '$raiz/lib/screens/empresa/empresa_contrataciones_screen.dart',
    ).readAsStringSync();
    expect(destino, contains('Navigator.of(context).maybePop()'));
  });
}
