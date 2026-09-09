import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/application_stage_service.dart';

/// Lógica crítica del cambio de etapa (migraciones 029 y 050).
///
/// Estos tests NO tocan la red. Lo que protegen es el contrato que la app
/// asume sobre el servidor: si alguien cambia la matriz de transiciones de un
/// lado y no del otro, acá se rompe antes de llegar al celular de nadie.
///
/// La matriz de referencia es la del cuerpo de `update_application_status`.
/// Si se modifica en una migración nueva, hay que actualizar los dos lados y
/// este test es el recordatorio.
void main() {
  group('matriz de transiciones', () {
    test('coincide exactamente con la de la migración 029/050', () {
      // Copiada a mano desde el SQL, a propósito: si se derivara del mismo
      // mapa que usa la app, el test no probaría nada.
      const esperada = {
        'pending': ['viewed', 'interviewing', 'accepted', 'rejected'],
        'viewed': ['pending', 'interviewing', 'accepted', 'rejected'],
        'interviewing': ['viewed', 'accepted', 'rejected'],
        'accepted': ['interviewing', 'hired', 'rejected'],
        'hired': ['accepted', 'rejected'],
        'rejected': ['pending', 'viewed', 'interviewing', 'accepted'],
      };

      for (final entry in esperada.entries) {
        expect(
          allowedStagesFrom(entry.key),
          entry.value,
          reason: 'destinos desde ${entry.key}',
        );
      }
    });

    test('a contratado sólo se llega desde con oferta', () {
      for (final desde in kAllowedStageTransitions.keys) {
        final puede = allowedStagesFrom(desde).contains('hired');
        expect(
          puede,
          desde == 'accepted',
          reason: 'desde $desde a hired',
        );
      }
    });

    test('nunca se puede reabrir un descarte directo a contratado', () {
      expect(allowedStagesFrom('rejected'), isNot(contains('hired')));
    });

    test('un estado desconocido no ofrece ningún destino', () {
      expect(allowedStagesFrom('pendiente'), isEmpty);
      expect(allowedStagesFrom(''), isEmpty);
    });

    test('requiereOfertaPrevia explica por qué falta la opción', () {
      expect(requiereOfertaPrevia('pending', 'hired'), isTrue);
      expect(requiereOfertaPrevia('interviewing', 'hired'), isTrue);
      expect(requiereOfertaPrevia('accepted', 'hired'), isFalse);
      expect(requiereOfertaPrevia('pending', 'rejected'), isFalse);
    });
  });

  group('motivo obligatorio al descartar', () {
    test('falla antes de llamar al servidor si no hay motivo', () async {
      await expectLater(
        setApplicationStage(
          applicationId: 'da-igual',
          status: 'rejected',
        ),
        throwsA(isA<StageChangeException>()),
      );
    });

    test('un motivo en blanco no cuenta como motivo', () async {
      await expectLater(
        setApplicationStage(
          applicationId: 'da-igual',
          status: 'rejected',
          reason: '   ',
        ),
        throwsA(isA<StageChangeException>()),
      );
    });

    test('el mensaje es legible para una persona', () async {
      try {
        await setApplicationStage(
          applicationId: 'da-igual',
          status: 'rejected',
        );
        fail('tendría que haber fallado');
      } on StageChangeException catch (e) {
        expect(e.mensaje, contains('motivo'));
        expect(e.mensaje, isNot(contains('ERRCODE')));
        expect(e.mensaje, isNot(contains('update_application_status')));
      }
    });
  });

  group('etiquetas', () {
    test('cada estado real tiene nombre en castellano', () {
      for (final estado in [...kApplicationStages, kApplicationRejected]) {
        final etiqueta = applicationStageLabel(estado);
        expect(etiqueta, isNotEmpty);
        expect(etiqueta, isNot(estado), reason: '$estado quedó sin traducir');
      }
    });

    test('con oferta y contratado NO son lo mismo', () {
      expect(
        applicationStageLabel('accepted'),
        isNot(applicationStageLabel('hired')),
      );
    });

    test('un estado desconocido se muestra crudo en vez de inventarse', () {
      expect(applicationStageLabel('pendiente'), 'pendiente');
    });
  });

  group('etiqueta de actor', () {
    final evento = ApplicationStageEvent(
      id: '1',
      toStatus: 'interviewing',
      changedAt: DateTime(2026, 8, 30),
      changedById: 'uid-empresa',
    );

    test('reconoce a la persona de la sesión', () {
      expect(evento.actorLabel('uid-empresa'), 'Vos');
    });

    test('no atribuye el cambio a nadie si no sabe quién fue', () {
      final sinActor = ApplicationStageEvent(
        id: '2',
        toStatus: 'viewed',
        changedAt: DateTime(2026, 8, 30),
      );
      expect(sinActor.actorLabel('uid-empresa'), 'Sistema');
    });

    test('distingue a otro integrante del equipo', () {
      expect(evento.actorLabel('uid-distinto'), 'Otro integrante');
    });
  });
}
