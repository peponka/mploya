/// Proveedor de estado para el modo de tema (claro/oscuro/sistema).
///
/// Permite cambiar el tema globalmente desde cualquier parte de la app
/// usando Riverpod. Por defecto usa [ThemeMode.system].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notificador que gestiona el modo de tema activo.
///
/// Expone métodos para cambiar entre claro, oscuro y sistema.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  /// Cambia al tema claro.
  void setLight() => state = ThemeMode.light;

  /// Cambia al tema oscuro.
  void setDark() => state = ThemeMode.dark;

  /// Usa el tema del sistema operativo.
  void setSystem() => state = ThemeMode.system;

  /// Establece un modo de tema específico.
  void setMode(ThemeMode mode) => state = mode;
}

/// Provider global para el modo de tema.
///
/// Uso:
/// ```dart
/// final themeMode = ref.watch(themeModeProvider);
/// ref.read(themeModeProvider.notifier).setDark();
/// ```
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);
