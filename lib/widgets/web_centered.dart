import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Padding lateral que, en web/escritorio, centra el contenido a [content] px
/// rellenando los costados. En móvil devuelve [mobile]. Útil para envolver
/// listas/formularios pensados para móvil sin reestructurar el árbol.
double webSidePad(BuildContext context, {double content = 600, double mobile = 24}) {
  final w = MediaQuery.of(context).size.width;
  if (kIsWeb && w > 700) {
    final pad = (w - content) / 2;
    return pad > mobile ? pad : mobile;
  }
  return mobile;
}

/// Centra y limita el ancho del contenido en web/escritorio para que las
/// pantallas pensadas para móvil no se estiren a todo lo ancho del navegador.
///
/// En móvil (o ventanas angostas) devuelve el hijo sin cambios.
class WebCentered extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  const WebCentered({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final isWideWeb = kIsWeb && MediaQuery.of(context).size.width > 700;
    if (!isWideWeb) return child;
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
