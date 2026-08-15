import 'package:flutter/cupertino.dart';
import '../utils/user_columns.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/mploya_tokens.dart';
import '../models/models.dart';
import '../services/social_service.dart';
import '../services/error_handler.dart';
import '../widgets/candidato/cand_perfil.dart' show CandMetrica;
import '../widgets/candidato/cand_red.dart';
import '../widgets/candidato/cand_ui.dart';
import 'profile_screen.dart';
import 'messaging_screen.dart';
import 'explore_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// RED — la agenda del propio candidato.
///
/// Composición aprobada de la Tanda 1:
/// `design-reference/Candidato_Tanda1_Final/*/03_red.png`.
///
/// Reemplaza a la pantalla «Matches», que explicaba el producto en vez de
/// mostrar la red: tenía tarjeta de explicación, «Primeros pasos» con badges
/// decorativos y un carrusel de recomendados sin jerarquía. Las tres secciones
/// —Conexiones, Solicitudes y Nexus— son ahora pestañas reales.
///
/// Los datos siguen siendo los mismos y salen de los mismos lugares:
/// `connections` para conexiones y solicitudes, `users` para las fichas y el
/// RPC de recomendados para Nexus.
/// ─────────────────────────────────────────────────────────────────────────────

/// Datos ya resueltos para el render aislado. Mismo patrón que
/// `JobsPreviewData`: si llega, la pantalla NO consulta Supabase.
@immutable
class NetworkPreviewData {
  const NetworkPreviewData({
    this.conexiones = const [],
    this.recomendados = const [],
    this.solicitudes = const [],
    this.personas = const [],
  });

  final List<NexUser> conexiones;
  final List<Map<String, dynamic>> recomendados;

  /// Filas de `connections` con `status = 'pending'`.
  final List<Map<String, dynamic>> solicitudes;

  /// Filas de `users` para resolver el autor de cada solicitud sin consultar.
  final List<Map<String, dynamic>> personas;
}

/// Las tres secciones de la pantalla.
enum _Seccion { conexiones, solicitudes, nexus }

class NetworkScreen extends StatefulWidget {
  /// Sólo lo usan los tests y el generador de capturas. En producción es
  /// `null` y el camino de datos es el real.
  final NetworkPreviewData? previewData;

  const NetworkScreen({super.key, this.previewData});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  // `late`: `Supabase.instance.client` LANZA si Supabase no está inicializado,
  // y un inicializador de campo se evalúa al construir el State.
  late final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  List<Map<String, dynamic>>? _recommended;
  List<NexUser>? _connections;
  bool _loadingConnections = true;

  _Seccion _seccion = _Seccion.conexiones;
  String _busqueda = '';
  final TextEditingController _buscador = TextEditingController();

  /// Persona abierta en el panel de detalle de desktop.
  String? _seleccionada;

  /// Solicitudes que están respondiéndose ahora mismo.
  final Set<String> _respondiendo = {};

  @override
  void initState() {
    super.initState();
    final preview = widget.previewData;
    if (preview != null) {
      // Render aislado: datos ya resueltos, sin tocar la red.
      _connections = preview.conexiones;
      _recommended = preview.recomendados;
      _loadingConnections = false;
      return;
    }
    _loadData();
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  // ── ÚNICOS PUNTOS DE BIFURCACIÓN preview / producción ───────────────────
  // Todo acceso a datos de esta pantalla pasa por acá. Con `previewData == null`
  // el camino es exactamente el productivo.

  /// Solicitudes pendientes. En producción es un stream en vivo; en render
  /// aislado, un stream de un solo valor, sin websocket que cerrar.
  Stream<List<Map<String, dynamic>>> get _solicitudesStream {
    final preview = widget.previewData;
    if (preview != null) return Stream.value(preview.solicitudes);
    return SocialService.instance.pendingRequestsStream;
  }

  /// Ficha mínima de quien envió una solicitud.
  Future<Map<String, dynamic>?> _perfilBreve(String userId) {
    final preview = widget.previewData;
    if (preview != null) {
      return Future.value(
        preview.personas.cast<Map<String, dynamic>?>().firstWhere(
          (p) => p?['id'] == userId,
          orElse: () => null,
        ),
      );
    }
    return _supabase
        .from('users')
        .select('name, avatar_url, headline')
        .eq('id', userId)
        .maybeSingle();
  }

  /// Ficha completa para las sugerencias de Nexus.
  Future<Map<String, dynamic>?> _perfilCompleto(String userId) {
    final preview = widget.previewData;
    if (preview != null) {
      return Future.value(
        preview.personas.cast<Map<String, dynamic>?>().firstWhere(
          (p) => p?['id'] == userId,
          orElse: () => null,
        ),
      );
    }
    return _supabase
        .from('users')
        .select(kUserColumns)
        .eq('id', userId)
        .maybeSingle();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadRecommended(), _loadConnections()]);
  }

  Future<void> _loadRecommended() async {
    final results = await SocialService.instance.getRecommendedUsers(limit: 20);
    if (mounted) setState(() => _recommended = results);
  }

  Future<void> _loadConnections() async {
    setState(() => _loadingConnections = true);
    try {
      final uid = _uid;
      if (uid == null) {
        if (mounted) {
          setState(() {
            _connections = [];
            _loadingConnections = false;
          });
        }
        return;
      }

      final rows = await _supabase
          .from('connections')
          .select('requester_id, addressee_id')
          .or('requester_id.eq.$uid,addressee_id.eq.$uid')
          .eq('status', 'accepted');

      final otherIds = rows
          .map<String>((r) {
            final req = r['requester_id']?.toString() ?? '';
            final add = r['addressee_id']?.toString() ?? '';
            return req == uid ? add : req;
          })
          .where((id) => id.isNotEmpty)
          .toList();

      if (otherIds.isEmpty) {
        if (mounted) {
          setState(() {
            _connections = [];
            _loadingConnections = false;
          });
        }
        return;
      }

      final users =
          await _supabase.from('users').select(kUserColumns).inFilter('id', otherIds);
      if (mounted) {
        setState(() {
          _connections = users.map((r) => NexUser.fromJson(r)).toList();
          _loadingConnections = false;
        });
      }
    } catch (e) {
      debugPrint('❌ _loadConnections: $e');
      if (mounted) {
        setState(() {
          _connections = [];
          _loadingConnections = false;
        });
      }
    }
  }

  /// Acepta o ignora una solicitud. Es la misma llamada que hacía la pantalla
  /// anterior; sólo cambió quién la dispara.
  Future<void> _responder(String requesterId, String accion) async {
    if (widget.previewData != null) return;
    setState(() => _respondiendo.add(requesterId));
    await MployaErrorHandler.instance.wrapAsync(
      context,
      () => SocialService.instance.respondConnection(requesterId, accion),
      successMessage:
          accion == 'accept' ? 'Conexión aceptada ✅' : 'Solicitud ignorada',
      errorMessage: 'No se pudo procesar',
    );
    if (!mounted) return;
    setState(() => _respondiendo.remove(requesterId));
    await _loadConnections();
  }

  // ── Traducción a lo que dibujan los componentes ─────────────────────────

  CandPersonaVista _deUsuario(NexUser u) => CandPersonaVista(
        id: u.id,
        nombre: u.name,
        titulo: u.headline,
        ciudad: (u.location ?? '').trim(),
        avatarUrl: u.avatarUrl,
        verificado: u.isVerified,
        etiquetas: u.skills.where((s) => s.trim().isNotEmpty).take(6).toList(),
      );

  CandPersonaVista _deFila(String id, Map<String, dynamic>? fila) =>
      CandPersonaVista(
        id: id,
        nombre: fila?['name']?.toString() ?? 'Usuario',
        titulo: fila?['headline']?.toString() ?? '',
        ciudad: fila?['city']?.toString() ?? fila?['location']?.toString() ?? '',
        avatarUrl: fila?['avatar_url']?.toString(),
        verificado: fila?['is_verified'] == true,
      );

  List<NexUser> get _conexionesFiltradas {
    final todas = _connections ?? const <NexUser>[];
    if (_busqueda.trim().isEmpty) return todas;
    final q = _busqueda.trim().toLowerCase();
    return todas
        .where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.headline.toLowerCase().contains(q))
        .toList();
  }

  // ── Acciones ────────────────────────────────────────────────────────────

  void _abrirPerfil(NexUser u) => Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => ProfileScreen(user: u)),
      );

  void _abrirChat(NexUser u) => Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => ChatDetailScreen(otherUser: u)),
      );

  void _abrirExplorar() => Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const ExploreScreen()),
      );

  // ── Construcción ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: MpTokens.lightBg,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _solicitudesStream,
        builder: (context, snap) {
          final pendientes = snap.data ?? const <Map<String, dynamic>>[];
          return switch (candFormatoDe(context)) {
            CandFormato.desktop => _desktop(pendientes),
            CandFormato.tablet => _ancho(pendientes, padding: 24, columnas: 2),
            CandFormato.mobile => _ancho(pendientes, padding: 20, columnas: 1),
          };
        },
      ),
    );
  }

  String _subtitulo(int pendientes) {
    final n = _connections?.length ?? 0;
    final conexiones = '$n ${n == 1 ? 'conexión' : 'conexiones'}';
    if (pendientes == 0) return conexiones;
    return '$conexiones · $pendientes '
        '${pendientes == 1 ? 'solicitud' : 'solicitudes'}';
  }

  List<Widget> _chipsSeccion(int pendientes) {
    final n = _connections?.length ?? 0;
    Widget chip(String texto, _Seccion s) => CandChip(
          texto,
          activo: _seccion == s,
          onTap: () => setState(() => _seccion = s),
        );
    return [
      chip('Conexiones · $n', _Seccion.conexiones),
      chip('Solicitudes · $pendientes', _Seccion.solicitudes),
      chip('Nexus', _Seccion.nexus),
    ];
  }

  /// Mobile y tablet: una columna con el selector arriba.
  Widget _ancho(
    List<Map<String, dynamic>> pendientes, {
    required double padding,
    required int columnas,
  }) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(height: candTopInset(context)),
        CandEncabezado(
          titulo: 'Red',
          subtitulo: _subtitulo(pendientes.length),
          padding: EdgeInsets.fromLTRB(padding, 12, padding, 12),
          acciones: [
            CandAccion(
              icono: CupertinoIcons.person_badge_plus,
              onTap: _abrirExplorar,
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 0, padding, 12),
          child: CandBuscador(
            controller: _buscador,
            placeholder: 'Buscar en tu red',
            onChanged: (v) => setState(() => _busqueda = v),
          ),
        ),
        CandFilaChips(padding: padding, children: _chipsSeccion(pendientes.length)),
        const SizedBox(height: 14),
        ..._contenido(pendientes, padding: padding, columnas: columnas),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _desktop(List<Map<String, dynamic>> pendientes) {
    final conexiones = _conexionesFiltradas;
    final NexUser? elegida = _elegida(conexiones);

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 26, 14, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: CandTituloDesktop(
                      'Red',
                      subtitulo: _subtitulo(pendientes.length),
                    ),
                  ),
                  CandBoton(
                    'Invitar contactos',
                    icono: CupertinoIcons.person_badge_plus,
                    secundario: true,
                    onTap: _abrirExplorar,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              CandBuscador(
                controller: _buscador,
                placeholder: 'Buscar en tu red',
                onChanged: (v) => setState(() => _busqueda = v),
              ),
              const SizedBox(height: 14),
              CandFilaChips(padding: 0, children: _chipsSeccion(pendientes.length)),
              const SizedBox(height: 18),
              ..._contenido(pendientes, padding: 0, columnas: 2),
            ],
          ),
        ),
        CandDetallePersona(
          persona: elegida == null ? null : _deUsuario(elegida),
          metricas: elegida == null ? const [] : _metricasDe(elegida),
          onMensaje: elegida == null ? null : () => _abrirChat(elegida),
          onVerPerfil: elegida == null ? null : () => _abrirPerfil(elegida),
        ),
      ],
    );
  }

  /// La conexión abierta en el panel de detalle: la elegida, o la primera de la
  /// lista para que el panel no arranque vacío.
  NexUser? _elegida(List<NexUser> conexiones) {
    for (final u in conexiones) {
      if (u.id == _seleccionada) return u;
    }
    return conexiones.isEmpty ? null : conexiones.first;
  }

  /// Métricas de la ficha: sólo lo que la fila de `users` trae de verdad.
  List<CandMetrica> _metricasDe(NexUser u) => [
        CandMetrica('${u.connections}', 'Conexiones'),
        CandMetrica('${u.skills.length}', 'Skills'),
        if (u.matchPercentage > 0)
          CandMetrica('${u.matchPercentage.round()}%', 'Afinidad')
        else
          CandMetrica(u.isVerified ? 'Sí' : 'No', 'Verificado'),
      ];

  // ── Secciones ───────────────────────────────────────────────────────────

  List<Widget> _contenido(
    List<Map<String, dynamic>> pendientes, {
    required double padding,
    required int columnas,
  }) {
    return switch (_seccion) {
      _Seccion.solicitudes => _seccionSolicitudes(pendientes, padding, columnas),
      _Seccion.nexus => _seccionNexus(padding, columnas),
      _Seccion.conexiones => [
          if (pendientes.isNotEmpty) ...[
            ..._seccionSolicitudes(pendientes, padding, columnas, resumida: true),
            const SizedBox(height: 6),
          ],
          _bannerNexus(padding),
          Padding(
            padding: EdgeInsets.fromLTRB(padding, 18, padding, 10),
            child: const CandTitulo('Tus conexiones'),
          ),
          ..._grillaConexiones(padding, columnas),
        ],
    };
  }

  List<Widget> _seccionSolicitudes(
    List<Map<String, dynamic>> pendientes,
    double padding,
    int columnas, {
    bool resumida = false,
  }) {
    if (pendientes.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: const CandVacio(
            icono: CupertinoIcons.person_badge_plus,
            titulo: 'No tenés solicitudes',
            detalle: 'Cuando alguien quiera conectar con vos, va a aparecer acá.',
          ),
        ),
      ];
    }

    final visibles = resumida ? pendientes.take(2).toList() : pendientes;

    Widget tarjeta(Map<String, dynamic> req) {
      final requesterId = req['requester_id']?.toString() ?? '';
      return FutureBuilder<Map<String, dynamic>?>(
        future: _perfilBreve(requesterId),
        builder: (context, snap) => CandTarjetaSolicitud(
          persona: _deFila(requesterId, snap.data),
          cargando: _respondiendo.contains(requesterId),
          onAceptar: () => _responder(requesterId, 'accept'),
          onIgnorar: () => _responder(requesterId, 'reject'),
        ),
      );
    }

    return [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: Row(
          children: [
            const CandTitulo('Solicitudes'),
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
            const Spacer(),
            if (resumida && pendientes.length > 2)
              GestureDetector(
                onTap: () => setState(() => _seccion = _Seccion.solicitudes),
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'Ver todas (${pendientes.length})',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: MpTokens.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      ..._enGrilla(
        visibles.map(tarjeta).toList(),
        padding: padding,
        columnas: columnas,
      ),
    ];
  }

  Widget _bannerNexus(double padding) {
    final sugeridos = _recommended ?? const <Map<String, dynamic>>[];
    if (sugeridos.isEmpty) return const SizedBox.shrink();

    final ids = sugeridos
        .take(3)
        .map((r) => r['user_id']?.toString() ?? r['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    return FutureBuilder<List<Map<String, dynamic>?>>(
      future: Future.wait(ids.map(_perfilBreve)),
      builder: (context, snap) {
        final avatares = <CandPersonaVista>[];
        final filas = snap.data;
        if (filas != null) {
          for (var i = 0; i < ids.length && i < filas.length; i++) {
            avatares.add(_deFila(ids[i], filas[i]));
          }
        }
        return CandBannerNexus(
          padding: padding,
          titulo: 'Nexus encontró ${sugeridos.length} '
              '${sugeridos.length == 1 ? 'persona afín' : 'personas afines'}',
          detalle:
              'Sugerencias calculadas sobre tu perfil, tus skills y tu red actual.',
          avatares: avatares,
          onVer: () => setState(() => _seccion = _Seccion.nexus),
        );
      },
    );
  }

  List<Widget> _grillaConexiones(double padding, int columnas) {
    if (_loadingConnections) {
      return [
        const CandCargandoLista(
          cantidad: 3,
          padding: EdgeInsets.symmetric(horizontal: 20),
        ),
      ];
    }

    final conexiones = _conexionesFiltradas;
    if (conexiones.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: CandVacio(
            icono: CupertinoIcons.person_2,
            titulo: _busqueda.trim().isEmpty
                ? 'Todavía no tenés conexiones'
                : 'Nadie coincide con esa búsqueda',
            detalle: _busqueda.trim().isEmpty
                ? 'Cuando alguien acepte tu solicitud, va a aparecer acá.'
                : 'Probá con otro nombre o con el puesto que buscás.',
            accion: _busqueda.trim().isEmpty ? 'Descubrir gente' : null,
            onAccion: _abrirExplorar,
          ),
        ),
      ];
    }

    return _enGrilla(
      [
        for (final u in conexiones)
          CandTarjetaPersona(
            persona: _deUsuario(u),
            seleccionada: _seleccionada == u.id,
            onTap: () {
              if (candFormatoDe(context) == CandFormato.desktop) {
                setState(() => _seleccionada = u.id);
              } else {
                _abrirPerfil(u);
              }
            },
            onMensaje: () => _abrirChat(u),
          ),
      ],
      padding: padding,
      columnas: columnas,
    );
  }

  List<Widget> _seccionNexus(double padding, int columnas) {
    final sugeridos = _recommended;

    if (sugeridos == null) {
      return [
        const CandCargandoLista(
          cantidad: 3,
          padding: EdgeInsets.symmetric(horizontal: 20),
        ),
      ];
    }

    if (sugeridos.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: CandVacio(
            icono: CupertinoIcons.bolt_fill,
            titulo: 'Nexus todavía no tiene sugerencias',
            detalle:
                'Completá tus skills y tu experiencia para que pueda encontrar '
                'gente afín.',
            accion: 'Explorar',
            onAccion: _abrirExplorar,
          ),
        ),
      ];
    }

    Widget tarjeta(Map<String, dynamic> r) {
      final id = r['user_id']?.toString() ?? r['id']?.toString() ?? '';
      return FutureBuilder<Map<String, dynamic>?>(
        future: _perfilCompleto(id),
        builder: (context, snap) {
          final fila = snap.data;
          if (fila == null) {
            return const CandTarjeta(
              padding: EdgeInsets.all(13),
              child: Row(
                children: [
                  CandSkeleton(ancho: 46, alto: 46, radio: 23),
                  SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CandSkeleton(ancho: 120, alto: 14),
                        SizedBox(height: 7),
                        CandSkeleton(ancho: 80, alto: 12),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          final u = NexUser.fromJson(fila);
          return CandTarjetaPersona(
            persona: _deUsuario(u),
            seleccionada: _seleccionada == u.id,
            onTap: () {
              if (candFormatoDe(context) == CandFormato.desktop) {
                setState(() => _seleccionada = u.id);
              } else {
                _abrirPerfil(u);
              }
            },
            onMensaje: () => _abrirChat(u),
          );
        },
      );
    }

    return [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: const CandTitulo('Sugerencias de Nexus'),
      ),
      const SizedBox(height: 10),
      ..._enGrilla(
        sugeridos.map(tarjeta).toList(),
        padding: padding,
        columnas: columnas,
      ),
    ];
  }

  /// Coloca las tarjetas en una o dos columnas según el formato.
  List<Widget> _enGrilla(
    List<Widget> tarjetas, {
    required double padding,
    required int columnas,
  }) {
    if (tarjetas.isEmpty) return const [];

    if (columnas == 1) {
      return [
        for (final t in tarjetas)
          Padding(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, 10),
            child: t,
          ),
      ];
    }

    return [
      for (var i = 0; i < tarjetas.length; i += 2)
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 0, padding, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: tarjetas[i]),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < tarjetas.length
                    ? tarjetas[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
    ];
  }
}
