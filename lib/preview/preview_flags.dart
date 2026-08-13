import 'package:flutter/foundation.dart';

/// PUERTA DE ENTRADA DEL MODO PREVIEW.
///
/// El preview local existe para poder ver y capturar pantallas sin sesión, sin
/// Supabase y sin internet. Es una herramienta de desarrollo: **no puede
/// existir en producción bajo ninguna circunstancia**.
///
/// Por eso la puerta tiene DOS condiciones que deben cumplirse a la vez:
///
///   1. `kDebugMode` — en un build de release es `false` y el compilador de
///      Dart elimina por *tree shaking* todo el código que dependa de él.
///   2. `MPLOYA_PREVIEW=true` — bandera explícita de compilación. Sin ella, ni
///      siquiera un build de debug entra en modo preview.
///
/// La bandera se lee con `const bool.fromEnvironment`, que se resuelve en
/// tiempo de COMPILACIÓN. No hay forma de activarla por URL, por argumento de
/// runtime, por preferencia guardada ni por deep link: si el binario no se
/// compiló con la bandera, la constante es `false` y las ramas de preview
/// desaparecen del binario.
///
/// Comando para levantarlo:
///
///     flutter run -d chrome --dart-define=MPLOYA_PREVIEW=true
///
/// Cualquier duda sobre si algo es preview o producción se resuelve mirando si
/// pasa por esta constante.
const bool kMployaPreviewFlag = bool.fromEnvironment('MPLOYA_PREVIEW');

/// `true` sólo en debug **y** con la bandera. Es la única condición que debe
/// consultarse; nunca `kMployaPreviewFlag` por su cuenta.
const bool kPreviewMode = kDebugMode && kMployaPreviewFlag;
