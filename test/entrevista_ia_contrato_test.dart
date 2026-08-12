import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/models/ai_interview_models.dart';
import 'package:mploya/screens/empresa/empresa_crear_entrevista_data.dart';
import 'package:mploya/screens/empresa/empresa_informe_entrevista_data.dart';
import 'package:mploya/screens/interview_flow_screen.dart';
import 'package:mploya/screens/notifications_screen.dart';

/// CONTRATO ENTRE LOS COMPONENTES DEL CIRCUITO DE ENTREVISTA CON IA.
///
/// `entrevista_ia_flujo_test.dart` fija que las piezas EXISTAN. Éste fija que
/// encajen: que lo que escribe un extremo sea exactamente lo que el otro sabe
/// leer.
///
///   Empresa pide        → RPC `request_ai_interview` (migración 027)
///                       → interviews + notifications, misma transacción
///   Candidato la toca   → InterviewFlowScreen con ESE interview_id
///   Servidor cierra     → interview_reports
///   Empresa la abre     → InformeEntrevista con esos datos
///
/// ────────────────────────────────────────────────────────────────────────────
/// QUÉ SE PUEDE Y QUÉ NO SE PUEDE PROBAR ACÁ
///
/// Las validaciones de la RPC (vacante propia, postulación real, autoentrevista,
/// no duplicar) viven en PL/pgSQL y **sólo se pueden ejecutar contra Postgres**.
/// Sin base no hay forma honesta de probarlas corriendo: montar un fake de
/// Supabase que "devuelva vacante_ajena" probaría el fake, no la función.
///
/// Así que se prueban en dos capas distintas y con distinta fuerza:
///
///   · FUERTE — todo lo que es Dart de verdad: el mapeo de cada código de error
///     a su mensaje, la semántica de `ResultadoPedido`, y el empalme SQL↔Dart,
///     donde las claves de `data` se LEEN del archivo de migración y se le pasan
///     al resolutor real del candidato. Si alguien renombra una clave en el SQL,
///     este test se rompe.
///   · GUARDIÁN — la estructura de la migración: que cada validación esté, en
///     orden, y que los permisos sean los correctos. Es lectura de fuente, y se
///     dice de frente. Sustituye a nada: la prueba real es el E2E.
///
/// La corrida completa contra Postgres sigue marcada como PENDIENTE al final.
/// ────────────────────────────────────────────────────────────────────────────
void main() {
  final raiz = Directory.current.path;
  String fuente(String ruta) => File('$raiz/$ruta').readAsStringSync();

  /// Quita las líneas de comentario.
  ///
  /// Varios de estos archivos DOCUMENTAN el placeholder y la key que ya no se
  /// usan, justamente para explicar por qué no se usan. Sin esto, los
  /// guardianes acusarían a la documentación en vez de al código.
  String sinComentarios(String src) => src
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  final migracion = fuente('supabase/migrations/027_request_ai_interview.sql');

  const entrevistaId = '11111111-2222-3333-4444-555555555555';
  const vacanteId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
  const candidatoId = '99999999-8888-7777-6666-555555555555';
  const empresaId = '00000000-1111-2222-3333-444444444444';

  /// Claves que la migración mete en `notifications.data`, leídas del SQL.
  ///
  /// No están escritas a mano en el test a propósito: el SQL es la fuente de
  /// verdad y el test se adapta a él, no al revés.
  List<String> clavesDeData() {
    final bloque = RegExp(
      r'jsonb_build_object\(([^;]*?)\)\s*\)\s*;',
      dotAll: true,
    ).firstMatch(migracion);
    expect(
      bloque,
      isNotNull,
      reason: 'No se encontró el jsonb_build_object del INSERT en notifications.',
    );
    return RegExp(r"'([a-z_]+)'\s*,")
        .allMatches(bloque!.group(1)!)
        .map((m) => m.group(1)!)
        .toList();
  }

  // ══ EMPALME 1 — lo que escribe la RPC lo sabe leer el candidato ═══════════
  group('EMPALME 1 · la invitación que arma el SQL la resuelve Dart', () {
    test('`data` lleva interview_id, job_id y from_user_id', () {
      expect(
        clavesDeData(),
        containsAll(<String>['interview_id', 'job_id', 'from_user_id']),
      );
    });

    test('el resolutor del candidato saca el interview_id de esa forma', () {
      // Se arma la notificación con las claves REALES del SQL y se la pasa al
      // resolutor de producción. Éste es el empalme: si el SQL renombra
      // `interview_id`, acá se rompe antes que en la mano del usuario.
      final claves = clavesDeData();
      final valores = <String, String>{
        'interview_id': entrevistaId,
        'job_id': vacanteId,
        'from_user_id': empresaId,
      };

      final resuelto = interviewIdDeNotificacion({
        'type': 'interview_request',
        'data': {for (final k in claves) k: valores[k] ?? 'x'},
      });

      expect(resuelto, entrevistaId);
    });

    test('el tipo que escribe el SQL es el que la pantalla enruta', () {
      expect(migracion.contains("'interview_request'"), isTrue);
      // Con cualquier otro `type`, el resolutor devuelve null y el tap no abre
      // nada, por más que el interview_id esté bien.
      expect(
        interviewIdDeNotificacion({
          'type': 'otra_cosa',
          'data': {'interview_id': entrevistaId},
        }),
        isNull,
      );
    });
  });

  // ══ EMPALME 2 — notificación → InterviewFlowScreen ════════════════════════
  group('EMPALME 2 · la pantalla del candidato recibe ese id y no otro', () {
    test('InterviewFlowScreen se arma con el id de la invitación', () {
      final id = interviewIdDeNotificacion({
        'type': 'interview_request',
        'data': {'interview_id': entrevistaId},
      });
      expect(id, isNotNull);
      expect(InterviewFlowScreen(interviewId: id!).interviewId, entrevistaId);
    });

    test('una invitación con id demo no llega a abrir la pantalla', () {
      for (final demo in ['demo-pending', 'demo-completed']) {
        expect(
          interviewIdDeNotificacion({
            'type': 'interview_request',
            'data': {'interview_id': demo},
          }),
          isNull,
          reason: demo,
        );
      }
    });
  });

  // ══ RPC · validaciones ════════════════════════════════════════════════════
  //
  // GUARDIÁN DE ESTRUCTURA. Lee la migración. No ejecuta PL/pgSQL.
  group('RPC · las validaciones obligatorias están y en orden', () {
    int posicionDe(String aguja) {
      final i = migracion.indexOf(aguja);
      expect(i, greaterThan(-1), reason: 'Falta en la migración: $aguja');
      return i;
    }

    test('1 · exige sesión', () {
      expect(migracion.contains('auth.uid()'), isTrue);
      expect(migracion.contains("'no_auth'"), isTrue);
    });

    test('2 · rechaza la autoentrevista', () {
      expect(migracion.contains("'autoentrevista'"), isTrue);
      expect(migracion.contains('p_candidate_id = v_me'), isTrue);
    });

    test('3 · comprueba que la vacante existe', () {
      expect(migracion.contains("'vacante_inexistente'"), isTrue);
    });

    test('4 · comprueba la propiedad por jobs.company_id', () {
      // `company_id` es la relación real de propiedad, la misma que usan las
      // políticas RLS de jobs. No se adivina ningún otro nombre de columna.
      expect(migracion.contains('j.company_id'), isTrue);
      expect(migracion.contains("'vacante_ajena'"), isTrue);
      expect(migracion.contains('v_company IS DISTINCT FROM v_me'), isTrue);
    });

    test('5 · exige postulación real en job_applications', () {
      expect(migracion.contains('public.job_applications'), isTrue);
      expect(migracion.contains('ja.candidate_id = p_candidate_id'), isTrue);
      expect(migracion.contains("'no_postulado'"), isTrue);
    });

    test('las validaciones corren en el orden pedido', () {
      final orden = [
        posicionDe("'no_auth'"),
        posicionDe("'autoentrevista'"),
        posicionDe("'vacante_inexistente'"),
        posicionDe("'vacante_ajena'"),
        posicionDe("'no_postulado'"),
      ];
      final ordenado = [...orden]..sort();
      expect(orden, ordenado, reason: 'El orden de las validaciones cambió.');
    });

    test('la propiedad se valida ANTES de tocar interviews', () {
      // Si el INSERT quedara antes de un chequeo, la validación sería adorno.
      expect(
        posicionDe("'vacante_ajena'"),
        lessThan(posicionDe('INSERT INTO public.interviews')),
      );
      expect(
        posicionDe("'no_postulado'"),
        lessThan(posicionDe('INSERT INTO public.interviews')),
      );
    });
  });

  // ══ RPC · duplicados ══════════════════════════════════════════════════════
  group('RPC · no duplica sin UNIQUE INDEX', () {
    test('busca una entrevista existente antes de insertar', () {
      expect(migracion.contains('FROM public.interviews i'), isTrue);
      expect(migracion.contains('IF v_interview IS NULL THEN'), isTrue);
    });

    test('el aviso se escribe SÓLO cuando se crea la entrevista', () {
      // El INSERT en notifications tiene que estar dentro del IF que crea la
      // entrevista: si quedara afuera, reintentar spamearía al candidato.
      final inicioIf = migracion.indexOf('IF v_interview IS NULL THEN');
      final finIf = migracion.indexOf('END IF;', inicioIf);
      final cuerpo = migracion.substring(inicioIf, finIf);
      expect(cuerpo.contains('INSERT INTO public.notifications'), isTrue);
      expect(cuerpo.contains('INSERT INTO public.interviews'), isTrue);
    });

    test('serializa las llamadas concurrentes con un lock de transacción', () {
      // Sin UNIQUE INDEX, SELECT-luego-INSERT es una carrera. El lock consultivo
      // la cierra para las llamadas que pasan por esta función.
      expect(migracion.contains('pg_advisory_xact_lock'), isTrue);
    });

    test('la limitación del lock queda documentada, no escondida', () {
      // El ATS legacy inserta en interviews sin tomar el lock: la carrera entre
      // ese camino y éste sigue abierta hasta que exista el UNIQUE INDEX.
      expect(migracion.contains('LÍMITE HONESTO'), isTrue);
      expect(migracion.contains('UNIQUE INDEX'), isTrue);
    });

    test('la migración NO crea el índice único todavía', () {
      expect(
        RegExp(r'CREATE\s+UNIQUE\s+INDEX').hasMatch(migracion),
        isFalse,
        reason: 'El índice quedó postergado por decisión explícita.',
      );
    });
  });

  // ══ RPC · seguridad ═══════════════════════════════════════════════════════
  group('RPC · endurecimiento', () {
    test('SECURITY DEFINER con search_path fijo', () {
      expect(migracion.contains('SECURITY DEFINER'), isTrue);
      expect(
        RegExp(r'SET\s+search_path\s*=').hasMatch(migracion),
        isTrue,
        reason: 'Sin search_path fijo, una SECURITY DEFINER es secuestrable.',
      );
    });

    test('nada de SQL dinámico', () {
      expect(migracion.contains('EXECUTE format('), isFalse);
      expect(RegExp(r'\bEXECUTE\s+[\x27v]').hasMatch(migracion), isFalse);
    });

    test('se revoca a PUBLIC y anon, y se concede sólo a authenticated', () {
      expect(migracion.contains('REVOKE ALL ON FUNCTION'), isTrue);
      expect(migracion.contains('FROM PUBLIC'), isTrue);
      expect(migracion.contains('FROM anon'), isTrue);
      expect(migracion.contains('GRANT EXECUTE'), isTrue);
      expect(migracion.contains('TO authenticated'), isTrue);
    });

    test('el revoke va ANTES del grant', () {
      expect(
        migracion.indexOf('REVOKE ALL ON FUNCTION'),
        lessThan(migracion.indexOf('GRANT EXECUTE')),
      );
    });

    test('no se toca RLS ni las políticas de notifications', () {
      expect(migracion.contains('DISABLE ROW LEVEL SECURITY'), isFalse);
      expect(
        RegExp(r'CREATE\s+POLICY').hasMatch(migracion),
        isFalse,
        reason: 'notifications no debe recibir política de INSERT.',
      );
      expect(RegExp(r'DROP\s+POLICY').hasMatch(migracion), isFalse);
    });

    test('el cliente no elige destinatario, tipo, título ni cuerpo', () {
      // Los cuatro son literales o valores ya validados dentro de la función.
      // La firma sólo acepta dos uuid: no hay por dónde inyectar texto.
      expect(
        RegExp(r'request_ai_interview\(\s*p_job_id\s+UUID,\s*p_candidate_id\s+UUID\s*\)')
            .hasMatch(migracion),
        isTrue,
      );
      expect(migracion.contains("'Te invitaron a una entrevista con IA'"), isTrue);
    });

    test('no se escriben columnas que notifications no tiene', () {
      // La base real no tiene actor_id ni description (migración 020).
      final insert = migracion.substring(
        migracion.indexOf('INSERT INTO public.notifications'),
      );
      expect(insert.contains('actor_id'), isFalse);
      expect(insert.contains('description'), isFalse);
    });
  });

  // ══ Cliente · errores y semántica ═════════════════════════════════════════
  group('Cliente · cada motivo del servidor dice algo accionable', () {
    test('los códigos de la migración están todos mapeados', () {
      // Se extraen del SQL: si mañana la RPC agrega un motivo y nadie lo mapea,
      // este test lo caza en vez de mostrarle al usuario un mensaje genérico.
      final codigos = RegExp(r"'error',\s*'([a-z_]+)'")
          .allMatches(migracion)
          .map((m) => m.group(1)!)
          .toSet();

      expect(codigos, isNotEmpty);
      final generico = mensajeDeErrorPedido('__desconocido__');
      for (final c in codigos) {
        expect(
          mensajeDeErrorPedido(c),
          isNot(generico),
          reason: 'El código "$c" no tiene mensaje propio.',
        );
      }
    });

    test('ningún mensaje filtra datos de una vacante ajena', () {
      expect(
        mensajeDeErrorPedido('vacante_ajena').toLowerCase(),
        isNot(contains('candidat')),
      );
      for (final c in ['vacante_ajena', 'vacante_inexistente', 'no_postulado']) {
        expect(mensajeDeErrorPedido(c), isNotEmpty);
      }
    });

    test('un código desconocido cae a un mensaje genérico, no al código crudo', () {
      final m = mensajeDeErrorPedido('sarasa');
      expect(m, isNot(contains('sarasa')));
      expect(m, isNotEmpty);
    });
  });

  group('Cliente · semántica de ResultadoPedido', () {
    test('sin id no hay éxito ni aviso', () {
      const r = ResultadoPedido(error: 'x');
      expect(r.ok, isFalse);
      expect(r.avisado, isFalse);
    });

    test('entrevista nueva ⇒ el candidato quedó avisado', () {
      const r = ResultadoPedido(interviewId: entrevistaId);
      expect(r.ok, isTrue);
      expect(r.yaExistia, isFalse);
      // La RPC escribe entrevista e invitación en la misma transacción: no
      // existe el caso "creada pero sin avisar".
      expect(r.avisado, isTrue);
    });

    test('entrevista ya existente ⇒ NO se vuelve a avisar', () {
      const r = ResultadoPedido(interviewId: entrevistaId, yaExistia: true);
      expect(r.ok, isTrue);
      expect(r.avisado, isFalse);
    });

    test('las preguntas son independientes del alta', () {
      const r = ResultadoPedido(interviewId: entrevistaId);
      expect(r.preguntas, isEmpty);
      expect(r.ok, isTrue, reason: 'Sin preguntas la entrevista existe igual.');
    });
  });

  // ══ Anti-demo y anti-regresión ════════════════════════════════════════════
  group('Empresa no escribe notifications ni toca datos demo', () {
    test('ninguna pantalla de Empresa inserta en notifications', () {
      // La tabla no tiene política de INSERT: cualquier insert directo devuelve
      // 42501 y el aviso se pierde. La única vía es la RPC.
      final dir = Directory('$raiz/lib/screens/empresa');
      final culpables = <String>[];
      for (final f in dir.listSync().whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final src = f.readAsStringSync();
        if (RegExp(r"from\('notifications'\)\s*\.\s*insert").hasMatch(src)) {
          culpables.add(f.path.split(RegExp(r'[/\\]')).last);
        }
      }
      expect(culpables, isEmpty, reason: 'Insert directo en: $culpables');
    });

    test('Empresa pide la entrevista por la RPC, no por createInterview', () {
      final alta =
          fuente('lib/screens/empresa/empresa_crear_entrevista_data.dart');
      expect(
        RegExp(r"rpc\(\s*'request_ai_interview'").hasMatch(alta),
        isTrue,
      );
      expect(
        alta.contains('createInterview'),
        isFalse,
        reason: 'createInterview sigue vivo para el ATS legacy, pero Empresa '
            'ya no lo usa: no valida propiedad ni postulación.',
      );
    });

    test('createInterview NO se rompió: el legacy lo sigue teniendo', () {
      final servicio = fuente('lib/services/ai_interview_service.dart');
      expect(servicio.contains('Future<Interview?> createInterview('), isTrue);
      expect(
        fuente('lib/screens/ats_dashboard_screen.dart')
            .contains('AIInterviewService.instance.createInterview'),
        isTrue,
      );
    });

    test('el alta de Empresa no nombra ids demo', () {
      expect(
        fuente('lib/screens/empresa/empresa_crear_entrevista_data.dart')
            .contains('demo-'),
        isFalse,
      );
    });

    test('esIdDemo sigue reconociendo los ids inventados', () {
      expect(esIdDemo('demo-completed'), isTrue);
      expect(esIdDemo(entrevistaId), isFalse);
    });

    test('ningún id demo se consulta contra interview_reports', () async {
      expect(
        await loadEntrevistasConInforme(const ['demo-completed']),
        isEmpty,
      );
    });
  });

  // ══ Generación de preguntas ═══════════════════════════════════════════════
  group('La generación de preguntas recibe el contexto que exige', () {
    final edge =
        fuente('supabase/functions/generate-interview-questions/index.ts');
    final servicio = fuente('lib/services/ai_interview_service.dart');
    final alta = fuente('lib/screens/empresa/empresa_crear_entrevista_data.dart');

    test('la Edge Function sigue exigiendo job_id', () {
      expect(edge.contains("'job_id requerido'"), isTrue);
    });

    test('el cliente manda job_id además de interview_id', () {
      // REGRESIÓN: se invocaba sólo con interview_id. La función respondía 400 y
      // NINGUNA entrevista llegaba a tener preguntas.
      expect(
        servicio.contains(
          "body: {'interview_id': interviewId, 'job_id': vacanteId}",
        ),
        isTrue,
      );
    });

    test('Empresa pasa el job_id real al disparar la generación', () {
      expect(
        alta.contains('triggerQuestionGeneration(interviewId, jobId: jobId)'),
        isTrue,
      );
    });

    test('no se declara éxito sin releer las preguntas de la base', () {
      // Que la Edge Function responda 200 no prueba que hayan quedado.
      expect(
        alta.indexOf('triggerQuestionGeneration'),
        lessThan(alta.indexOf('fetchQuestions')),
      );
    });

    test('la generación NO ocurre dentro de la transacción de la RPC', () {
      expect(migracion.contains('generate-interview-questions'), isFalse);
      expect(migracion.contains('http_post'), isFalse);
    });
  });

  // ══ Informe del servidor → pantalla de Empresa ════════════════════════════
  group('EMPALME 4 · el informe que escribe el servidor lo dibuja Empresa', () {
    InterviewReport filaDelServidor() => InterviewReport.fromJson({
          'id': 'ffffffff-0000-0000-0000-000000000001',
          'interview_id': entrevistaId,
          'summary': 'Perfil sólido en Flutter, comunica con orden.',
          'competencies': [
            {'name': 'Flutter', 'score': 88, 'note': 'Domina el ciclo de vida.'},
            {'name': 'Comunicación', 'score': 74},
            {'name': '', 'score': 10},
          ],
          'keywords': ['#Flutter', 'Riverpod', '  '],
          'score': 81,
          'rationale': 'Respuestas concretas y con ejemplos.',
          'created_at': '2026-08-12T10:00:00.000Z',
        });

    test('el informe queda atado al interview_id correcto', () {
      expect(filaDelServidor().interviewId, entrevistaId);
    });

    test('las competencias JSONB se leen con nombre, score y nota', () {
      final competencias = <CompetenciaEvaluada>[
        for (final c in filaDelServidor().competencies!)
          if (CompetenciaEvaluada.desde(c) != null)
            CompetenciaEvaluada.desde(c)!,
      ];
      expect(competencias.length, 2); // la tercera no tiene nombre
      expect(competencias.first.puntaje, 88);
      expect(competencias[1].nota, isNull);
    });

    test('el promedio sale de las competencias, no del score global', () {
      final vista = InformeEntrevista(
        entrevista: Interview(
          id: entrevistaId,
          jobId: vacanteId,
          candidateId: candidatoId,
          status: 'completed',
          createdAt: DateTime(2026, 8, 12),
        ),
        informe: filaDelServidor(),
        candidato: 'Candidato',
        competencias: const [
          CompetenciaEvaluada(nombre: 'Flutter', puntaje: 88),
          CompetenciaEvaluada(nombre: 'Comunicación', puntaje: 74),
        ],
      );
      expect(vista.puntaje, 81);
      expect(vista.promedioCompetencias, 81);
    });

    test('una respuesta sin video ni transcripción no finge tenerlos', () {
      const vacia = RespuestaEntrevista(pregunta: '¿Contame un desafío?');
      expect(vacia.tieneVideo, isFalse);
      expect(vacia.tieneTranscripcion, isFalse);
    });
  });

  // ══ TRANSCRIPCIÓN REAL ════════════════════════════════════════════════════
  //
  // La lógica de transcripción vive en TypeScript y tiene sus propios tests
  // EJECUTABLES —20 casos, sin red ni Supabase— en
  // `supabase/functions/_shared/transcribe.test.ts`:
  //
  //     node --test supabase/functions/_shared/transcribe.test.ts
  //
  // Acá sólo se fija lo que es del lado Dart y lo que ninguna de las dos partes
  // debe poder reintroducir.
  group('Transcripción · el placeholder no puede volver', () {
    const placeholder = '[Respuesta grabada en video]';
    final servicio = sinComentarios(fuente('lib/services/ai_interview_service.dart'));
    final flujo = sinComentarios(fuente('lib/screens/interview_flow_screen.dart'));

    test('ningún código de lib/ escribe el placeholder', () {
      // Era el texto que el informe de IA evaluaba como si fuera la respuesta
      // del candidato. Los comentarios que lo nombran para explicar la historia
      // no cuentan: lo que importa es que nadie lo vuelva a escribir.
      final culpables = <String>[];
      for (final f in Directory('$raiz/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (sinComentarios(f.readAsStringSync()).contains(placeholder)) {
          culpables.add(f.path.split(RegExp(r'[/\\]')).last);
        }
      }
      expect(culpables, isEmpty, reason: 'Placeholder en: $culpables');
    });

    test('submitAnswer ya no acepta un transcript del cliente', () {
      // Sin parámetro no hay forma de volver a inyectar un placeholder.
      final firma = RegExp(
        r'Future<bool> submitAnswer\(\{(.*?)\}\)',
        dotAll: true,
      ).firstMatch(servicio);
      expect(firma, isNotNull);
      expect(firma!.group(1)!.contains('transcript'), isFalse);
    });

    test('submitAnswer no escribe la columna transcript', () {
      // Debe quedar NULL: es lo que hace detectable el estado "sin transcribir".
      final insert = servicio.substring(
        servicio.indexOf("from('interview_answers').insert"),
        servicio.indexOf('unawaited('),
      );
      expect(insert.contains('transcript'), isFalse);
      expect(insert.contains('video_url'), isTrue);
    });

    test('la transcripción se dispara sin bloquear al candidato', () {
      expect(servicio.contains('unawaited(_dispararTranscripcion('), isTrue);
    });

    test('InterviewFlowScreen ya no manda transcript', () {
      final llamada = RegExp(
        r'submitAnswer\((.*?)\);',
        dotAll: true,
      ).firstMatch(flujo);
      expect(llamada, isNotNull);
      expect(llamada!.group(1)!.contains('transcript'), isFalse);
    });

    test('ninguna API key de transcripción vive en Flutter', () {
      // La GEMINI_API_KEY sólo la ve la Edge Function.
      expect(servicio.contains('GEMINI_API_KEY'), isFalse);
      expect(servicio.contains('generativelanguage'), isFalse);
    });
  });

  group('Transcripción · la Edge Function está protegida', () {
    final fn = fuente('supabase/functions/transcribe-interview-answer/index.ts');
    final shared = fuente('supabase/functions/_shared/transcribe.ts');

    final auth = fuente('supabase/functions/_shared/autorizacion.ts');

    test('exige JWT y resuelve el usuario contra la base', () {
      expect(fn.contains('esParteDeLaEntrevista('), isTrue);
      expect(auth.contains("req.headers.get('Authorization')"), isTrue);
      expect(auth.contains('supabase.auth.getUser(jwt)'), isTrue);
      // El id del usuario NO puede salir del body.
      expect(RegExp(r'\buser_id\b').hasMatch(fn), isFalse);
      expect(RegExp(r'\buser_id\b').hasMatch(auth), isFalse);
    });

    test('sólo pasan el candidato o la empresa dueña de la vacante', () {
      expect(auth.contains('entrevista.candidate_id === uid'), isTrue);
      expect(auth.contains('vacante?.company_id === uid'), isTrue);
    });

    test('un tercero no averigua si la entrevista existe', () {
      // Mismo error para "no existe" que para "no sos parte": los dos caminos
      // devuelven `entrevista_inexistente` con 404.
      expect(
        RegExp("error: 'entrevista_inexistente', status: 404")
            .allMatches(auth)
            .length,
        2,
      );
    });

    test('la autorización corre ANTES de gastar nada', () {
      expect(
        fn.indexOf('esParteDeLaEntrevista('),
        lessThan(fn.indexOf('transcribirRespuesta(')),
      );
    });

    test('la pregunta tiene que ser de esa entrevista', () {
      expect(fn.contains('pregunta_ajena_a_la_entrevista'), isTrue);
    });

    test('los ids demo quedan bloqueados por la forma uuid', () {
      expect(fn.contains('ES_UUID.test'), isTrue);
      // 'demo-pending' no matchea el patrón uuid.
      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      expect(uuid.hasMatch('demo-pending'), isFalse);
      expect(uuid.hasMatch('demo-completed'), isFalse);
      expect(uuid.hasMatch(entrevistaId), isTrue);
    });

    test('el service_role no se devuelve nunca al llamador', () {
      // Nombrar la variable de entorno en un mensaje de error es correcto; lo
      // que no puede pasar es que su VALOR salga en una respuesta.
      for (final m in RegExp(r'json\([^;]*?\)').allMatches(sinComentarios(fn))) {
        expect(m.group(0)!.contains('serviceKey'), isFalse);
        expect(m.group(0)!.contains('geminiKey'), isFalse);
      }
      expect(fn.contains(r'${serviceKey}'), isFalse);
    });

    test('el prompt transcribe y no evalúa', () {
      expect(shared.contains('Transcribí literalmente el audio'), isTrue);
      expect(shared.contains('No inventes palabras'), isTrue);
      expect(shared.contains('[inaudible]'), isTrue);
      // Nada de scoring en esta función.
      expect(shared.contains('score'), isFalse);
      expect(shared.contains('competenc'), isFalse);
    });

    test('el prompt prohíbe describir el video y da salida para el mudo', () {
      // Gemini VE los cuadros: sin esto, un video sin audio puede volver como
      // una descripción visual que parece una respuesta del candidato.
      expect(shared.contains('No describas lo que se ve en el video'), isTrue);
      expect(shared.contains('SIN_AUDIO'), isTrue);
      expect(shared.contains("error: 'video_sin_voz'"), isTrue);
    });

    test('la escritura es condicional sobre el valor leído', () {
      expect(shared.contains("escritura.is('transcript', null)"), isTrue);
      expect(shared.contains("escritura.eq('transcript', fila.transcript)"), isTrue);
    });

    test('la relectura previa al UPDATE controla su error', () {
      expect(shared.contains('error: errRelectura'), isTrue);
      expect(shared.contains(r'`relectura: ${errRelectura.message}`'), isTrue);
    });

    test('el límite de inline sale del tope de 20 MB del endpoint', () {
      // 20 MB de request total ÷ 4/3 de inflado base64 ≈ 15 MB de video.
      expect(shared.contains('LIMITE_INLINE_BYTES'), isTrue);
      expect(shared.contains('subirPorFilesApi'), isTrue);
      expect(shared.contains('fileData'), isTrue);
    });
  });

  group('Transcripción · el informe no evalúa relleno', () {
    final informe =
        sinComentarios(fuente('supabase/functions/generate-interview-report/index.ts'));

    test('usa la MISMA regla de validez que la transcripción', () {
      expect(informe.contains("from '../_shared/transcribe.ts'"), isTrue);
      expect(informe.contains('esTranscripcionReal'), isTrue);
    });

    test('verifica que el llamador sea parte de la entrevista', () {
      // AGUJERO CORREGIDO EL 12/8/2026: la función corre con service_role, o sea
      // que saltea RLS, y NO validaba nada. Cualquiera con un interview_id
      // recibía el informe completo de un candidato ajeno.
      expect(informe.contains('esParteDeLaEntrevista('), isTrue);
      expect(informe.contains('jwtDeRequest(req)'), isTrue);
    });

    test('la autorización va antes de leer la entrevista y de transcribir', () {
      final permiso = informe.indexOf('esParteDeLaEntrevista(');
      expect(permiso, greaterThan(-1));
      expect(permiso, lessThan(informe.indexOf("from('interview_questions')")));
      expect(permiso, lessThan(informe.indexOf('transcribirRespuesta(')));
      // Contra la LLAMADA a Gemini, no contra la constante, que se declara
      // arriba de todo.
      expect(permiso, lessThan(informe.indexOf('fetch(GEMINI_URL')));
    });

    test('las dos funciones comparten la MISMA regla de autorización', () {
      final transcribe =
          fuente('supabase/functions/transcribe-interview-answer/index.ts');
      for (final f in [informe, transcribe]) {
        expect(f.contains("from '../_shared/autorizacion.ts'"), isTrue);
      }
    });

    test('intenta recuperar lo que falte antes de rendirse', () {
      expect(informe.contains('transcribirRespuesta'), isTrue);
      expect(
        informe.indexOf('const faltantes'),
        lessThan(informe.indexOf('const irrecuperables')),
      );
    });

    test('aborta si queda alguna sin transcripción real', () {
      expect(informe.contains('transcripciones_faltantes'), isTrue);
      expect(
        informe.indexOf('irrecuperables.length > 0'),
        lessThan(informe.indexOf('const qaText')),
        reason: 'La verificación tiene que estar ANTES de armar el prompt.',
      );
    });

    test('ya no rellena con "(sin respuesta)"', () {
      expect(informe.contains('(sin respuesta)'), isFalse);
    });

    test('sigue generando score, competencias, keywords y rationale', () {
      for (final campo in ['summary', 'competencies', 'keywords', 'score', 'rationale']) {
        expect(informe.contains(campo), isTrue, reason: campo);
      }
      expect(informe.contains('interview_reports'), isTrue);
      expect(informe.contains("status: 'completed'"), isTrue);
    });

    test('no reprocesa lo que ya está transcripto', () {
      // Sólo entran a `faltantes` las que no pasan la regla de validez.
      expect(
        informe.contains('.filter((id) => !esTranscripcionReal(respuestas.get(id)))'),
        isTrue,
      );
    });
  });

  // ══ PRUEBA E2E REAL — pendiente a propósito ═══════════════════════════════
  group('PRUEBA E2E REAL', () {
    test(
      'circuito completo contra Postgres y las Edge Functions',
      () {
        // Lo que SÓLO se puede comprobar con base de verdad:
        //   · request_ai_interview rechaza vacante ajena / candidato no
        //     postulado / autoentrevista, y reutiliza la entrevista existente;
        //   · el INSERT en notifications pasa (corre como owner, saltea RLS);
        //   · generate-interview-questions persiste interview_questions;
        //   · la notificación llega y abre la entrevista correcta;
        //   · los videos suben al bucket `videos`;
        //   · cada respuesta obtiene una transcripción REAL, verificable contra
        //     lo que el candidato dijo en el video;
        //   · generate-interview-report escribe el informe y deja completed,
        //     citando contenido real y no genéricos.
        fail('no debe ejecutarse: está marcado como pendiente');
      },
      skip: 'PENDIENTE: requiere la migración 027 aplicada, las Edge Functions '
          'desplegadas y un postulante real. No se fabrica ninguno para no '
          'ensuciar la base.',
    );
  });
}
