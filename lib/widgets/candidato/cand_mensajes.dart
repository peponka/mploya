import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'cand_ui.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MENSAJES — piezas productivas de la composición aprobada.
///
/// Referencia: `design-reference/Candidato_Tanda1_Final/*/04_mensajes.png` y
/// `lib/preview/candidato/cand_mensajes_preview.dart`.
///
/// La conversación en sí NO vive acá: la sigue dibujando `ChatDetailScreen`,
/// que es la que envía, adjunta, llama y agenda. Esto es la bandeja y el panel
/// de contexto.
/// ─────────────────────────────────────────────────────────────────────────────

/// Una conversación de la bandeja, ya resuelta por la pantalla.
@immutable
class CandConversacionVista {
  const CandConversacionVista({
    required this.id,
    required this.nombre,
    this.avatarUrl,
    this.ultimo = '',
    this.hora = '',
    this.sinLeer = 0,
    this.enLinea = false,
  });

  final String id;
  final String nombre;
  final String? avatarUrl;
  final String ultimo;
  final String hora;
  final int sinLeer;
  final bool enLinea;
}

/// Fila de la bandeja.
///
/// `compacta` es la variante de los paneles de tablet y desktop: sin borde,
/// porque ya está dentro de una tarjeta.
class CandFilaConversacion extends StatelessWidget {
  const CandFilaConversacion({
    super.key,
    required this.conversacion,
    this.seleccionada = false,
    this.compacta = false,
    this.onTap,
  });

  final CandConversacionVista conversacion;
  final bool seleccionada;
  final bool compacta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversacion;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin:
            EdgeInsets.symmetric(horizontal: compacta ? 10 : 14, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: seleccionada
              ? MpTokens.primary.withValues(alpha: 0.07)
              : (compacta ? null : MpTokens.lightCard),
          borderRadius: BorderRadius.circular(MpTokens.radiusMD),
          border: compacta ? null : Border.all(color: MpTokens.lightBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CandAvatar(
                  nombre: c.nombre,
                  imagenUrl: c.avatarUrl,
                  tamano: 44,
                ),
                if (c.enLinea)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: MpTokens.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: CupertinoColors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: c.sinLeer > 0
                                ? FontWeight.w800
                                : FontWeight.w700,
                            color: MpTokens.lightText,
                          ),
                        ),
                      ),
                      if (c.hora.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          c.hora,
                          style: const TextStyle(
                            fontSize: 11,
                            color: MpTokens.lightTextTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          c.ultimo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            color: c.sinLeer > 0
                                ? MpTokens.lightText
                                : MpTokens.lightTextTertiary,
                          ),
                        ),
                      ),
                      if (c.sinLeer > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: MpTokens.primary,
                            borderRadius:
                                BorderRadius.circular(MpTokens.radiusPill),
                          ),
                          child: Text(
                            '${c.sinLeer}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una acción del panel de contexto.
@immutable
class CandAccionContexto {
  const CandAccionContexto({
    required this.icono,
    required this.etiqueta,
    this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback? onTap;
}

/// Panel derecho de desktop: quién es la persona y qué se puede hacer con ella.
///
/// En la referencia del set este panel es la ficha del candidato con créditos,
/// que es de la bandeja del RECLUTADOR. Para el candidato se conserva la
/// estructura y se reemplaza el contenido por el contacto real y sus acciones.
class CandPanelContexto extends StatelessWidget {
  const CandPanelContexto({
    super.key,
    required this.nombre,
    this.titulo = '',
    this.avatarUrl,
    this.enLinea = false,
    this.acciones = const [],
    this.ancho = 300,
  });

  final String nombre;
  final String titulo;
  final String? avatarUrl;
  final bool enLinea;
  final List<CandAccionContexto> acciones;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      child: CandTarjeta(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Sobre esta conversación',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: MpTokens.lightText,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                CandAvatar(nombre: nombre, imagenUrl: avatarUrl, tamano: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: MpTokens.lightText,
                        ),
                      ),
                      if (titulo.isNotEmpty)
                        Text(
                          titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.3,
                            color: MpTokens.lightTextTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (enLinea) ...[
              const SizedBox(height: 12),
              Row(
                children: const [
                  Icon(
                    CupertinoIcons.circle_fill,
                    size: 7,
                    color: MpTokens.success,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'En línea',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: MpTokens.lightTextTertiary,
                    ),
                  ),
                ],
              ),
            ],
            if (acciones.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Acciones rápidas',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: MpTokens.lightTextTertiary,
                ),
              ),
              const SizedBox(height: 8),
              for (final a in acciones) _fila(a),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fila(CandAccionContexto a) {
    return GestureDetector(
      onTap: a.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: MpTokens.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(MpTokens.radiusSM),
              ),
              child: Icon(a.icono, size: 15, color: MpTokens.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                a.etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: MpTokens.lightText,
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: MpTokens.lightTextTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder del panel de conversación cuando todavía no se eligió ninguna.
class CandChatSinElegir extends StatelessWidget {
  const CandChatSinElegir({super.key});

  @override
  Widget build(BuildContext context) {
    return const CandVacio(
      icono: CupertinoIcons.chat_bubble_2_fill,
      titulo: 'Elegí una conversación',
      detalle: 'Seleccioná un chat de la lista para ver los mensajes.',
    );
  }
}
