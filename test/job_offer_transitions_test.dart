import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/job_offer_service.dart';

/// Lógica crítica de ofertas laborales (migración 051, bloque E2).
///
/// Estos tests NO tocan la red. Lo que protegen es el contrato que la app
/// asume sobre el servidor: los ocho estados de `job_offers.status`, cuáles
/// están "abiertos", y la validación local que evita una ida y vuelta cuando
/// ya se sabe que el servidor la va a rechazar (mensaje obligatorio para
/// rechazar o pedir cambios).
void main() {
  group('vocabulario de estados', () {
    test('los ocho estados reales tienen etiqueta propia', () {
      const estados = [
        'draft',
        'sent',
        'viewed',
        'changes_requested',
        'accepted',
        'declined',
        'withdrawn',
        'expired',
      ];
      final etiquetas = estados.map(offerStatusLabel).toSet();
      // Ocho estados, ocho etiquetas distintas: si dos coincidieran, una
      // persona no podría distinguirlos en la pantalla.
      expect(etiquetas.length, estados.length);
    });

    test('un estado desconocido no inventa una etiqueta', () {
      expect(offerStatusLabel('algo_que_no_existe'), 'algo_que_no_existe');
    });

    test('sólo sent, viewed y changes_requested están abiertos', () {
      const abiertos = {'sent', 'viewed', 'changes_requested'};
      const todos = {
        'draft',
        'sent',
        'viewed',
        'changes_requested',
        'accepted',
        'declined',
        'withdrawn',
        'expired',
      };
      for (final estado in todos) {
        expect(
          offerStatusAbierta(estado),
          abiertos.contains(estado),
          reason: estado,
        );
      }
    });

    test('kOfferOpenStatuses y kOfferClosedStatuses no se superponen', () {
      final interseccion =
          kOfferOpenStatuses.toSet().intersection(kOfferClosedStatuses.toSet());
      expect(interseccion, isEmpty);
    });

    test('los nueve tipos de versión tienen etiqueta propia', () {
      const tipos = [
        'creada',
        'enviada',
        'revisada',
        'vista',
        'cambios_pedidos',
        'aceptada',
        'rechazada',
        'retirada',
        'vencida',
      ];
      final etiquetas = tipos.map(offerChangeKindLabel).toSet();
      expect(etiquetas.length, tipos.length);
    });
  });

  group('respondToJobOffer — validación local antes de llamar al servidor',
      () {
    test('rechazar sin mensaje falla antes de tocar la red', () async {
      await expectLater(
        respondToJobOffer(offerId: 'x', decision: 'declined'),
        throwsA(isA<JobOfferException>()),
      );
    });

    test('pedir cambios sin mensaje falla antes de tocar la red', () async {
      await expectLater(
        respondToJobOffer(
          offerId: 'x',
          decision: 'changes_requested',
          message: '   ',
        ),
        throwsA(isA<JobOfferException>()),
      );
    });

    test('el mensaje de error no expone detalles internos', () async {
      try {
        await respondToJobOffer(offerId: 'x', decision: 'declined');
        fail('tenía que lanzar JobOfferException');
      } on JobOfferException catch (e) {
        expect(e.mensaje, isNot(contains('ERRCODE')));
        expect(e.mensaje, isNot(contains('respond_to_job_offer')));
      }
    });
  });

  group('JobOffer — datos derivados', () {
    JobOffer construir({
      String status = 'sent',
      double? salaryAmount = 850000,
      String? salaryCurrency = 'ARS',
      String salaryPeriod = 'mensual',
      String? modalidad,
      DateTime? expiresAt,
    }) {
      final ahora = DateTime.now();
      return JobOffer(
        id: '1',
        applicationId: 'app-1',
        companyId: 'company-1',
        candidateId: 'candidate-1',
        jobId: 'job-1',
        status: status,
        salaryAmount: salaryAmount,
        salaryCurrency: salaryCurrency,
        salaryPeriod: salaryPeriod,
        modalidad: modalidad,
        benefits: const [],
        version: 1,
        createdAt: ahora,
        updatedAt: ahora,
        expiresAt: expiresAt,
      );
    }

    test('el salario se formatea con separador de miles y periodo', () {
      expect(construir().salarioFormateado, 'ARS \$850.000/mes');
      expect(
        construir(salaryPeriod: 'anual').salarioFormateado,
        'ARS \$850.000/año',
      );
      expect(
        construir(salaryPeriod: 'hora').salarioFormateado,
        'ARS \$850.000/hora',
      );
    });

    test('sin monto o sin moneda, el salario es "a convenir"', () {
      expect(construir(salaryAmount: null).salarioFormateado, 'A convenir');
      expect(
        construir(salaryCurrency: null).salarioFormateado,
        'A convenir',
      );
    });

    test('la modalidad tiene una etiqueta legible, o ninguna', () {
      expect(construir(modalidad: 'hibrido').modalidadLabel, 'Híbrido');
      expect(construir(modalidad: 'remoto').modalidadLabel, 'Remoto');
      expect(construir(modalidad: 'presencial').modalidadLabel, 'Presencial');
      expect(construir(modalidad: null).modalidadLabel, '');
    });

    test('abierta refleja el estado real, no una suposición', () {
      expect(construir(status: 'sent').abierta, isTrue);
      expect(construir(status: 'viewed').abierta, isTrue);
      expect(construir(status: 'changes_requested').abierta, isTrue);
      expect(construir(status: 'accepted').abierta, isFalse);
      expect(construir(status: 'draft').abierta, isFalse);
    });

    test('vencida requiere estar abierta Y con fecha pasada', () {
      final pasado = DateTime.now().subtract(const Duration(days: 1));
      final futuro = DateTime.now().add(const Duration(days: 1));

      expect(construir(status: 'sent', expiresAt: pasado).vencida, isTrue);
      expect(construir(status: 'sent', expiresAt: futuro).vencida, isFalse);
      // Cerrada y vencida en el pasado no cuenta: ya no está "abierta".
      expect(
        construir(status: 'accepted', expiresAt: pasado).vencida,
        isFalse,
      );
    });
  });

  group('JobOffer.fromRow — no inventa datos que la fila no trae', () {
    test('reconstruye una oferta completa', () {
      final row = <String, dynamic>{
        'id': 'offer-1',
        'application_id': 'app-1',
        'company_id': 'company-1',
        'candidate_id': 'candidate-1',
        'job_id': 'job-1',
        'status': 'sent',
        'salary_amount': '850000.00',
        'salary_currency': 'ARS',
        'salary_period': 'mensual',
        'modalidad': 'hibrido',
        'benefits': ['Obra social', 'Home office'],
        'start_date': '2026-09-15',
        'expires_at': '2026-09-05T00:00:00Z',
        'version': 1,
        'created_at': '2026-08-30T17:51:22.912893Z',
        'updated_at': '2026-08-30T17:51:22.912893Z',
      };
      final oferta = JobOffer.fromRow(row);

      expect(oferta.id, 'offer-1');
      expect(oferta.applicationId, 'app-1');
      expect(oferta.status, 'sent');
      expect(oferta.salaryAmount, 850000.0);
      expect(oferta.salaryCurrency, 'ARS');
      expect(oferta.benefits, ['Obra social', 'Home office']);
      expect(oferta.modalidad, 'hibrido');
    });

    test('una fila sin datos opcionales no explota', () {
      final row = <String, dynamic>{
        'id': 'offer-2',
        'application_id': 'app-2',
        'company_id': 'company-1',
        'candidate_id': 'candidate-2',
        'job_id': 'job-1',
        'status': 'draft',
        'version': 1,
        'created_at': '2026-08-30T17:51:22Z',
        'updated_at': '2026-08-30T17:51:22Z',
      };
      final oferta = JobOffer.fromRow(row);

      expect(oferta.salaryAmount, isNull);
      expect(oferta.salaryCurrency, isNull);
      expect(oferta.modalidad, isNull);
      expect(oferta.benefits, isEmpty);
      expect(oferta.message, isNull);
      expect(oferta.salarioFormateado, 'A convenir');
    });
  });
}
