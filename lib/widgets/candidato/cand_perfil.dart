import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'cand_ui.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// PERFIL PROPIO DE CANDIDATO — piezas productivas de la composición aprobada.
///
/// Referencia: `design-reference/Candidato_Tanda1_Final/*/05_perfil.png` y
/// `lib/preview/candidato/cand_perfil_preview.dart`.
///
/// Ninguna de estas piezas consulta nada: reciben lo que la pantalla ya leyó de
/// Supabase. Cuando un dato falta, la pieza se omite o dice que falta; no se
/// rellena con nada inventado.
/// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS DE VISTA (planos, sin dependencias de datos)
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class CandMetrica {
  const CandMetrica(this.valor, this.etiqueta);
  final String valor;
  final String etiqueta;
}

@immutable
class CandAcceso {
  const CandAcceso({
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.onTap,
    this.verde = false,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback? onTap;

  /// Verde = señal confirmada (verificación). Violeta = acceso normal.
  final bool verde;
}

@immutable
class CandExperienciaItem {
  const CandExperienciaItem({
    required this.rol,
    required this.empresa,
    required this.periodo,
    this.logoUrl,
  });

  final String rol;
  final String empresa;
  final String periodo;
  final String? logoUrl;
}

// ─────────────────────────────────────────────────────────────────────────────
// PIEZAS
// ─────────────────────────────────────────────────────────────────────────────

/// Portada violeta con las acciones de compartir y configuración.
class CandPerfilPortada extends StatelessWidget {
  const CandPerfilPortada({
    super.key,
    this.alto = 118,
    this.onCompartir,
    this.onConfiguracion,
  });

  final double alto;
  final VoidCallback? onCompartir;
  final VoidCallback? onConfiguracion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alto,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              MpTokens.primary,
              Color(0xFF6E3BE8),
              MpTokens.primaryLight,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 16,
              top: alto - 72,
              child: Row(
                children: [
                  _redondo(CupertinoIcons.share, onCompartir),
                  const SizedBox(width: 8),
                  _redondo(CupertinoIcons.gear_alt_fill, onConfiguracion),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _redondo(IconData i, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: CupertinoColors.white.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        child: Icon(i, size: 16, color: CupertinoColors.white),
      ),
    );
  }
}

/// Avatar montado sobre la portada + nombre, headline y ubicación reales.
class CandPerfilIdentidad extends StatelessWidget {
  const CandPerfilIdentidad({
    super.key,
    required this.nombre,
    required this.headline,
    required this.ubicacion,
    this.avatarUrl,
    this.verificado = false,
    this.abiertaOfertas = false,
    this.ancho = false,
    this.onAvatarTap,
  });

  final String nombre;
  final String headline;
  final String ubicacion;
  final String? avatarUrl;
  final bool verificado;
  final bool abiertaOfertas;
  final bool ancho;
  final VoidCallback? onAvatarTap;

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
              child: CandAvatar(
                nombre: nombre,
                imagenUrl: avatarUrl,
                tamano: 74,
                onTap: onAvatarTap,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Flexible(
                  child: Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: MpTokens.lightText,
                    ),
                  ),
                ),
                if (verificado) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    CupertinoIcons.checkmark_seal_fill,
                    size: 17,
                    color: MpTokens.info,
                  ),
                ],
                if (abiertaOfertas) ...[
                  const SizedBox(width: 8),
                  const Flexible(
                    child: CandChip(
                      'Abierta a ofertas',
                      compacto: true,
                      activo: true,
                    ),
                  ),
                ],
              ],
            ),
            if (headline.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: MpTokens.lightTextSecondary,
                ),
              ),
            ],
            if (ubicacion.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.location_solid,
                    size: 13,
                    color: MpTokens.lightTextTertiary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      ubicacion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: MpTokens.lightTextTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila de métricas. Sólo pinta lo que la pantalla le pasa; sin métricas, no
/// se dibuja la tarjeta.
class CandPerfilMetricas extends StatelessWidget {
  const CandPerfilMetricas({super.key, required this.metricas, this.onTap});

  final List<CandMetrica> metricas;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (metricas.isEmpty) return const SizedBox.shrink();
    return CandTarjeta(
      padding: const EdgeInsets.symmetric(vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          for (final m in metricas)
            Expanded(
              child: Column(
                children: [
                  Text(
                    m.valor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
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
              ),
            ),
        ],
      ),
    );
  }
}

class CandPerfilAcciones extends StatelessWidget {
  const CandPerfilAcciones({
    super.key,
    this.vertical = false,
    this.onEditar,
    this.onConfiguracion,
  });

  final bool vertical;
  final VoidCallback? onEditar;
  final VoidCallback? onConfiguracion;

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return Column(
        children: [
          CandBoton(
            'Editar perfil',
            icono: CupertinoIcons.pencil,
            ancho: double.infinity,
            onTap: onEditar,
          ),
          const SizedBox(height: 9),
          CandBoton(
            'Configuración',
            icono: CupertinoIcons.gear_alt_fill,
            secundario: true,
            ancho: double.infinity,
            onTap: onConfiguracion,
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: CandBoton(
            'Editar perfil',
            icono: CupertinoIcons.pencil,
            onTap: onEditar,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CandBoton(
            'Configuración',
            icono: CupertinoIcons.gear_alt_fill,
            secundario: true,
            onTap: onConfiguracion,
          ),
        ),
      ],
    );
  }
}

/// Siguiente paso concreto para que el candidato no tenga que adivinar cómo
/// mejorar su perfil antes de empezar a postularse.
class CandPerfilProgreso extends StatelessWidget {
  const CandPerfilProgreso({
    super.key,
    required this.porcentaje,
    required this.tieneVideo,
    required this.tieneExperiencia,
    this.onEditar,
    this.onGrabar,
  });

  final int porcentaje;
  final bool tieneVideo;
  final bool tieneExperiencia;
  final VoidCallback? onEditar;
  final VoidCallback? onGrabar;

  @override
  Widget build(BuildContext context) {
    final complete = porcentaje >= 100 && tieneVideo && tieneExperiencia;
    final actionIsVideo = !tieneVideo;
    final message = complete
        ? 'Tu perfil está listo para postularte.'
        : actionIsVideo
        ? 'Grabá tu Video Pitch para destacar en las vacantes.'
        : !tieneExperiencia
        ? 'Sumá tu experiencia para que las empresas te conozcan mejor.'
        : 'Completá los datos que faltan para mejorar tus matches.';
    final actionLabel = actionIsVideo ? 'Grabar pitch' : 'Completar perfil';

    return CandTarjeta(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MpTokens.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$porcentaje%',
              style: const TextStyle(
                color: MpTokens.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Impulsá tu perfil',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.25,
                    color: MpTokens.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: actionIsVideo ? onGrabar : onEditar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: MpTokens.primary,
                borderRadius: BorderRadius.circular(MpTokens.radiusPill),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloque de video pitch. Sin video grabado el bloque lo dice y ofrece grabarlo,
/// en vez de simular una reproducción que no existe.
class CandPerfilVideoPitch extends StatelessWidget {
  const CandPerfilVideoPitch({
    super.key,
    required this.tieneVideo,
    this.onVer,
    this.onGrabar,
  });

  final bool tieneVideo;
  final VoidCallback? onVer;
  final VoidCallback? onGrabar;

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
                  child: GestureDetector(
                    onTap: tieneVideo ? onVer : onGrabar,
                    behavior: HitTestBehavior.opaque,
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
                      child: Icon(
                        tieneVideo
                            ? CupertinoIcons.play_fill
                            : CupertinoIcons.videocam_fill,
                        size: 24,
                        color: CupertinoColors.white,
                      ),
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
                      Expanded(
                        child: Text(
                          tieneVideo
                              ? 'Tu presentación de 30 segundos'
                              : 'Todavía no grabaste tu video pitch',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onGrabar,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: CupertinoColors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(
                              MpTokens.radiusPill,
                            ),
                          ),
                          child: Text(
                            tieneVideo ? 'Regrabar' : 'Grabar',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.white,
                            ),
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

/// Mis Herramientas, Guardados y verificación: los accesos del candidato.
class CandPerfilAccesos extends StatelessWidget {
  const CandPerfilAccesos({super.key, required this.accesos});

  final List<CandAcceso> accesos;

  @override
  Widget build(BuildContext context) {
    if (accesos.isEmpty) return const SizedBox.shrink();
    return CandTarjeta(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < accesos.length; i++) ...[
            if (i > 0) const CandSeparador(),
            _Fila(accesos[i]),
          ],
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.a);
  final CandAcceso a;

  @override
  Widget build(BuildContext context) {
    final tinte = a.verde ? MpTokens.success : MpTokens.primary;
    return GestureDetector(
      onTap: a.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tinte.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(MpTokens.radiusSM),
              ),
              child: Icon(a.icono, size: 16, color: tinte),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    a.titulo,
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
                    a.detalle,
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
            if (a.onTap != null)
              const Icon(
                CupertinoIcons.chevron_right,
                size: 15,
                color: MpTokens.lightTextTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

/// Sobre mí + skills reales.
class CandPerfilSobre extends StatelessWidget {
  const CandPerfilSobre({
    super.key,
    required this.texto,
    this.etiquetas = const [],
    this.onEditar,
  });

  final String texto;
  final List<String> etiquetas;
  final VoidCallback? onEditar;

  @override
  Widget build(BuildContext context) {
    final vacio = texto.trim().isEmpty;
    return CandTarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: CandTitulo('Sobre mí')),
              if (vacio && onEditar != null)
                GestureDetector(
                  onTap: onEditar,
                  behavior: HitTestBehavior.opaque,
                  child: const Text(
                    'Agregar',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: MpTokens.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            vacio ? 'Todavía no escribiste tu descripción.' : texto,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: vacio
                  ? MpTokens.lightTextTertiary
                  : MpTokens.lightTextSecondary,
            ),
          ),
          if (etiquetas.isNotEmpty) ...[
            const SizedBox(height: 13),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in etiquetas) CandChip(t, compacto: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Experiencia real. Vacía, lo dice; no se inventan puestos.
class CandPerfilExperiencia extends StatelessWidget {
  const CandPerfilExperiencia({
    super.key,
    required this.items,
    this.onVerTodo,
    this.titulo = 'Experiencia',
  });

  final List<CandExperienciaItem> items;
  final VoidCallback? onVerTodo;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return CandTarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: CandTitulo(titulo)),
              if (onVerTodo != null)
                GestureDetector(
                  onTap: onVerTodo,
                  behavior: HitTestBehavior.opaque,
                  child: const Text(
                    'Ver todo',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: MpTokens.primary,
                    ),
                  ),
                ),
            ],
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Todavía no cargaste tu experiencia.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: MpTokens.lightTextTertiary,
                ),
              ),
            )
          else
            for (final e in items)
              Padding(
                padding: const EdgeInsets.only(top: 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CandAvatar(
                      nombre: e.empresa,
                      imagenUrl: e.logoUrl,
                      tamano: 38,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e.rol,
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
                            e.empresa,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: MpTokens.lightTextSecondary,
                            ),
                          ),
                          if (e.periodo.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              e.periodo,
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
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Tarjeta del modo confidencial. El switch refleja el estado real de la cuenta.
class CandPerfilConfidencial extends StatelessWidget {
  const CandPerfilConfidencial({
    super.key,
    required this.activo,
    required this.resumenOculto,
    this.onTap,
  });

  final bool activo;

  /// Cómo se ve el perfil cuando está oculto: headline + ciudad reales, que es
  /// justo lo que la empresa sigue viendo.
  final String resumenOculto;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                    color: activo
                        ? MpTokens.success
                        : CupertinoColors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                  ),
                  alignment: activo
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
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
                      if (resumenOculto.isNotEmpty)
                        Text(
                          resumenOculto,
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
      ),
    );
  }
}
