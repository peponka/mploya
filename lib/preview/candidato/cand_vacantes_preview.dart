import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'cand_datos_preview.dart';
import 'cand_kit.dart';

/// VACANTES — composición visual de la Tanda 1.
///
/// Referencia mobile: `todas las vacantes.png` (violeta, set CODEX). De ahí
/// vienen el buscador con filtros al lado, las tarjetas con match a la derecha,
/// los chips de modalidad y el panel lateral de filtros del layout ancho.
///
/// Diferencias conscientes con esa referencia:
///  · su barra inferior es Inicio · Explorar · Publicar · Mensajes · Perfil;
///    acá va la canónica de cinco destinos, sin botón de publicar (el candidato
///    no publica vacantes).
///  · "Empresas cerca tuyo" es un acceso propio de esta tanda: reemplaza a la
///    pestaña Explorar que dejó de existir.
class CandVacantesPreview extends StatelessWidget {
  const CandVacantesPreview({super.key});

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
              children: [
                const SizedBox(height: 46),
                const CandEncabezado(
                  titulo: 'Vacantes',
                  subtitulo: '4 oportunidades para vos',
                  acciones: [
                    CupertinoIcons.map_pin_ellipse,
                    CupertinoIcons.bookmark_fill,
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: CandBuscador(
                    placeholder: 'Buscar puesto, empresa o skill',
                  ),
                ),
                const _FilaFiltros(),
                const _CercaDeVos(),
                const SizedBox(height: 4),
                for (final v in candVacantes.take(3))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _TarjetaVacante(v),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const CandBarraInferior(
            activo: CandDestino.vacantes,
            badgeMensajes: 3,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET 820 × 1180 — filtros persistentes arriba y listado de dos columnas
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
              children: [
                const SizedBox(height: 40),
                const CandEncabezado(
                  titulo: 'Vacantes',
                  subtitulo: '4 oportunidades para vos',
                  acciones: [
                    CupertinoIcons.map_pin_ellipse,
                    CupertinoIcons.bookmark_fill,
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                  child: const Row(
                    children: [
                      Expanded(
                        child: CandBuscador(
                          placeholder: 'Buscar puesto, empresa o skill',
                        ),
                      ),
                      SizedBox(width: 12),
                      CandBoton(
                        'Filtros',
                        icono: CupertinoIcons.slider_horizontal_3,
                        secundario: true,
                      ),
                    ],
                  ),
                ),
                const _FilaFiltros(padding: 24),
                const _CercaDeVos(padding: 24),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      for (var i = 0; i < candVacantes.length; i += 2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _TarjetaVacante(candVacantes[i])),
                              const SizedBox(width: 14),
                              Expanded(
                                child: i + 1 < candVacantes.length
                                    ? _TarjetaVacante(candVacantes[i + 1])
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const CandBarraInferior(
            activo: CandDestino.vacantes,
            badgeMensajes: 3,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP 1440 × 900 — sidebar · filtros · listado · detalle
// ─────────────────────────────────────────────────────────────────────────────

class _Desktop extends StatelessWidget {
  const _Desktop();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MpTokens.lightBg,
      child: Row(
        children: [
          const CandSidebar(activo: CandDestino.vacantes, badgeMensajes: 3),
          // Columna de filtros: en desktop dejan de estar escondidos detrás de
          // un botón, como en el panel derecho de `todas las vacantes.png`.
          const _PanelFiltros(),
          Expanded(
            flex: 5,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 26, 12, 24),
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: Text(
                        'Vacantes',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                          color: MpTokens.lightText,
                        ),
                      ),
                    ),
                    CandBoton(
                      'Empresas cerca tuyo',
                      icono: CupertinoIcons.map_pin_ellipse,
                      secundario: true,
                    ),
                    SizedBox(width: 10),
                    CandBoton(
                      'Guardados',
                      icono: CupertinoIcons.bookmark_fill,
                      secundario: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '4 oportunidades ordenadas por match',
                  style: TextStyle(
                    fontSize: 13,
                    color: MpTokens.lightTextTertiary,
                  ),
                ),
                const SizedBox(height: 18),
                const CandBuscador(
                  placeholder: 'Buscar puesto, empresa o skill',
                ),
                const SizedBox(height: 16),
                for (final v in candVacantes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TarjetaVacante(v, ancha: true),
                  ),
              ],
            ),
          ),
          const _DetalleVacante(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIEZAS
// ─────────────────────────────────────────────────────────────────────────────

class _FilaFiltros extends StatelessWidget {
  const _FilaFiltros({this.padding = 20});
  final double padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: padding),
        children: const [
          CandChip('Para vos', activo: true),
          SizedBox(width: 8),
          CandChip('Remoto'),
          SizedBox(width: 8),
          CandChip('Híbrido'),
          SizedBox(width: 8),
          CandChip('Con salario'),
          SizedBox(width: 8),
          CandChip('Senior'),
        ],
      ),
    );
  }
}

/// Acceso a Explorar filtrado a empresas. Reemplaza a la pestaña que se quitó.
class _CercaDeVos extends StatelessWidget {
  const _CercaDeVos({this.padding = 20});
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 14, padding, 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [MpTokens.primary, MpTokens.primaryLight],
          ),
          borderRadius: BorderRadius.circular(MpTokens.radiusLG),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: CupertinoColors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(MpTokens.radiusSM),
              ),
              child: const Icon(
                CupertinoIcons.map_pin_ellipse,
                size: 20,
                color: CupertinoColors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Empresas cerca tuyo',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: CupertinoColors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '7 empresas contratando en Rosario',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xCCFFFFFF),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaVacante extends StatelessWidget {
  const _TarjetaVacante(this.v, {this.ancha = false});
  final CandVacante v;
  final bool ancha;

  @override
  Widget build(BuildContext context) {
    return CandTarjeta(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CandAvatar(nombre: v.empresa, tamano: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            v.puesto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: MpTokens.lightText,
                            ),
                          ),
                        ),
                        if (v.destacada) ...[
                          const SizedBox(width: 6),
                          const CandChip('Nuevo', compacto: true, activo: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${v.empresa} · ${v.ubicacion}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: MpTokens.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                v.guardada
                    ? CupertinoIcons.bookmark_fill
                    : CupertinoIcons.bookmark,
                size: 19,
                color: v.guardada
                    ? MpTokens.primary
                    : MpTokens.lightTextTertiary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CandMatch(valor: v.match, tamano: 40, etiqueta: 'Match IA'),
              const Spacer(),
              Flexible(
                child: Text(
                  v.salario,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MpTokens.lightText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              CandChip(v.modalidad, compacto: true),
              for (final t in v.etiquetas.take(ancha ? 3 : 2))
                CandChip(t, compacto: true),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Text(
                v.publicada,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: MpTokens.lightTextTertiary,
                ),
              ),
              const Spacer(),
              const CandBoton('Postularme', alto: 36),
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelFiltros extends StatelessWidget {
  const _PanelFiltros();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      padding: const EdgeInsets.fromLTRB(20, 26, 8, 24),
      child: ListView(
        children: [
          const Text(
            'Filtros',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: MpTokens.lightText,
            ),
          ),
          const SizedBox(height: 14),
          _grupo('Modalidad', const [
            ('Remoto', '9', true),
            ('Híbrido', '18', true),
            ('Presencial', '4', false),
          ]),
          _grupo('Experiencia', const [
            ('Semi Senior', '12', false),
            ('Senior', '10', true),
            ('Lead', '3', false),
          ]),
          _grupo('Área', const [
            ('Diseño', '11', true),
            ('Producto', '5', false),
            ('Datos', '4', false),
          ]),
        ],
      ),
    );
  }

  Widget _grupo(String titulo, List<(String, String, bool)> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: MpTokens.lightTextTertiary,
            ),
          ),
          const SizedBox(height: 9),
          for (final (label, n, activo) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      color: activo ? MpTokens.primary : null,
                      border: Border.all(
                        color: activo
                            ? MpTokens.primary
                            : MpTokens.lightBorderStrong,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: activo
                        ? const Icon(
                            CupertinoIcons.check_mark,
                            size: 12,
                            color: CupertinoColors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: MpTokens.lightText,
                      ),
                    ),
                  ),
                  Text(
                    n,
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
    );
  }
}

class _DetalleVacante extends StatelessWidget {
  const _DetalleVacante();

  @override
  Widget build(BuildContext context) {
    final v = candVacantes.first;
    return Container(
      width: 344,
      margin: const EdgeInsets.fromLTRB(12, 26, 24, 24),
      child: CandTarjeta(
        padding: const EdgeInsets.all(18),
        child: ListView(
          children: [
            Row(
              children: [
                CandAvatar(nombre: v.empresa, tamano: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        v.empresa,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: MpTokens.lightText,
                        ),
                      ),
                      const Text(
                        'Tecnología · 250+ personas',
                        style: TextStyle(
                          fontSize: 12,
                          color: MpTokens.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              v.puesto,
              style: const TextStyle(
                fontSize: 20,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: MpTokens.lightText,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CandMatch(valor: v.match, tamano: 52, etiqueta: ''),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Tu perfil coincide en skills y experiencia con lo que pide esta búsqueda.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: MpTokens.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _dato(CupertinoIcons.money_dollar, v.salario),
            _dato(CupertinoIcons.location, '${v.ubicacion} · ${v.modalidad}'),
            _dato(CupertinoIcons.time, v.publicada),
            const SizedBox(height: 14),
            const Text(
              'Buscamos una persona que lleve adelante el sistema de diseño y '
              'trabaje codo a codo con ingeniería.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: MpTokens.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in v.etiquetas) CandChip(t, compacto: true)],
            ),
            const SizedBox(height: 20),
            const CandBoton('Postularme', ancho: double.infinity),
            const SizedBox(height: 9),
            const CandBoton(
              'Guardar vacante',
              icono: CupertinoIcons.bookmark,
              secundario: true,
              ancho: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dato(IconData i, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(i, size: 15, color: MpTokens.lightTextTertiary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13,
                color: MpTokens.lightText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
