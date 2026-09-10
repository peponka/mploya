import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../../widgets/mobile_map_stub.dart'
    if (dart.library.io) '../../widgets/mobile_map.dart';
import '../../widgets/web_map_stub.dart'
    if (dart.library.html) '../../widgets/web_map.dart';
import '../chat_inmail_screen.dart';
import 'empresa_candidato_perfil_screen.dart';

/// Un candidato ubicado en el mapa. Todos los campos vienen de la RPC
/// `get_explore_pins`; no hay ninguno derivado ni inventado.
@immutable
class CandidatoCercano {
  final String id;
  final String nombre;
  final String headline;
  final double lat;
  final double lng;
  final String? avatar;
  final bool tieneVideo;

  /// Distancia real en km devuelta por la RPC. Null si no la informa.
  final double? distanciaKm;

  const CandidatoCercano({
    required this.id,
    required this.nombre,
    required this.headline,
    required this.lat,
    required this.lng,
    this.avatar,
    this.tieneVideo = false,
    this.distanciaKm,
  });

  /// Distancia legible.
  ///
  /// NO dice "de vos": el valor lo calcula la RPC contra el centro del mapa,
  /// que hoy es un punto fijo de Buenos Aires, no la ubicación real de la
  /// empresa. Decir "de vos" mostraba "0 m de vos" para un candidato que puede
  /// estar a kilómetros. Cuando se pida geolocalización real, este texto puede
  /// volver a ser relativo al usuario.
  String? get distancia {
    if (distanciaKm == null) return null;
    if (distanciaKm! < 1) {
      return 'a ${(distanciaKm! * 1000).round()} m del centro';
    }
    return 'a ${distanciaKm!.toStringAsFixed(1)} km del centro';
  }

  Map<String, dynamic> get comoPin => {
        'id': id,
        'name': nombre,
        'headline': headline,
        'lat': lat,
        'lng': lng,
        'type': 'candidato',
        'video': tieneVideo,
        'avatar': avatar ?? '',
        'distancia': distanciaKm,
      };
}

@immutable
class MapaData {
  final List<CandidatoCercano> candidatos;
  final double centroLat;
  final double centroLng;
  final bool error;

  const MapaData({
    required this.candidatos,
    this.centroLat = -34.6037,
    this.centroLng = -58.3816,
    this.error = false,
  });

  static const empty = MapaData(candidatos: []);
}

/// Convierte las filas crudas de `get_explore_pins` en candidatos visibles
/// en el mapa. Función pura y testeable sin red — es donde vive el filtro de
/// privacidad, así que tiene que poder probarse sin depender de Supabase.
///
/// Empresa busca TALENTO: se descartan pines de empresa y headhunter.
/// También los confidenciales/stealth: `get_explore_pins` (mig. 023) NO
/// enmascara nombre/foto/coordenadas para ellos y devuelve la fila cruda —
/// a diferencia de Pipeline, Shortlist, Mensajes, Match IA y el Perfil de
/// Candidato, que sí ocultan identidad. Se filtra acá, en el cliente, porque
/// el enmascarado real (o directamente no exponer sus coordenadas) tiene que
/// resolverse en la función — fuera de esta tanda. Ver informe: deuda de
/// privacidad de mayor prioridad.
List<CandidatoCercano> candidatosDesdeFilas(List<Map<String, dynamic>> filas) {
  final candidatos = <CandidatoCercano>[];

  for (final fila in filas) {
    final tipo = (fila['pin_type'] ?? 'candidato').toString().toLowerCase();
    if (tipo == 'empresa' ||
        tipo == 'headhunter' ||
        tipo.startsWith('confidenc') ||
        tipo == 'stealth') {
      continue;
    }

    final plat = (fila['latitude'] as num?)?.toDouble() ?? 0.0;
    final plng = (fila['longitude'] as num?)?.toDouble() ?? 0.0;
    if (plat == 0.0 && plng == 0.0) continue;

    candidatos.add(
      CandidatoCercano(
        id: fila['pin_id'].toString(),
        nombre: (fila['pin_name'] ?? 'Candidato').toString(),
        headline: (fila['pin_headline'] ?? '').toString(),
        lat: plat,
        lng: plng,
        avatar: (fila['avatar_url']?.toString().isNotEmpty ?? false)
            ? fila['avatar_url'].toString()
            : null,
        tieneVideo: fila['has_video'] == true,
        distanciaKm: (fila['distance_km'] as num?)?.toDouble(),
      ),
    );
  }

  candidatos.sort((a, b) {
    final da = a.distanciaKm;
    final db = b.distanciaKm;
    if (da == null || db == null) return 0;
    return da.compareTo(db);
  });

  return candidatos;
}

/// Carga los candidatos con ubicación real alrededor del centro dado.
///
/// A diferencia de `explore_screen.dart`, acá NO hay respaldo con pines demo:
/// esa pantalla, cuando la consulta vuelve vacía, dibuja gente inventada "para
/// que el mapa no quede vacío". Si no hay candidatos reales, esta pantalla
/// muestra su estado vacío.
Future<MapaData> loadCandidatosCercanos({
  double lat = -34.6037,
  double lng = -58.3816,
  double radioKm = 150,
}) async {
  try {
    final res = await Supabase.instance.client.rpc(
      'get_explore_pins',
      params: {'p_lat': lat, 'p_lng': lng, 'p_radius_km': radioKm},
    );

    final filas = List<Map<String, dynamic>>.from(res ?? []);
    final candidatos = candidatosDesdeFilas(filas);

    return MapaData(candidatos: candidatos, centroLat: lat, centroLng: lng);
  } catch (e) {
    debugPrint('mapa · get_explore_pins: $e');
    return const MapaData(candidatos: [], error: true);
  }
}

/// Mapa de talento de Empresa.
///
/// DERIVACIÓN CONTROLADA de `mapa de candidatos 2.png` (5. Mapa de Candidatos):
/// se conserva su estructura —encabezado con contexto, fila de filtros, mapa
/// protagonista con controles al costado y hoja inferior "Candidatos cerca de
/// vos"— y se lleva al sistema violeta con la barra de Empresa. El PNG trae FAB
/// naranja y navegación Feed/Perfil del sistema anterior: eso NO se copia.
///
/// El mapa reutiliza la infraestructura que ya funciona (Leaflet en iframe para
/// web, mapa nativo en móvil). No se reimplementa nada.
///
/// Match IA no aparece: es candidato ↔ vacante y acá no hay vacante
/// seleccionada, así que inventar un porcentaje rompería la regla del feed.
///
/// POLISH VISUAL 5 (15/8/2026) — FUGA DE PRIVACIDAD REAL ENCONTRADA Y
/// MITIGADA DEL LADO DEL CLIENTE: `get_explore_pins` (mig. 023) no filtra ni
/// enmascara candidatos confidenciales/stealth — devuelve su `name`,
/// `avatar_url` y coordenadas EXACTAS igual que a cualquier otro usuario, y
/// está otorgada a `anon` además de `authenticated`. `loadCandidatosCercanos`
/// ahora descarta esos pines igual que ya descartaba empresa/headhunter. Esto
/// evita que ESTA pantalla los muestre, pero NO corrige la función: cualquier
/// llamada directa a la RPC (o cualquier otro consumidor futuro) seguiría
/// recibiendo el dato crudo. Arreglar eso de raíz requiere tocar la función
/// SQL, fuera del alcance de esta tanda (prohibido backend/migraciones).
/// LAYOUT (10/9/2026) — Pedro pidió, tras ver capturas de JobToday, que el
/// mapa fuera protagonista a pantalla completa en vez de compartir la mitad
/// de arriba con encabezado/filtros y la mitad de abajo con la lista.
/// Encabezado y filtros ahora flotan sobre el mapa (`_controlesFlotantes`,
/// `_mapa(fullBleed: true)`); la lista de candidatos queda como una hoja fija
/// más chica abajo. Pendiente, pedido explícitamente por Pedro pero NO hecho
/// en esta tanda por requerir tocar el HTML/JS embebido de Leaflet en
/// `mobile_map.dart`/`web_map.dart` sin forma de probarlo visualmente en esta
/// sesión: (a) ícono por categoría en cada pin — hoy `CandidatoCercano` ni
/// siquiera trae un campo de categoría/rubro, así que primero habría que
/// sumar ese dato; (b) agrupar pines cercanos con un número (clustering) —
/// requiere sumar una librería (Leaflet.markercluster) al HTML embebido.
/// Mejor hacerlas junto con una prueba real en el teléfono.
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 12/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ║ Actualizada el 10/9/2026 por el cambio de layout de arriba, con OK    ║
/// ║ explícito de Pedro. El resto de la pantalla (datos, filtros, mapa     ║
/// ║ embebido) sigue congelado igual que antes.                            ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
class EmpresaMapaScreen extends StatefulWidget {
  final MapaData? previewData;

  const EmpresaMapaScreen({super.key, this.previewData});

  @override
  State<EmpresaMapaScreen> createState() => _EmpresaMapaScreenState();
}

class _EmpresaMapaScreenState extends State<EmpresaMapaScreen> {
  MapaData _data = MapaData.empty;
  bool _loading = true;
  String? _seleccionado;

  /// 0 = Todos · 1 = Con video · 2 = Cerca (≤ 25 km)
  int _filtro = 0;

  @override
  void initState() {
    super.initState();
    if (widget.previewData != null) {
      _data = widget.previewData!;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (widget.previewData != null) return;
    if (!mounted) return;
    setState(() => _loading = true);
    final data = await loadCandidatosCercanos();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  List<CandidatoCercano> get _visibles {
    switch (_filtro) {
      case 1:
        return _data.candidatos.where((c) => c.tieneVideo).toList();
      case 2:
        return _data.candidatos
            .where((c) => c.distanciaKm != null && c.distanciaKm! <= 25)
            .toList();
      default:
        return _data.candidatos;
    }
  }

  /// Perfil de Candidato de Empresa, no el `ProfileScreen` legacy: ese es la
  /// ficha del rol candidato y ofrece acciones que no son las de una empresa.
  /// La pantalla nueva recarga el perfil completo desde el id, así que acá no
  /// hace falta pasarle nada más de lo que el pin ya tiene.
  void _abrirCandidato(CandidatoCercano candidato) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => EmpresaCandidatoPerfilScreen(
          candidatoId: candidato.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 15))
            : LayoutBuilder(
                builder: (context, constraints) {
                  // Mapa a pantalla completa (pedido de Pedro tras ver
                  // JobToday, 10/9/2026): el mapa es lo primero que se ve, de
                  // punta a punta. Encabezado y filtros flotan arriba sobre
                  // él; la lista de candidatos es una hoja fija abajo, más
                  // chica que antes, no un panel que se come casi media
                  // pantalla.
                  final alto = constraints.maxHeight;
                  final alturaHoja = (alto * 0.30).clamp(200.0, 300.0);

                  return Stack(
                    children: [
                      Positioned.fill(child: _mapa(fullBleed: true)),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: _controlesFlotantes(),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: alturaHoja,
                        child: _hoja(),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  // ── Encabezado + filtros flotando sobre el mapa ─────────────────────────────

  Widget _controlesFlotantes() {
    final s = context.mp;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        MpTokens.space12,
        MpTokens.screenPadding,
        MpTokens.space12,
      ),
      decoration: BoxDecoration(color: s.card, boxShadow: MpTokens.cardShadow),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _encabezado(flotante: true),
          const SizedBox(height: MpTokens.space12),
          _filtros(flotante: true),
        ],
      ),
    );
  }

  // ── Encabezado ────────────────────────────────────────────────────────────

  /// [flotante]: cuando el encabezado vive dentro de `_controlesFlotantes()`
  /// (mapa a pantalla completa), el padding ya lo pone el contenedor de
  /// afuera y el título va más chico — es una barra compacta sobre el mapa,
  /// no el título grande de una pantalla con scroll normal.
  Widget _encabezado({bool flotante = false}) {
    final s = context.mp;
    final total = _visibles.length;

    return Padding(
      padding: flotante
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(
              MpTokens.screenPadding,
              MpTokens.space12,
              MpTokens.screenPadding,
              0,
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mapa de candidatos',
                  style: MpTokens.h1.copyWith(
                    color: s.text,
                    fontSize: flotante ? 19 : 25,
                  ),
                ),
                const SizedBox(height: MpTokens.space4),
                Text(
                  total == 0
                      ? 'Sin candidatos con ubicación'
                      : '$total ${total == 1 ? 'candidato' : 'candidatos'} con ubicación',
                  style: MpTokens.body.copyWith(
                    color: s.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          MpIconButton(icon: CupertinoIcons.refresh, onPressed: _load),
        ],
      ),
    );
  }

  Widget _filtros({bool flotante = false}) {
    return Padding(
      padding: flotante
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: MpTokens.screenPadding),
      child: MpSegmentedFilter(
        options: [
          MpFilterOption('Todos', count: _data.candidatos.length),
          MpFilterOption(
            'Con video',
            count: _data.candidatos.where((c) => c.tieneVideo).length,
          ),
          MpFilterOption(
            'Cerca',
            count: _data.candidatos
                .where((c) => c.distanciaKm != null && c.distanciaKm! <= 25)
                .length,
          ),
        ],
        selectedIndex: _filtro,
        onChanged: (i) => setState(() => _filtro = i),
      ),
    );
  }

  // ── Mapa ──────────────────────────────────────────────────────────────────

  /// [fullBleed]: mapa a pantalla completa (sin margen ni bordes
  /// redondeados) para el layout nuevo, donde el mapa va de punta a punta y
  /// el encabezado/filtros flotan arriba (`_controlesFlotantes`). Los
  /// controles propios del mapa (ubicación / deseleccionar) bajan para no
  /// quedar tapados por esa barra flotante.
  Widget _mapa({bool fullBleed = false}) {
    final s = context.mp;
    final visibles = _visibles;

    final contenido = Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: s.fill,
                // En modo vista previa (golden tests) no se instancia el mapa
                // real: `webview_flutter` no tiene implementación de plataforma
                // fuera de la app y reventaría el test.
                child: visibles.isEmpty || widget.previewData != null
                    ? Center(
                        child: Icon(
                          CupertinoIcons.map,
                          size: 40,
                          color: s.textTertiary,
                        ),
                      )
                    // Infraestructura existente: Leaflet en iframe para web,
                    // mapa nativo en móvil. No se reimplementa.
                    : (kIsWeb ? buildWebMap : buildMobileMap)(
                        centerLat: _data.centroLat,
                        centerLng: _data.centroLng,
                        zoom: 11,
                        pins: [for (final c in visibles) c.comoPin],
                        selectedId: _seleccionado,
                        onPinTap: (id) =>
                            setState(() => _seleccionado = id),
                      ),
              ),
            ),
            Positioned(
              right: MpTokens.space12,
              // Full-bleed: la barra flotante de encabezado + filtros ocupa
              // la parte de arriba, así que estos botones bajan para no
              // quedar tapados por ella.
              top: fullBleed ? 148 : MpTokens.space12,
              child: Column(
                children: [
                  _controlMapa(CupertinoIcons.location_fill, _load),
                  const SizedBox(height: MpTokens.space8),
                  _controlMapa(
                    CupertinoIcons.square_stack_3d_up,
                    () => setState(() => _seleccionado = null),
                  ),
                ],
              ),
            ),
          ],
        );

    if (fullBleed) return contenido;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MpTokens.screenPadding),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MpTokens.radiusXL),
        child: contenido,
      ),
    );
  }

  Widget _controlMapa(IconData icon, VoidCallback onTap) {
    final s = context.mp;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: s.card,
          borderRadius: BorderRadius.circular(MpTokens.radiusMD),
          boxShadow: MpTokens.cardShadow,
        ),
        child: Icon(icon, size: 18, color: s.text),
      ),
    );
  }

  // ── Hoja inferior ─────────────────────────────────────────────────────────

  Widget _hoja() {
    final s = context.mp;
    final visibles = _visibles;

    return Container(
      margin: const EdgeInsets.only(top: MpTokens.space12),
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(MpTokens.radiusXXL),
        ),
        boxShadow: MpTokens.raisedShadow,
      ),
      child: Column(
        children: [
          // Tirador, como en el mockup.
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: MpTokens.space12),
            decoration: BoxDecoration(
              color: s.borderStrong,
              borderRadius: BorderRadius.circular(MpTokens.radiusPill),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MpTokens.screenPadding,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Candidatos cerca',
                    style: MpTokens.h2.copyWith(color: s.text, fontSize: 17),
                  ),
                ),
                if (visibles.isNotEmpty)
                  Text(
                    'Más cercanos',
                    style: MpTokens.label.copyWith(color: s.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: MpTokens.space12),
          Expanded(
            child: visibles.isEmpty ? _vacio() : _lista(visibles),
          ),
        ],
      ),
    );
  }

  Widget _vacio() {
    return SingleChildScrollView(
      child: MpEmptyState(
        icon: _data.error
            ? CupertinoIcons.exclamationmark_triangle
            : CupertinoIcons.map_pin_slash,
        title: _data.error
            ? 'No pudimos cargar el mapa'
            : 'Sin candidatos con ubicación',
        message: _data.error
            ? 'Revisá tu conexión y volvé a intentar.'
            : 'Cuando haya talento con ubicación publicada lo vas a ver acá.',
        actionLabel: _data.error ? 'Reintentar' : null,
        onAction: _data.error ? _load : null,
      ),
    );
  }

  Widget _lista(List<CandidatoCercano> visibles) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        0,
        MpTokens.screenPadding,
        MpTokens.space20,
      ),
      itemCount: visibles.length,
      separatorBuilder: (_, __) => const SizedBox(height: MpTokens.space8),
      itemBuilder: (context, i) => _fila(visibles[i]),
    );
  }

  Widget _fila(CandidatoCercano candidato) {
    final s = context.mp;
    final activo = candidato.id == _seleccionado;

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.all(MpTokens.space12),
      highlighted: activo,
      onTap: () => _abrirCandidato(candidato),
      child: Row(
        children: [
          MpAvatar(
            name: candidato.nombre,
            size: 46,
            image: (candidato.avatar?.isNotEmpty ?? false)
                ? NetworkImage(candidato.avatar!)
                : null,
          ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  candidato.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MpTokens.title.copyWith(color: s.text, fontSize: 15.5),
                ),
                if (candidato.headline.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    candidato.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MpTokens.label.copyWith(
                      color: MpTokens.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Wrap(
                  spacing: 12,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Distancia REAL de la RPC; si no viene, no se muestra.
                    if (candidato.distancia != null)
                      _meta(CupertinoIcons.placemark, candidato.distancia!),
                    if (candidato.tieneVideo)
                      _meta(CupertinoIcons.play_circle, 'Video pitch'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => ChatInmailScreen(
                  targetUser: NexUser(
                    id: candidato.id,
                    name: candidato.nombre,
                    headline: candidato.headline,
                    avatarUrl: candidato.avatar,
                  ),
                ),
              ),
            ),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: MpTokens.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(MpTokens.radiusMD),
              ),
              child: const Icon(
                CupertinoIcons.chat_bubble_text,
                size: 17,
                color: MpTokens.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String label) {
    final s = context.mp;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.5, color: s.textTertiary),
        const SizedBox(width: 4),
        Text(
          label,
          style: MpTokens.caption.copyWith(
            color: s.textSecondary,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}
