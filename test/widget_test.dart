import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/explore_screen.dart';

void main() {
  testWidgets('ExploreScreen render test', (WidgetTester tester) async {
    // Simular pantalla de desktop
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const CupertinoApp(
        home: ExploreScreen(),
      ),
    );

    // Permitir animaciones y renders iniciales
    await tester.pump();
  });
}
