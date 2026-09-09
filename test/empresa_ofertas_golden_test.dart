import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_ofertas_screen.dart';
import 'package:mploya/screens/empresa/empresa_proceso_data.dart';
import 'package:mploya/services/job_offer_service.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

import 'mp_golden_host.dart';

/// Golden de Ofertas.
///
/// ADENDA 30/8/2026 — migración 051, bloque E2. Reescrito por completo: la
/// versión anterior fijaba `PersonaEnProceso`/`ProcesoData` (la adaptación de
/// cuando "oferta" era sólo `job_applications.status = 'accepted'`, sin
/// salario, moneda ni vencimiento). Ahora la pantalla lee `job_offers` real
/// vía `OfertaEmpresa`/`OfertasEmpresaData`, así que las fixtures y las
/// aserciones sobre "qué no se guarda" quedaron obsoletas.
///
///   flutter test test/empresa_ofertas_golden_test.dart --update-goldens

JobOffer _oferta(
  String id, {
  String applicationId = '',
  String status = 'sent',
  double salaryAmount = 850000,
  String salaryCurrency = 'ARS',
}) {
  final ahora = DateTime.now();
  return JobOffer(
    id: id,
    applicationId: applicationId.isEmpty ? 'app-$id' : applicationId,
    companyId: 'company-1',
    candidateId: 'candidate-$id',
    jobId: 'job-$id',
    status: status,
    salaryAmount: salaryAmount,
    salaryCurrency: salaryCurrency,
    salaryPeriod: 'mensual',
    benefits: const [],
    version: 1,
    createdAt: ahora.subtract(const Duration(days: 2)),
    updatedAt: ahora,
    startDate: ahora.add(const Duration(days: 14)),
    expiresAt: ahora.add(const Duration(days: 5)),
  );
}

OfertaEmpresa _o(
  String id,
  String nombre,
  String? vacante, {
  bool confidencial = false,
  String status = 'sent',
}) {
  return OfertaEmpresa(
    oferta: _oferta(id, applicationId: 'app-$id', status: status),
    candidatoId: id,
    nombre: nombre,
    vacante: vacante ?? 'Sin vacante',
    headline: 'Product Manager',
    confidencial: confidencial,
  );
}

final _conDatos = OfertasEmpresaData(
  ofertas: [
    _o('1', 'María López', 'Product Manager Senior'),
    _o('2', 'Juan Martín', 'Product Manager Senior', status: 'viewed'),
    _o('3', 'Carla Méndez', 'Data Scientist', status: 'accepted'),
  ],
);

Widget _pantalla(OfertasEmpresaData d, {String clave = 'ofertas'}) =>
    EmpresaOfertasScreen(key: ValueKey(clave), previewData: d);

void main() {
  setUpAll(loadMpFonts);

  testWidgets('golden · con ofertas', (tester) async {
    await pumpMp(tester, const Size(393, 852), _pantalla(_conDatos));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_ofertas.png'));
  });

  testWidgets('golden · sin ofertas', (tester) async {
    await pumpMp(tester, const Size(393, 852),
        _pantalla(OfertasEmpresaData.empty, clave: 'vacio'));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CupertinoApp),
        matchesGoldenFile('goldens/empresa_ofertas_vacio.png'));
  });

  for (final size in mpTamanos) {
    final n = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('sin overflow en $n', (tester) async {
      await pumpMp(tester, size, _pantalla(_conDatos, clave: 'a-$n'));
      expect(tester.takeException(), isNull);
    });
    testWidgets('vacío sin overflow en $n', (tester) async {
      await pumpMp(tester, size,
          _pantalla(OfertasEmpresaData.empty, clave: 'v-$n'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('muestra el salario real de cada oferta', (tester) async {
    await pumpMp(tester, const Size(393, 1800), _pantalla(_conDatos));
    expect(find.textContaining('ARS \$850.000'), findsWidgets);
  });

  testWidgets('el estado de cada oferta viene de job_offers, no inventado',
      (tester) async {
    await pumpMp(tester, const Size(393, 1800), _pantalla(_conDatos));
    // Enviada (sent), Vista (viewed) y Aceptada (accepted): los tres estados
    // reales de las fixtures de arriba.
    expect(find.text('Enviada'), findsOneWidget);
    expect(find.text('Vista'), findsOneWidget);
    expect(find.text('Aceptada'), findsOneWidget);
  });

  testWidgets('una oferta confidencial no expone nombre ni avatar',
      (tester) async {
    final data = OfertasEmpresaData(
      ofertas: [
        _o(
          'confidencial',
          'Nombre Real Oculto',
          'Product Manager Senior',
          confidencial: true,
        ),
      ],
    );
    await pumpMp(tester, const Size(393, 852), _pantalla(data));

    expect(find.text('Candidato confidencial'), findsOneWidget);
    expect(find.text('Nombre Real Oculto'), findsNothing);
    final avatar = tester.widget<MpAvatar>(find.byType(MpAvatar));
    expect(avatar.image, isNull);
  });

  testWidgets('se agrupa por vacante real', (tester) async {
    expect(_conDatos.porVacante.length, 2);
    expect(_conDatos.porVacante['Product Manager Senior']!.length, 2);
  });

  testWidgets('el error se distingue del vacío', (tester) async {
    await pumpMp(
      tester,
      const Size(393, 852),
      _pantalla(const OfertasEmpresaData(ofertas: [], error: true),
          clave: 'err'),
    );
    expect(find.text('No pudimos cargar las ofertas'), findsOneWidget);

    await pumpMp(tester, const Size(393, 852),
        _pantalla(OfertasEmpresaData.empty, clave: 'sin'));
    expect(find.text('Todavía no hay ofertas'), findsOneWidget);
  });
}
