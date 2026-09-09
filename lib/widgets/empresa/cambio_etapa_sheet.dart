import 'package:flutter/cupertino.dart';

import '../../services/application_stage_service.dart';
import '../ds/mploya_ds.dart';

/// Lo que la empresa eligió al mover a alguien de etapa.
@immutable
class CambioEtapa {
  const CambioEtapa({required this.status, this.reason, this.notes});

  final String status;
  final String? reason;
  final String? notes;
}

/// Hoja para mover una postulación de etapa, con motivo y notas.
///
/// SÓLO OFRECE MOVIMIENTOS VÁLIDOS. Los destinos salen de la matriz de
/// transiciones de la migración 029/050, así que la persona no puede elegir
/// un cambio que el servidor va a rechazar. La autoridad sigue siendo el
/// servidor: si las dos se desincronizan, gana la base.
///
/// EL MOTIVO ES OBLIGATORIO PARA DESCARTAR. No es una regla de esta pantalla,
/// es del backend: `update_application_status` falla sin motivo. Acá se pide
/// antes para no gastar una ida y vuelta y para que la persona entienda por
/// qué se lo piden.
Future<CambioEtapa?> mostrarCambioEtapa(
  BuildContext context, {
  required String nombreCandidato,
  required String estadoActual,
}) {
  return showCupertinoModalPopup<CambioEtapa>(
    context: context,
    builder: (_) => _CambioEtapaSheet(
      nombreCandidato: nombreCandidato,
      estadoActual: estadoActual,
    ),
  );
}

class _CambioEtapaSheet extends StatefulWidget {
  const _CambioEtapaSheet({
    required this.nombreCandidato,
    required this.estadoActual,
  });

  final String nombreCandidato;
  final String estadoActual;

  @override
  State<_CambioEtapaSheet> createState() => _CambioEtapaSheetState();
}

class _CambioEtapaSheetState extends State<_CambioEtapaSheet> {
  String? _destino;
  final _motivo = TextEditingController();
  final _notas = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    _notas.dispose();
    super.dispose();
  }

  bool get _pideMotivo => _destino == kApplicationRejected;

  bool get _puedeConfirmar {
    if (_destino == null) return false;
    if (_pideMotivo && _motivo.text.trim().isEmpty) return false;
    return true;
  }

  void _confirmar() {
    final destino = _destino;
    if (destino == null) return;
    final motivo = _motivo.text.trim();
    final notas = _notas.text.trim();
    Navigator.of(context).pop(
      CambioEtapa(
        status: destino,
        reason: motivo.isEmpty ? null : motivo,
        notes: notas.isEmpty ? null : notas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinos = allowedStagesFrom(widget.estadoActual);

    return MpSurface(
      style: MpSurfaceStyle.light,
      child: Builder(
        builder: (context) {
          final s = context.mp;
          return Container(
            decoration: BoxDecoration(
              color: s.bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(MpTokens.radiusXL),
              ),
            ),
            padding: EdgeInsets.only(
              left: MpTokens.screenPadding,
              right: MpTokens.screenPadding,
              top: MpTokens.space16,
              bottom: MediaQuery.of(context).viewInsets.bottom +
                  MpTokens.space24,
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: s.fill,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: MpTokens.space16),
                    Text(
                      'Mover a ${widget.nombreCandidato}',
                      style: MpTokens.h2.copyWith(color: s.text),
                    ),
                    const SizedBox(height: MpTokens.space4),
                    Text(
                      'Ahora está en '
                      '${applicationStageLabel(widget.estadoActual)}.',
                      style: MpTokens.body.copyWith(
                        color: s.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: MpTokens.space16),

                    if (destinos.isEmpty)
                      Text(
                        'Desde esta etapa no hay movimientos disponibles.',
                        style: MpTokens.body.copyWith(color: s.textSecondary),
                      )
                    else
                      for (final destino in destinos) ...[
                        _opcion(destino, s),
                        const SizedBox(height: MpTokens.space8),
                      ],

                    // A `hired` sólo se llega desde `accepted`. En vez de
                    // mostrar una opción apagada sin explicación, se dice por
                    // qué no está.
                    if (requiereOfertaPrevia(widget.estadoActual, 'hired')) ...[
                      const SizedBox(height: MpTokens.space4),
                      Text(
                        'Para marcarlo como contratado primero tiene que '
                        'pasar por Con oferta.',
                        style: MpTokens.micro.copyWith(color: s.textTertiary),
                      ),
                    ],

                    if (_destino != null) ...[
                      const SizedBox(height: MpTokens.space16),
                      MpFieldLabel(
                        _pideMotivo ? 'Motivo (obligatorio)' : 'Motivo',
                      ),
                      const SizedBox(height: MpTokens.space8),
                      MpTextField(
                        controller: _motivo,
                        placeholder: _pideMotivo
                            ? 'Por qué no sigue en el proceso'
                            : 'Opcional',
                        maxLines: 2,
                        counter: '${_motivo.text.length}/240',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: MpTokens.space12),
                      const MpFieldLabel('Notas internas'),
                      const SizedBox(height: MpTokens.space8),
                      MpTextField(
                        controller: _notas,
                        placeholder: 'Sólo las ve tu equipo',
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],

                    const SizedBox(height: MpTokens.space20),
                    MpButton(
                      label: 'Mover de etapa',
                      expand: true,
                      onPressed: _puedeConfirmar ? _confirmar : null,
                    ),
                    const SizedBox(height: MpTokens.space8),
                    MpButton(
                      label: 'Cancelar',
                      variant: MpButtonVariant.ghost,
                      expand: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _opcion(String destino, MpSurfaceStyle s) {
    final elegido = _destino == destino;
    final esDescarte = destino == kApplicationRejected;
    final color = esDescarte ? MpTokens.danger : MpTokens.primary;

    return GestureDetector(
      onTap: () => setState(() => _destino = destino),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MpTokens.space12,
          vertical: MpTokens.space12,
        ),
        decoration: BoxDecoration(
          color: elegido ? color.withValues(alpha: 0.10) : s.fill,
          borderRadius: BorderRadius.circular(MpTokens.radiusMD),
          border: Border.all(
            color: elegido ? color : const Color(0x00000000),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              elegido
                  ? CupertinoIcons.largecircle_fill_circle
                  : CupertinoIcons.circle,
              size: 19,
              color: elegido ? color : s.textTertiary,
            ),
            const SizedBox(width: MpTokens.space12),
            Expanded(
              child: Text(
                applicationStageLabel(destino),
                style: MpTokens.label.copyWith(
                  color: elegido ? color : s.text,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
