import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';
import 'cand_red.dart' show CandPersonaVista;
import 'cand_ui.dart';
import 'cand_vacantes.dart' show CandVacanteVista;

/// ─────────────────────────────────────────────────────────────────────────────
/// INICIO — columna de contexto de tablet y desktop.
///
/// Referencia: `design-reference/Candidato_Tanda1_Final/{tablet,desktop}/
/// 01_inicio.png` y `lib/preview/candidato/cand_inicio_preview.dart`.
///
/// El reel es la pantalla; esta columna es lo que en mobile no entra. Cada
/// bloque se dibuja sólo si hay datos reales que mostrar.
/// ─────────────────────────────────────────────────────────────────────────────
class CandPanelInicio extends StatelessWidget {
  const CandPanelInicio({
    super.key,
    this.nombre = '',
    this.avatarUrl,
    this.detallePerfil = '',
    this.vacantes = const [],
    this.personas = const [],
    this.tip,
    this.onPerfil,
    this.onVacante,
    this.onPersona,
    this.onVerVacantes,
  });

  final String nombre;
  final String? avatarUrl;

  /// Línea bajo el nombre. Debe ser un dato real del perfil.
  final String detallePerfil;

  final List<CandVacanteVista> vacantes;
  final List<CandPersonaVista> personas;

  /// Tip al pie. En desktop el shell ya lo muestra en la barra lateral, así que
  /// ahí se pasa `null` para no duplicarlo.
  final String? tip;

  final VoidCallback? onPerfil;
  final ValueChanged<CandVacanteVista>? onVacante;
  final ValueChanged<CandPersonaVista>? onPersona;
  final VoidCallback? onVerVacantes;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (nombre.isNotEmpty) ...[
          CandTarjeta(
            onTap: onPerfil,
            child: Row(
              children: [
                CandAvatar(nombre: nombre, imagenUrl: avatarUrl, tamano: 46),
                const SizedBox(width: 12),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: MpTokens.lightText,
                        ),
                      ),
                      if (detallePerfil.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detallePerfil,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
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
          const SizedBox(height: 12),
        ],
        if (vacantes.isNotEmpty) ...[
          CandTarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: _TituloPanel('Vacantes para vos')),
                    if (onVerVacantes != null)
                      GestureDetector(
                        onTap: onVerVacantes,
                        behavior: HitTestBehavior.opaque,
                        child: const Text(
                          'Ver todas',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: MpTokens.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                for (final v in vacantes)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GestureDetector(
                      onTap: onVacante == null ? null : () => onVacante!(v),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          CandAvatar(
                            nombre: v.empresa,
                            imagenUrl: v.logoEmpresa,
                            tamano: 36,
                          ),
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
                                  [v.empresa, v.modalidad]
                                      .where((p) => p.isNotEmpty)
                                      .join(' · '),
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
                          if (v.match != null) ...[
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
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (personas.isNotEmpty) ...[
          CandTarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TituloPanel('Gente que te puede interesar'),
                for (final p in personas)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        CandAvatar(
                          nombre: p.nombre,
                          imagenUrl: p.avatarUrl,
                          tamano: 36,
                        ),
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
                              if (p.titulo.isNotEmpty)
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
                        CandBoton(
                          'Ver perfil',
                          alto: 30,
                          secundario: true,
                          onTap:
                              onPersona == null ? null : () => onPersona!(p),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (tip != null && tip!.isNotEmpty) ...[
          const SizedBox(height: 12),
          CandTarjetaTip(texto: tip!),
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
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: MpTokens.lightText,
      ),
    );
  }
}
