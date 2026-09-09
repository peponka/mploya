import 'package:flutter/cupertino.dart';

import '../ds/mploya_ds.dart';

/// Lo que el candidato eligió al responder una oferta.
@immutable
class RespuestaOferta {
  const RespuestaOferta({required this.decision, this.message});

  /// 'accepted' | 'declined' | 'changes_requested' — los mismos valores que
  /// espera `respond_to_job_offer` (migración 051).
  final String decision;
  final String? message;
}

/// Hoja para responder una oferta: aceptar, rechazar o pedir cambios.
///
/// MENSAJE OBLIGATORIO PARA RECHAZAR O PEDIR CAMBIOS. No es una regla de esta
/// pantalla: `respond_to_job_offer` la exige del lado del servidor. Se pide
/// acá antes para no gastar una ida y vuelta con el servidor.
Future<RespuestaOferta?> mostrarRespuestaOferta(
  BuildContext context, {
  required String vacante,
}) {
  return showCupertinoModalPopup<RespuestaOferta>(
    context: context,
    builder: (_) => _RespuestaOfertaSheet(vacante: vacante),
  );
}

class _RespuestaOfertaSheet extends StatefulWidget {
  const _RespuestaOfertaSheet({required this.vacante});

  final String vacante;

  @override
  State<_RespuestaOfertaSheet> createState() => _RespuestaOfertaSheetState();
}

class _RespuestaOfertaSheetState extends State<_RespuestaOfertaSheet> {
  String? _decision;
  final _mensaje = TextEditingController();

  @override
  void dispose() {
    _mensaje.dispose();
    super.dispose();
  }

  bool get _pideMensaje =>
      _decision == 'declined' || _decision == 'changes_requested';

  bool get _puedeConfirmar {
    if (_decision == null) return false;
    if (_pideMensaje && _mensaje.text.trim().isEmpty) return false;
    return true;
  }

  void _confirmar() {
    final decision = _decision;
    if (decision == null) return;
    final mensaje = _mensaje.text.trim();
    Navigator.of(context).pop(
      RespuestaOferta(
        decision: decision,
        message: mensaje.isEmpty ? null : mensaje,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    Text('Responder oferta',
                        style: MpTokens.h2.copyWith(color: s.text)),
                    const SizedBox(height: MpTokens.space4),
                    Text(
                      widget.vacante,
                      style: MpTokens.body
                          .copyWith(color: s.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: MpTokens.space16),

                    _opcion('accepted', 'Aceptar',
                        CupertinoIcons.checkmark_circle, MpTokens.success, s),
                    const SizedBox(height: MpTokens.space8),
                    _opcion('changes_requested', 'Pedir cambios',
                        CupertinoIcons.pencil_circle, MpTokens.primary, s),
                    const SizedBox(height: MpTokens.space8),
                    _opcion('declined', 'Rechazar',
                        CupertinoIcons.xmark_circle, MpTokens.danger, s),

                    if (_pideMensaje) ...[
                      const SizedBox(height: MpTokens.space16),
                      MpFieldLabel(
                        _decision == 'declined'
                            ? 'Motivo (obligatorio)'
                            : 'Qué te gustaría cambiar (obligatorio)',
                      ),
                      MpTextField(
                        controller: _mensaje,
                        placeholder: _decision == 'declined'
                            ? 'Por qué no te sirve esta oferta'
                            : 'Ej: el salario o la fecha de inicio',
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],

                    const SizedBox(height: MpTokens.space20),
                    MpButton(
                      label: 'Confirmar',
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

  Widget _opcion(
    String valor,
    String etiqueta,
    IconData icon,
    Color color,
    MpSurfaceStyle s,
  ) {
    final elegido = _decision == valor;
    return GestureDetector(
      onTap: () => setState(() => _decision = valor),
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
            Icon(icon, size: 19, color: elegido ? color : s.textTertiary),
            const SizedBox(width: MpTokens.space12),
            Expanded(
              child: Text(
                etiqueta,
                style: MpTokens.label
                    .copyWith(color: elegido ? color : s.text, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
