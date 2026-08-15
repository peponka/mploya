import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/models/ai_interview_models.dart';
import 'package:mploya/screens/empresa/empresa_informe_entrevista_data.dart';
import 'package:mploya/screens/empresa/empresa_informe_entrevista_screen.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

import 'mp_golden_host.dart';

/// Golden del Informe de Entrevista IA, reconstruido de
/// `resumenIA de la entrevista.png` (20) con `resumen ia video.png` de apoyo.
///
///   flutter test test/empresa_informe_entrevista_golden_test.dart --update-goldens

final _entrevista = Interview(
  id: 'i1',
  jobId: 'j1',
  candidateId: 'c1',
  status: 'completed',
  createdAt: DateTime(2026, 5, 28),
  completedAt: DateTime(2026, 5, 30),
);

/// Muestra con la FORMA de un `interview_reports` real: los puntajes y el texto
/// son los que devolvería la Edge Function, no valores del mockup.
final _informeCompleto = InformeEntrevistaData(
  candidato: 'Lucas Fernández',
  candidatoHeadline: 'Senior Product Manager',
  informe: InformeEntrevista(
    entrevista: _entrevista,
    informe: InterviewReport(
      id: 'r1',
      interviewId: 'i1',
      summary: 'Mostró claridad al explicar conceptos complejos y experiencia '
          'liderando equipos multidisciplinarios.',
      rationale: 'El puntaje refleja respuestas estructuradas y ejemplos '
          'concretos en los casos planteados.',
      score: 88,
      competencies: const [
        {'name': 'Comunicación', 'score': 90, 'note': 'Se expresó con claridad.'},
        {'name': 'Conocimientos técnicos', 'score': 92},
        {'name': 'Resolución de problemas', 'score': 85},
        {'name': 'Liderazgo', 'score': 62},
      ],
      keywords: const ['Producto', 'Analytics', 'Liderazgo'],
      createdAt: DateTime(2026, 5, 30),
    ),
    candidato: 'Lucas Fernández',
    candidatoHeadline: 'Senior Product Manager',
    vacante: 'Product Manager Senior',
    competencias: const [
      CompetenciaEvaluada(
        nombre: 'Comunicación',
        puntaje: 90,
        nota: 'Se expresó con claridad.',
      ),
      CompetenciaEvaluada(nombre: 'Conocimientos técnicos', puntaje: 92),
      CompetenciaEvaluada(nombre: 'Resolución de problemas', puntaje: 85),
      CompetenciaEvaluada(nombre: 'Liderazgo', puntaje: 62),
    ],
    habilidades: const ['Producto', 'Analytics', 'Liderazgo'],
    respuestas: const [
      RespuestaEntrevista(
        pregunta: '¿Cuál fue tu mayor desafío liderando un equipo?',
        transcripcion: 'Coordinar prioridades entre diseño y desarrollo.',
        videoUrl: 'https://example.com/r1.mp4',
      ),
      RespuestaEntrevista(
        pregunta: '¿Cómo priorizás un roadmap?',
        transcripcion: 'Por impacto medible y esfuerzo estimado.',
      ),
    ],
  ),
);

final _informeConfidencial = InformeEntrevistaData(
  candidato: 'Nombre Real Oculto',
  candidatoHeadline: 'Senior Product Manager',
  candidatoAvatar: 'https://example.com/avatar-real.jpg',
  informe: InformeEntrevista(
    entrevista: _entrevista,
    informe: InterviewReport(
      id: 'r-confidencial',
      interviewId: 'i1',
      summary: 'Resumen disponible.',
      score: 84,
      createdAt: DateTime(2026, 5, 30),
    ),
    candidato: 'Nombre Real Oculto',
    candidatoHeadline: 'Senior Product Manager',
    candidatoAvatar: 'https://example.com/avatar-real.jpg',
    candidatoConfidencial: true,
    respuestas: const [
      RespuestaEntrevista(
        pregunta: 'Contanos sobre tu experiencia.',
        transcripcion: 'Respuesta transcripta.',
        videoUrl: 'https://example.com/respuesta-real.mp4',
      ),
    ],
  ),
);

Widget _pantalla(InformeEntrevistaData d, {String clave = 'informe'}) =>
    EmpresaInformeEntrevistaScreen(
      key: ValueKey(clave),
      interviewId: 'i1',
      previewData: d,
    );

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · informe completo', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_informeCompleto),
        style: MpSurfaceStyle.dark);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_informe_entrevista.png'));
  });

  testWidgets('golden · informe pendiente', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(
        const InformeEntrevistaData(
          motivo: MotivoSinInforme.informePendiente,
          candidato: 'Lucas Fernández',
        ),
        clave: 'pendiente',
      ),
      style: MpSurfaceStyle.dark,
    );
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_informe_entrevista_pendiente.png'));
  });

  for (final size in mpTamanos) {
    final n = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('sin overflow en $n', (tester) async {
      await pumpMp(tester, size, _pantalla(_informeCompleto, clave: 'a-$n'),
          style: MpSurfaceStyle.dark);
      expect(tester.takeException(), isNull);
    });
    testWidgets('pendiente sin overflow en $n', (tester) async {
      await pumpMp(
        tester,
        size,
        _pantalla(
          const InformeEntrevistaData(
            motivo: MotivoSinInforme.informePendiente,
          ),
          clave: 'p-$n',
        ),
        style: MpSurfaceStyle.dark,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('muestra los datos reales del informe', (tester) async {
    await pumpMp(tester, const Size(393, 2400), _pantalla(_informeCompleto),
        style: MpSurfaceStyle.dark);
    expect(find.text('88'), findsOneWidget);
    expect(find.text('Comunicación'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);
    expect(find.text('Veredicto de la IA'), findsOneWidget);
    expect(find.text('Resumen de la entrevista'), findsOneWidget);
    expect(find.text('Habilidades detectadas'), findsOneWidget);
  });

  testWidgets('un candidato confidencial no expone identidad ni video', (
    tester,
  ) async {
    await pumpMp(
      tester,
      const Size(393, 1600),
      _pantalla(_informeConfidencial, clave: 'confidencial'),
      style: MpSurfaceStyle.dark,
    );

    expect(find.text('Candidato confidencial'), findsOneWidget);
    expect(find.text('Nombre Real Oculto'), findsNothing);
    expect(find.text('Senior Product Manager'), findsOneWidget);
    expect(find.text('Ver respuesta en video'), findsNothing);
    expect(find.byIcon(CupertinoIcons.play_circle), findsNothing);

    final avatar = tester.widget<MpAvatar>(find.byType(MpAvatar));
    expect(avatar.image, isNull);
  });

  testWidgets('no se inventa nada de lo que el mockup promete',
      (tester) async {
    await pumpMp(tester, const Size(393, 2400), _pantalla(_informeCompleto),
        style: MpSurfaceStyle.dark);
    for (final inventado in [
      'Comparación con otros candidatos',
      'Próximos pasos sugeridos',
      'Siguientes pasos recomendados',
      'Descargar reporte',
      'Enviar por email',
      'Probabilidad de éxito',
      'Momentos destacados',
    ]) {
      expect(find.textContaining(inventado), findsNothing, reason: inventado);
    }
  });

  testWidgets('sin informe se explica el estado, no se rellena',
      (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(
        const InformeEntrevistaData(
          motivo: MotivoSinInforme.entrevistaIncompleta,
        ),
        clave: 'incompleta',
      ),
      style: MpSurfaceStyle.dark,
    );
    expect(find.text('La entrevista todavía no terminó'), findsOneWidget);
    expect(find.text('Evaluación general'), findsNothing);
  });

  testWidgets('sin puntaje no se dibuja un cero', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 1600),
      _pantalla(
        InformeEntrevistaData(
          candidato: 'Ana Suárez',
          informe: InformeEntrevista(
            entrevista: _entrevista,
            informe: InterviewReport(
              id: 'r2',
              interviewId: 'i1',
              summary: 'Resumen disponible sin puntaje.',
              createdAt: DateTime(2026, 5, 30),
            ),
            candidato: 'Ana Suárez',
          ),
        ),
        clave: 'sin-score',
      ),
      style: MpSurfaceStyle.dark,
    );
    expect(find.text('/100'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  test('los ids demo quedan bloqueados', () {
    // `AIInterviewService` devuelve entrevistas, respuestas y videos FALSOS
    // para cualquier id que empiece con `demo-`. Empresa no debe llegar ahí.
    expect(esIdDemo('demo-completed'), isTrue);
    expect(esIdDemo('demo-pending'), isTrue);
    expect(esIdDemo('a1b2c3d4-0000-0000-0000-000000000000'), isFalse);
  });

  test('el promedio sale de las competencias con puntaje', () {
    final i = _informeCompleto.informe!;
    // (90 + 92 + 85 + 62) / 4 = 82.25 → 82
    expect(i.promedioCompetencias, 82);
  });
}
