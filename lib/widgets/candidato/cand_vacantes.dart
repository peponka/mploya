import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'cand_ui.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// VACANTES — piezas productivas de la composición aprobada.
///
/// Referencia: `design-reference/Candidato_Tanda1_Final/*/02_vacantes.png` y
/// `lib/preview/candidato/cand_vacantes_preview.dart`.
///
/// Todo entra por parámetro. La tarjeta no sabe de dónde salió la vacante ni
/// cómo se guarda: sólo dibuja y avisa.
/// ─────────────────────────────────────────────────────────────────────────────

/// Lo que la tarjeta necesita saber de una vacante. La pantalla lo arma desde
/// la fila real de `jobs`; los campos que la fila no tenga quedan vacíos y la
/// tarjeta simplemente no los dibuja.
@immutable
class CandVacanteVista {
  const CandVacanteVista({
    required this.id,
    required this.puesto,
    required this.empresa,
    this.logoEmpresa,
    this.ubicacion = '',
    this.modalidad = '',
    this.salario = '',
    this.match,
    this.etiquetas = const [],
    this.publicada = '',
    this.nueva = false,
    this.descripcion = '',
  });

  final String id;
  final String puesto;
  final String empresa;
  final String? logoEmpresa;
  final String ubicacion;
  final String modalidad;
  final String salario;

  /// `null` cuando todavía no hay match calculado: no se dibuja un 0 %.
  final int? match;

  final List<String> etiquetas;
  final String publicada;
  final bool nueva;
  final String descripcion;

  String get lineaEmpresa =>
      [empresa, ubicacion].where((p) => p.trim().isNotEmpty).join(' · ');
}

/// Tarjeta de vacante de la tanda.
class CandTarjetaVacante extends StatelessWidget {
  const CandTarjetaVacante({
    super.key,
    required this.vacante,
    this.ancha = false,
    this.guardada = false,
    this.postulada = false,
    this.seleccionada = false,
    this.onTap,
    this.onGuardar,
    this.onPostularme,
  });

  final CandVacanteVista vacante;
  final bool ancha;
  final bool guardada;
  final bool postulada;
  final bool seleccionada;
  final VoidCallback? onTap;
  final VoidCallback? onGuardar;
  final VoidCallback? onPostularme;

  @override
  Widget build(BuildContext context) {
    final v = vacante;
    final chips = <String>[
      if (v.modalidad.isNotEmpty) v.modalidad,
      ...v.etiquetas.take(ancha ? 3 : 2),
    ];

    return CandTarjeta(
      padding: const EdgeInsets.all(15),
      onTap: onTap,
      resaltada: seleccionada,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CandAvatar(
                nombre: v.empresa,
                imagenUrl: v.logoEmpresa,
                tamano: 42,
              ),
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
                        if (v.nueva) ...[
                          const SizedBox(width: 6),
                          const CandChip('Nuevo', compacto: true, activo: true),
                        ],
                      ],
                    ),
                    if (v.lineaEmpresa.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        v.lineaEmpresa,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: MpTokens.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onGuardar,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  guardada
                      ? CupertinoIcons.bookmark_fill
                      : CupertinoIcons.bookmark,
                  size: 19,
                  color:
                      guardada ? MpTokens.primary : MpTokens.lightTextTertiary,
                ),
              ),
            ],
          ),
          if (v.match != null || v.salario.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (v.match != null)
                  CandMatch(valor: v.match!, tamano: 40, etiqueta: 'Match IA'),
                const Spacer(),
                if (v.salario.isNotEmpty)
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
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in chips) CandChip(t, compacto: true)],
            ),
          ],
          const SizedBox(height: 13),
          Row(
            children: [
              Flexible(
                child: Text(
                  v.publicada,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: MpTokens.lightTextTertiary,
                  ),
                ),
              ),
              const Spacer(),
              CandBoton(
                postulada ? 'Postulada' : 'Postularme',
                alto: 36,
                secundario: postulada,
                onTap: postulada ? null : onPostularme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Acceso a Explorar filtrado a empresas. Reemplaza a la pestaña que se quitó.
class CandBannerCerca extends StatelessWidget {
  const CandBannerCerca({
    super.key,
    required this.detalle,
    this.padding = 20,
    this.onTap,
  });

  /// Texto real: cuántas empresas están contratando en el listado cargado.
  final String detalle;
  final double padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 14, padding, 14),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MpTokens.primary,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Empresas cerca tuyo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: CupertinoColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
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
      ),
    );
  }
}

/// Una opción del panel de filtros persistente de desktop.
@immutable
class CandOpcionFiltro {
  const CandOpcionFiltro({
    required this.etiqueta,
    required this.cantidad,
    required this.activo,
    this.onTap,
  });

  final String etiqueta;

  /// Cuántas vacantes del listado cargado cumplen la condición. Es un conteo
  /// real, no un número decorativo.
  final int cantidad;

  final bool activo;
  final VoidCallback? onTap;
}

@immutable
class CandGrupoFiltro {
  const CandGrupoFiltro({required this.titulo, required this.opciones});
  final String titulo;
  final List<CandOpcionFiltro> opciones;
}

/// Panel lateral de filtros de desktop: en ancho dejan de estar escondidos
/// detrás de un botón.
class CandPanelFiltros extends StatelessWidget {
  const CandPanelFiltros({
    super.key,
    required this.grupos,
    this.ancho = 236,
    this.onLimpiar,
  });

  final List<CandGrupoFiltro> grupos;
  final double ancho;
  final VoidCallback? onLimpiar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 26, 8, 24),
        children: [
          Row(
            children: [
              const Expanded(child: CandTitulo('Filtros')),
              if (onLimpiar != null)
                GestureDetector(
                  onTap: onLimpiar,
                  behavior: HitTestBehavior.opaque,
                  child: const Text(
                    'Limpiar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MpTokens.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          for (final g in grupos)
            if (g.opciones.isNotEmpty) _grupo(g),
        ],
      ),
    );
  }

  Widget _grupo(CandGrupoFiltro g) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            g.titulo,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: MpTokens.lightTextTertiary,
            ),
          ),
          const SizedBox(height: 9),
          for (final o in g.opciones)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: GestureDetector(
                onTap: o.onTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: o.activo ? MpTokens.primary : null,
                        border: Border.all(
                          color: o.activo
                              ? MpTokens.primary
                              : MpTokens.lightBorderStrong,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: o.activo
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
                        o.etiqueta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: MpTokens.lightText,
                        ),
                      ),
                    ),
                    Text(
                      '${o.cantidad}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MpTokens.lightTextTertiary,
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
}

/// Panel de detalle de desktop.
class CandDetalleVacante extends StatelessWidget {
  const CandDetalleVacante({
    super.key,
    required this.vacante,
    this.ancho = 344,
    this.guardada = false,
    this.postulada = false,
    this.onPostularme,
    this.onGuardar,
    this.onAbrir,
  });

  final CandVacanteVista? vacante;
  final double ancho;
  final bool guardada;
  final bool postulada;
  final VoidCallback? onPostularme;
  final VoidCallback? onGuardar;
  final VoidCallback? onAbrir;

  @override
  Widget build(BuildContext context) {
    final v = vacante;
    return Container(
      width: ancho,
      margin: const EdgeInsets.fromLTRB(12, 26, 24, 24),
      child: CandTarjeta(
        padding: const EdgeInsets.all(18),
        child: v == null
            ? const CandVacio(
                icono: CupertinoIcons.briefcase,
                titulo: 'Elegí una vacante',
                detalle:
                    'Al tocar una de la lista vas a ver acá su detalle completo.',
              )
            : ListView(
                children: [
                  Row(
                    children: [
                      CandAvatar(
                        nombre: v.empresa,
                        imagenUrl: v.logoEmpresa,
                        tamano: 46,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              v.empresa,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: MpTokens.lightText,
                              ),
                            ),
                            if (v.ubicacion.isNotEmpty)
                              Text(
                                v.ubicacion,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                  if (v.match != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CandMatch(valor: v.match!, tamano: 52, etiqueta: ''),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Coincidencia calculada entre tus skills y lo que '
                            'pide esta búsqueda.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: MpTokens.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (v.salario.isNotEmpty)
                    _dato(CupertinoIcons.money_dollar, v.salario),
                  if (v.ubicacion.isNotEmpty || v.modalidad.isNotEmpty)
                    _dato(
                      CupertinoIcons.location,
                      [v.ubicacion, v.modalidad]
                          .where((p) => p.isNotEmpty)
                          .join(' · '),
                    ),
                  if (v.publicada.isNotEmpty)
                    _dato(CupertinoIcons.time, v.publicada),
                  if (v.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      v.descripcion,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: MpTokens.lightTextSecondary,
                      ),
                    ),
                  ],
                  if (v.etiquetas.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in v.etiquetas) CandChip(t, compacto: true),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  CandBoton(
                    postulada ? 'Ya te postulaste' : 'Postularme',
                    ancho: double.infinity,
                    secundario: postulada,
                    onTap: postulada ? null : onPostularme,
                  ),
                  const SizedBox(height: 9),
                  CandBoton(
                    guardada ? 'Guardada' : 'Guardar vacante',
                    icono: guardada
                        ? CupertinoIcons.bookmark_fill
                        : CupertinoIcons.bookmark,
                    secundario: true,
                    ancho: double.infinity,
                    onTap: onGuardar,
                  ),
                  if (onAbrir != null) ...[
                    const SizedBox(height: 9),
                    CandBoton(
                      'Ver ficha completa',
                      secundario: true,
                      ancho: double.infinity,
                      onTap: onAbrir,
                    ),
                  ],
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
              style: const TextStyle(fontSize: 13, color: MpTokens.lightText),
            ),
          ),
        ],
      ),
    );
  }
}
