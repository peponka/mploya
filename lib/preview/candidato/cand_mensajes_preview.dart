import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'cand_datos_preview.dart';
import 'cand_kit.dart';

/// MENSAJES — composición visual de la Tanda 1.
///
/// REFERENCIA ELEGIDA: `mensaes especiales.png` ("38. Mensajes" del set CODEX).
/// De las cinco variantes es la única violeta, la única con la barra lateral
/// completa y la única que resuelve el layout ancho: sidebar · lista ·
/// conversación · panel de contexto. Las otras cuatro (`mensajes.png`,
/// `mensajes2.png`, `mensaes4.png`, `mensaes el mejor.png`) quedaron fuera del
/// set depurado CODEX.
///
/// Diferencias conscientes: esa referencia es la bandeja del RECLUTADOR —tiene
/// "Desbloquear por 25 créditos", ficha del candidato y métricas de conversión.
/// Nada de eso aplica al candidato, así que se conserva la ESTRUCTURA de tres
/// columnas y se reemplaza el panel derecho por el contexto de la vacante que
/// motivó la charla.
class CandMensajesPreview extends StatelessWidget {
  const CandMensajesPreview({super.key});

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
// MOBILE 390 × 844 — el inbox es la pantalla
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
                  titulo: 'Mensajes',
                  subtitulo: '3 sin leer',
                  acciones: [CupertinoIcons.square_pencil],
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: CandBuscador(placeholder: 'Buscar conversaciones'),
                ),
                const _Filtros(),
                const SizedBox(height: 8),
                for (final c in candConversaciones)
                  _FilaConversacion(c, seleccionada: c == candConversaciones.first),
              ],
            ),
          ),
          const CandBarraInferior(
            activo: CandDestino.mensajes,
            badgeMensajes: 3,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET 820 × 1180 — panel doble: entra cómodo
// ─────────────────────────────────────────────────────────────────────────────

class _Tablet extends StatelessWidget {
  const _Tablet();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MpTokens.lightBg,
      child: Column(
        children: const [
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 40, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 316,
                    child: CandTarjeta(
                      padding: EdgeInsets.zero,
                      child: _ListaConversaciones(),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: CandTarjeta(
                      padding: EdgeInsets.zero,
                      child: _Conversacion(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          CandBarraInferior(
            activo: CandDestino.mensajes,
            badgeMensajes: 3,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP 1440 × 900 — sidebar · lista · chat · contexto
// ─────────────────────────────────────────────────────────────────────────────

class _Desktop extends StatelessWidget {
  const _Desktop();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MpTokens.lightBg,
      child: Row(
        children: const [
          CandSidebar(activo: CandDestino.mensajes, badgeMensajes: 3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 24, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 322,
                    child: CandTarjeta(
                      padding: EdgeInsets.zero,
                      child: _ListaConversaciones(),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: CandTarjeta(
                      padding: EdgeInsets.zero,
                      child: _Conversacion(),
                    ),
                  ),
                  SizedBox(width: 14),
                  SizedBox(width: 300, child: _PanelContexto()),
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

class _Filtros extends StatelessWidget {
  const _Filtros({this.padding = 20});
  final double padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: padding),
        children: const [
          CandChip('Todos · 5', activo: true, compacto: true),
          SizedBox(width: 8),
          CandChip('Sin leer · 3', compacto: true),
          SizedBox(width: 8),
          CandChip('Empresas', compacto: true),
          SizedBox(width: 8),
          CandChip('Archivados', compacto: true),
        ],
      ),
    );
  }
}

class _ListaConversaciones extends StatelessWidget {
  const _ListaConversaciones();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            'Mensajes',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: MpTokens.lightText,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: CandBuscador(placeholder: 'Buscar conversaciones'),
        ),
        const _Filtros(padding: 16),
        const SizedBox(height: 6),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final c in candConversaciones)
                _FilaConversacion(
                  c,
                  seleccionada: c == candConversaciones.first,
                  compacta: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilaConversacion extends StatelessWidget {
  const _FilaConversacion(
    this.c, {
    this.seleccionada = false,
    this.compacta = false,
  });

  final CandConversacion c;
  final bool seleccionada;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: compacta ? 10 : 14, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: seleccionada
            ? MpTokens.primary.withValues(alpha: 0.07)
            : (compacta ? null : MpTokens.lightCard),
        borderRadius: BorderRadius.circular(MpTokens.radiusMD),
        border: compacta
            ? null
            : Border.all(color: MpTokens.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CandAvatar(nombre: c.persona.nombre, tamano: 44),
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
                        c.persona.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              c.sinLeer > 0 ? FontWeight.w800 : FontWeight.w700,
                          color: MpTokens.lightText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      c.hora,
                      style: const TextStyle(
                        fontSize: 11,
                        color: MpTokens.lightTextTertiary,
                      ),
                    ),
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
    );
  }
}

class _Conversacion extends StatelessWidget {
  const _Conversacion();

  @override
  Widget build(BuildContext context) {
    final c = candConversaciones.first;
    return Column(
      children: [
        // Encabezado
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: MpTokens.lightBorder)),
          ),
          child: Row(
            children: [
              CandAvatar(nombre: c.persona.nombre, tamano: 40),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.persona.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: MpTokens.lightText,
                      ),
                    ),
                    const Row(
                      children: [
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
                ),
              ),
              const Icon(
                CupertinoIcons.ellipsis,
                size: 18,
                color: MpTokens.lightTextTertiary,
              ),
            ],
          ),
        ),
        // Hilo
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            children: [
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Hoy',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: MpTokens.lightTextTertiary,
                    ),
                  ),
                ),
              ),
              for (final m in candHilo) _Burbuja(m),
            ],
          ),
        ),
        // Composer
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: MpTokens.lightBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: MpTokens.lightFill,
                    borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                  ),
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Escribí un mensaje…',
                    style: TextStyle(
                      fontSize: 14,
                      color: MpTokens.lightTextTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: MpTokens.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.paperplane_fill,
                  size: 18,
                  color: CupertinoColors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja(this.m);
  final CandMensaje m;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        mainAxisAlignment:
            m.mio ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
              decoration: BoxDecoration(
                color: m.mio ? MpTokens.primary : MpTokens.lightFill,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(MpTokens.radiusMD),
                  topRight: const Radius.circular(MpTokens.radiusMD),
                  bottomLeft: Radius.circular(m.mio ? MpTokens.radiusMD : 4),
                  bottomRight: Radius.circular(m.mio ? 4 : MpTokens.radiusMD),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.texto,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: m.mio
                          ? CupertinoColors.white
                          : MpTokens.lightText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    m.hora,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: m.mio
                          ? CupertinoColors.white.withValues(alpha: 0.75)
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
}

/// Panel derecho de desktop. En la referencia es la ficha del candidato con
/// créditos; para el candidato es el contexto de la vacante que originó la
/// conversación.
class _PanelContexto extends StatelessWidget {
  const _PanelContexto();

  @override
  Widget build(BuildContext context) {
    final v = candVacantes.first;
    return CandTarjeta(
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
              CandAvatar(nombre: v.empresa, tamano: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      v.empresa,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MpTokens.lightText,
                      ),
                    ),
                    const Text(
                      'Talent Partner',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: MpTokens.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: MpTokens.lightFill,
              borderRadius: BorderRadius.circular(MpTokens.radiusMD),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vacante en conversación',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: MpTokens.lightTextTertiary,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  v.puesto,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: MpTokens.lightText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${v.modalidad} · ${v.salario}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: MpTokens.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 11),
                CandMatch(valor: v.match, tamano: 40, etiqueta: 'Match IA'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Tu postulación',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: MpTokens.lightTextTertiary,
            ),
          ),
          const SizedBox(height: 9),
          _paso('Postulación enviada', true),
          _paso('Perfil visto', true),
          _paso('Entrevista', false),
          const SizedBox(height: 18),
          const CandBoton('Ver vacante', secundario: true, ancho: double.infinity),
        ],
      ),
    );
  }

  Widget _paso(String texto, bool hecho) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: hecho ? MpTokens.success : MpTokens.lightFill,
              shape: BoxShape.circle,
              border: hecho
                  ? null
                  : Border.all(color: MpTokens.lightBorderStrong, width: 1.5),
            ),
            child: hecho
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
              texto,
              style: TextStyle(
                fontSize: 13,
                fontWeight: hecho ? FontWeight.w600 : FontWeight.w500,
                color: hecho
                    ? MpTokens.lightText
                    : MpTokens.lightTextTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
