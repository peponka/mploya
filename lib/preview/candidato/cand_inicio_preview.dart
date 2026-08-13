import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'cand_datos_preview.dart';
import 'cand_kit.dart';

/// INICIO / FEED — composición visual de la Tanda 1.
///
/// Referencia mobile: `feed vacantes.png` (violeta, set CODEX). De ahí vienen
/// el reel a pantalla completa, el bloque de match arriba a la derecha, la
/// ficha de la vacante sobre el video y la columna de acciones a la derecha.
///
/// Diferencias conscientes:
///  · barra canónica de cinco destinos, sin el botón central de publicar;
///  · el mapa de "a 12 min de vos" de la referencia se reemplaza por el chip de
///    ubicación: la distancia real depende de permisos de geolocalización que
///    esta tanda no toca.
///
/// Desktop y tablet son derivaciones nuevas: no existe referencia para ellas.
class CandInicioPreview extends StatelessWidget {
  const CandInicioPreview({super.key});

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
// MOBILE 390 × 844 — reel vertical dominante
// ─────────────────────────────────────────────────────────────────────────────

class _Mobile extends StatelessWidget {
  const _Mobile();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MpTokens.darkBg,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                const Positioned.fill(child: _Reel()),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 46,
                  child: _BarraSuperior(),
                ),
                const Positioned(right: 12, top: 132, child: _Acciones()),
                const Positioned(
                  left: 16,
                  right: 84,
                  bottom: 18,
                  child: _FichaVacante(),
                ),
              ],
            ),
          ),
          const CandBarraInferior(
            activo: CandDestino.inicio,
            badgeMensajes: 3,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET 820 × 1180 — reel dominante + panel contextual
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(MpTokens.radiusXL),
                      child: Stack(
                        children: const [
                          Positioned.fill(child: _Reel()),
                          Positioned(
                            right: 12,
                            top: 16,
                            child: _Acciones(),
                          ),
                          Positioned(
                            left: 16,
                            right: 84,
                            bottom: 16,
                            child: _FichaVacante(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(flex: 2, child: _PanelContexto()),
                ],
              ),
            ),
          ),
          const CandBarraInferior(
            activo: CandDestino.inicio,
            badgeMensajes: 3,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP 1440 × 900 — sidebar + dos columnas reales
// ─────────────────────────────────────────────────────────────────────────────

class _Desktop extends StatelessWidget {
  const _Desktop();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MpTokens.lightBg,
      child: Row(
        children: [
          const CandSidebar(activo: CandDestino.inicio, badgeMensajes: 3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Columna principal: el reel no se estira a todo el ancho —
                  // se mantiene en proporción vertical, centrado, como en una
                  // web de video real.
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 470),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(MpTokens.radiusXL),
                          child: Stack(
                            children: const [
                              Positioned.fill(child: _Reel()),
                              Positioned(
                                right: 12,
                                top: 16,
                                child: _Acciones(),
                              ),
                              Positioned(
                                left: 16,
                                right: 84,
                                bottom: 16,
                                child: _FichaVacante(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  const SizedBox(width: 360, child: _PanelContexto(ancho: true)),
                ],
              ),
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

/// Superficie del video. Es un placeholder local: el preview no descarga nada.
class _Reel extends StatelessWidget {
  const _Reel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B1436), Color(0xFF2E1F63), Color(0xFF0E0A1E)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: CupertinoColors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: CupertinoColors.white.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: const Icon(
                CupertinoIcons.play_fill,
                size: 30,
                color: CupertinoColors.white,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Video pitch',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: CupertinoColors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarraSuperior extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const CandLogotipo(claro: true),
          const Spacer(),
          _redondo(CupertinoIcons.bell, badge: 3),
          const SizedBox(width: 8),
          _redondo(CupertinoIcons.briefcase),
        ],
      ),
    );
  }

  Widget _redondo(IconData i, {int badge = 0}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: CupertinoColors.black.withValues(alpha: 0.32),
            shape: BoxShape.circle,
          ),
          child: Icon(i, size: 18, color: CupertinoColors.white),
        ),
        if (badge > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: MpTokens.brandOrange,
                borderRadius: BorderRadius.circular(MpTokens.radiusPill),
              ),
              child: Text(
                '$badge',
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

class _Acciones extends StatelessWidget {
  const _Acciones();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _AccionReel(
          icono: CupertinoIcons.bookmark,
          etiqueta: 'Guardar',
        ),
        _AccionReel(
          icono: CupertinoIcons.heart_fill,
          etiqueta: '128',
          destacada: true,
        ),
        _AccionReel(
          icono: CupertinoIcons.chat_bubble,
          etiqueta: '32',
        ),
        _AccionReel(
          icono: CupertinoIcons.arrowshape_turn_up_right,
          etiqueta: 'Compartir',
        ),
      ],
    );
  }
}

class _AccionReel extends StatelessWidget {
  const _AccionReel({
    required this.icono,
    required this.etiqueta,
    this.destacada = false,
  });

  final IconData icono;
  final String etiqueta;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: destacada
                  ? MpTokens.primary
                  : CupertinoColors.black.withValues(alpha: 0.34),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 21, color: CupertinoColors.white),
          ),
          const SizedBox(height: 5),
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ficha de la vacante sobre el video, como en `feed vacantes.png`.
class _FichaVacante extends StatelessWidget {
  const _FichaVacante();

  @override
  Widget build(BuildContext context) {
    final v = candVacantes.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            CandAvatar(
              nombre: v.empresa,
              tamano: 34,
              borde: CupertinoColors.white,
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                v.empresa,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.white,
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              CupertinoIcons.checkmark_seal_fill,
              size: 14,
              color: MpTokens.info,
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          v.puesto,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 20,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: CupertinoColors.white,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _pill(CupertinoIcons.money_dollar, v.salario),
            _pill(CupertinoIcons.location_solid, v.ubicacion),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(MpTokens.radiusMD),
          ),
          child: Row(
            children: [
              CandMatch(valor: v.match, tamano: 36, etiqueta: 'Match IA'),
              const Spacer(),
              const CandBoton('Ver vacante', alto: 34),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(IconData i, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: CupertinoColors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(MpTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 12, color: CupertinoColors.white),
          const SizedBox(width: 5),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Columna secundaria de tablet y desktop: lo que en mobile no entra.
class _PanelContexto extends StatelessWidget {
  const _PanelContexto({this.ancho = false});
  final bool ancho;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        CandTarjeta(
          child: Row(
            children: [
              const CandAvatar(nombre: 'Renata Ferreyra', tamano: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Renata Ferreyra',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: MpTokens.lightText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Perfil completo al ${candMetricas[2].$1}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MpTokens.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CandTarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TituloPanel('Vacantes para vos'),
              for (final v in candVacantes.skip(1).take(ancho ? 3 : 2))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      CandAvatar(nombre: v.empresa, tamano: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              v.puesto,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: MpTokens.lightText,
                              ),
                            ),
                            Text(
                              '${v.empresa} · ${v.modalidad}',
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
                      const SizedBox(width: 8),
                      Text(
                        '${v.match}%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: MpTokens.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CandTarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TituloPanel('Gente que te puede interesar'),
              for (final p in candPersonas.take(ancho ? 3 : 2))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      CandAvatar(nombre: p.nombre, tamano: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              p.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: MpTokens.lightText,
                              ),
                            ),
                            Text(
                              p.titulo,
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
                      const SizedBox(width: 8),
                      const CandBoton('Seguir', alto: 30, secundario: true),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // En desktop el tip ya vive al pie del sidebar: repetirlo acá lo
        // duplicaba en la misma pantalla. En tablet no hay sidebar, así que ahí
        // sí corresponde.
        if (!ancho) ...[
          const SizedBox(height: 12),
          const CandTarjetaTip(),
        ],
      ],
    );
  }
}

class _TituloPanel extends StatelessWidget {
  const _TituloPanel(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: MpTokens.lightText,
      ),
    );
  }
}
