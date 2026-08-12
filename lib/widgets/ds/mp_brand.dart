import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'mp_surface.dart';

/// Los mockups usan DOS logotipos y no son intercambiables:
///
///   [MpWordmarkStyle.dotAi]  "mploya" oscuro + ".ai" naranja
///                            → pantallas de entrada (bienvenida, login, alta)
///
///   [MpWordmarkStyle.product] "M" violeta + "ploya" oscuro
///                            → encabezados dentro del producto
enum MpWordmarkStyle { dotAi, product }

class MpWordmark extends StatelessWidget {
  final MpWordmarkStyle style;
  final double fontSize;

  /// Fuerza texto claro (barra lateral oscura del escritorio).
  final bool onDark;

  const MpWordmark({
    super.key,
    this.style = MpWordmarkStyle.product,
    this.fontSize = 26,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;
    final base = onDark ? MpTokens.darkText : s.text;

    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2,
      height: 1.1,
    );

    return switch (style) {
      MpWordmarkStyle.dotAi => Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'mploya',
                style: textStyle.copyWith(color: base),
              ),
              TextSpan(
                text: '.ai',
                style: textStyle.copyWith(color: MpTokens.brandOrange),
              ),
            ],
          ),
        ),
      MpWordmarkStyle.product => Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'M',
                style: textStyle.copyWith(color: MpTokens.primary),
              ),
              TextSpan(
                text: 'ploya',
                style: textStyle.copyWith(color: base),
              ),
            ],
          ),
        ),
    };
  }
}

/// Isotipo: cuadrado naranja redondeado con la "m" y el triángulo de play.
/// El play es lo que carga el concepto del producto ("Dale Play a tu carrera"),
/// así que se dibuja, no se sustituye por un ícono cualquiera.
class MpLogoMark extends StatelessWidget {
  final double size;

  const MpLogoMark({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: MpTokens.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.235),
        boxShadow: MpTokens.glow(MpTokens.brandOrange),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(right: size * 0.08),
            child: Text(
              'm',
              style: TextStyle(
                fontSize: size * 0.62,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFFFFFF),
                height: 1,
                letterSpacing: -2,
              ),
            ),
          ),
          Positioned(
            right: size * 0.19,
            bottom: size * 0.27,
            child: Icon(
              CupertinoIcons.play_fill,
              size: size * 0.2,
              color: const Color(0xFFFFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuadrado de logo de empresa con monograma.
/// → "TP", "N", "G", "H", "LG" en `headhunter clientes.png`.
class MpCompanyLogo extends StatelessWidget {
  final String name;
  final Color color;
  final double size;

  /// Imagen real; si es nula se dibuja el monograma.
  final ImageProvider? image;

  const MpCompanyLogo({
    super.key,
    required this.name,
    required this.color,
    this.size = 56,
    this.image,
  });

  /// Iniciales: dos letras si el nombre es CamelCase o tiene dos palabras.
  String get _monogram {
    final clean = name.trim();
    if (clean.isEmpty) return '?';

    final words = clean.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }

    // "TechPro" → "TP", "NovaSoft" → "NS"
    final caps = RegExp(r'[A-Z]').allMatches(clean).toList();
    if (caps.length >= 2) {
      return (clean[caps[0].start] + clean[caps[1].start]).toUpperCase();
    }
    return clean[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.28),
        image: image == null
            ? null
            : DecorationImage(image: image!, fit: BoxFit.cover),
      ),
      child: image != null
          ? null
          : Center(
              child: Text(
                _monogram,
                style: TextStyle(
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFFFFFF),
                  letterSpacing: -0.5,
                ),
              ),
            ),
    );
  }
}

/// Avatar circular con anillo de acento y punto de conexión opcionales.
class MpAvatar extends StatelessWidget {
  final ImageProvider? image;
  final String? name;
  final double size;

  /// Anillo violeta alrededor (perfil propio, historias sin ver).
  final bool ring;

  /// Punto verde de "en línea" abajo a la derecha.
  final bool online;

  const MpAvatar({
    super.key,
    this.image,
    this.name,
    this.size = 44,
    this.ring = false,
    this.online = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.mp;

    Widget avatar = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: s.fill,
        shape: BoxShape.circle,
        image: image == null
            ? null
            : DecorationImage(image: image!, fit: BoxFit.cover),
      ),
      child: image != null
          ? null
          : Center(
              child: Text(
                (name?.trim().isNotEmpty ?? false)
                    ? name!.trim()[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w700,
                  color: s.textSecondary,
                ),
              ),
            ),
    );

    if (ring) {
      avatar = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: s.accent, width: 2),
        ),
        child: avatar,
      );
    }

    if (!online) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: size * 0.26,
            height: size * 0.26,
            decoration: BoxDecoration(
              color: MpTokens.success,
              shape: BoxShape.circle,
              border: Border.all(color: s.card, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sello de verificado junto a un nombre.
class MpVerifiedBadge extends StatelessWidget {
  final double size;
  final Color? color;

  const MpVerifiedBadge({super.key, this.size = 15, this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      CupertinoIcons.checkmark_seal_fill,
      size: size,
      color: color ?? MpTokens.primary,
    );
  }
}
