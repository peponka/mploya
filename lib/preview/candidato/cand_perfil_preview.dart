import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'cand_datos_preview.dart';
import 'cand_kit.dart';

/// PERFIL — composición visual de la Tanda 1.
///
/// Referencia: `perfil de candidato.png` (set CODEX). De ahí vienen la portada
/// con avatar montado, la fila de métricas, el bloque de video pitch y las
/// secciones de experiencia y skills.
///
/// Agregados de esta tanda, que la referencia no tiene porque son decisiones
/// posteriores: los accesos a **Mis Herramientas** y **Guardados** —hasta ahora
/// inalcanzables para el candidato— junto a Editar y Configuración.
///
/// La variante CONFIDENCIAL se muestra dentro de la misma composición, como
/// tarjeta de estado, para no gastar tres imágenes más.
class CandPerfilPreview extends StatelessWidget {
  const CandPerfilPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final formato = candFormato(MediaQuery.of(context).size.width);
    return switch (formato) {
      CandFormato.desktop => const _Desktop(),
      CandFormato.tablet => const _Tablet(),
      CandFormato.mobile => const _Mobile(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE 390 × 844
// ─────────────────────────────────────────────────────────────────────────────

class _Mobile extends StatelessWidget {
  const _Mobile();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MpTokens.lightBg,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: const [
                _Portada(),
                _Identidad(),
                SizedBox(height: 14),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _Metricas(),
                ),
                SizedBox(height: 14),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _AccionesPrincipales(),
                ),
                SizedBox(height: 14),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _VideoPitch(),
                ),
                SizedBox(height: 14),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _Accesos(),
                ),
                SizedBox(height: 14),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _Sobre(),
                ),
                SizedBox(height: 14),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _Experiencia(),
                ),
                SizedBox(height: 14),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _Confidencial(),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
          const CandBarraInferior(activo: CandDestino.perfil, badgeMensajes: 3),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET 820 × 1180 — dos columnas bajo la portada
// ─────────────────────────────────────────────────────────────────────────────

class _Tablet extends StatelessWidget {
  const _Tablet();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MpTokens.lightBg,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: const [
                _Portada(),
                _Identidad(),
                SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _Metricas(),
                            SizedBox(height: 14),
                            _VideoPitch(),
                            SizedBox(height: 14),
                            _Sobre(),
                            SizedBox(height: 14),
                            _Experiencia(),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            _AccionesPrincipales(vertical: true),
                            SizedBox(height: 14),
                            _Accesos(),
                            SizedBox(height: 14),
                            _Confidencial(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18),
              ],
            ),
          ),
          const CandBarraInferior(activo: CandDestino.perfil, badgeMensajes: 3),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP 1440 × 900 — sidebar + ancho máximo + dos columnas
// ─────────────────────────────────────────────────────────────────────────────

class _Desktop extends StatelessWidget {
  const _Desktop();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MpTokens.lightBg,
      child: Row(
        children: [
          const CandSidebar(activo: CandDestino.perfil, badgeMensajes: 3),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Center(
                  // Ancho máximo premium: en 1440 el contenido no se estira de
                  // borde a borde, se centra en una columna legible.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1060),
                    child: Column(
                      children: const [
                        _Portada(alto: 150),
                        _Identidad(ancho: true),
                        SizedBox(height: 18),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 28),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  children: [
                                    _Metricas(),
                                    SizedBox(height: 14),
                                    _VideoPitch(),
                                    SizedBox(height: 14),
                                    _Sobre(),
                                    SizedBox(height: 14),
                                    _Experiencia(),
                                  ],
                                ),
                              ),
                              SizedBox(width: 18),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    _AccionesPrincipales(vertical: true),
                                    SizedBox(height: 14),
                                    _Accesos(),
                                    SizedBox(height: 14),
                                    // Sin `CandTarjetaTip` acá: el sidebar ya
                                    // lo muestra al pie y quedaba repetido dos
                                    // veces en la misma pantalla.
                                    _Confidencial(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIEZAS
// ─────────────────────────────────────────────────────────────────────────────

class _Portada extends StatelessWidget {
  const _Portada({this.alto = 118});
  final double alto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alto,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MpTokens.primary, Color(0xFF6E3BE8), MpTokens.primaryLight],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 16,
              top: 46,
              child: Row(
                children: [
                  _redondo(CupertinoIcons.share),
                  const SizedBox(width: 8),
                  _redondo(CupertinoIcons.gear_alt_fill),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _redondo(IconData i) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
      child: Icon(i, size: 16, color: CupertinoColors.white),
    );
  }
}

class _Identidad extends StatelessWidget {
  const _Identidad({this.ancho = false});
  final bool ancho;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -34),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ancho ? 28 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: CupertinoColors.white,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(3),
              child: const CandAvatar(nombre: 'Renata Ferreyra', tamano: 74),
            ),
            const SizedBox(height: 10),
            Row(
              children: const [
                Flexible(
                  child: Text(
                    'Renata Ferreyra',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: MpTokens.lightText,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Icon(
                  CupertinoIcons.checkmark_seal_fill,
                  size: 17,
                  color: MpTokens.info,
                ),
                SizedBox(width: 8),
                CandChip('Abierta a ofertas', compacto: true, activo: true),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              candYo.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: MpTokens.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(
                  CupertinoIcons.location_solid,
                  size: 13,
                  color: MpTokens.lightTextTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  candYo.ciudad,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: MpTokens.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metricas extends StatelessWidget {
  const _Metricas();

  @override
  Widget build(BuildContext context) {
    return CandTarjeta(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          for (final (valor, etiqueta) in candMetricas)
            Expanded(
              child: Column(
                children: [
                  Text(
                    valor,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: MpTokens.lightText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    etiqueta,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: MpTokens.lightTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AccionesPrincipales extends StatelessWidget {
  const _AccionesPrincipales({this.vertical = false});
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return const Column(
        children: [
          CandBoton(
            'Editar perfil',
            icono: CupertinoIcons.pencil,
            ancho: double.infinity,
          ),
          SizedBox(height: 9),
          CandBoton(
            'Configuración',
            icono: CupertinoIcons.gear_alt_fill,
            secundario: true,
            ancho: double.infinity,
          ),
        ],
      );
    }
    return const Row(
      children: [
        Expanded(child: CandBoton('Editar perfil', icono: CupertinoIcons.pencil)),
        SizedBox(width: 10),
        Expanded(
          child: CandBoton(
            'Configuración',
            icono: CupertinoIcons.gear_alt_fill,
            secundario: true,
          ),
        ),
      ],
    );
  }
}

class _VideoPitch extends StatelessWidget {
  const _VideoPitch();

  @override
  Widget build(BuildContext context) {
    return CandTarjeta(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MpTokens.radiusLG),
        child: SizedBox(
          height: 168,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1B1436), Color(0xFF3A2680)],
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: CupertinoColors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CupertinoColors.white.withValues(alpha: 0.55),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.play_fill,
                      size: 24,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
                const Positioned(
                  left: 14,
                  top: 13,
                  child: CandChip('Video pitch', compacto: true, activo: true),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 13,
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tu presentación de 30 segundos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(MpTokens.radiusPill),
                        ),
                        child: const Text(
                          'Regrabar',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mis Herramientas y Guardados: los dos accesos que hasta esta tanda no
/// existían en ninguna parte de la app para el candidato.
class _Accesos extends StatelessWidget {
  const _Accesos();

  @override
  Widget build(BuildContext context) {
    return CandTarjeta(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          _fila(
            CupertinoIcons.wrench_fill,
            'Mis Herramientas',
            'CV, referidos, impulsar perfil',
          ),
          const _Separador(),
          _fila(
            CupertinoIcons.bookmark_fill,
            'Guardados',
            '6 vacantes · 4 perfiles',
          ),
          const _Separador(),
          _fila(
            CupertinoIcons.checkmark_shield_fill,
            'Verificación',
            'Perfil verificado',
            verde: true,
          ),
        ],
      ),
    );
  }

  Widget _fila(
    IconData icono,
    String titulo,
    String detalle, {
    bool verde = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (verde ? MpTokens.success : MpTokens.primary)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(MpTokens.radiusSM),
            ),
            child: Icon(
              icono,
              size: 16,
              color: verde ? MpTokens.success : MpTokens.primary,
            ),
          ),
          const SizedBox(width: 12),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MpTokens.lightText,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: MpTokens.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 15,
            color: MpTokens.lightTextTertiary,
          ),
        ],
      ),
    );
  }
}

class _Sobre extends StatelessWidget {
  const _Sobre();

  @override
  Widget build(BuildContext context) {
    return CandTarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TituloSeccion('Sobre mí'),
          const SizedBox(height: 9),
          const Text(
            candYoSobre,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: MpTokens.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in candYo.etiquetas) CandChip(t, compacto: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Experiencia extends StatelessWidget {
  const _Experiencia();

  @override
  Widget build(BuildContext context) {
    return CandTarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TituloSeccion('Experiencia'),
          for (final (rol, empresa, periodo) in candExperiencia)
            Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CandAvatar(nombre: empresa, tamano: 38),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rol,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: MpTokens.lightText,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          empresa,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: MpTokens.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          periodo,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: MpTokens.lightTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// La variante confidencial, representada como estado dentro de la misma
/// composición en vez de como tres imágenes aparte.
class _Confidencial extends StatelessWidget {
  const _Confidencial();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: MpTokens.lightText,
        borderRadius: BorderRadius.circular(MpTokens.radiusLG),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(MpTokens.radiusSM),
                ),
                child: const Icon(
                  CupertinoIcons.lock_fill,
                  size: 16,
                  color: CupertinoColors.white,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Modo confidencial',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
              Container(
                width: 42,
                height: 25,
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: 19,
                  height: 19,
                  decoration: const BoxDecoration(
                    color: CupertinoColors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            'Con el modo confidencial tu nombre y tu foto quedan ocultos. Las '
            'empresas ven tu experiencia y tus skills, y sólo descubren quién '
            'sos si aceptás.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: CupertinoColors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              const CandAvatar(
                nombre: 'C C',
                tamano: 34,
                color: CupertinoColors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Candidato Confidencial',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.white,
                      ),
                    ),
                    Text(
                      'Product Designer Senior · Rosario',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: CupertinoColors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: MpTokens.lightText,
      ),
    );
  }
}

/// Separador de 1 px. `Divider` es de Material y este archivo es Cupertino.
class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: MpTokens.lightBorder);
  }
}
