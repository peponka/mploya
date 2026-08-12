/// ─────────────────────────────────────────────────────────────────────────────
/// SISTEMA DE DISEÑO DE MPLOYA
///
/// Derivado de las 87 pantallas aprobadas en:
///   design-reference/FINAL_SCREENS_CODEX/MPLOYA_FINAL_SCREENS_LIMPIO/FINAL_SCREENS
///
/// Uso:
///   import '../widgets/ds/mploya_ds.dart';
///
/// Reglas que sostienen la coherencia del set — romperlas es lo que hace que
/// una pantalla "no se vea Mploya":
///
///   1. El color de acción sale de la superficie, no se escribe a mano.
///      Naranja SOLO en `MpSurfaceKind.auth`. Violeta en todo el producto.
///
///   2. Las pantallas de video (feed, historias, notificaciones, llamada) son
///      oscuras SIEMPRE, sin importar el tema del sistema. Se declaran con
///      `MpSurfaceKind.dark`, no con `MediaQuery.platformBrightnessOf`.
///
///   3. El violeta sobre fondo tenue significa "esto lo hizo la IA"
///      (ver [MpAiCard]). No usarlo como adorno.
///
///   4. La barra inferior tiene 4 pestañas + acción central. Nunca 5 pestañas.
///
///   5. Nada de colores literales en las pantallas: todo sale de [MpTokens] o
///      de `context.mp`.
/// ─────────────────────────────────────────────────────────────────────────────
library;

export '../../theme/mploya_tokens.dart';
export 'mp_brand.dart';
export 'mp_button.dart';
export 'mp_card.dart';
export 'mp_chart.dart';
export 'mp_chip.dart';
export 'mp_feedback.dart';
export 'mp_input.dart';
export 'mp_nav.dart';
export 'mp_roles.dart';
export 'mp_surface.dart';
