import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'cand_perfil.dart' show CandMetrica;
import 'cand_ui.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// RED — piezas productivas de la composición aprobada.
///
/// Referencia: `design-reference/Candidato_Tanda1_Final/*/03_red.png` y
/// `lib/preview/candidato/cand_red_preview.dart`.
///
/// No hay mockup original de esta pantalla: la composición se derivó del
/// lenguaje de las otras cuatro. Nexus usa el violeta tenue que en el sistema
/// significa «esto lo sugirió la IA».
/// ─────────────────────────────────────────────────────────────────────────────

/// Lo que se necesita saber de una persona para dibujarla. Lo arma la pantalla
/// desde la fila real de `users`.
@immutable
class CandPersonaVista {
  const CandPersonaVista({
    required this.id,
    required this.nombre,
    this.titulo = '',
    this.ciudad = '',
    this.avatarUrl,
    this.verificado = false,
    this.etiquetas = const [],
  });

  final String id;
  final String nombre;
  final String titulo;
  final String ciudad;
  final String? avatarUrl;
  final bool verificado;
  final List<String> etiquetas;
}

/// Tarjeta de conexión.
class CandTarjetaPersona extends StatelessWidget {
  const CandTarjetaPersona({
    super.key,
    required this.persona,
    this.seleccionada = false,
    this.onTap,
    this.onMensaje,
  });

  final CandPersonaVista persona;
  final bool seleccionada;
  final VoidCallback? onTap;
  final VoidCallback? onMensaje;

  @override
  Widget build(BuildContext context) {
    final p = persona;
    return CandTarjeta(
      padding: const EdgeInsets.all(13),
      onTap: onTap,
      resaltada: seleccionada,
      child: Row(
        children: [
          CandAvatar(nombre: p.nombre, imagenUrl: p.avatarUrl, tamano: 46),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: MpTokens.lightText,
                        ),
                      ),
                    ),
                    if (p.verificado) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        size: 13,
                        color: MpTokens.info,
                      ),
                    ],
                  ],
                ),
                if (p.titulo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    p.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: MpTokens.lightTextSecondary,
                    ),
                  ),
                ],
                if (p.ciudad.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    p.ciudad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: MpTokens.lightTextTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onMensaje != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onMensaje,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: MpTokens.lightFill,
                  borderRadius: BorderRadius.circular(MpTokens.radiusSM),
                ),
                child: const Icon(
                  CupertinoIcons.chat_bubble_fill,
                  size: 16,
                  color: MpTokens.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Solicitud pendiente, con Aceptar e Ignorar.
class CandTarjetaSolicitud extends StatelessWidget {
  const CandTarjetaSolicitud({
    super.key,
    required this.persona,
    this.cargando = false,
    this.onAceptar,
    this.onIgnorar,
    this.onTap,
  });

  final CandPersonaVista persona;
  final bool cargando;
  final VoidCallback? onAceptar;
  final VoidCallback? onIgnorar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = persona;
    return CandTarjeta(
      padding: const EdgeInsets.all(13),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CandAvatar(nombre: p.nombre, imagenUrl: p.avatarUrl, tamano: 44),
          const SizedBox(width: 11),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MpTokens.lightText,
                  ),
                ),
                if (p.titulo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    p.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: MpTokens.lightTextTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                if (cargando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: CupertinoActivityIndicator(radius: 9),
                  )
                else
                  Row(
                    children: [
                      Flexible(
                        child: CandBoton(
                          'Aceptar',
                          alto: 32,
                          onTap: onAceptar,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: CandBoton(
                          'Ignorar',
                          alto: 32,
                          secundario: true,
                          onTap: onIgnorar,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nexus: la sugerencia de la IA.
class CandBannerNexus extends StatelessWidget {
  const CandBannerNexus({
    super.key,
    required this.titulo,
    required this.detalle,
    this.avatares = const [],
    this.padding = 20,
    this.onVer,
  });

  final String titulo;
  final String detalle;
  final List<CandPersonaVista> avatares;
  final double padding;
  final VoidCallback? onVer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 14, padding, 0),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: MpTokens.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(MpTokens.radiusLG),
          border: Border.all(color: MpTokens.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: MpTokens.primary,
                    borderRadius: BorderRadius.circular(MpTokens.radiusSM),
                  ),
                  child: const Icon(
                    CupertinoIcons.bolt_fill,
                    size: 15,
                    color: CupertinoColors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: MpTokens.lightText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              detalle,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: MpTokens.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final p in avatares.take(3))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: CandAvatar(
                      nombre: p.nombre,
                      imagenUrl: p.avatarUrl,
                      tamano: 34,
                    ),
                  ),
                const Spacer(),
                CandBoton('Ver sugerencias', alto: 34, onTap: onVer),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel de detalle de desktop.
class CandDetallePersona extends StatelessWidget {
  const CandDetallePersona({
    super.key,
    required this.persona,
    this.metricas = const [],
    this.ancho = 340,
    this.onMensaje,
    this.onVerPerfil,
  });

  final CandPersonaVista? persona;
  final List<CandMetrica> metricas;
  final double ancho;
  final VoidCallback? onMensaje;
  final VoidCallback? onVerPerfil;

  @override
  Widget build(BuildContext context) {
    final p = persona;
    return Container(
      width: ancho,
      margin: const EdgeInsets.fromLTRB(14, 26, 28, 24),
      child: CandTarjeta(
        padding: const EdgeInsets.all(18),
        child: p == null
            ? const CandVacio(
                icono: CupertinoIcons.person_2,
                titulo: 'Elegí a alguien de tu red',
                detalle: 'Al tocar una tarjeta vas a ver acá su ficha.',
              )
            : ListView(
                children: [
                  Center(
                    child: Column(
                      children: [
                        CandAvatar(
                          nombre: p.nombre,
                          imagenUrl: p.avatarUrl,
                          tamano: 80,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                p.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: MpTokens.lightText,
                                ),
                              ),
                            ),
                            if (p.verificado) ...[
                              const SizedBox(width: 5),
                              const Icon(
                                CupertinoIcons.checkmark_seal_fill,
                                size: 15,
                                color: MpTokens.info,
                              ),
                            ],
                          ],
                        ),
                        if (p.titulo.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            p.titulo,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: MpTokens.lightTextSecondary,
                            ),
                          ),
                        ],
                        if (p.ciudad.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            p.ciudad,
                            style: const TextStyle(
                              fontSize: 12,
                              color: MpTokens.lightTextTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (metricas.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        for (final m in metricas)
                          Expanded(child: _metrica(m)),
                      ],
                    ),
                  ],
                  if (p.etiquetas.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Skills',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: MpTokens.lightTextTertiary,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in p.etiquetas) CandChip(t, compacto: true),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  CandBoton(
                    'Enviar mensaje',
                    icono: CupertinoIcons.chat_bubble_fill,
                    ancho: double.infinity,
                    onTap: onMensaje,
                  ),
                  const SizedBox(height: 9),
                  CandBoton(
                    'Ver perfil completo',
                    secundario: true,
                    ancho: double.infinity,
                    onTap: onVerPerfil,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _metrica(CandMetrica m) {
    return Column(
      children: [
        Text(
          m.valor,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: MpTokens.lightText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          m.etiqueta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            color: MpTokens.lightTextTertiary,
          ),
        ),
      ],
    );
  }
}
