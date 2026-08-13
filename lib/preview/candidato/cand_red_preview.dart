import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'cand_datos_preview.dart';
import 'cand_kit.dart';

/// RED — composición visual de la Tanda 1.
///
/// NO EXISTE MOCKUP para esta pantalla: en todo el set las pantallas de
/// personas (`busqueda digital.png`, `mapa de talento.png`) son de Empresa y
/// Headhunter — buscan talento para contratar. Red es lo contrario: la agenda
/// del propio candidato.
///
/// Se derivó del lenguaje de las otras cuatro:
///  · el selector de secciones toma la fila de chips de Vacantes;
///  · las tarjetas de persona reusan avatar + título + acciones de Mensajes;
///  · el panel de detalle de desktop repite el patrón de Vacantes;
///  · Nexus se representa con el violeta de "esto lo hizo la IA" del sistema.
class CandRedPreview extends StatelessWidget {
  const CandRedPreview({super.key});

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
                  titulo: 'Red',
                  subtitulo: '34 conexiones · 2 solicitudes',
                  acciones: [CupertinoIcons.person_badge_plus],
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: CandBuscador(placeholder: 'Buscar en tu red'),
                ),
                const _Secciones(),
                const SizedBox(height: 14),
                const _Solicitudes(),
                const SizedBox(height: 6),
                const _NexusBanner(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: _Titulo('Tus conexiones'),
                ),
                for (final p in candPersonas.take(3))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: _TarjetaPersona(p),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const CandBarraInferior(activo: CandDestino.red, badgeMensajes: 3),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET 820 × 1180 — grilla de dos columnas
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
                  titulo: 'Red',
                  subtitulo: '34 conexiones · 2 solicitudes',
                  acciones: [CupertinoIcons.person_badge_plus],
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: CandBuscador(placeholder: 'Buscar en tu red'),
                ),
                const _Secciones(padding: 24),
                const SizedBox(height: 14),
                const _Solicitudes(padding: 24, columnas: 2),
                const SizedBox(height: 6),
                const _NexusBanner(padding: 24),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 18, 24, 10),
                  child: _Titulo('Tus conexiones'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      for (var i = 0; i < candPersonas.length; i += 2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _TarjetaPersona(candPersonas[i])),
                              const SizedBox(width: 12),
                              Expanded(
                                child: i + 1 < candPersonas.length
                                    ? _TarjetaPersona(candPersonas[i + 1])
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
          const CandBarraInferior(activo: CandDestino.red, badgeMensajes: 3),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP 1440 × 900 — sidebar · lista · detalle
// ─────────────────────────────────────────────────────────────────────────────

class _Desktop extends StatelessWidget {
  const _Desktop();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MpTokens.lightBg,
      child: Row(
        children: [
          const CandSidebar(activo: CandDestino.red, badgeMensajes: 3),
          Expanded(
            flex: 5,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 26, 14, 24),
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Red',
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                              color: MpTokens.lightText,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '34 conexiones · 2 solicitudes pendientes',
                            style: TextStyle(
                              fontSize: 13,
                              color: MpTokens.lightTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CandBoton(
                      'Invitar contactos',
                      icono: CupertinoIcons.person_badge_plus,
                      secundario: true,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const CandBuscador(placeholder: 'Buscar en tu red'),
                const SizedBox(height: 14),
                const _Secciones(padding: 0),
                const SizedBox(height: 18),
                const _Solicitudes(padding: 0, columnas: 2),
                const SizedBox(height: 10),
                const _Titulo('Tus conexiones'),
                const SizedBox(height: 12),
                for (var i = 0; i < candPersonas.length; i += 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _TarjetaPersona(candPersonas[i])),
                        const SizedBox(width: 12),
                        Expanded(
                          child: i + 1 < candPersonas.length
                              ? _TarjetaPersona(candPersonas[i + 1])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const _DetallePersona(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIEZAS
// ─────────────────────────────────────────────────────────────────────────────

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
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

class _Secciones extends StatelessWidget {
  const _Secciones({this.padding = 20});
  final double padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: padding),
        children: const [
          CandChip('Conexiones · 34', activo: true),
          SizedBox(width: 8),
          CandChip('Solicitudes · 2'),
          SizedBox(width: 8),
          CandChip('Nexus'),
          SizedBox(width: 8),
          CandChip('Sugeridas'),
        ],
      ),
    );
  }
}

class _Solicitudes extends StatelessWidget {
  const _Solicitudes({this.padding = 20, this.columnas = 1});
  final double padding;
  final int columnas;

  @override
  Widget build(BuildContext context) {
    final pendientes = candPersonas.skip(2).take(2).toList();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Titulo('Solicitudes'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: MpTokens.danger,
                  borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                ),
                child: Text(
                  '${pendientes.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (columnas == 1)
            for (final p in pendientes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TarjetaSolicitud(p),
              )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < pendientes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: _TarjetaSolicitud(pendientes[i])),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _TarjetaSolicitud extends StatelessWidget {
  const _TarjetaSolicitud(this.p);
  final CandPersona p;

  @override
  Widget build(BuildContext context) {
    return CandTarjeta(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          CandAvatar(nombre: p.nombre, tamano: 44),
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
                const SizedBox(height: 9),
                const Row(
                  children: [
                    CandBoton('Aceptar', alto: 32),
                    SizedBox(width: 8),
                    CandBoton('Ignorar', alto: 32, secundario: true),
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

/// Nexus: la sugerencia de la IA. Usa el violeta tenue que en el sistema
/// significa exactamente eso.
class _NexusBanner extends StatelessWidget {
  const _NexusBanner({this.padding = 20});
  final double padding;

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
                const Expanded(
                  child: Text(
                    'Nexus encontró 3 personas afines',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: MpTokens.lightText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Trabajan en sistemas de diseño y están en tu zona.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: MpTokens.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final p in candPersonas.take(3))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: CandAvatar(nombre: p.nombre, tamano: 34),
                  ),
                const Spacer(),
                const CandBoton('Ver sugerencias', alto: 34),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaPersona extends StatelessWidget {
  const _TarjetaPersona(this.p);
  final CandPersona p;

  @override
  Widget build(BuildContext context) {
    return CandTarjeta(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          CandAvatar(nombre: p.nombre, tamano: 46),
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
            ),
          ),
          const SizedBox(width: 8),
          Container(
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
        ],
      ),
    );
  }
}

class _DetallePersona extends StatelessWidget {
  const _DetallePersona();

  @override
  Widget build(BuildContext context) {
    final p = candPersonas.first;
    return Container(
      width: 340,
      margin: const EdgeInsets.fromLTRB(14, 26, 28, 24),
      child: CandTarjeta(
        padding: const EdgeInsets.all(18),
        child: ListView(
          children: [
            Center(
              child: Column(
                children: [
                  CandAvatar(nombre: p.nombre, tamano: 80),
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
                      const SizedBox(width: 5),
                      const Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        size: 15,
                        color: MpTokens.info,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.titulo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: MpTokens.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.ciudad,
                    style: const TextStyle(
                      fontSize: 12,
                      color: MpTokens.lightTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _metrica('12', 'En común')),
                Expanded(child: _metrica('3', 'Proyectos')),
                Expanded(child: _metrica('${p.match}%', 'Afinidad')),
              ],
            ),
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
            const SizedBox(height: 20),
            const CandBoton(
              'Enviar mensaje',
              icono: CupertinoIcons.chat_bubble_fill,
              ancho: double.infinity,
            ),
            const SizedBox(height: 9),
            const CandBoton(
              'Ver perfil completo',
              secundario: true,
              ancho: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metrica(String valor, String etiqueta) {
    return Column(
      children: [
        Text(
          valor,
          style: const TextStyle(
            fontSize: 17,
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
    );
  }
}
