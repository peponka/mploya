import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/notifications_screen.dart';

/// GUARDIÁN DEL CIRCUITO DE ENTREVISTA CON IA.
///
/// El recorrido real es:
///   Empresa pide la entrevista  → `interviews` (pending) + preguntas por IA
///                               → notificación `interview_request` con el
///                                 `interview_id` dentro de `data`
///   Candidato toca la notificación → `InterviewFlowScreen` con ESE id
///                               → responde en video → `interview_answers`
///                               → dispara `generate-interview-report`
///   Servidor                    → upsert en `interview_reports`
///                               + `interviews.status = 'completed'`
///   Empresa                     → "Ver informe" en Entrevistas
///
/// Estos tests fijan los dos puntos donde el circuito se rompía: el aviso que
/// no se guardaba y el tap que no llevaba a ninguna parte.
void main() {
  final raiz = Directory.current.path;

  String fuente(String ruta) => File('$raiz/$ruta').readAsStringSync();

  group('resolución del id de entrevista desde la notificación', () {
    test('una invitación real devuelve su interview_id', () {
      final id = interviewIdDeNotificacion({
        'type': 'interview_request',
        'data': {'interview_id': 'a1b2c3d4-0000-0000-0000-000000000000'},
      });
      expect(id, 'a1b2c3d4-0000-0000-0000-000000000000');
    });

    test('un id demo NO se abre nunca', () {
      // `AIInterviewService` responde con entrevista, preguntas, respuestas y
      // video INVENTADOS para cualquier id `demo-`.
      for (final demo in ['demo-pending', 'demo-completed', 'demo-x']) {
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

    test('sin data no se adivina una entrevista', () {
      expect(
        interviewIdDeNotificacion({
          'type': 'interview_request',
        }),
        isNull,
      );
      expect(
        interviewIdDeNotificacion({
          'type': 'interview_request',
          'data': {'job_id': 'j1'},
        }),
        isNull,
      );
      expect(
        interviewIdDeNotificacion({
          'type': 'interview_request',
          'data': {'interview_id': '   '},
        }),
        isNull,
      );
    });

    test('otro tipo de notificación no abre entrevistas', () {
      expect(
        interviewIdDeNotificacion({
          'type': 'message',
          'data': {'interview_id': 'a1b2c3d4'},
        }),
        isNull,
      );
    });
  });

  group('el aviso lo escribe el servidor, no el cliente', () {
    // CAMBIO DE ARQUITECTURA (12/8/2026). El aviso se insertaba desde Flutter.
    // No podía funcionar: `notifications` tiene RLS activa y NINGUNA política de
    // INSERT, así que devolvía 42501 y el candidato nunca se enteraba. Ahora lo
    // escribe la RPC `request_ai_interview` (migración 027), que corre como
    // owner y saltea RLS después de validar del lado del servidor.
    final alta = fuente('lib/screens/empresa/empresa_crear_entrevista_data.dart');
    final migracion =
        fuente('supabase/migrations/027_request_ai_interview.sql');

    test('Empresa ya no inserta en notifications', () {
      expect(
        RegExp(r"from\('notifications'\)\s*\.\s*insert").hasMatch(alta),
        isFalse,
        reason: 'Sin política de INSERT, ese camino devuelve 42501.',
      );
    });

    test('no se insertan columnas que la tabla no tiene', () {
      // La base real no tiene `actor_id` ni `description`, aunque schema.sql los
      // declare (migración 020). Insertarlos devuelve 42703.
      final insert = migracion.substring(
        migracion.indexOf('INSERT INTO public.notifications'),
      );
      expect(insert.contains('actor_id'), isFalse);
      expect(insert.contains('description'), isFalse);
    });

    test('el interview_id viaja en data', () {
      expect(migracion.contains('jsonb_build_object'), isTrue);
      expect(migracion.contains("'interview_id'"), isTrue);
    });
  });

  group('el circuito no toca datos demo', () {
    test('la pantalla de notificaciones no navega con ids demo', () {
      final notif = fuente('lib/screens/notifications_screen.dart');
      // El único push a InterviewFlowScreen pasa por el resolutor, que ya
      // filtra los demo.
      expect(
        notif.contains("InterviewFlowScreen(interviewId: id)"),
        isTrue,
        reason: 'Debe navegar con el id resuelto, no con uno literal.',
      );
      expect(
        notif.contains("interviewId: 'demo-"),
        isFalse,
        reason: 'Ningún id demo literal en la pantalla del candidato.',
      );
    });

    test('el alta de Empresa no crea entrevistas demo', () {
      final alta =
          fuente('lib/screens/empresa/empresa_crear_entrevista_data.dart');
      expect(alta.contains('demo-'), isFalse);
    });

    test('el informe de Empresa bloquea ids demo', () {
      final informe =
          fuente('lib/screens/empresa/empresa_informe_entrevista_data.dart');
      expect(informe.contains('esIdDemo'), isTrue);
    });
  });

  group('el cierre del circuito sigue en pie', () {
    test('el flujo del candidato dispara la generación del informe', () {
      final flujo = fuente('lib/screens/interview_flow_screen.dart');
      expect(
        flujo.contains('triggerReportGeneration'),
        isTrue,
        reason: 'Sin esto no se genera el informe ni se marca completed.',
      );
      expect(flujo.contains('submitAnswer'), isTrue);
    });

    test('la Edge Function marca completed y persiste el informe', () {
      final edge =
          fuente('supabase/functions/generate-interview-report/index.ts');
      expect(edge.contains('interview_reports'), isTrue);
      expect(edge.contains("status: 'completed'"), isTrue);
    });

    test('Empresa sólo ofrece "Ver informe" si el informe existe', () {
      final agenda =
          fuente('lib/screens/empresa/empresa_entrevistas_screen.dart');
      expect(agenda.contains('conInforme.contains'), isTrue);
    });
  });
}
