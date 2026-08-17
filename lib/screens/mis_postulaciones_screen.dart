import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/safe_profile_query_service.dart';
import '../widgets/candidato/cand_ui.dart';
import '../widgets/ds/mploya_ds.dart';

/// MIS POSTULACIONES (candidato) — Tanda 2, polish visual en Tanda 4.
///
/// Referencia visual: design-reference/FINAL_SCREENS_CODEX/.../
/// mis postulaciones candidato.png — estructura, jerarquía, cards y filtros.
///
/// El mockup muestra 5 etapas (Enviada/Vista/Entrevista/Oferta/Contratado).
/// El CHECK real de `job_applications.status` (confirmado contra la base:
/// `job_applications_status_check CHECK (status = ANY (ARRAY['pending',
/// 'viewed','accepted','rejected']))`) solo admite 4. Esta pantalla usa
/// EXACTAMENTE esos 4 — no agrega "Entrevista" ni "Contratado" porque no hay
/// una fuente real que los respalde acá. `ghost_applications` queda afuera a
/// propósito: es una fuente de datos distinta, pendiente de una tanda futura.
///
/// Mini-timeline: sólo tenemos DOS anclas reales por postulación —
/// `created_at` (cuándo se envió) y `status` (dónde está ahora). No hay
/// historial de cambios de estado en la base, así que la tarjeta NO finge
/// fechas intermedias de "vista"/"entrevista": muestra el punto de envío y
/// el estado actual, nada más.
/// Filas ya resueltas para tests/capturas — misma forma que devuelve la
/// query real (`id, status, created_at, jobs(title, location, is_remote,
/// users(name, avatar_url))`). Mismo patrón que `ProfilePreviewData` /
/// `JobsPreviewData`: si llega, la pantalla NO consulta Supabase. Nunca es
/// fallback productivo — en producción es siempre `null`.
@immutable
class MisPostulacionesPreviewData {
  const MisPostulacionesPreviewData({required this.filas});
  final List<Map<String, dynamic>> filas;
}

class MisPostulacionesScreen extends StatefulWidget {
  const MisPostulacionesScreen({super.key, this.previewData});

  final MisPostulacionesPreviewData? previewData;

  @override
  State<MisPostulacionesScreen> createState() => _MisPostulacionesScreenState();
}

enum _Estado {
  pending,
  viewed,
  accepted,
  rejected;

  static _Estado? fromStatus(String? status) => switch (status) {
    'pending' => _Estado.pending,
    'viewed' => _Estado.viewed,
    'accepted' => _Estado.accepted,
    'rejected' => _Estado.rejected,
    _ => null,
  };
}

extension on _Estado {
  String get etiqueta => switch (this) {
    _Estado.pending => 'Enviada',
    _Estado.viewed => 'Vista',
    _Estado.accepted => 'Aceptada',
    _Estado.rejected => 'No seleccionada',
  };

  IconData get icono => switch (this) {
    _Estado.pending => CupertinoIcons.paperplane_fill,
    _Estado.viewed => CupertinoIcons.eye_fill,
    _Estado.accepted => CupertinoIcons.checkmark_seal_fill,
    _Estado.rejected => CupertinoIcons.xmark_seal_fill,
  };

  Color get color => switch (this) {
    _Estado.pending => MpTokens.info,
    _Estado.viewed => MpTokens.primary,
    _Estado.accepted => MpTokens.success,
    _Estado.rejected => MpTokens.lightTextTertiary,
  };
}

class _Postulacion {
  const _Postulacion({
    required this.id,
    required this.estado,
    required this.creada,
    required this.jobTitle,
    required this.location,
    required this.isRemote,
    required this.companyName,
    required this.companyAvatarUrl,
  });

  final String id;
  final _Estado? estado;
  final DateTime? creada;
  final String jobTitle;
  final String? location;
  final bool isRemote;
  final String companyName;
  final String? companyAvatarUrl;
}

class _MisPostulacionesScreenState extends State<MisPostulacionesScreen> {
  late final _supabase = Supabase.instance.client;

  bool _cargando = true;
  String? _error;
  List<_Postulacion> _postulaciones = const [];
  _Estado? _filtro; // null = "Todas"
  final _busquedaController = TextEditingController();
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _busquedaController.addListener(() {
      setState(() => _busqueda = _busquedaController.text.trim().toLowerCase());
    });
    // Render aislado: los datos ya vienen resueltos y no se toca la red.
    if (widget.previewData != null) {
      _postulaciones = widget.previewData!.filas.map(_filaAPostulacion).toList();
      _cargando = false;
      return;
    }
    _cargar();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  static _Postulacion _filaAPostulacion(Map<String, dynamic> row) {
    final job = row['jobs'] as Map<String, dynamic>?;
    final empresa = job?['users'] as Map<String, dynamic>?;
    return _Postulacion(
      id: row['id'].toString(),
      estado: _Estado.fromStatus(row['status']?.toString()),
      creada: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      jobTitle: job?['title']?.toString() ?? 'Vacante',
      location: job?['location']?.toString(),
      isRemote: job?['is_remote'] == true,
      companyName: empresa?['name']?.toString() ?? 'Empresa',
      companyAvatarUrl: empresa?['avatar_url']?.toString(),
    );
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) {
        setState(() {
          _postulaciones = const [];
          _cargando = false;
        });
        return;
      }
      final rows = await _supabase
          .from('job_applications')
          .select(
            'id, status, created_at, '
            'jobs(title, location, is_remote, company_id)',
          )
          .eq('candidate_id', uid)
          .order('created_at', ascending: false);
      final hydrated = await hydrateNestedJobCompanies(rows, client: _supabase);
      final lista = hydrated
          .map(_filaAPostulacion)
          .toList();

      if (!mounted) return;
      setState(() {
        _postulaciones = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Map<_Estado, int> get _conteos {
    final mapa = <_Estado, int>{};
    for (final p in _postulaciones) {
      if (p.estado == null) continue;
      mapa[p.estado!] = (mapa[p.estado!] ?? 0) + 1;
    }
    return mapa;
  }

  List<_Postulacion> get _filtradas {
    var lista = _postulaciones;
    if (_filtro != null) {
      lista = lista.where((p) => p.estado == _filtro).toList();
    }
    if (_busqueda.isNotEmpty) {
      lista = lista
          .where((p) =>
              p.jobTitle.toLowerCase().contains(_busqueda) ||
              p.companyName.toLowerCase().contains(_busqueda))
          .toList();
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    // Pantalla empujada (push) desde Mi Perfil, no un destino de tab: usa
    // `CupertinoNavigationBar` con back explícito, el mismo patrón que ya
    // usa `CandidateProfileFormScreen` en modo edición.
    return CupertinoPageScaffold(
      backgroundColor: MpSurfaceStyle.light.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: MpSurfaceStyle.light.bg,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Icon(CupertinoIcons.chevron_back),
        ),
      ),
      child: MpSurface(
        style: MpSurfaceStyle.light,
        child: _buildCuerpo(context),
      ),
    );
  }

  Widget _buildCuerpo(BuildContext context) {
    final s = context.mp;

    if (_cargando) return const CandCargandoLista();
    if (_error != null) {
      return CandError(
        titulo: 'No pudimos cargar tus postulaciones',
        detalle: _error!,
        onReintentar: _cargar,
      );
    }
    if (_postulaciones.isEmpty) {
      return const CandVacio(
        icono: CupertinoIcons.tray,
        titulo: 'Todavía no te postulaste a ninguna vacante.',
        detalle: 'Cuando te postules a una oferta, la vas a ver acá con su estado real.',
      );
    }

    final conteos = _conteos;
    final filtradas = _filtradas;

    return ListView(
      padding: const EdgeInsets.only(bottom: MpTokens.space24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mis Postulaciones', style: MpTokens.h1.copyWith(fontSize: 28, color: s.text)),
              const SizedBox(height: MpTokens.space4),
              Text(
                'Seguimiento de tus postulaciones reales',
                style: MpTokens.body.copyWith(color: s.textTertiary),
              ),
            ],
          ),
        ),
        const SizedBox(height: MpTokens.space16),
        _buildResumen(conteos),
        const SizedBox(height: MpTokens.space16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: MpTextField(
            controller: _busquedaController,
            icon: CupertinoIcons.search,
            placeholder: 'Buscar por empresa o cargo',
          ),
        ),
        const SizedBox(height: MpTokens.space12),
        CandFilaChips(
          children: [
            CandChip(
              'Todas (${_postulaciones.length})',
              activo: _filtro == null,
              onTap: () => setState(() => _filtro = null),
            ),
            for (final estado in _Estado.values)
              CandChip(
                '${estado.etiqueta} (${conteos[estado] ?? 0})',
                activo: _filtro == estado,
                color: estado.color,
                onTap: () => setState(() => _filtro = estado),
              ),
          ],
        ),
        const SizedBox(height: MpTokens.space16),
        if (filtradas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: CandVacio(
              icono: CupertinoIcons.slider_horizontal_3,
              titulo: 'Nada con este filtro',
              detalle: 'Probá con otro estado, otra búsqueda o volvé a "Todas".',
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (final p in filtradas) ...[
                  _buildTarjeta(p),
                  const SizedBox(height: MpTokens.space12),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // Tarjetas de resumen en fila horizontal scrolleable: a propósito, para que
  // ninguna etiqueta se corte por falta de ancho (antes "Aceptada"/
  // "No seleccionada" quedaban en "Aceptad…"/"No sel…" a 5 columnas fijas
  // en 390px). Ícono en círculo de color + número + etiqueta COMPLETA.
  Widget _buildResumen(Map<_Estado, int> conteos) {
    final tiles = <(String, int, IconData, Color)>[
      ('Total', _postulaciones.length, CupertinoIcons.doc_text_fill, MpTokens.primary),
      for (final estado in _Estado.values)
        (estado.etiqueta, conteos[estado] ?? 0, estado.icono, estado.color),
    ];
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: MpTokens.space8),
        itemBuilder: (context, i) {
          final (label, valor, icono, color) = tiles[i];
          return _statTile(label, valor, icono, color);
        },
      ),
    );
  }

  Widget _statTile(String label, int valor, IconData icono, Color color) {
    return CandTarjeta(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: SizedBox(
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(icono, size: 13, color: color),
                ),
                const SizedBox(width: MpTokens.space8),
                Text('$valor', style: MpTokens.stat.copyWith(fontSize: 20, color: color)),
              ],
            ),
            const SizedBox(height: MpTokens.space4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: MpTokens.micro.copyWith(color: MpTokens.lightTextTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTarjeta(_Postulacion p) {
    final estado = p.estado;
    return CandTarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CandAvatar(nombre: p.companyName, imagenUrl: p.companyAvatarUrl, tamano: 48),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.jobTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MpTokens.title.copyWith(fontSize: 15.5),
                    ),
                    const SizedBox(height: MpTokens.space2),
                    Text(
                      p.companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MpTokens.body.copyWith(color: MpTokens.lightTextSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MpTokens.space8),
              if (estado != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: estado.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(estado.icono, size: 11, color: estado.color),
                      const SizedBox(width: 4),
                      Text(
                        estado.etiqueta,
                        style: MpTokens.micro.copyWith(color: estado.color, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: MpTokens.space12),
          Wrap(
            spacing: MpTokens.space8,
            runSpacing: MpTokens.space4,
            children: [
              if (p.isRemote) const CandChip('Remoto', compacto: true),
              if (p.location != null &&
                  p.location!.trim().isNotEmpty &&
                  p.location!.trim().toLowerCase() != 'remoto')
                CandChip(p.location!, compacto: true),
            ],
          ),
          if (p.creada != null) ...[
            const SizedBox(height: MpTokens.space12),
            _miniTimeline(p),
          ],
        ],
      ),
    );
  }

  // Mini-timeline honesta: sólo 2 anclas reales (envío → estado actual). No
  // se dibuja "vista"/"entrevista" como paso intermedio porque no hay fecha
  // real de cuándo pasó — sólo sabemos que HOY está en `estado`.
  Widget _miniTimeline(_Postulacion p) {
    final color = p.estado?.color ?? MpTokens.lightTextTertiary;
    return Row(
      children: [
        Container(width: 7, height: 7, decoration: const BoxDecoration(color: MpTokens.lightTextTertiary, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('Enviada ${_fechaRelativa(p.creada!)}', style: MpTokens.micro.copyWith(color: MpTokens.lightTextTertiary)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(height: 1.5, color: color.withValues(alpha: 0.35)),
          ),
        ),
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          p.estado?.etiqueta ?? 'Sin estado',
          style: MpTokens.micro.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  String _fechaRelativa(DateTime fecha) {
    final dias = DateTime.now().difference(fecha).inDays;
    if (dias <= 0) return 'hoy';
    if (dias == 1) return 'ayer';
    if (dias < 30) return 'hace $dias días';
    // Numérico a propósito, sin nombres de mes: `DateFormat('d MMM', 'es')`
    // requiere `initializeDateFormatting()`, que esta app nunca llama en
    // `main.dart` — con locale explícito revienta con `LocaleDataException`
    // en cualquier postulación de más de 30 días.
    return 'el ${fecha.day}/${fecha.month}/${fecha.year.toString().substring(2)}';
  }
}
