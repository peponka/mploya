import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';

import '../../theme/mploya_tokens.dart';

/// Ruta del preview. Sólo se registra en debug (ver `main.dart`).
const String rutaPreviewSalaEntrevista = '/debug/sala-entrevista';

/// PREVIEW LOCAL de la sala de entrevista. **Sólo modo debug.**
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ NO ES UNA SALA REAL Y NO DEBE PARECERLO.                              ║
/// ║                                                                        ║
/// ║ · No crea entrevistas ni escribe una sola fila en Supabase.           ║
/// ║ · No genera notificaciones, preguntas ni informes.                    ║
/// ║ · No usa ids demo: no maneja NINGÚN id, así que no puede entrar al    ║
/// ║   circuito productivo ni por accidente.                               ║
/// ║ · No toca `AgoraCallScreen` ni `EmpresaSalaEntrevistaScreen`, que      ║
/// ║   están congeladas: esto es una pantalla aparte que copia su layout.  ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// PARA QUÉ SIRVE. Permite revisar la sala —encuadre de la cámara local,
/// jerarquía, controles, responsive, overflow— sin necesitar un postulante real
/// ni una videollamada de verdad.
///
/// QUÉ ES REAL Y QUÉ NO, sin ambigüedad:
///   · La cámara local **es real**: sale del paquete `camera`, el mismo que usa
///     `CameraScreen` para grabar los video-pitch. Apagarla apaga de verdad el
///     dispositivo (se ve en el indicador del navegador o del teléfono).
///   · El cuadro remoto **es un placeholder declarado**. No hay nadie del otro
///     lado, y la pantalla lo dice con todas las letras en vez de simular una
///     persona.
///   · El micrófono es un control **sólo visual**. La sala real lo silencia por
///     Agora (`muteLocalAudioStream`), que no funciona en web; el paquete
///     `camera` no expone un mute de preview. Antes que fingir que silencia
///     algo, se rotula.
///   · El estado de conexión está simulado, y también se rotula.
///
/// El layout replica `AgoraCallScreen` —remoto a pantalla completa, cuadro
/// local de 100×140 arriba a la derecha, encabezado con degradado y la fila de
/// tres controles abajo— con los colores del sistema de diseño.
class EmpresaSalaPreviewScreen extends StatefulWidget {
  const EmpresaSalaPreviewScreen({super.key});

  @override
  State<EmpresaSalaPreviewScreen> createState() =>
      _EmpresaSalaPreviewScreenState();
}

enum _EstadoCamara { iniciando, activa, apagada, sinCamara }

class _EmpresaSalaPreviewScreenState extends State<EmpresaSalaPreviewScreen> {
  CameraController? _camara;
  _EstadoCamara _estado = _EstadoCamara.iniciando;
  String? _detalleError;

  bool _micSilenciado = false;
  bool _conectado = false;
  bool _finalizado = false;
  Timer? _temporizador;

  @override
  void initState() {
    super.initState();
    _encenderCamara();
    // Estado de conexión SIMULADO: sirve para ver cómo se comporta el rótulo
    // cuando cambia, no para representar una conexión que no existe.
    _temporizador = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _conectado = true);
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _camara?.dispose();
    super.dispose();
  }

  Future<void> _encenderCamara() async {
    setState(() {
      _estado = _EstadoCamara.iniciando;
      _detalleError = null;
    });

    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _estado = _EstadoCamara.sinCamara;
          _detalleError = 'No hay ninguna cámara disponible en este equipo.';
        });
        return;
      }

      // Frontal si existe, como en la sala real y en la grabación de pitches.
      var indice = camaras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (indice == -1) indice = 0;

      // CON audio: aunque el preview no grabe, tomar la pista de micrófono hace
      // que la sala se comporte como la real y, sobre todo, que se pueda
      // comprobar que al colgar se libera TAMBIÉN el micrófono y no sólo la
      // cámara. Si el permiso de micrófono se niega, se reintenta sin audio en
      // vez de dejar la pantalla sin cámara por algo secundario.
      CameraController controlador;
      try {
        controlador = CameraController(
          camaras[indice],
          ResolutionPreset.medium,
          enableAudio: true,
        );
        await controlador.initialize();
      } catch (_) {
        controlador = CameraController(
          camaras[indice],
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await controlador.initialize();
        if (mounted) {
          setState(() => _detalleError =
              'Sin micrófono (permiso denegado o no disponible): sólo cámara.');
        }
      }

      if (!mounted) {
        await controlador.dispose();
        return;
      }
      setState(() {
        _camara = controlador;
        _estado = _EstadoCamara.activa;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estado = _EstadoCamara.sinCamara;
        _detalleError = '$e';
      });
    }
  }

  /// Suelta la cámara y el micrófono de verdad.
  ///
  /// `CameraController.dispose()` corta el `MediaStream`: detiene TODAS las
  /// pistas —video y audio— y libera el dispositivo, que es lo que apaga el
  /// indicador de cámara del navegador. No alcanza con esconder el widget: el
  /// stream seguiría abierto.
  ///
  /// Se quita el controlador del árbol ANTES de destruirlo, para que ningún
  /// `CameraPreview` intente pintar con un controlador ya liberado.
  Future<void> _liberarMedios() async {
    final c = _camara;
    if (c == null) return;

    if (mounted) {
      setState(() {
        _camara = null;
        _estado = _EstadoCamara.apagada;
      });
    } else {
      _camara = null;
    }
    await c.dispose();
  }

  /// Apaga la cámara de verdad: libera el dispositivo, no esconde el widget.
  Future<void> _alternarCamara() async {
    if (_estado == _EstadoCamara.activa) {
      await _liberarMedios();
      return;
    }
    await _encenderCamara();
  }

  /// Botón rojo de colgar.
  ///
  /// Primero libera cámara y micrófono, y RECIÉN DESPUÉS cambia la pantalla.
  /// No intenta volver atrás: entrando por URL el preview es la ruta raíz y no
  /// hay a dónde ir, pero eso no puede ser excusa para dejar el dispositivo
  /// tomado. Cortar es cortar.
  Future<void> _colgar() async {
    await _liberarMedios();
    _temporizador?.cancel();
    if (!mounted) return;
    setState(() {
      _finalizado = true;
      _conectado = false;
    });
  }

  /// Flecha de volver: libera igual, y vuelve si hay a dónde.
  Future<void> _volver() async {
    await _liberarMedios();
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    _temporizador?.cancel();
    setState(() {
      _finalizado = true;
      _conectado = false;
    });
  }

  Future<void> _reabrir() async {
    setState(() {
      _finalizado = false;
      _conectado = false;
      _detalleError = null;
    });
    _temporizador?.cancel();
    _temporizador = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _conectado = true);
    });
    await _encenderCamara();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: MpTokens.darkBg,
      child: _finalizado
          ? _pantallaFinalizada()
          : Stack(
              fit: StackFit.expand,
              children: [
                _cuadroRemoto(),
                Positioned(top: 96, right: 16, child: _cuadroLocal()),
                Positioned(top: 0, left: 0, right: 0, child: _encabezado()),
                Positioned(left: 0, right: 0, bottom: 40, child: _controles()),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _pieDeAclaraciones(),
                ),
              ],
            ),
    );
  }

  /// Después de colgar. No queda ni un widget de cámara en el árbol.
  Widget _pantallaFinalizada() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: MpTokens.darkElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.phone_down_fill,
                color: MpTokens.darkTextSecondary,
                size: 34,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Preview finalizado',
              style: TextStyle(
                color: MpTokens.darkText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Cámara y micrófono liberados. El indicador de grabación del '
              'navegador tiene que estar apagado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MpTokens.darkTextSecondary,
                fontSize: 13.5,
                height: 1.4,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 26),
            CupertinoButton(
              color: MpTokens.primary,
              borderRadius: BorderRadius.circular(MpTokens.radiusSM),
              onPressed: _reabrir,
              child: const Text('Volver a abrir el preview'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Remoto: placeholder declarado, nunca una persona simulada ──
  Widget _cuadroRemoto() {
    return ColoredBox(
      color: MpTokens.darkCard,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: MpTokens.darkElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: MpTokens.darkBorder, width: 2),
                ),
                child: const Icon(
                  CupertinoIcons.person_crop_square,
                  color: MpTokens.darkTextTertiary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Vista remota de prueba',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MpTokens.darkText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No hay ninguna persona conectada. Este cuadro existe sólo '
                'para revisar el encuadre y la jerarquía de la sala.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MpTokens.darkTextSecondary,
                  fontSize: 13,
                  height: 1.4,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Local: cámara REAL, mismas medidas que la sala ──
  Widget _cuadroLocal() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        height: 140,
        color: MpTokens.darkElevated,
        child: Stack(
          fit: StackFit.expand,
          children: [
            switch (_estado) {
              _EstadoCamara.activa when _camara != null =>
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _camara!.value.previewSize?.height ?? 100,
                    height: _camara!.value.previewSize?.width ?? 140,
                    child: CameraPreview(_camara!),
                  ),
                ),
              _EstadoCamara.iniciando => const Center(
                  child: CupertinoActivityIndicator(color: MpTokens.darkText),
                ),
              _EstadoCamara.apagada => const Center(
                  child: Icon(
                    CupertinoIcons.videocam_circle,
                    color: MpTokens.darkTextTertiary,
                    size: 30,
                  ),
                ),
              _ => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(
                      'Sin cámara',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: MpTokens.darkTextTertiary,
                        fontSize: 11,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
            },
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: const Color(0xCC000810),
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: const Text(
                  'Vos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MpTokens.darkText,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Encabezado ──
  Widget _encabezado() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE6000810), Color(0x00000810)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 44, 16, 28),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              onPressed: _volver,
              child: const Icon(
                CupertinoIcons.chevron_left,
                color: MpTokens.darkText,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Sala de entrevista',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MpTokens.darkText,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _conectado
                              ? MpTokens.success
                              : MpTokens.premium,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _conectado
                              ? 'Conectado · estado simulado'
                              : 'Conectando… · estado simulado',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MpTokens.darkTextSecondary,
                            fontSize: 12,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const _EtiquetaPreview(),
          ],
        ),
      ),
    );
  }

  // ── Controles ──
  Widget _controles() {
    final camaraEncendida = _estado == _EstadoCamara.activa;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _BotonControl(
          icono: _micSilenciado
              ? CupertinoIcons.mic_slash_fill
              : CupertinoIcons.mic_fill,
          activo: !_micSilenciado,
          etiqueta: 'Micrófono',
          onTap: () => setState(() => _micSilenciado = !_micSilenciado),
        ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: _colgar,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: MpTokens.danger,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: MpTokens.danger.withValues(alpha: 0.4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(
              CupertinoIcons.phone_down_fill,
              color: CupertinoColors.white,
              size: 30,
            ),
          ),
        ),
        const SizedBox(width: 24),
        _BotonControl(
          icono: camaraEncendida
              ? CupertinoIcons.video_camera_solid
              : CupertinoIcons.videocam_circle,
          activo: camaraEncendida,
          etiqueta: 'Cámara',
          onTap: _alternarCamara,
        ),
      ],
    );
  }

  // ── Pie: qué es real y qué no ──
  Widget _pieDeAclaraciones() {
    final detalle = _detalleError;

    return Container(
      width: double.infinity,
      color: const Color(0xF2081018),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cámara y micrófono reales · el botón rojo los libera · '
              'cuadro remoto simulado · no se escribe nada en Supabase',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MpTokens.darkTextTertiary,
                fontSize: 10.5,
                height: 1.3,
                decoration: TextDecoration.none,
              ),
            ),
            if (detalle != null) ...[
              const SizedBox(height: 4),
              Text(
                detalle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MpTokens.premium,
                  fontSize: 10.5,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EtiquetaPreview extends StatelessWidget {
  const _EtiquetaPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: MpTokens.premium.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(MpTokens.radiusPill),
        border: Border.all(color: MpTokens.premium.withValues(alpha: 0.5)),
      ),
      child: const Text(
        'PREVIEW',
        style: TextStyle(
          color: MpTokens.premium,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _BotonControl extends StatelessWidget {
  final IconData icono;
  final bool activo;
  final String etiqueta;
  final VoidCallback onTap;

  const _BotonControl({
    required this.icono,
    required this.activo,
    required this.etiqueta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: activo
                  ? MpTokens.darkText.withValues(alpha: 0.18)
                  : MpTokens.darkText,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icono,
              color: activo ? MpTokens.darkText : MpTokens.darkBg,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          etiqueta,
          style: const TextStyle(
            color: MpTokens.darkTextSecondary,
            fontSize: 10.5,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
