import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';

/// KIT VISUAL COMPARTIDO DE LA TANDA 1 DE CANDIDATO.
///
/// Piezas presentacionales puras: reciben datos por parámetro, no consultan
/// nada y no conocen Supabase. Están pensadas para reutilizarse después en las
/// pantallas productivas, que es el motivo de tenerlas separadas de los
/// mockups en vez de inline.
///
/// Toda la paleta sale de `MpTokens` — el mismo sistema violeta con el que se
/// construyeron las 29 pantallas congeladas de Empresa, así que Candidato y
/// Empresa quedan hablando el mismo idioma sin tocar Empresa.

// ─────────────────────────────────────────────────────────────────────────────
// BREAKPOINTS
// ─────────────────────────────────────────────────────────────────────────────

/// Los tres tamaños de la tanda y cómo se decide la composición.
enum CandFormato { mobile, tablet, desktop }

CandFormato candFormato(double ancho) {
  if (ancho >= 1100) return CandFormato.desktop;
  if (ancho >= 700) return CandFormato.tablet;
  return CandFormato.mobile;
}

// ─────────────────────────────────────────────────────────────────────────────
// NAVEGACIÓN CANÓNICA
// ─────────────────────────────────────────────────────────────────────────────

/// Los cinco destinos. Es la navegación decidida y ya implementada en
/// `main_navigation.dart`, no la de los mockups viejos: ninguna referencia
/// tiene "Red" y todas traen un botón central de publicar que Candidato no usa.
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
  });

  final CandDestino activo;
  final int badgeMensajes;

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
                      fontWeight: d == activo ? FontWeight.w700 : FontWeight.w500,
                      color: d == activo
                          ? MpTokens.primary
                          : MpTokens.lightTextTertiary,
                    ),
                  ),
                ],
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
  });

  final CandDestino activo;
  final int badgeMensajes;
  final double ancho;

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
          const CandTarjetaTip(),
        ],
      ),
    );
  }

  Widget _fila(CandDestino d) {
    final act = d == activo;
    return Container(
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

/// Avatar por iniciales: sin imágenes remotas, el preview funciona sin red.
class CandAvatar extends StatelessWidget {
  const CandAvatar({
    super.key,
    required this.nombre,
    this.tamano = 44,
    this.color,
    this.borde,
  });

  final String nombre;
  final double tamano;
  final Color? color;
  final Color? borde;

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
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: fondo.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: borde != null ? Border.all(color: borde!, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        _iniciales,
        style: TextStyle(
          fontSize: tamano * 0.36,
          fontWeight: FontWeight.w800,
          color: fondo,
        ),
      ),
    );
  }
}

/// Chip de etiqueta.
class CandChip extends StatelessWidget {
  const CandChip(
    this.texto, {
    super.key,
    this.activo = false,
    this.color,
    this.compacto = false,
  });

  final String texto;
  final bool activo;
  final Color? color;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final c = color ?? MpTokens.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 9 : 13,
        vertical: compacto ? 4 : 7,
      ),
      decoration: BoxDecoration(
        color: activo ? c : MpTokens.lightFill,
        borderRadius: BorderRadius.circular(MpTokens.radiusPill),
        border: Border.all(
          color: activo ? c : MpTokens.lightBorderStrong,
        ),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: compacto ? 11 : 13,
          fontWeight: activo ? FontWeight.w700 : FontWeight.w600,
          color: activo ? CupertinoColors.white : MpTokens.lightTextSecondary,
        ),
      ),
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
          Text(
            etiqueta,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: claro
                  ? CupertinoColors.white.withValues(alpha: 0.85)
                  : MpTokens.lightTextSecondary,
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
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: MpTokens.lightCard,
        borderRadius: BorderRadius.circular(MpTokens.radiusLG),
        border: Border.all(color: MpTokens.lightBorder),
      ),
      child: child,
    );
  }
}

/// Aviso violeta tenue: en el sistema significa "esto lo hizo la IA".
class CandTarjetaTip extends StatelessWidget {
  const CandTarjetaTip({super.key, this.texto = 'Completá tu video pitch y duplicá tus vistas.'});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: MpTokens.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(MpTokens.radiusMD),
        border: Border.all(color: MpTokens.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.sparkles, size: 14, color: MpTokens.primary),
              SizedBox(width: 6),
              Text(
                'Tip de Mploya',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: MpTokens.primary,
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
  }
}

/// Encabezado de pantalla para mobile y tablet.
class CandEncabezado extends StatelessWidget {
  const CandEncabezado({
    super.key,
    required this.titulo,
    this.acciones = const [],
    this.subtitulo,
  });

  final String titulo;
  final List<IconData> acciones;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    color: MpTokens.lightText,
                  ),
                ),
                if (subtitulo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitulo!,
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
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: MpTokens.lightFill,
                shape: BoxShape.circle,
              ),
              child: Icon(a, size: 18, color: MpTokens.lightText),
            ),
          ],
        ],
      ),
    );
  }
}

/// Buscador tipo píldora.
class CandBuscador extends StatelessWidget {
  const CandBuscador({super.key, this.placeholder = 'Buscar'});

  final String placeholder;

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
            child: Text(
              placeholder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
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
  });

  final String texto;
  final IconData? icono;
  final bool secundario;
  final double? ancho;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho,
      height: alto,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: secundario ? MpTokens.lightFill : MpTokens.primary,
        borderRadius: BorderRadius.circular(MpTokens.radiusSM),
        border: secundario
            ? Border.all(color: MpTokens.lightBorderStrong)
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(
              icono,
              size: 16,
              color: secundario ? MpTokens.lightText : CupertinoColors.white,
            ),
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
                color: secundario ? MpTokens.lightText : CupertinoColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío honesto, reutilizable en las cinco pantallas.
class CandVacio extends StatelessWidget {
  const CandVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final String? accion;

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
              CandBoton(accion!),
            ],
          ],
        ),
      ),
    );
  }
}
