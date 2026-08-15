import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// KIT VISUAL PRODUCTIVO DE CANDIDATO — TANDA 1
///
/// Es la versión de producción del kit aprobado en `lib/preview/candidato/
/// cand_kit.dart`. Mismos tokens, mismas medidas, mismas formas; lo que cambia
/// es que estas piezas SÍ reciben callbacks, aceptan avatares reales y saben
/// dibujar carga, vacío y error.
///
/// Reglas que cumple todo lo de esta carpeta:
///  · recibe datos y callbacks por parámetro;
///  · no consulta Supabase ni ningún servicio;
///  · no conoce fixtures ni importa `lib/preview/`;
///  · no inventa usuarios, vacantes, métricas ni mensajes.
///
/// La paleta sale entera de `MpTokens` (violeta #4129F0), que es el sistema con
/// el que se midieron los 87 PNG de FINAL_SCREENS.
/// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// BREAKPOINTS
// ─────────────────────────────────────────────────────────────────────────────

/// Los tres formatos de la tanda. Son composiciones distintas, no una sola
/// estirada: mobile con barra inferior, tablet a dos columnas, desktop con
/// columna lateral persistente.
enum CandFormato { mobile, tablet, desktop }

CandFormato candFormato(double ancho) {
  if (ancho >= 1100) return CandFormato.desktop;
  if (ancho >= 700) return CandFormato.tablet;
  return CandFormato.mobile;
}

CandFormato candFormatoDe(BuildContext context) =>
    candFormato(MediaQuery.sizeOf(context).width);

/// Aire sobre el encabezado.
///
/// En un dispositivo real lo manda el notch; sin safe area (capturas y tests)
/// se usa el valor de la composición aprobada, que reserva 46 px para la barra
/// de estado. Así la pantalla productiva y el mockup arrancan a la misma altura.
double candTopInset(BuildContext context) {
  final top = MediaQuery.paddingOf(context).top;
  return top > 0 ? top + 8 : 46;
}

extension CandFormatoX on CandFormato {
  bool get esMobile => this == CandFormato.mobile;
  bool get esTablet => this == CandFormato.tablet;
  bool get esDesktop => this == CandFormato.desktop;
  bool get esAncho => this != CandFormato.mobile;
}

// ─────────────────────────────────────────────────────────────────────────────
// NAVEGACIÓN CANÓNICA
//
// Los cinco destinos ya implementados en `lib/navigation/main_navigation.dart`.
// Estas dos piezas son la representación visual aprobada de esa misma barra;
// el shell productivo es quien decide cuándo mostrarlas.
// ─────────────────────────────────────────────────────────────────────────────

enum CandDestino {
  inicio('Inicio', CupertinoIcons.house_fill, CupertinoIcons.house),
  vacantes('Vacantes', CupertinoIcons.briefcase_fill, CupertinoIcons.briefcase),
  red('Red', CupertinoIcons.person_2_fill, CupertinoIcons.person_2),
  mensajes(
    'Mensajes',
    CupertinoIcons.chat_bubble_2_fill,
    CupertinoIcons.chat_bubble_2,
  ),
  perfil('Perfil', CupertinoIcons.person_fill, CupertinoIcons.person);

  const CandDestino(this.etiqueta, this.iconoActivo, this.icono);
  final String etiqueta;
  final IconData iconoActivo;
  final IconData icono;
}

/// Barra inferior de mobile y tablet.
class CandBarraInferior extends StatelessWidget {
  const CandBarraInferior({
    super.key,
    required this.activo,
    this.badgeMensajes = 0,
    this.onDestino,
  });

  final CandDestino activo;
  final int badgeMensajes;
  final ValueChanged<CandDestino>? onDestino;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        border: Border(top: BorderSide(color: MpTokens.lightBorder)),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Row(
        children: [
          for (final d in CandDestino.values)
            Expanded(
              child: GestureDetector(
                onTap: onDestino == null ? null : () => onDestino!(d),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _icono(d),
                    const SizedBox(height: 4),
                    Text(
                      d.etiqueta,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        fontWeight:
                            d == activo ? FontWeight.w700 : FontWeight.w500,
                        color: d == activo
                            ? MpTokens.primary
                            : MpTokens.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _icono(CandDestino d) {
    final activoEste = d == activo;
    final icono = Icon(
      activoEste ? d.iconoActivo : d.icono,
      size: 23,
      color: activoEste ? MpTokens.primary : MpTokens.lightTextTertiary,
    );
    if (d != CandDestino.mensajes || badgeMensajes <= 0) return icono;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icono,
        Positioned(
          right: -6,
          top: -3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: MpTokens.danger,
              borderRadius: BorderRadius.circular(MpTokens.radiusPill),
            ),
            child: Text(
              '$badgeMensajes',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Barra lateral de desktop. Sustituye a la inferior a partir de 1100 px.
class CandSidebar extends StatelessWidget {
  const CandSidebar({
    super.key,
    required this.activo,
    this.badgeMensajes = 0,
    this.ancho = 232,
    this.onDestino,
    this.tip,
  });

  final CandDestino activo;
  final int badgeMensajes;
  final double ancho;
  final ValueChanged<CandDestino>? onDestino;

  /// Tip al pie. Sin texto, no se dibuja: no hay tip de relleno.
  final String? tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho,
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        border: Border(right: BorderSide(color: MpTokens.lightBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 28),
            child: CandLogotipo(),
          ),
          for (final d in CandDestino.values) ...[
            _fila(d),
            const SizedBox(height: 4),
          ],
          const Spacer(),
          if (tip != null && tip!.isNotEmpty) CandTarjetaTip(texto: tip!),
        ],
      ),
    );
  }

  Widget _fila(CandDestino d) {
    final act = d == activo;
    return GestureDetector(
      onTap: onDestino == null ? null : () => onDestino!(d),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: act ? MpTokens.primary.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(MpTokens.radiusSM),
        ),
        child: Row(
          children: [
            Icon(
              act ? d.iconoActivo : d.icono,
              size: 20,
              color: act ? MpTokens.primary : MpTokens.lightTextSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              d.etiqueta,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: act ? FontWeight.w700 : FontWeight.w500,
                color: act ? MpTokens.primary : MpTokens.lightText,
              ),
            ),
            if (d == CandDestino.mensajes && badgeMensajes > 0) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: MpTokens.danger,
                  borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                ),
                child: Text(
                  '$badgeMensajes',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIEZAS BÁSICAS
// ─────────────────────────────────────────────────────────────────────────────

class CandLogotipo extends StatelessWidget {
  const CandLogotipo({super.key, this.claro = false});

  final bool claro;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MpTokens.primary, MpTokens.primaryLight],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Text(
            'm',
            style: TextStyle(
              fontSize: 17,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: CupertinoColors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'mploya',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: claro ? CupertinoColors.white : MpTokens.lightText,
          ),
        ),
      ],
    );
  }
}

/// Avatar de persona o empresa.
///
/// Si hay foto real la usa; si no, cae en las iniciales sobre color, que es lo
/// aprobado en la tanda. Nunca inventa una foto: sin `imagenUrl` no hay imagen.
class CandAvatar extends StatelessWidget {
  const CandAvatar({
    super.key,
    required this.nombre,
    this.imagenUrl,
    this.tamano = 44,
    this.color,
    this.borde,
    this.onTap,
  });

  final String nombre;
  final String? imagenUrl;
  final double tamano;
  final Color? color;
  final Color? borde;
  final VoidCallback? onTap;

  static const _paleta = [
    MpTokens.primary,
    MpTokens.catPurple,
    MpTokens.info,
    MpTokens.success,
    MpTokens.catIndigo,
  ];

  String get _iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fondo = color ?? _paleta[nombre.length % _paleta.length];
    final url = imagenUrl?.trim();
    final tieneFoto = url != null && url.isNotEmpty;

    final avatar = Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: fondo.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: borde != null ? Border.all(color: borde!, width: 2) : null,
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: tieneFoto
          ? CachedNetworkImage(
              imageUrl: url,
              width: tamano,
              height: tamano,
              fit: BoxFit.cover,
              // Sin foto disponible se vuelve a las iniciales, no a un ícono
              // genérico: la inicial sigue diciendo de quién es la tarjeta.
              errorWidget: (_, __, ___) => _Iniciales(
                texto: _iniciales,
                tamano: tamano,
                color: fondo,
              ),
              placeholder: (_, __) => _Iniciales(
                texto: _iniciales,
                tamano: tamano,
                color: fondo,
              ),
            )
          : _Iniciales(texto: _iniciales, tamano: tamano, color: fondo),
    );

    if (onTap == null) return avatar;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: avatar,
    );
  }
}

class _Iniciales extends StatelessWidget {
  const _Iniciales({
    required this.texto,
    required this.tamano,
    required this.color,
  });

  final String texto;
  final double tamano;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        texto,
        style: TextStyle(
          fontSize: tamano * 0.36,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

/// Chip de etiqueta o de filtro. Con `onTap` se vuelve seleccionable.
class CandChip extends StatelessWidget {
  const CandChip(
    this.texto, {
    super.key,
    this.activo = false,
    this.color,
    this.compacto = false,
    this.onTap,
  });

  final String texto;
  final bool activo;
  final Color? color;
  final bool compacto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = color ?? MpTokens.primary;
    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 9 : 13,
        vertical: compacto ? 4 : 7,
      ),
      decoration: BoxDecoration(
        color: activo ? c : MpTokens.lightFill,
        borderRadius: BorderRadius.circular(MpTokens.radiusPill),
        border: Border.all(color: activo ? c : MpTokens.lightBorderStrong),
      ),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compacto ? 11 : 13,
          fontWeight: activo ? FontWeight.w700 : FontWeight.w600,
          color: activo ? CupertinoColors.white : MpTokens.lightTextSecondary,
        ),
      ),
    );

    if (onTap == null) return chip;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: chip,
    );
  }
}

/// Anillo de porcentaje de match.
class CandMatch extends StatelessWidget {
  const CandMatch({
    super.key,
    required this.valor,
    this.tamano = 46,
    this.etiqueta = 'Match IA',
    this.claro = false,
  });

  final int valor;
  final double tamano;
  final String etiqueta;
  final bool claro;

  Color get _color => valor >= 85
      ? MpTokens.success
      : (valor >= 70 ? MpTokens.primary : MpTokens.lightTextTertiary);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: tamano,
          height: tamano,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: tamano,
                height: tamano,
                child: CustomPaint(
                  painter: _AnilloPainter(valor / 100, _color),
                ),
              ),
              Text(
                '$valor%',
                style: TextStyle(
                  fontSize: tamano * 0.28,
                  fontWeight: FontWeight.w800,
                  color: claro ? CupertinoColors.white : MpTokens.lightText,
                ),
              ),
            ],
          ),
        ),
        if (etiqueta.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: claro
                    ? CupertinoColors.white.withValues(alpha: 0.85)
                    : MpTokens.lightTextSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AnilloPainter extends CustomPainter {
  _AnilloPainter(this.progreso, this.color);
  final double progreso;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = size.width / 2 - 3;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = color.withValues(alpha: 0.16);
    final activo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(centro, radio, base);
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: radio),
      -1.5708,
      6.2832 * progreso,
      false,
      activo,
    );
  }

  @override
  bool shouldRepaint(_AnilloPainter old) =>
      old.progreso != progreso || old.color != color;
}

/// Tarjeta blanca estándar.
class CandTarjeta extends StatelessWidget {
  const CandTarjeta({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.onTap,
    this.resaltada = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  /// Estado seleccionado de los layouts maestro-detalle.
  final bool resaltada;

  @override
  Widget build(BuildContext context) {
    final tarjeta = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: MpTokens.lightCard,
        borderRadius: BorderRadius.circular(MpTokens.radiusLG),
        border: Border.all(
          color: resaltada ? MpTokens.primary : MpTokens.lightBorder,
          width: resaltada ? 1.5 : 1,
        ),
      ),
      child: child,
    );

    if (onTap == null) return tarjeta;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: tarjeta,
    );
  }
}

/// Aviso violeta tenue. En el sistema significa "esto lo sugirió la IA".
class CandTarjetaTip extends StatelessWidget {
  const CandTarjetaTip({
    super.key,
    required this.texto,
    this.titulo = 'Tip de Mploya',
    this.onTap,
  });

  final String texto;
  final String titulo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tarjeta = Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: MpTokens.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(MpTokens.radiusMD),
        border: Border.all(color: MpTokens.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.sparkles, size: 14, color: MpTokens.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: MpTokens.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: MpTokens.lightTextSecondary,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return tarjeta;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: tarjeta,
    );
  }
}

/// Acción circular del encabezado.
class CandAccion {
  const CandAccion({required this.icono, this.onTap, this.badge = 0});

  final IconData icono;
  final VoidCallback? onTap;
  final int badge;
}

/// Encabezado de pantalla para mobile y tablet.
class CandEncabezado extends StatelessWidget {
  const CandEncabezado({
    super.key,
    required this.titulo,
    this.acciones = const [],
    this.subtitulo,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 12),
  });

  final String titulo;
  final List<CandAccion> acciones;
  final String? subtitulo;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    color: MpTokens.lightText,
                  ),
                ),
                if (subtitulo != null && subtitulo!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitulo!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: MpTokens.lightTextTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final a in acciones) ...[
            const SizedBox(width: 8),
            _BotonAccion(accion: a),
          ],
        ],
      ),
    );
  }
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({required this.accion});
  final CandAccion accion;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: accion.onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: MpTokens.lightFill,
              shape: BoxShape.circle,
            ),
            child: Icon(accion.icono, size: 18, color: MpTokens.lightText),
          ),
          if (accion.badge > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: MpTokens.danger,
                  borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                ),
                child: Text(
                  '${accion.badge}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Buscador tipo píldora. En producción escribe de verdad.
class CandBuscador extends StatelessWidget {
  const CandBuscador({
    super.key,
    this.placeholder = 'Buscar',
    this.controller,
    this.onChanged,
    this.onTap,
    this.soloLectura = false,
  });

  final String placeholder;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool soloLectura;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: MpTokens.lightFill,
        borderRadius: BorderRadius.circular(MpTokens.radiusPill),
        border: Border.all(color: MpTokens.lightBorder),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.search,
            size: 17,
            color: MpTokens.lightTextTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              onChanged: onChanged,
              onTap: onTap,
              readOnly: soloLectura,
              placeholder: placeholder,
              padding: EdgeInsets.zero,
              decoration: const BoxDecoration(),
              maxLines: 1,
              style: const TextStyle(fontSize: 14, color: MpTokens.lightText),
              placeholderStyle: const TextStyle(
                fontSize: 14,
                color: MpTokens.lightTextTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón principal.
class CandBoton extends StatelessWidget {
  const CandBoton(
    this.texto, {
    super.key,
    this.icono,
    this.secundario = false,
    this.ancho,
    this.alto = 44,
    this.onTap,
    this.cargando = false,
    this.deshabilitado = false,
  });

  final String texto;
  final IconData? icono;
  final bool secundario;
  final double? ancho;
  final double alto;
  final VoidCallback? onTap;
  final bool cargando;
  final bool deshabilitado;

  @override
  Widget build(BuildContext context) {
    final inactivo = deshabilitado || cargando;
    final frente = secundario ? MpTokens.lightText : CupertinoColors.white;

    final boton = Opacity(
      opacity: inactivo ? 0.55 : 1,
      child: Container(
        width: ancho,
        height: alto,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: secundario ? MpTokens.lightFill : MpTokens.primary,
          borderRadius: BorderRadius.circular(MpTokens.radiusSM),
          border:
              secundario ? Border.all(color: MpTokens.lightBorderStrong) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cargando) ...[
              SizedBox(
                width: 15,
                height: 15,
                child: CupertinoActivityIndicator(color: frente, radius: 7),
              ),
              const SizedBox(width: 7),
            ] else if (icono != null) ...[
              Icon(icono, size: 16, color: frente),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: frente,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null || inactivo) return boton;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: boton,
    );
  }
}

/// Título de sección.
class CandTitulo extends StatelessWidget {
  const CandTitulo(this.texto, {super.key, this.tamano = 15});

  final String texto;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: tamano,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: MpTokens.lightText,
      ),
    );
  }
}

/// Título grande de las cabeceras de desktop.
class CandTituloDesktop extends StatelessWidget {
  const CandTituloDesktop(this.texto, {super.key, this.subtitulo});

  final String texto;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: MpTokens.lightText,
          ),
        ),
        if (subtitulo != null && subtitulo!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            subtitulo!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: MpTokens.lightTextTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Separador de 1 px. `Divider` es de Material y este kit es Cupertino.
class CandSeparador extends StatelessWidget {
  const CandSeparador({super.key, this.margen = EdgeInsets.zero});

  final EdgeInsets margen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margen,
      child: Container(height: 1, color: MpTokens.lightBorder),
    );
  }
}

/// Fila de chips horizontal, el selector de secciones de la tanda.
class CandFilaChips extends StatelessWidget {
  const CandFilaChips({
    super.key,
    required this.children,
    this.padding = 20,
    this.alto = 36,
  });

  final List<Widget> children;
  final double padding;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alto,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: padding),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS: VACÍO, ERROR, CARGA
//
// Las tres pantallas del sistema. Un estado vacío honesto es preferible a un
// dato inventado: si la consulta no trajo nada, se dice.
// ─────────────────────────────────────────────────────────────────────────────

class CandVacio extends StatelessWidget {
  const CandVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.accion,
    this.onAccion,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final String? accion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: MpTokens.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(MpTokens.radiusXXL),
              ),
              child: Icon(icono, size: 32, color: MpTokens.primary),
            ),
            const SizedBox(height: 18),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: MpTokens.lightText,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: MpTokens.lightTextTertiary,
              ),
            ),
            if (accion != null) ...[
              const SizedBox(height: 18),
              CandBoton(accion!, onTap: onAccion),
            ],
          ],
        ),
      ),
    );
  }
}

class CandError extends StatelessWidget {
  const CandError({
    super.key,
    required this.titulo,
    required this.detalle,
    this.onReintentar,
  });

  final String titulo;
  final String detalle;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: MpTokens.danger.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(MpTokens.radiusXXL),
              ),
              child: const Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 30,
                color: MpTokens.danger,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: MpTokens.lightText,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: MpTokens.lightTextTertiary,
              ),
            ),
            if (onReintentar != null) ...[
              const SizedBox(height: 18),
              CandBoton(
                'Reintentar',
                icono: CupertinoIcons.refresh,
                onTap: onReintentar,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bloque gris de carga. Se usa para armar los esqueletos de cada pantalla.
class CandSkeleton extends StatelessWidget {
  const CandSkeleton({
    super.key,
    this.ancho,
    this.alto = 14,
    this.radio = 8,
  });

  final double? ancho;
  final double alto;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho,
      height: alto,
      decoration: BoxDecoration(
        color: MpTokens.lightBorderStrong.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(radio),
      ),
    );
  }
}

/// Esqueleto de una lista de tarjetas, el patrón de carga de la tanda.
class CandCargandoLista extends StatelessWidget {
  const CandCargandoLista({
    super.key,
    this.cantidad = 3,
    this.padding = const EdgeInsets.all(20),
  });

  final int cantidad;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cantidad,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => CandTarjeta(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                CandSkeleton(ancho: 42, alto: 42, radio: 21),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CandSkeleton(ancho: 150, alto: 15),
                      SizedBox(height: 7),
                      CandSkeleton(ancho: 100, alto: 12),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            CandSkeleton(alto: 12),
            SizedBox(height: 8),
            CandSkeleton(ancho: 180, alto: 12),
          ],
        ),
      ),
    );
  }
}
