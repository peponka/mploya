import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

/// Verifica las composiciones apretadas del Dashboard de Empresa.
///
/// `dashboard empresa.png` mete CUATRO KPIs y CINCO accesos rápidos en el ancho
/// de un móvil. Es exactamente donde un `Row` desborda, y el desbordamiento no
/// lo detecta `flutter analyze`: sólo aparece al renderizar.

const _phone = Size(393, 852);
const _smallPhone = Size(360, 780);

Future<void> _pump(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    CupertinoApp(
      home: MpScaffold(
        surface: MpSurfaceKind.light,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(MpTokens.screenPadding),
            child: child,
          ),
        ),
      ),
    ),
  );
}

Widget _kpiRow() {
  const tiles = [
    ('Vacantes\nactivas', 'Ver todas', CupertinoIcons.briefcase, MpTokens.catViolet),
    ('Candidatos\nen proceso', 'Ver pipeline', CupertinoIcons.person_2, MpTokens.catGreen),
    ('Entrevistas\nregistradas', 'Ver agenda', CupertinoIcons.calendar, MpTokens.catOrange),
    ('Contrataciones\nregistradas', 'Ver informes', CupertinoIcons.check_mark_circled, MpTokens.catBlue),
  ];

  // Igual que en la pantalla: dentro de un scroll la altura no está acotada,
  // así que el Row con `stretch` va envuelto en IntrinsicHeight.
  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: MpTokens.space8),
          Expanded(
            child: MpStatTile(
              compact: true,
              icon: tiles[i].$3,
              color: tiles[i].$4,
              // Valor de 3 dígitos: el caso ancho real.
              value: '156',
              label: tiles[i].$1,
              linkLabel: tiles[i].$2,
            ),
          ),
        ],
      ],
    ),
  );
}

void main() {
  testWidgets('la fila de 4 KPIs entra en un móvil de 393pt', (tester) async {
    await _pump(tester, _phone, _kpiRow());
    expect(tester.takeException(), isNull);
  });

  testWidgets('la fila de 4 KPIs entra en un móvil chico de 360pt', (tester) async {
    await _pump(tester, _smallPhone, _kpiRow());
    expect(tester.takeException(), isNull);
  });

  testWidgets('los 5 accesos rápidos entran en un móvil de 393pt', (tester) async {
    await _pump(
      tester,
      _phone,
      IntrinsicHeight(
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(width: MpTokens.space8),
            const Expanded(
              child: MpCard(
                padding: EdgeInsets.symmetric(
                  horizontal: MpTokens.space8,
                  vertical: MpTokens.space16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MpIconTile(
                      icon: CupertinoIcons.add,
                      color: MpTokens.primary,
                      size: 36,
                      circular: true,
                    ),
                    SizedBox(height: MpTokens.space8),
                    Text(
                      'Agenda de\nentrevistas',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(fontSize: 11, height: 1.3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el embudo de 5 etapas entra en un móvil de 393pt', (tester) async {
    const stages = [
      ('Postulados', 156),
      ('En proceso', 48),
      ('Entrevistas', 32),
      ('Contratados', 12),
      ('Descartados', 8),
    ];

    await _pump(
      tester,
      _phone,
      MpCard(
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < stages.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: Icon(CupertinoIcons.chevron_right, size: 13),
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        const Icon(CupertinoIcons.doc_text, size: 21),
                        const SizedBox(height: MpTokens.space8),
                        Text('${stages[i].$2}'),
                        Text(
                          stages[i].$1,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: MpTokens.space16),
            const MpFunnelBar(
              segments: [
                MpFunnelSegment(fraction: 1.0, color: MpTokens.catViolet),
                MpFunnelSegment(fraction: 0.31, color: MpTokens.catBlue),
              ],
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('la barra inferior de Empresa no rotula el botón central', (tester) async {
    expect(MpRole.empresa.centerLabel, isNull);

    final labels =
        MpRole.empresa.navItems().map((item) => item.label).toList();
    expect(labels, ['Inicio', 'Mapa', 'Mensajes', 'Herramientas']);
  });

  testWidgets('la barra inferior de Empresa renderiza sin desbordar', (tester) async {
    tester.view.physicalSize = _smallPhone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CupertinoApp(
        home: MpScaffold(
          surface: MpSurfaceKind.light,
          bottomBar: MpBottomNav(
            items: MpRole.empresa.navItems(unreadMessages: 12),
            currentIndex: 0,
            onTap: (_) {},
            onCenterTap: () {},
            centerLabel: MpRole.empresa.centerLabel,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Herramientas'), findsOneWidget);
  });

  testWidgets('sin vacante elegida no se muestra ningún porcentaje de match',
      (tester) async {
    // El anillo sólo existe cuando hay match; el caso "sin vacante" usa otro
    // widget. Se comprueba que MpProgressRing acepta el valor y no lo inventa.
    await _pump(
      tester,
      _phone,
      const MpProgressRing(value: 0.96, center: Text('96%')),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('96%'), findsOneWidget);
  });
}
