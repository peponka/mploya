import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../agora_call_screen.dart';
import '../chat_inmail_screen.dart';
import 'empresa_candidato_perfil_screen.dart';
import 'empresa_entrevistas_data.dart';

/// Link determinista de la sala de una entrevista.
///
/// Se deriva del id de la entrevista, que las dos partes conocen: así la
/// empresa y el candidato llegan a la MISMA sala sin necesidad de un servicio
/// de reuniones aparte. Es el mismo dominio que ya usa el fallback web de
/// [AgoraCallScreen].
String salaDeEntrevista(String interviewId) =>
    'https://meet.jit.si/mploya-entrevista-$interviewId';

/// Guarda el link de la sala en `scheduled_interviews.meeting_url`.
///
/// Sin esto la sala existiría sólo del lado de la empresa: al persistirlo, el
/// candidato ve el mismo link en su propia agenda.
Future<bool> guardarSala(String interviewId, String url) async {
  try {
    await Supabase.instance.client
        .from('scheduled_interviews')
        .update({'meeting_url': url}).eq('id', interviewId);
    return true;
  } catch (e) {
    debugPrint('sala entrevista · update meeting_url: $e');
    return false;
  }
}

/// Sala de entrevista de la Empresa.
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 11/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// DERIVACIÓN CONTROLADA de `entrevistas video.png` (Pantalla de entrevista en
/// curso), con `entrevistas nuevas.png` y `agenda inteligente.png` de apoyo
/// para el encabezado y los estados.
///
/// LO QUE SÍ ES REAL. La videollamada existe en el proyecto y se reutiliza tal
/// cual: [AgoraCallScreen] pide su token a la Edge Function `agora-token` y en
/// web embebe Jitsi. Esta pantalla no reimplementa nada de eso: prepara la
/// entrevista y entra.
///
/// LO QUE SE OMITE, y por qué. El PNG muestra, encima del video: "IA Score en
/// vivo 88", una barra de transcripción en tiempo real, notas privadas
/// colaborativas, grabación y cinco competencias puntuadas sobre 100. Nada de
/// eso existe: no hay transcripción en vivo, ni scoring durante la llamada, ni
/// tabla de notas. Dibujar esos controles sería prometer funciones inexistentes
/// sobre una llamada que sí funciona, que es la peor mezcla posible.
class EmpresaSalaEntrevistaScreen extends StatefulWidget {
  final EntrevistaEmpresa entrevista;

  /// Nombre con el que entra la empresa a la sala.
  final String nombreEmpresa;

  /// Sólo para los golden tests: evita tocar la red al montar.
  final bool previewMode;

  const EmpresaSalaEntrevistaScreen({
    super.key,
    required this.entrevista,
    this.nombreEmpresa = 'Empresa',
    this.previewMode = false,
  });

  @override
  State<EmpresaSalaEntrevistaScreen> createState() =>
      _EmpresaSalaEntrevistaScreenState();
}

class _EmpresaSalaEntrevistaScreenState
    extends State<EmpresaSalaEntrevistaScreen> {
  late String? _meetingUrl = widget.entrevista.meetingUrl;
  bool _creando = false;
  String? _aviso;

  static const _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  EntrevistaEmpresa get _e => widget.entrevista;

  bool get _esAgenda => _e.fuente == FuenteEntrevista.agenda;

  String get _cuando {
    final c = _e.cuando;
    if (c == null) return 'Sin fecha agendada';
    final h = c.hour.toString().padLeft(2, '0');
    final m = c.minute.toString().padLeft(2, '0');
    return '${c.day} de ${_meses[c.month - 1]} · $h:$m';
  }

  /// Minutos hasta el inicio. Negativo si ya empezó. Null sin fecha.
  int? get _minutosPara {
    final c = _e.cuando;
    if (c == null) return null;
    return c.difference(DateTime.now()).inMinutes;
  }

  String get _estadoLegible => switch (_e.estado.toLowerCase()) {
        'confirmed' => 'Confirmada',
        'pending' => 'Pendiente',
        'cancelled' => 'Cancelada',
        'completed' => 'Completada',
        'in_progress' => 'En curso',
        _ => _e.estado,
      };

  MpStatus get _estadoChip => switch (_e.estado.toLowerCase()) {
        'confirmed' => MpStatus.active,
        'completed' => MpStatus.finished,
        'cancelled' => MpStatus.danger,
        'in_progress' => MpStatus.info,
        _ => MpStatus.neutral,
      };

  Future<void> _crearSala() async {
    if (_creando || widget.previewMode) return;
    setState(() {
      _creando = true;
      _aviso = null;
    });

    final url = salaDeEntrevista(_e.id);
    final ok = await guardarSala(_e.id, url);
    if (!mounted) return;

    setState(() {
      _creando = false;
      if (ok) {
        _meetingUrl = url;
        _aviso = 'Sala creada. El candidato ya la ve en su agenda.';
      } else {
        _aviso = 'No pudimos guardar la sala. Probá de nuevo en un momento.';
      }
    });
  }

  void _entrar() {
    if (widget.previewMode) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => AgoraCallScreen(
          channelName: 'mploya-entrevista-${_e.id}',
          displayName: widget.nombreEmpresa,
          otherName: _e.candidato,
        ),
      ),
    );
  }

  Future<void> _abrirEnNavegador() async {
    final url = _meetingUrl;
    if (url == null || widget.previewMode) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.dark,
      child: CupertinoPageScaffold(
        backgroundColor: MpTokens.darkBg,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MpTokens.screenPadding,
                  MpTokens.space8,
                  MpTokens.screenPadding,
                  0,
                ),
                child: MpHeader(
                  title: 'Sala de entrevista',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        MpTokens.screenPadding,
                        MpTokens.space16,
                        MpTokens.screenPadding,
                        MpTokens.space24,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(_cuerpo()),
                      ),
                    ),
                  ],
                ),
              ),
              _barraAcciones(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _cuerpo() {
    return [
      _fichaCandidato(),
      const SizedBox(height: MpTokens.space16),
      _cuandoYEstado(),
      if (_aviso != null) ...[
        const SizedBox(height: MpTokens.space16),
        _bannerAviso(),
      ],
      const SizedBox(height: MpTokens.space16),
      _sala(),
      const SizedBox(height: MpTokens.space24),
      _antesDeEmpezar(),
    ];
  }

  Widget _fichaCandidato() {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusXL,
      onTap: _e.candidatoId == null || widget.previewMode
          ? null
          : () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => EmpresaCandidatoPerfilScreen(
                    candidatoId: _e.candidatoId!,
                  ),
                ),
              ),
      child: Row(
        children: [
          MpAvatar(
            name: _e.candidato,
            size: 58,
            image: _e.candidatoAvatar == null
                ? null
                : NetworkImage(_e.candidatoAvatar!),
          ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _e.candidato,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MpTokens.h2.copyWith(color: s.text, fontSize: 18),
                ),
                if (_e.candidatoHeadline != null)
                  Text(
                    _e.candidatoHeadline!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MpTokens.caption.copyWith(color: s.textSecondary),
                  ),
                if (_e.vacante != null) ...[
                  const SizedBox(height: MpTokens.space8),
                  MpTypeChip(
                    label: _e.vacante!,
                    color: MpTokens.primary,
                    icon: CupertinoIcons.briefcase,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cuandoYEstado() {
    final s = context.mp;
    final minutos = _minutosPara;

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MpIconTile(
                icon: CupertinoIcons.calendar,
                color: MpTokens.catBlue,
                size: 42,
              ),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _cuando,
                      style: MpTokens.label.copyWith(color: s.text),
                    ),
                    if (_e.duracionMinutos != null)
                      Text(
                        '${_e.duracionMinutos} minutos',
                        style: MpTokens.micro.copyWith(
                          color: s.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              MpStatusBadge(label: _estadoLegible, status: _estadoChip),
            ],
          ),
          // La cuenta regresiva sale de la hora agendada, no de un temporizador
          // inventado: si no hay fecha, no se muestra.
          if (minutos != null && !_e.cancelada) ...[
            const SizedBox(height: MpTokens.space12),
            Container(height: 1, color: s.border),
            const SizedBox(height: MpTokens.space12),
            Text(
              minutos > 60
                  ? 'Empieza en ${(minutos / 60).floor()} h ${minutos % 60} min'
                  : minutos > 0
                      ? 'Empieza en $minutos min'
                      : minutos > -120
                          ? 'Ya debería haber empezado'
                          : 'Esta entrevista ya pasó',
              style: MpTokens.caption.copyWith(color: s.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bannerAviso() {
    final esError = _aviso!.startsWith('No pudimos');

    return MpBanner(
      icon: esError
          ? CupertinoIcons.exclamationmark_triangle
          : CupertinoIcons.checkmark_circle,
      title: esError ? 'No se pudo' : 'Listo',
      message: _aviso!,
      color: esError ? MpTokens.danger : MpTokens.success,
      onDismiss: () => setState(() => _aviso = null),
    );
  }

  Widget _sala() {
    final s = context.mp;

    if (!_esAgenda) {
      // Las entrevistas con IA son asíncronas: el candidato graba cuando puede.
      // No hay sala en vivo a la que entrar.
      return MpCard(
        radius: MpTokens.radiusXL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entrevista con IA',
              style: MpTokens.title.copyWith(color: s.text),
            ),
            const SizedBox(height: MpTokens.space4),
            Text(
              'Es asíncrona: el candidato graba sus respuestas cuando puede. '
              'No hay una sala en vivo para esta entrevista.',
              style: MpTokens.body.copyWith(
                color: s.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MpIconTile(
                icon: CupertinoIcons.videocam_fill,
                color: _meetingUrl == null
                    ? MpTokens.premium
                    : MpTokens.success,
                size: 42,
              ),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _meetingUrl == null ? 'Todavía sin sala' : 'Sala lista',
                      style: MpTokens.title.copyWith(
                        color: s.text,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      _meetingUrl == null
                          ? 'Creá la sala y el candidato la va a ver en su '
                              'agenda.'
                          : 'La misma sala para vos y para el candidato.',
                      style: MpTokens.micro.copyWith(color: s.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_meetingUrl != null) ...[
            const SizedBox(height: MpTokens.space12),
            Container(
              padding: const EdgeInsets.all(MpTokens.space12),
              decoration: BoxDecoration(
                color: s.fill,
                borderRadius: BorderRadius.circular(MpTokens.radiusMD),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _meetingUrl!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MpTokens.micro.copyWith(color: s.textSecondary),
                    ),
                  ),
                  const SizedBox(width: MpTokens.space8),
                  GestureDetector(
                    onTap: _abrirEnNavegador,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      CupertinoIcons.arrow_up_right_square,
                      size: 17,
                      color: s.accent,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: MpTokens.space12),
            MpButton(
              label: 'Crear sala',
              icon: CupertinoIcons.add_circled,
              variant: MpButtonVariant.outline,
              expand: true,
              loading: _creando,
              onPressed: _crearSala,
            ),
          ],
        ],
      ),
    );
  }

  /// Lo único que se puede afirmar antes de una entrevista: qué hay disponible
  /// del candidato. Nada de puntajes ni predicciones.
  Widget _antesDeEmpezar() {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Antes de empezar',
            style: MpTokens.title.copyWith(color: s.text),
          ),
          const SizedBox(height: MpTokens.space12),
          MpListRow(
            leading: const MpIconTile(
              icon: CupertinoIcons.person,
              color: MpTokens.primary,
              size: 38,
            ),
            title: 'Ver el perfil del candidato',
            subtitle: 'Habilidades, experiencia y postulación.',
            onTap: _e.candidatoId == null || widget.previewMode
                ? null
                : () => Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => EmpresaCandidatoPerfilScreen(
                          candidatoId: _e.candidatoId!,
                        ),
                      ),
                    ),
          ),
          MpListRow(
            leading: const MpIconTile(
              icon: CupertinoIcons.chat_bubble,
              color: MpTokens.catBlue,
              size: 38,
            ),
            title: 'Escribirle',
            subtitle: 'Confirmá o reprogramá por mensaje.',
            onTap: _e.candidatoId == null || widget.previewMode
                ? null
                : () => Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => ChatInmailScreen(
                          targetUser: NexUser.fromJson({
                            'id': _e.candidatoId,
                            'name': _e.candidato,
                            'headline': _e.candidatoHeadline ?? '',
                            'avatar_url': _e.candidatoAvatar,
                            'tags': const <String>[],
                          }),
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _barraAcciones() {
    final s = context.mp;
    final puedeEntrar = _esAgenda && !_e.cancelada;

    return Container(
      padding: EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        MpTokens.space12,
        MpTokens.screenPadding,
        MediaQuery.of(context).padding.bottom + MpTokens.space12,
      ),
      decoration: BoxDecoration(
        color: s.card,
        border: Border(top: BorderSide(color: s.border)),
      ),
      child: puedeEntrar
          ? MpButton(
              label: 'Entrar a la sala',
              icon: CupertinoIcons.videocam_fill,
              size: MpButtonSize.large,
              expand: true,
              onPressed: _entrar,
            )
          : Text(
              _e.cancelada
                  ? 'Esta entrevista está cancelada.'
                  : 'Esta entrevista no tiene sala en vivo.',
              textAlign: TextAlign.center,
              style: MpTokens.caption.copyWith(color: s.textSecondary),
            ),
    );
  }
}

