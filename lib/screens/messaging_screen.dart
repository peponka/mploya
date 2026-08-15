import 'dart:ui';
import '../utils/user_columns.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
// Material widgets (SliverAppBar, Colors, Icons) have no Cupertino equivalent
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../theme/mploya_tokens.dart';
import '../models/models.dart';
import '../widgets/candidato/cand_mensajes.dart';
import '../widgets/candidato/cand_ui.dart';
import '../widgets/nex_avatar.dart';
import '../widgets/mploya_toast.dart';
import '../services/chat_service.dart';
import '../services/content_moderation_service.dart';
import '../utils/time_utils.dart';
import '../utils/headhunter_candidate_privacy.dart';
import 'agora_call_screen.dart';
import 'headhunter/headhunter_interviews_screen.dart';
import 'profile_screen.dart';
import 'scheduling_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MessagingScreen — inbox & matches reales (Premium "No-Line" Theme)
// ─────────────────────────────────────────────────────────────────────────────

/// Datos ya resueltos para el modo preview local. Mismo patrón que
/// `JobsPreviewData`: si llega, la pantalla NO consulta Supabase ni abre
/// streams en tiempo real.
@immutable
class MessagingPreviewData {
  const MessagingPreviewData({
    this.conexiones = const [],
    this.usuarios = const [],
    this.mensajes = const [],
    this.viewerAccountType = 'candidato',
  });

  final List<Map<String, dynamic>> conexiones;
  final List<Map<String, dynamic>> usuarios;
  final List<Map<String, dynamic>> mensajes;
  final String viewerAccountType;
}

class MessagingScreen extends StatefulWidget {
  /// Sólo lo usa `lib/preview/`. En producción es `null`.
  final MessagingPreviewData? previewData;

  const MessagingScreen({super.key, this.previewData});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  // ── Search ──
  String _searchQuery = '';
  // ── Filtro de conversaciones (chips: Todos / Talento Match / No leídos) ──
  String _convFilter = 'todos';
  // ── Panel maestro-detalle web: conversación seleccionada ──
  NexUser? _selectedUser;

  // Los seis usuarios demo y el avatar de "nuevo match" se eliminaron: la
  // bandeja vacia los mostraba como si fueran conversaciones reales.
  // `_demoMessagesMap` queda como codigo inalcanzable -ningun usuario `demo_`
  // se renderiza ni se puede seleccionar- y se retira aparte, para no tocar
  // en el mismo pase el camino real del chat.

  static final Map<String, List<Map<String, dynamic>>> _demoMessagesMap = {
    'demo_elena': [
      {'text': 'Hola Elena! Vi tu portafolio y me encantó tu estilo visual 🎨', 'isMe': true, 'time': '09:15'},
      {'text': '¡Gracias! Me especializo en motion graphics para startups', 'isMe': false, 'time': '09:17'},
      {'text': 'Perfecto. Estamos buscando alguien para nuestro pitch video', 'isMe': true, 'time': '09:19'},
      {'text': '¿Viste el concepto para el corto?', 'isMe': false, 'time': '09:22'},
      {'text': '¡Sí! Me encanta. ¿Grabamos hoy?', 'isMe': false, 'time': '09:25'},
    ],
    'demo_alex': [
      {'text': 'Hola Alex, ¿cómo va el diseño de la app?', 'isMe': true, 'time': 'Ayer'},
      {'text': 'Hola! Muy bien, ya tengo listos los wireframes de la sección de vacantes.', 'isMe': false, 'time': 'Ayer'},
      {'text': 'Buenísimo, los revisamos en la reunión del lunes.', 'isMe': true, 'time': 'Ayer'},
    ],
    'demo_martin': [
      {'text': 'Hola Martín, te envío el brief del proyecto.', 'isMe': false, 'time': '08:30'},
      {'text': 'Recibido, lo reviso con el equipo de diseño y te comento.', 'isMe': true, 'time': '08:45'},
    ],
    'demo_camila': [
      {'text': 'Hola Camila, ¿pudiste ver los resultados del test de usuario?', 'isMe': true, 'time': 'Ayer'},
      {'text': '¡Sí! El video de la entrevista quedó increíble, el feedback es super positivo.', 'isMe': false, 'time': 'Ayer'},
    ],
    'demo_lucas': [
      {'text': 'Hola Lucas, ¿cuándo agendamos la sesión de feedback?', 'isMe': false, 'time': 'Ayer'},
      {'text': 'Dale, agendamos para el jueves por la mañana.', 'isMe': true, 'time': 'Ayer'},
    ],
    'demo_valentina': [
      {'text': 'Hola Valentina, muchas gracias por la oportunidad.', 'isMe': false, 'time': 'Lun'},
      {'text': '¡Gracias a ti por la entrevista! Te mantendré al tanto del proceso.', 'isMe': true, 'time': 'Lun'},
    ],
  };

  // ── Streams — Defense in depth: filtros explícitos + RLS ──────────────
  // Aunque RLS protege los datos en Supabase, agregamos filtros del lado
  // del cliente como segunda capa de seguridad. Si RLS falla por
  // misconfiguration, estos filtros limitan la superficie de exposición.

  // `late`: ver la nota de jobs_screen.dart. En preview no hay sesión ni
  // Supabase inicializado, y este campo se evaluaba al construir el State.
  late final String? _currentUserId = widget.previewData != null
      ? '${'preview'}-cand-01'
      : Supabase.instance.client.auth.currentUser?.id;

  List<Map<String, dynamic>>? _connectionsData;
  List<Map<String, dynamic>>? _usersData;
  List<Map<String, dynamic>>? _messagesData;
  String? _viewerAccountType;

  StreamSubscription? _connectionsSub;
  StreamSubscription? _usersSub;
  StreamSubscription? _messagesSub;

  @override
  void initState() {
    super.initState();
    final preview = widget.previewData;
    if (preview != null) {
      // Preview local: datos resueltos y SIN suscribirse a streams en tiempo
      // real, que abrirían websockets contra Supabase.
      _connectionsData = preview.conexiones;
      _usersData = preview.usuarios;
      _messagesData = preview.mensajes;
      _viewerAccountType = preview.viewerAccountType;
      return;
    }
    _loadInitialData();
    _subscribeToStreams();
  }

  @override
  void dispose() {
    _connectionsSub?.cancel();
    _usersSub?.cancel();
    _messagesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final connFut = Supabase.instance.client
          .from('connections')
          .select()
          .limit(200);

      final usersFut = Supabase.instance.client
          .from('users')
          .select(kUserColumns)
          .order('created_at', ascending: false)
          .limit(100);

      final msgFut = Supabase.instance.client
          .from('messages')
          .select()
          .order('created_at', ascending: false)
          .limit(200);

      final viewerFut = _currentUserId == null
          ? Future<Map<String, dynamic>?>.value(null)
          : Supabase.instance.client
              .from('users')
              .select('account_type')
              .eq('id', _currentUserId!)
              .maybeSingle();

      final results = await Future.wait<dynamic>([
        connFut,
        usersFut,
        msgFut,
        viewerFut,
      ]);
      if (mounted) {
        setState(() {
          _connectionsData = List<Map<String, dynamic>>.from(results[0]);
          _usersData = List<Map<String, dynamic>>.from(results[1]);
          _messagesData = List<Map<String, dynamic>>.from(results[2]);
          final viewer = results[3] as Map<String, dynamic>?;
          _viewerAccountType = viewer?['account_type']?.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading initial chat data: $e');
    }
  }

  void _subscribeToStreams() {
    try {
      _connectionsSub = _connectionsStream.listen(
        (data) {
          if (mounted) {
            setState(() {
              _connectionsData = data;
            });
          }
        },
        onError: (err) {
          debugPrint('Connections stream error (silently ignored): $err');
        },
      );

      _usersSub = _usersStream.listen(
        (data) {
          if (mounted) {
            setState(() {
              _usersData = data;
            });
          }
        },
        onError: (err) {
          debugPrint('Users stream error (silently ignored): $err');
        },
      );

      _messagesSub = _messagesStreamGlobal.listen(
        (data) {
          if (mounted) {
            setState(() {
              _messagesData = data;
            });
          }
        },
        onError: (err) {
          debugPrint('Messages stream error (silently ignored): $err');
        },
      );
    } catch (e) {
      debugPrint('Error subscribing to streams: $e');
    }
  }

  // ── ÚNICOS PUNTOS DE BIFURCACIÓN preview / producción ───────────────────
  // Los `late final` de abajo resuelven `Supabase.instance.client`, que LANZA
  // si Supabase no está inicializado. En preview no se los toca: estos getters
  // devuelven un stream de un solo valor, sin websocket ni suscripción.
  // Con `previewData == null` el camino es el productivo de siempre.

  Stream<List<Map<String, dynamic>>> get _conexionesStream {
    final preview = widget.previewData;
    if (preview != null) return Stream.value(preview.conexiones);
    return _connectionsStream;
  }

  Stream<List<Map<String, dynamic>>> get _usuariosStream {
    final preview = widget.previewData;
    if (preview != null) return Stream.value(preview.usuarios);
    return _usersStream;
  }

  late final _usersStream = Supabase.instance.client
      .from('users')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(100);

  // Solo mis conexiones (ambos lados del vínculo)
  late final _connectionsStream = Supabase.instance.client
      .from('connections')
      .stream(primaryKey: ['id'])
      .limit(200);

  // Solo mensajes donde soy sender o receiver — límite razonable
  late final _messagesStreamGlobal = Supabase.instance.client
      .from('messages')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(200); // era 500 — innecesario para inbox




  /// Filtra usuarios por nombre o headline (case-insensitive)
  List<NexUser> _applySearch(List<NexUser> users) {
    if (_searchQuery.isEmpty) return users;
    final q = _searchQuery.toLowerCase();
    return users.where((u) =>
      u.name.toLowerCase().contains(q) ||
      u.headline.toLowerCase().contains(q)
    ).toList();
  }

  NexUser _visibleUser(NexUser user) =>
      protectCandidateForHeadhunter(user, _viewerAccountType);

  /// Muestra un sheet con las conexiones para iniciar un nuevo chat
  void _showNewMessageSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        decoration: BoxDecoration(
          color: ctx.isDark ? NexTheme.darkCard : CupertinoColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: ctx.dividerColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Nuevo Mensaje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ctx.textPrimary)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _conexionesStream,
                builder: (ctx, snap) {
                  if (!snap.hasData) return const Center(child: CupertinoActivityIndicator());
                  final accepted = snap.data!.where((c) =>
                    c['status'] == 'accepted' &&
                    (c['requester_id'] == _currentUserId || c['addressee_id'] == _currentUserId)
                  ).toList();
                  if (accepted.isEmpty) {
                    return Center(child: Text('No tenés conexiones aún', style: TextStyle(color: ctx.textSecondary)));
                  }
                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _usuariosStream,
                    builder: (ctx, usersSnap) {
                      if (!usersSnap.hasData) return const Center(child: CupertinoActivityIndicator());
                      final userMap = {for (var u in usersSnap.data!) u['id']?.toString() ?? '': u};
                      final contactIds = accepted.map((c) {
                        final rid = c['requester_id']?.toString() ?? '';
                        final aid = c['addressee_id']?.toString() ?? '';
                        return rid == _currentUserId ? aid : rid;
                      }).toSet();
                      final contacts = contactIds
                          .where((id) => userMap.containsKey(id))
                          .map((id) => NexUser.fromJson(userMap[id]!))
                          .toList();
                      return ListView.builder(
                        itemCount: contacts.length,
                        itemBuilder: (ctx, i) {
                          final u = _visibleUser(contacts[i]);
                          return CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              Navigator.pop(ctx);
                              if (MediaQuery.of(context).size.width > 900) {
                                setState(() => _selectedUser = u);
                              } else {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(builder: (_) => ChatDetailScreen(
                                    otherUser: u,
                                    viewerAccountType: _viewerAccountType,
                                  )),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: Row(
                                children: [
                                  NexAvatar(user: u, size: 44),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(u.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ctx.textPrimary)),
                                        if (u.headline.isNotEmpty)
                                          Text(u.headline, style: TextStyle(fontSize: 13, color: ctx.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MENSAJES — composición aprobada de la Tanda 1
  //
  // Referencia: design-reference/Candidato_Tanda1_Final/*/04_mensajes.png
  //
  // Reemplaza a la bandeja anterior, que además del lenguaje visual viejo tenía
  // un `Row` de tres chips que pedía ~502 px y desbordaba 112 px en mobile y
  // 103 px en el panel de desktop. Ahora el selector es una fila desplazable.
  //
  // La conversación en sí la sigue dibujando `ChatDetailScreen`: envío,
  // adjuntos, videollamada y agenda no se tocaron.
  // ───────────────────────────────────────────────────────────────────────────

  /// Mis conexiones aceptadas, que son las personas con las que puedo hablar.
  List<NexUser> get _contactos {
    if (_connectionsData == null || _usersData == null) return const [];
    final validos = _connectionsData!
        .where((c) => c['status'] == 'accepted')
        .map(
          (c) => c['requester_id'] == _currentUserId
              ? c['addressee_id']
              : c['requester_id'],
        )
        .toSet();
    return _usersData!
        .where((r) => validos.contains(r['id']))
        .map((r) => _visibleUser(NexUser.fromJson(r)))
        .toList();
  }

  List<Map<String, dynamic>> _mensajesCon(NexUser u) {
    final todos = _messagesData ?? const <Map<String, dynamic>>[];
    return todos
        .where(
          (m) =>
              (m['sender_id'] == _currentUserId && m['receiver_id'] == u.id) ||
              (m['sender_id'] == u.id && m['receiver_id'] == _currentUserId),
        )
        .toList();
  }

  int _sinLeerDe(NexUser u) => _mensajesCon(u)
      .where((m) => m['receiver_id'] == _currentUserId && m['is_read'] != true)
      .length;

  bool _esEmpresa(NexUser u) =>
      u.accountType == 'empresa' || u.accountType == 'headhunter';

  /// Conversación lista para dibujar. El último mensaje y la hora salen de
  /// `messages`; si todavía no hay ninguno se dice, no se inventa un texto.
  CandConversacionVista _conversacionDe(NexUser u) {
    final msgs = _mensajesCon(u);
    final ultimo = msgs.isNotEmpty ? msgs.first : null;
    return CandConversacionVista(
      id: u.id,
      nombre: u.name,
      avatarUrl: u.avatarUrl,
      ultimo: ultimo != null
          ? (ultimo['content']?.toString() ?? ultimo['text']?.toString() ?? '')
          : 'Todavía no se escribieron.',
      hora: ultimo != null ? timeAgo(ultimo['created_at']) : '',
      sinLeer: _sinLeerDe(u),
    );
  }

  /// Contactos visibles según el buscador y el filtro elegido.
  List<NexUser> get _conversacionesVisibles {
    final base = _applySearch(_contactos);
    return base.where((u) {
      switch (_convFilter) {
        case 'noleidos':
          return _sinLeerDe(u) > 0;
        case 'empresas':
          return _esEmpresa(u);
        default:
          return true;
      }
    }).toList();
  }

  List<Widget> _chipsFiltro() {
    final total = _contactos.length;
    final sinLeer = _contactos.where((u) => _sinLeerDe(u) > 0).length;
    final empresas = _contactos.where(_esEmpresa).length;

    Widget chip(String texto, String valor) => CandChip(
          texto,
          compacto: true,
          activo: _convFilter == valor,
          onTap: () => setState(() => _convFilter = valor),
        );

    return [
      chip('Todos · $total', 'todos'),
      chip('Sin leer · $sinLeer', 'noleidos'),
      chip('Empresas · $empresas', 'empresas'),
    ];
  }

  void _abrirConversacion(NexUser u) {
    setState(() => _selectedUser = u);
    if (candFormatoDe(context) == CandFormato.mobile) {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => _chat(u)),
      );
    }
  }

  /// El chat productivo. En render aislado recibe los mensajes ya resueltos,
  /// así que no abre streams contra Supabase.
  Widget _chat(NexUser u) {
    final preview = widget.previewData;
    return ChatDetailScreen(
      key: ValueKey(u.id),
      otherUser: u,
      viewerAccountType: _viewerAccountType,
      previewData: preview == null
          ? null
          : ChatDetailPreviewData(
              miId: _currentUserId ?? '',
              mensajes: preview.mensajes,
            ),
    );
  }

  List<CandAccionContexto> _accionesDe(NexUser u) => [
        CandAccionContexto(
          icono: CupertinoIcons.person_fill,
          etiqueta: 'Ver perfil',
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => _profileFor(u)),
          ),
        ),
        CandAccionContexto(
          icono: CupertinoIcons.calendar,
          etiqueta: _viewerAccountType == 'headhunter'
              ? 'Ver entrevistas'
              : 'Agendar entrevista',
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => _viewerAccountType == 'headhunter'
                  ? const HeadhunterInterviewsScreen()
                  : const SchedulingScreen(isCompany: true),
            ),
          ),
        ),
        CandAccionContexto(
          icono: CupertinoIcons.star_fill,
          etiqueta: 'Guardar contacto',
          onTap: () => MployaToast.saved(context, 'Contacto guardado'),
        ),
        CandAccionContexto(
          icono: CupertinoIcons.doc_on_doc_fill,
          etiqueta: 'Compartir CV',
          onTap: () =>
              MployaToast.info(context, 'Compartir CV estará disponible pronto'),
        ),
      ];

  Widget _profileFor(NexUser user) => ProfileScreen(
        user: user,
        viewerAccountType: _viewerAccountType,
        previewData: widget.previewData == null
            ? null
            : ProfilePreviewData(
                usuario: user.toJson(),
                isOwnProfile: false,
                viewerAccountType: _viewerAccountType,
              ),
      );

  @override
  Widget build(BuildContext context) {
    // Sin conversación elegida no se preselecciona a nadie en mobile; en los
    // formatos anchos se abre la primera para que el panel no quede vacío.
    final formato = candFormatoDe(context);
    return CupertinoPageScaffold(
      backgroundColor: MpTokens.lightBg,
      child: switch (formato) {
        CandFormato.desktop => _desktop(),
        CandFormato.tablet => _tablet(),
        CandFormato.mobile => _mobile(),
      },
    );
  }

  NexUser? get _elegido {
    final visibles = _conversacionesVisibles;
    final sel = _selectedUser;
    if (sel != null) {
      for (final u in visibles) {
        if (u.id == sel.id) return u;
      }
    }
    return visibles.isEmpty ? null : visibles.first;
  }

  bool get _cargando => _connectionsData == null || _usersData == null;

  Widget _mobile() {
    if (_cargando) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: candTopInset(context)),
          const CandEncabezado(titulo: 'Mensajes', subtitulo: 'Cargando…'),
          const Expanded(child: CandCargandoLista(cantidad: 4)),
        ],
      );
    }

    final visibles = _conversacionesVisibles;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(height: candTopInset(context)),
        CandEncabezado(
          titulo: 'Mensajes',
          subtitulo: _subtitulo(),
          acciones: [
            CandAccion(
              icono: CupertinoIcons.square_pencil,
              onTap: () => _showNewMessageSheet(context),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: CandBuscador(
            placeholder: 'Buscar conversaciones',
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        CandFilaChips(alto: 34, children: _chipsFiltro()),
        const SizedBox(height: 8),
        if (visibles.isEmpty)
          _vacio()
        else
          for (final u in visibles)
            CandFilaConversacion(
              conversacion: _conversacionDe(u),
              seleccionada: _selectedUser?.id == u.id,
              onTap: () => _abrirConversacion(u),
            ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _tablet() {
    final elegido = _elegido;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 316,
            child: CandTarjeta(
              padding: EdgeInsets.zero,
              child: _panelLista(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: CandTarjeta(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(MpTokens.radiusLG),
                child: elegido == null
                    ? const CandChatSinElegir()
                    : _chat(elegido),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktop() {
    final elegido = _elegido;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 322,
            child: CandTarjeta(
              padding: EdgeInsets.zero,
              child: _panelLista(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: CandTarjeta(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(MpTokens.radiusLG),
                child: elegido == null
                    ? const CandChatSinElegir()
                    : _chat(elegido),
              ),
            ),
          ),
          const SizedBox(width: 14),
          if (elegido != null)
            CandPanelContexto(
              nombre: elegido.name,
              titulo: elegido.headline,
              avatarUrl: elegido.avatarUrl,
              acciones: _accionesDe(elegido),
            ),
        ],
      ),
    );
  }

  /// Columna de la bandeja dentro de los paneles de tablet y desktop.
  Widget _panelLista() {
    if (_cargando) {
      return const CandCargandoLista(
        cantidad: 4,
        padding: EdgeInsets.all(14),
      );
    }

    final visibles = _conversacionesVisibles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: CandTitulo('Mensajes', tamano: 19),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: CandBuscador(
            placeholder: 'Buscar conversaciones',
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        CandFilaChips(padding: 16, alto: 34, children: _chipsFiltro()),
        const SizedBox(height: 6),
        Expanded(
          child: visibles.isEmpty
              ? _vacio()
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final u in visibles)
                      CandFilaConversacion(
                        conversacion: _conversacionDe(u),
                        seleccionada: _elegido?.id == u.id,
                        compacta: true,
                        onTap: () => _abrirConversacion(u),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  String _subtitulo() {
    final sinLeer = _contactos.fold<int>(0, (t, u) => t + _sinLeerDe(u));
    if (sinLeer > 0) return '$sinLeer sin leer';
    final n = _contactos.length;
    return n == 0 ? 'Sin conversaciones' : '$n ${n == 1 ? 'contacto' : 'contactos'}';
  }

  /// Bandeja sin conversaciones.
  ///
  /// Antes esto NO era un estado vacío: dibujaba seis "nuevos matches" y seis
  /// conversaciones inventadas —con textos, horas y contadores de no leídos—
  /// indistinguibles de las reales. Un candidato nuevo creía tener mensajes
  /// esperándolo. Ahora dice la verdad.
  Widget _vacio() {
    if (_searchQuery.trim().isNotEmpty) {
      return CandVacio(
        icono: CupertinoIcons.search,
        titulo: 'Sin resultados',
        detalle: 'Nadie de tu red coincide con "$_searchQuery".',
      );
    }
    if (_convFilter == 'noleidos') {
      return const CandVacio(
        icono: CupertinoIcons.checkmark_circle,
        titulo: 'No tenés mensajes sin leer',
        detalle: 'Estás al día con toda tu bandeja.',
      );
    }
    if (_convFilter == 'empresas') {
      return const CandVacio(
        icono: CupertinoIcons.building_2_fill,
        titulo: 'Todavía no hablaste con empresas',
        detalle: 'Cuando una empresa te escriba, la vas a ver acá.',
      );
    }
    return const CandVacio(
      icono: CupertinoIcons.chat_bubble_2,
      titulo: 'Todavía no tenés mensajes',
      detalle:
          'Cuando conectes con alguien vas a poder escribirle desde acá.',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat Detail Screen — Premium Chat UI
// ─────────────────────────────────────────────────────────────────────────────

/// Mensajes ya resueltos para el render aislado del chat. Mismo patrón que
/// `MessagingPreviewData`: si llega, la conversación NO abre streams ni canales
/// de realtime contra Supabase.
@immutable
class ChatDetailPreviewData {
  const ChatDetailPreviewData({required this.miId, this.mensajes = const []});

  final String miId;
  final List<Map<String, dynamic>> mensajes;
}

class ChatDetailScreen extends StatefulWidget {
  final NexUser otherUser;
  final String? viewerAccountType;

  /// Sólo lo usan los tests y el generador de capturas. En producción es
  /// `null` y el chat funciona exactamente igual que antes.
  final ChatDetailPreviewData? previewData;

  const ChatDetailScreen({
    super.key,
    required this.otherUser,
    this.previewData,
    this.viewerAccountType,
  });

  @override
  State<ChatDetailScreen> createState() => ChatDetailScreenState();
}

class ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _otherIsTyping = false;
  RealtimeChannel? _typingChannel;
  DateTime? _lastTypingEvent;
  String _myDisplayName = 'Usuario';

  NexUser get _visibleOtherUser => protectCandidateForHeadhunter(
        widget.otherUser,
        widget.viewerAccountType,
      );

  // `late`: en render aislado Supabase no está inicializado y un inicializador
  // de campo se evalúa al construir el State. Con `late` sólo se resuelve si
  // alguien lo pide, y en preview nadie lo pide.
  late final _messagesStream = Supabase.instance.client
      .from('messages')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(200);

  late final StreamController<List<Map<String, dynamic>>> _demoStreamController;
  List<Map<String, dynamic>> _demoMessagesList = [];

  Stream<List<Map<String, dynamic>>> get messagesStream {
    final preview = widget.previewData;
    if (preview != null) return Stream.value(preview.mensajes);
    if (widget.otherUser.id.startsWith('demo_')) {
      return _demoStreamController.stream;
    }
    return _messagesStream;
  }

  String? get _currentUserId =>
      widget.previewData?.miId ??
      Supabase.instance.client.auth.currentUser?.id;

  String get _otherId => widget.otherUser.id;

  @override
  void initState() {
    super.initState();
    // Render aislado: ni canal de typing ni consulta del propio nombre.
    if (widget.previewData != null) return;
    if (widget.otherUser.id.startsWith('demo_')) {
      final initialMsgs = _MessagingScreenState._demoMessagesMap[widget.otherUser.id] ?? [];
      _demoMessagesList = initialMsgs.map((m) => {
        'id': 'demo_msg_${widget.otherUser.id}_${initialMsgs.indexOf(m)}',
        'sender_id': m['isMe'] == true ? (_currentUserId ?? 'user_me') : widget.otherUser.id,
        'receiver_id': m['isMe'] == true ? widget.otherUser.id : (_currentUserId ?? 'user_me'),
        'content': m['text'],
        'text': m['text'],
        'created_at': DateTime.now().subtract(Duration(minutes: 10 - initialMsgs.indexOf(m))).toIso8601String(),
        'is_read': true,
      }).toList().reversed.toList();
      _demoStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();
      _demoStreamController.add(_demoMessagesList);
    } else {
      _setupTypingChannel();
      _controller.addListener(_onTextChanged);
      _loadMyName();
    }
  }

  Future<void> _loadMyName() async {
    if (_currentUserId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('name')
          .eq('id', _currentUserId!)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() => _myDisplayName = row['name']?.toString() ?? 'Usuario');
      }
    } catch (_) {}
  }

  void _setupTypingChannel() {
    final roomId = ChatService.instance.generateJitsiRoom(
      _currentUserId ?? '', _otherId,
    );
    _typingChannel = Supabase.instance.client.channel('typing:$roomId');
    
    _typingChannel!
      .onBroadcast(
        event: 'typing',
        callback: (payload) {
          final senderId = payload['user_id'];
          if (senderId == _otherId && mounted) {
            setState(() => _otherIsTyping = true);
            // Auto-hide after 3 seconds
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) setState(() => _otherIsTyping = false);
            });
          }
        },
      )
      .subscribe();
  }

  void _onTextChanged() {
    if (_controller.text.isEmpty) return;
    final now = DateTime.now();
    // Throttle: only send typing event every 2 seconds
    if (_lastTypingEvent != null &&
        now.difference(_lastTypingEvent!).inSeconds < 2) {
      return;
    }
    _lastTypingEvent = now;
    _typingChannel?.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': _currentUserId},
    );
  }

  List<Map<String, dynamic>> _filterMessages(List<Map<String, dynamic>> all) {
    return all.where((m) {
      final s = m['sender_id']?.toString();
      final r = m['receiver_id']?.toString();
      return (s == _currentUserId && r == _otherId) ||
          (s == _otherId && r == _currentUserId);
    }).toList();
  }

  /// Detecta emails y teléfonos en texto (misma lógica que comentarios)
  bool _containsContactInfo(String text) {
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    final phoneRegex = RegExp(r'(\+?\d[\d\s\-\.]{7,}\d)');
    final obfuscatedEmail = RegExp(r'(arroba|@|at)\s*.+\s*(punto|dot)\s*(com|net|org|io)', caseSensitive: false);
    return emailRegex.hasMatch(text) || phoneRegex.hasMatch(text) || obfuscatedEmail.hasMatch(text);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    if (_currentUserId == null) return;

    // ── Filtro de datos personales ──
    if (_containsContactInfo(text)) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Datos protegidos'),
            content: const Text(
              'No podés compartir emails ni teléfonos por chat. '
              'Usá las herramientas de Mploya para coordinar entrevistas.',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Entendido'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
      return;
    }

    // ── Moderación IA de contenido ──
    final moderation = await ContentModerationService.instance.moderate(
      text,
      context: 'chat',
    );
    if (moderation.isBlocked) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Contenido no permitido'),
            content: Text(
              moderation.reason ?? 'Este mensaje no cumple con las normas de la comunidad.',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Entendido'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
      return;
    }
    if (moderation.isFlagged) {
      // Se envía pero se registra para revisión
      ContentModerationService.instance.logFlaggedContent(
        text, moderation.category ?? 'unknown', 'chat',
      );
    }

    setState(() => _isSending = true);
    _controller.clear();

    try {
      if (widget.otherUser.id.startsWith('demo_')) {
        _demoMessagesList.insert(0, {
          'id': 'demo_msg_user_${DateTime.now().millisecondsSinceEpoch}',
          'sender_id': _currentUserId ?? 'user_me',
          'receiver_id': widget.otherUser.id,
          'content': text,
          'text': text,
          'created_at': DateTime.now().toIso8601String(),
          'is_read': true,
        });
        _demoStreamController.add(List.from(_demoMessagesList));
      } else {
        try {
          await Supabase.instance.client.from('messages').insert({
            'sender_id': _currentUserId,
            'receiver_id': _otherId,
            'content': text,
            'text': text,
            'type': 'text',
            'is_read': false,
          });
        } catch (e) {
          debugPrint('Error enviando mensaje: $e');
          if (mounted) {
            showCupertinoDialog(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: const Text('Error DB'),
                content: Text(e.toString()),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('OK'),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            );
          }
          _controller.text = text;
        }
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Iniciar videollamada Jitsi (estilo Google Meet) ──
  Widget _headerAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x0C000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: MpTokens.primary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MpTokens.primary)),
          ],
        ),
      ),
    );
  }

  Future<void> _startJitsiCall() async {
    if (_currentUserId == null) return;
    HapticFeedback.mediumImpact();

    // ── 0. Pedir permisos de cámara y micrófono ──
    try {
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (!cameraStatus.isGranted || !micStatus.isGranted) {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text('Permisos Necesarios'),
              content: const Text(
                'Para iniciar una videollamada necesitás permitir '
                'acceso a la cámara y al micrófono en Ajustes.',
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Abrir Ajustes'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Permission check error: $e');
      // Continue anyway — Jitsi SDK may handle permissions itself
    }

    final roomId = ChatService.instance.generateJitsiRoom(_currentUserId!, _otherId);

    // ── 1. Obtener nombre real del usuario actual ──
    String myName = 'Mploya User';
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('name')
          .eq('id', _currentUserId!)
          .maybeSingle();
      if (row != null) {
        myName = row['name']?.toString() ?? myName;
      }
    } catch (e) {
      debugPrint('⚠️ Jitsi: error fetching user info: $e');
    }

    // ── 2. Enviar mensaje automático en el chat ──
    try {
      await ChatService.instance.sendTextMessage(
        receiverId: _otherId,
        text: '📹 CALL:$roomId\n$myName te está llamando.',
      );
    } catch (e) {
      debugPrint('⚠️ Call auto-message send failed: $e');
    }

    // ── 3. Push FCM al receptor ──
    try {
      await Supabase.instance.client.functions.invoke('send-fcm', body: {
        'target_user_id': _otherId,
        'title': '📹 Videollamada entrante',
        'body': '$myName te está llamando. Abrí el chat para unirte.',
        'data': {'type': 'call', 'channel_name': roomId, 'caller_name': myName},
      });
    } catch (e) {
      debugPrint('⚠️ FCM call notify failed: $e');
    }

    // ── 4. Abrir la videollamada dentro de la app ──
    // Una sola ruta para web y móvil: AgoraCallScreen resuelve la llamada según
    // plataforma (móvil = Agora nativo; web = Jitsi embebido en iframe). Antes
    // en web abría meet.jit.si en otra pestaña (no embebido); ahora queda dentro
    // de Mploya, igual que el botón "Unirse".
    if (!mounted) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => AgoraCallScreen(
          channelName: roomId,
          displayName: myName,
          otherName: _visibleOtherUser.name,
        ),
      ),
    );
  }

  // ── Mostrar opciones de adjuntar archivo ──
  void _showAttachmentOptions() {
    HapticFeedback.lightImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Enviar archivo'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              await _pickAndSendImage();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo_fill, color: Color(0xFF34C759), size: 22),
                SizedBox(width: 10),
                Text('Foto / Imagen'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              await _pickAndSendFile();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.doc_fill, color: Color(0xFF007AFF), size: 22),
                SizedBox(width: 10),
                Text('Documento / PDF'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage() async {
    final file = await ChatService.instance.pickImage();
    if (file == null) return;
    final path = file.path;
    if (path == null) return;
    
    setState(() => _isSending = true);
    try {
      await ChatService.instance.sendFileMessage(
        receiverId: _otherId,
        filePath: path,
        fileName: file.name,
      );
    } catch (e) {
      debugPrint('Error enviando imagen: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    final file = await ChatService.instance.pickFile();
    if (file == null) return;
    final path = file.path;
    if (path == null) return;
    
    setState(() => _isSending = true);
    try {
      await ChatService.instance.sendFileMessage(
        receiverId: _otherId,
        filePath: path,
        fileName: file.name,
      );
    } catch (e) {
      debugPrint('Error enviando archivo: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    if (widget.previewData != null) {
      // En render aislado no se creó ni el controlador demo ni el canal.
    } else if (widget.otherUser.id.startsWith('demo_')) {
      _demoStreamController.close();
    } else {
      _controller.removeListener(_onTextChanged);
      _typingChannel?.unsubscribe();
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otherUser = _visibleOtherUser;
    return CupertinoPageScaffold(
      // Fondo con contraste para que resalten las burbujas
      backgroundColor: context.isDark ? NexTheme.darkBg : MpTokens.lightBg,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: context.isDark ? const Color(0xEE000000) : const Color(0xEEFFFFFF),
        border: null, // No-Line
        middle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            otherUser.id.startsWith('demo_')
                ? Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Colors.grey.shade200, Colors.grey.shade300]),
                    ),
                    child: Center(child: Text(otherUser.avatarUrl ?? '👤', style: const TextStyle(fontSize: 16))),
                  )
                : NexAvatar(user: otherUser, size: 32),
            const SizedBox(width: 10),
            // `Flexible` + elipsis: en el panel de tablet la barra queda con
            // ~158 px para el centro y el nombre completo desbordaba 184 px.
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherUser.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                      fontFamily: '.SF Pro Text',
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34C759),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          otherUser.headline.isNotEmpty
                              ? otherUser.headline
                              : 'Conexión activa',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _headerAction(
              icon: CupertinoIcons.video_camera_solid,
              label: 'Video',
              onTap: () => _startJitsiCall(),
            ),
            const SizedBox(width: 8),
            _headerAction(
              icon: CupertinoIcons.person_fill,
              label: 'Ver Perfil',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => ProfileScreen(
                  user: widget.otherUser,
                  viewerAccountType: widget.viewerAccountType,
                  previewData: widget.previewData == null
                      ? null
                      : ProfilePreviewData(
                          usuario: widget.otherUser.toJson(),
                          isOwnProfile: false,
                          viewerAccountType: widget.viewerAccountType,
                        ),
                )),
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Área de Mensajes ──
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                initialData: widget.otherUser.id.startsWith('demo_') ? _demoMessagesList : null,
                stream: messagesStream,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CupertinoActivityIndicator());
                  }

                  final messages = _filterMessages(snap.data!);

                  // MARCAR MENSAJES RECIBIDOS COMO LEÍDOS
                  if (widget.previewData == null &&
                      !widget.otherUser.id.startsWith('demo_')) {
                    final unreadMsgs = messages.where((m) => m['receiver_id'] == _currentUserId && m['is_read'] != true).toList();
                    if (unreadMsgs.isNotEmpty) {
                      Future.microtask(() {
                        for (var m in unreadMsgs) {
                          Supabase.instance.client.from('messages').update({'is_read': true}).eq('id', m['id']);
                        }
                      });
                    }
                  }

                  if (messages.isEmpty) {
                    return _EmptyChat(
                      otherUser: otherUser,
                      onSendHello: () {
                        _controller.text = '¡Hola! Me encantó tu perfil.';
                        _sendMessage();
                      },
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg['sender_id']?.toString() == _currentUserId;
                      // Logicas de agrupación (quitar colas si hay mensajes seguidos) se pueden hacer aquí.
                      return _MessageBubble(
                        text: msg['text']?.toString() ?? msg['content']?.toString() ?? '',
                        isMe: isMe,
                        time: timeAgo(msg['created_at']),
                        fileUrl: msg['file_url']?.toString(),
                        fileName: msg['file_name']?.toString(),
                        fileType: msg['file_type']?.toString(),
                        fileSizeBytes: msg['file_size_bytes'] as int?,
                        isRead: msg['is_read'] == true,
                        onJoinCall: (channelName) {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => AgoraCallScreen(
                                channelName: channelName,
                                displayName: _myDisplayName,
                                otherName: otherUser.name,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // ── Typing Indicator ──
            if (_otherIsTyping)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _TypingDot(delay: 0),
                          const SizedBox(width: 4),
                          const _TypingDot(delay: 150),
                          const SizedBox(width: 4),
                          const _TypingDot(delay: 300),
                          const SizedBox(width: 8),
                          Text(
                            '${otherUser.name.split(' ').first} escribiendo...',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ── Barra de Input Glassmorphic ──
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: context.isDark ? const Color(0xCC16181F) : const Color(0xCCFFFFFF),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, -4))
                    ],
                  ),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: () => _showAttachmentOptions(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(CupertinoIcons.add, size: 22, color: context.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoTextField(
                          controller: _controller,
                          placeholder: 'Escribe un mensaje...',
                          placeholderStyle: TextStyle(color: context.textTertiary, fontFamily: '.SF Pro Text'),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          style: TextStyle(fontSize: 16, color: context.textPrimary),
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          decoration: BoxDecoration(
                            color: context.isDark ? NexTheme.darkCard : CupertinoColors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: context.dividerColor, width: 1), // Única linea permitida por input
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ── Mic button ──
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: () => MployaToast.info(context, 'Los mensajes de voz estarán disponibles muy pronto'),
                        child: Icon(CupertinoIcons.mic_fill, size: 22, color: context.textTertiary),
                      ),
                      const SizedBox(width: 10),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: _isSending ? null : _sendMessage,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            // Identidad violeta aprobada de la Tanda 1.
                            gradient: const LinearGradient(
                              colors: [MpTokens.primary, MpTokens.primaryDeep],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: MpTokens.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))
                            ],
                          ),
                          child: Center(
                            child: _isSending
                                ? const CupertinoActivityIndicator(color: Colors.white, radius: 10)
                                : const Icon(CupertinoIcons.arrow_up, size: 20, color: CupertinoColors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty Chat State (Premium)
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  final NexUser otherUser;
  final VoidCallback? onSendHello;
  const _EmptyChat({required this.otherUser, this.onSendHello});

  List<String> _generateIcebreakers() {
    final name = otherUser.name.split(' ').first;
    final headline = otherUser.headline;
    final tags = otherUser.tags;
    final isCompany = otherUser.accountType == 'empresa' || otherUser.accountType == 'headhunter';

    final icebreakers = <String>[];

    if (isCompany) {
      icebreakers.add('¡Hola! Me interesa mucho la propuesta de $name. ¿Podemos charlar?');
      if (tags.isNotEmpty) {
        icebreakers.add('Vi que buscan perfil ${tags.first}. Tengo experiencia en eso. ¿Coordinamos?');
      }
      icebreakers.add('¡Buenas! Me encantaría conocer más sobre las oportunidades en $name.');
    } else {
      if (headline.isNotEmpty) {
        icebreakers.add('Hola $name, vi tu perfil de "$headline". ¡Muy interesante!');
      } else {
        icebreakers.add('¡Hola $name! Me encantó tu video pitch.');
      }
      if (tags.isNotEmpty) {
        icebreakers.add('Vi que trabajás con ${tags.take(2).join(' y ')}. ¡Tenemos mucho en común!');
      }
      icebreakers.add('Hola $name, me gustaría conectar y explorar sinergias. ¿Cómo estás?');
    }

    return icebreakers.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final icebreakers = _generateIcebreakers();
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [MpTokens.primary, MpTokens.primaryDeep]),
                boxShadow: [
                  BoxShadow(color: MpTokens.primary.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8))
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.isDark ? NexTheme.darkBg : const Color(0xFFF2F2F7),
                  shape: BoxShape.circle,
                ),
                child: otherUser.id.startsWith('demo_')
                    ? Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [Colors.grey.shade200, Colors.grey.shade300]),
                        ),
                        child: Center(child: Text(otherUser.avatarUrl ?? '👤', style: const TextStyle(fontSize: 48))),
                      )
                    : NexAvatar(user: otherUser, size: 90, showBadge: false),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Has conectado con ${otherUser.name.split(' ').first}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
                letterSpacing: -0.5,
                fontFamily: '.SF Pro Display',
              ),
            ),
            const SizedBox(height: 16),
            // ── IA Icebreaker Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5F3DC4), Color(0xFFAE3EC9)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.sparkles, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'IA sugiere empezar con...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Icebreaker Pills ──
            ...icebreakers.map((text) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _IcebreakerPill(text: text),
            )),
          ],
        ),
      ),
    );
  }
}

class _IcebreakerPill extends StatelessWidget {
  final String text;
  const _IcebreakerPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: () {
        // Buscar el ChatDetailScreenState padre y setear el texto
        final chatState = context.findAncestorStateOfType<ChatDetailScreenState>();
        if (chatState != null) {
          chatState._controller.text = text;
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 3))],
          border: null, // No-Line Rule
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.lightbulb_fill, color: Color(0xFFFFCC00), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
            const Icon(CupertinoIcons.arrow_right_circle_fill, color: Color(0xFF5F3DC4), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message Bubble (No-Line Premium styling)
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final int? fileSizeBytes;
  final bool isRead;
  final Function(String channelName)? onJoinCall;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.time,
    this.fileUrl,
    this.fileName,
    this.fileType,
    this.fileSizeBytes,
    this.isRead = false,
    this.onJoinCall,
  });

  bool get _hasFile => fileUrl != null && fileUrl!.isNotEmpty;
  bool get _isImage => fileType == 'image';
  bool get _isCallMessage => text.startsWith('📹 CALL:');
  String get _callChannel => text.split('\n').first.replaceFirst('📹 CALL:', '').trim();
  String get _callCallerName => text.contains('\n') ? text.split('\n').last.replaceAll(' te está llamando.', '').trim() : '';
  bool get _isVideoReply => text.contains('Video Reply') && text.contains('https://');
  String get _extractVideoUrl {
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('http') && trimmed.contains('.mp4')) return trimmed;
    }
    return '';
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMe) const Spacer(flex: 1),
          Flexible(
            flex: 4,
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isMe ? null : context.cardColor,
                    gradient: isMe
                        ? const LinearGradient(
                            colors: [MpTokens.primary, MpTokens.primaryDeep],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(22),
                      topRight: const Radius.circular(22),
                      bottomLeft: Radius.circular(isMe ? 22 : 6),
                      bottomRight: Radius.circular(isMe ? 6 : 22),
                    ),
                    boxShadow: isMe
                        ? [BoxShadow(color: MpTokens.primary.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))]
                        : const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Imagen adjunta ──
                      if (_hasFile && _isImage)
                        GestureDetector(
                          onTap: () => _openUrl(fileUrl!),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(22),
                              topRight: Radius.circular(22),
                            ),
                            child: Image.network(
                              fileUrl!,
                              width: 240,
                              height: 180,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 240,
                                height: 60,
                                color: const Color(0xFFF2F2F7),
                                child: const Center(child: Icon(CupertinoIcons.photo, color: Color(0xFF8E8E93))),
                              ),
                            ),
                          ),
                        ),

                      // ── Archivo adjunto (doc/PDF) ──
                      if (_hasFile && !_isImage)
                        GestureDetector(
                          onTap: () => _openUrl(fileUrl!),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : (context.isDark ? NexTheme.darkSurface : const Color(0xFFF2F2F7)),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(child: Icon(CupertinoIcons.doc_fill, size: 20, color: Color(0xFFFF3B30))),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileName ?? 'Archivo',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isMe ? Colors.white : context.textPrimary,
                                        ),
                                      ),
                                      if (fileSizeBytes != null)
                                        Text(
                                          ChatService.formatFileSize(fileSizeBytes!),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isMe ? Colors.white70 : context.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  CupertinoIcons.arrow_down_circle_fill,
                                  size: 24,
                                  color: isMe ? Colors.white70 : const Color(0xFF007AFF),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ── Texto del mensaje (con detección de Video Reply y Llamada) ──
                      if (text.isNotEmpty)
                        _isCallMessage
                            ? _CallMessageBubble(
                                callerName: _callCallerName,
                                isMe: isMe,
                                onJoin: onJoinCall != null ? () => onJoinCall!(_callChannel) : null,
                              )
                            : _isVideoReply
                                ? _VideoReplyBubble(
                                    videoUrl: _extractVideoUrl,
                                    isMe: isMe,
                                  )
                                : Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Text(
                                      text,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isMe ? CupertinoColors.white : context.textPrimary,
                                        fontFamily: '.SF Pro Text',
                                        height: 1.35,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                    ],
                  ),
                ),
                if (time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // ── Read Receipt Checks ──
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            isRead ? CupertinoIcons.checkmark_alt_circle_fill : CupertinoIcons.checkmark_alt_circle,
                            size: 14,
                            color: isRead ? MpTokens.primary : const Color(0xFFAEAEB2),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!isMe) const Spacer(flex: 1),
        ],
      ),
    );
  }

  void _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Video Reply Bubble ──
// ── Call Message Bubble ──
class _CallMessageBubble extends StatelessWidget {
  final String callerName;
  final bool isMe;
  final VoidCallback? onJoin;

  const _CallMessageBubble({required this.callerName, required this.isMe, this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isMe ? 0.2 : 0.0),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.video_camera_solid, size: 22,
                    color: isMe ? Colors.white : const Color(0xFF34C759)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Videollamada',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: isMe ? Colors.white : context.textPrimary,
                      )),
                  if (callerName.isNotEmpty)
                    Text(callerName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe ? Colors.white70 : context.textSecondary,
                        )),
                ],
              ),
            ],
          ),
          if (onJoin != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onJoin,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.video_camera_solid, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Unirse', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VideoReplyBubble extends StatelessWidget {
  final String videoUrl;
  final bool isMe;

  const _VideoReplyBubble({required this.videoUrl, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (_) => _FullScreenVideoPlayer(videoUrl: videoUrl),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        width: 220,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    NexTheme.brandAccent.withValues(alpha: 0.3),
                    Colors.black87,
                  ],
                ),
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: NexTheme.brandAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: NexTheme.brandAccent.withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 28),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Row(
                children: [
                  const Icon(CupertinoIcons.videocam_fill, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Video Reply',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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

// ── Fullscreen Video Player (in-app) ──
class _FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _FullScreenVideoPlayer({required this.videoUrl});

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video ──
          Center(
            child: _initialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CupertinoActivityIndicator(color: Colors.white, radius: 16),
          ),

          // ── Top bar ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 20),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Video Reply',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                const SizedBox(width: 36),
              ],
            ),
          ),

          // ── Play/Pause tap ──
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                });
              },
              behavior: HitTestBehavior.translucent,
              child: _initialized && !_controller.value.isPlaying
                  ? Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 32),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing Dot Animation ──
class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _animation.value),
        child: child,
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFF8E8E93),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
