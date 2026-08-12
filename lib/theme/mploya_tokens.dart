import 'package:flutter/widgets.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MPLOYA · TOKENS DE DISEÑO
///
/// FUENTE ÚNICA DE VERDAD:
///   design-reference/FINAL_SCREENS_CODEX/MPLOYA_FINAL_SCREENS_LIMPIO/FINAL_SCREENS
///   (87 PNG)
///
/// Los valores de color NO están estimados a ojo: se extrajeron muestreando los
/// 87 PNG y quedándose, por familia de tono, con el color exacto más frecuente
/// entre píxeles de relleno deliberado (saturación > 0.65, brillo 0.25–0.72,
/// que descarta fotos, gradientes y antialiasing). El `n=` de cada comentario es
/// la cantidad de píxeles muestreados con ese valor exacto en el set completo.
///
/// Este archivo es ADITIVO: no reemplaza a `app_theme.dart` (NexTheme). Ver la
/// nota de DEUDA al final sobre la divergencia entre ambos.
/// ─────────────────────────────────────────────────────────────────────────────
class MpTokens {
  const MpTokens._();

  // ───────────────────────────────────────────────────────────────────────────
  // MARCA
  //
  // Los mockups usan DOS colores de marca con roles distintos, y no son
  // intercambiables:
  //   · NARANJA → superficie de entrada (bienvenida, login, crear cuenta) y el
  //     logotipo. Es el color "mploya.ai" de cara al público.
  //   · VIOLETA → producto ya logueado (candidato, empresa, headhunter). Es el
  //     color de acción dentro de la app.
  // Confundirlos es el error visual más caro de este rediseño.
  // ───────────────────────────────────────────────────────────────────────────

  /// Naranja de marca. Medido: #FE5001 (n=995), toda la familia cae en
  /// #FE4E01–#FE5401 en las 87 pantallas. Altísima consistencia.
  static const Color brandOrange = Color(0xFFFE5001);

  /// El CTA naranja de auth es un degradado vertical. Extremos medidos en
  /// `iniciar sesion.png` / `crear cuenta.png`: ~#FF8A00 arriba → #FE5001 abajo.
  static const Color brandOrangeTop = Color(0xFFFF8A00);
  static const Color brandOrangeBottom = brandOrange;

  /// Violeta de producto. Medido: #4129F0 (n=433) y #4128F0 (n=333) — el mismo
  /// color. Es el color del FAB central, los botones primarios y el bloque hero
  /// del dashboard de headhunter.
  static const Color primary = Color(0xFF4129F0);

  /// Variante profunda para hero llenos y estado :pressed.
  /// Medido en el hero de `headhunter dashboard.png`: #3820D8 / #4028E8.
  static const Color primaryDeep = Color(0xFF3820D8);

  /// Variante clara para tintes, bordes activos y el final del degradado.
  /// Medido en acentos de `perfil de candidato.png`: #6870F0 / #9078E8.
  static const Color primaryLight = Color(0xFF6D5AF5);

  // ───────────────────────────────────────────────────────────────────────────
  // SEMÁNTICOS
  // ───────────────────────────────────────────────────────────────────────────

  /// Verde de éxito sobre superficie clara (texto "USD 120.000 anuales",
  /// checks de plan). Medido: #01813C (n=35).
  static const Color successDeep = Color(0xFF01813C);

  /// Verde de íconos, barras de progreso y donas de dashboard.
  /// Medido en `dashboard empresa.png`: #20B068.
  static const Color success = Color(0xFF20B068);

  /// Azul profundo de enlaces y etiquetas ("Ver todas", "Ver pipeline").
  /// Medido: #0041B3 (n=314).
  static const Color infoDeep = Color(0xFF0041B3);

  /// Azul brillante de íconos y series de gráfico.
  /// Medido en `dashboard empresa.png`: #4070F8.
  static const Color info = Color(0xFF4070F8);

  /// Rojo de error, badges de no leídos y acciones destructivas.
  /// Medido: #FD2E38 (n=46).
  static const Color danger = Color(0xFFFD2E38);

  /// Ámbar premium (coronas, "Más popular", tips).
  /// Medido: #F8AF18 / #F7D005.
  static const Color premium = Color(0xFFF8AF18);
  static const Color premiumBright = Color(0xFFF7D005);

  // ───────────────────────────────────────────────────────────────────────────
  // TINTES DE CATEGORÍA
  //
  // Los stat tiles, los círculos de ícono y los badges de tipo usan una paleta
  // fija. Medidos en `01_Bienvenida_SeleccionRol.png` (círculos de rol) y en los
  // dashboards. Usar SIEMPRE estos, no colores sueltos por pantalla.
  // ───────────────────────────────────────────────────────────────────────────

  /// Rol "Soy Candidato" + categoría naranja.
  static const Color catOrange = brandOrange;

  /// Rol "Candidato Confidencial" (medido: #4860E0) + categoría índigo.
  static const Color catIndigo = Color(0xFF4860E0);

  /// Rol "Soy Empresa" + categoría verde.
  static const Color catGreen = success;

  /// Rol "Soy Headhunter" (medido: #8040D8) + categoría púrpura.
  static const Color catPurple = Color(0xFF8040D8);

  /// Categoría azul (entrevistas, mensajes).
  static const Color catBlue = info;

  /// Categoría violeta = la primaria (vacantes, IA).
  static const Color catViolet = primary;

  // ───────────────────────────────────────────────────────────────────────────
  // NEUTRALES · SUPERFICIE CLARA
  // Usada por: auth, empresa, headhunter, formularios, perfil.
  // ───────────────────────────────────────────────────────────────────────────

  /// Fondo de página. Medido: #F8F8FF (blanco fantasma, levísimo tinte violeta)
  /// — aparece masivamente en `crear vacante.png` y `creditos y planes.png`.
  static const Color lightBg = Color(0xFFF8F8FF);

  /// Superficie de tarjeta: blanco puro. Es el neutral dominante de todas las
  /// pantallas claras (n≈110.000–127.000 por imagen).
  static const Color lightCard = Color(0xFFFFFFFF);

  /// Relleno sutil (inputs en reposo, filas alternas, chips inactivos).
  static const Color lightFill = Color(0xFFF4F4FA);

  /// Borde de tarjeta e input. Medido: #F0F0F8 / #F0F0FF.
  static const Color lightBorder = Color(0xFFEDEDF6);

  /// Borde algo más marcado (divisores, input enfocado en reposo).
  static const Color lightBorderStrong = Color(0xFFE2E2EE);

  /// Texto principal. Los mockups tipografían los títulos en negro real: la
  /// rampa medida es #000000 → #202020 (puro antialiasing sobre blanco).
  /// Se usa un negro apenas desaturado para no vibrar en pantallas OLED.
  static const Color lightText = Color(0xFF0A0A0F);

  /// Texto secundario (subtítulos, descripciones).
  static const Color lightTextSecondary = Color(0xFF5B5B6B);

  /// Texto terciario (timestamps, ayudas, placeholders).
  static const Color lightTextTertiary = Color(0xFF9A9AAC);

  // ───────────────────────────────────────────────────────────────────────────
  // NEUTRALES · SUPERFICIE OSCURA
  // Usada por: feed de video, centro de notificaciones, visor de historias,
  // videollamada. Es oscura POR DISEÑO, no por el tema del sistema.
  // ───────────────────────────────────────────────────────────────────────────

  /// Fondo de página. Medido en `centro de notificaciones.png`: #000810
  /// (n=44.211) — negro azulado, no gris.
  static const Color darkBg = Color(0xFF000810);

  /// Superficie de tarjeta. Medido: #081018 (n=75.294), el neutral dominante.
  static const Color darkCard = Color(0xFF081018);

  /// Superficie elevada (fila resaltada, sheet, chip activo).
  /// Medido: #101820 / #101028.
  static const Color darkElevated = Color(0xFF101820);

  /// Borde sobre oscuro. Medido: #182028.
  static const Color darkBorder = Color(0xFF182028);

  /// Texto principal sobre oscuro.
  static const Color darkText = Color(0xFFF7F8FC);

  /// Texto secundario sobre oscuro.
  static const Color darkTextSecondary = Color(0xFFA3AABD);

  /// Texto terciario sobre oscuro.
  static const Color darkTextTertiary = Color(0xFF6B7386);

  // ───────────────────────────────────────────────────────────────────────────
  // DEGRADADOS
  // ───────────────────────────────────────────────────────────────────────────

  /// CTA primario del producto (botones violeta, FAB central).
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// CTA de auth ("Iniciar sesión", "Crear cuenta"). Degradado VERTICAL.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandOrangeTop, brandOrangeBottom],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Bloque hero lleno (banda de métricas del dashboard de headhunter).
  static const LinearGradient heroGradient = LinearGradient(
    colors: [primaryDeep, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ───────────────────────────────────────────────────────────────────────────
  // RADIOS
  // Medidos sobre los PNG a escala 1x (los mockups son ~853px de ancho ≈ 393pt,
  // factor ≈ 2.17; los valores acá ya están convertidos a puntos lógicos).
  // ───────────────────────────────────────────────────────────────────────────

  /// Chips, badges, avatares cuadrados chicos.
  static const double radiusXS = 8;

  /// Cuadrado de ícono dentro de un stat tile.
  static const double radiusSM = 12;

  /// Inputs, botones rectangulares, logos de empresa.
  static const double radiusMD = 14;

  /// Stat tiles y tarjetas de lista.
  static const double radiusLG = 18;

  /// Tarjetas de sección y paneles.
  static const double radiusXL = 22;

  /// Sheet de auth, tarjetas de rol, modales.
  static const double radiusXXL = 28;

  /// Píldoras, FAB, botones redondeados.
  static const double radiusPill = 999;

  // ───────────────────────────────────────────────────────────────────────────
  // ESPACIADO
  // ───────────────────────────────────────────────────────────────────────────

  static const double space2 = 2;
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;

  /// Margen horizontal de pantalla. Constante en todos los mockups móviles.
  static const double screenPadding = 20;

  /// Alto de la barra inferior de navegación (sin el safe area).
  static const double navBarHeight = 64;

  /// Diámetro del FAB central de la barra inferior. Medido en
  /// `dashboard empresa.png`: es deliberadamente grande y pisa la barra.
  static const double fabSize = 64;

  // ───────────────────────────────────────────────────────────────────────────
  // SOMBRAS
  // En claro las tarjetas llevan borde de 1px + una sombra muy difusa y baja.
  // En oscuro NO llevan sombra: se separan por borde y por color de superficie.
  // ───────────────────────────────────────────────────────────────────────────

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0A0A0F).withValues(alpha: 0.04),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get raisedShadow => [
        BoxShadow(
          color: const Color(0xFF0A0A0F).withValues(alpha: 0.08),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];

  /// Halo de color bajo un CTA lleno. [tint] debe ser el color del botón.
  static List<BoxShadow> glow(Color tint) => [
        BoxShadow(
          color: tint.withValues(alpha: 0.32),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  // ───────────────────────────────────────────────────────────────────────────
  // TIPOGRAFÍA
  //
  // Escala leída de los mockups. Los pesos son deliberadamente altos (w700/w800)
  // y el tracking negativo en los tamaños grandes: eso es lo que da el aspecto
  // "producto premium" del set. El color NO se fija acá — lo inyecta la
  // superficie (ver MpSurfaceStyle) para que el mismo estilo sirva en claro y
  // en oscuro.
  // ───────────────────────────────────────────────────────────────────────────

  /// Titular de bienvenida ("Mutea el papel.").
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.1,
    height: 1.15,
  );

  /// Título de pantalla ("Centro de Notificaciones", "Créditos & Planes").
  static const TextStyle h1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
    height: 1.2,
  );

  /// Título de sección ("Pipeline general", "Actividad reciente").
  static const TextStyle h2 = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.25,
  );

  /// Título de tarjeta o de fila ("Airbnb", "Product Manager Senior").
  static const TextStyle title = TextStyle(
    fontSize: 16.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.3,
  );

  /// Número grande de métrica ("24", "156", "92%").
  static const TextStyle stat = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.3,
    height: 1.1,
  );

  /// Cuerpo de texto.
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.45,
  );

  /// Cuerpo enfatizado.
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.4,
  );

  /// Etiqueta de campo, texto de botón.
  static const TextStyle label = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.3,
  );

  /// Descripción secundaria, timestamps.
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.35,
  );

  /// Etiqueta de nav, texto de chip, badges.
  static const TextStyle micro = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.2,
  );

  /// Antetítulo en mayúsculas ("ESTAMOS CONTRATANDO").
  static const TextStyle eyebrow = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
    height: 1.2,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DEUDA CONOCIDA — leer antes de migrar pantallas
//
// `lib/theme/app_theme.dart` (NexTheme) dice en su comentario "FINAL_SCREENS
// palette", pero sus valores NO coinciden con lo medido en los PNG:
//
//   NexTheme.brandAccent = #5B3DF5   ·  medido: #4129F0
//   NexTheme.brandOrange = #FF6B2C   ·  medido: #FE5001
//   NexTheme.darkBg      = #090C17   ·  medido: #000810
//   NexTheme.success     = #18C58F   ·  medido: #20B068 / #01813C
//
// NexTheme NO se tocó a propósito: lo consumen ~195 archivos y cambiarlo movería
// el color de pantallas que todavía no se revisaron contra su PNG. La migración
// correcta es por pantalla, junto con su rediseño, apuntando a MpTokens.
// ─────────────────────────────────────────────────────────────────────────────
