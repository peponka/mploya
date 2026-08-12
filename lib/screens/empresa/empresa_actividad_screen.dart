import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/ds/mploya_ds.dart';

/// Categorías de la barra superior de `actividad y notificaciones.png`.
enum ActividadTipo { candidatos, entrevistas, vacantes, sistema }

/// Una notificación real, ya clasificada.
@immutable
class Actividad {
  final String id;
  final String titulo;
  final String? detalle;
  final ActividadTipo tipo;
  final DateTime? fecha;
  final bool leida;

  const Actividad({
    required this.id,
    required this.titulo,
    required this.tipo,
    this.detalle,
    this.fecha,
    this.leida = false,
  });

  /// "Hoy" / "Ayer" / "Anteriores": los grupos del mockup.
  String get grupo {
    if (fecha == null) return 'Anteriores';
    final hoy = DateTime.now();
    final f = fecha!;
    final mismoDia = f.year == hoy.year && f.month == hoy.month && f.day == hoy.day;
    if (mismoDia) return 'Hoy';
    final ayer = hoy.subtract(const Duration(days: 1));
    if (f.year == ayer.year && f.month == ayer.month && f.day == ayer.day) {
      return 'Ayer';
    }
    return 'Anteriores';
  }

  String get hora {
    if (fecha == null) return '';
    final h = fecha!.hour.toString().padLeft(2, '0');
    final m = fecha!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

@immutable
class ActividadData {
  final List<Actividad> items;

  /// La consulta falló (p. ej. permisos). Se distingue de "no hay ninguna".
  final bool error;

  const ActividadData({required this.items, this.error = false});

  static const empty = ActividadData(items: []);

  int contarDe(ActividadTipo tipo) =>
      items.where((a) => a.tipo == tipo).length;

  int get sinLeer => items.where((a) => !a.leida).length;
}

/// Clasifica el `type` REAL de la tabla en las categorías del mockup.
///
/// Los valores existentes son 'like', 'comment', 'connection', 'profileView',
/// 'jobAlert', 'mention' y los que agregue el backend. Lo que no encaja va a
/// Sistema en vez de inventarle una categoría.
ActividadTipo _clasificar(String type) {
  final t = type.toLowerCase();
  if (t.contains('interview') || t.contains('entrevista') ||
      t.contains('schedul')) {
    return ActividadTipo.entrevistas;
  }
  if (t.contains('job') || t.contains('vacante') || t.contains('applic') ||
      t.contains('postul')) {
    return ActividadTipo.vacantes;
  }
  if (t.contains('connection') || t.contains('profileview') ||
      t.contains('match') || t.contains('like') || t.contains('comment') ||
      t.contains('mention') || t.contains('candidat')) {
    return ActividadTipo.candidatos;
  }
  return ActividadTipo.sistema;
}

Future<ActividadData> loadEmpresaActividad() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return ActividadData.empty;

  try {
    final filas = List<Map<String, dynamic>>.from(
      await client
          .from('notifications')
          .select('id, type, title, body, is_read, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(100),
    );

    return ActividadData(
      items: [
        for (final fila in filas)
          Actividad(
            id: fila['id'].toString(),
            titulo: (fila['title']?.toString().isNotEmpty ?? false)
                ? fila['title'].toString()
                : 'Actividad',
            detalle: (fila['body']?.toString().isNotEmpty ?? false)
                ? fila['body'].toString()
                : null,
            tipo: _clasificar(fila['type']?.toString() ?? ''),
            fecha: DateTime.tryParse(fila['created_at']?.toString() ?? ''),
            leida: fila['is_read'] == true,
          ),
      ],
    );
  } catch (e) {
    debugPrint('actividad · notifications: $e');
    return const ActividadData(items: [], error: true);
  }
}

/// Actividad y Notificaciones de Empresa.
///
/// RECONSTRUCCIÓN DIRECTA desde `actividad y notificaciones.png`
/// (17. Actividad y Notificaciones): título "Actividad" + campana y filtro ·
/// barra de categorías con contador · listado agrupado por Hoy / Ayer ·
/// tarjeta "Insights de tu actividad".
///
/// Los ejemplos del mockup (Camila Rodríguez, Juan Pérez, 245 vistas…) NO se
/// copian: se listan las notificaciones reales del usuario y, si no hay, va el
/// estado vacío.
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 12/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
class EmpresaActividadScreen extends StatefulWidget {
  final ActividadData? previewData;

  const EmpresaActividadScreen({super.key, this.previewData});

  @override
  State<EmpresaActividadScreen> createState() => _EmpresaActividadScreenState();
}

class _EmpresaActividadScreenState extends State<EmpresaActividadScreen> {
  ActividadData _data = ActividadData.empty;
  bool _loading = true;

  /// null = pestaña "Todo".
  ActividadTipo? _filtro;

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
    final data = await loadEmpresaActividad();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  List<Actividad> get _visibles => _filtro == null
      ? _data.items
      : _data.items.where((a) => a.tipo == _filtro).toList();

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 15))
            : CustomScrollView(
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _load),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      MpTokens.screenPadding,
                      MpTokens.space12,
                      MpTokens.screenPadding,
                      MpTokens.space32,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _encabezado(),
                        const SizedBox(height: MpTokens.space16),
                        _categorias(),
                        const SizedBox(height: MpTokens.space20),
                        ..._listado(),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _encabezado() {
    final s = context.mp;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Actividad', style: MpTokens.h1.copyWith(color: s.text)),
              const SizedBox(height: MpTokens.space4),
              Text(
                'Mantenete al día con todo lo que sucede',
                style: MpTokens.body.copyWith(
                  color: s.textSecondary,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: MpTokens.space12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            MpIconButton(icon: CupertinoIcons.bell, onPressed: _load),
            if (_data.sinLeer > 0)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  constraints: const BoxConstraints(minWidth: 21),
                  decoration: BoxDecoration(
                    color: MpTokens.primary,
                    borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                    border: Border.all(color: s.bg, width: 2),
                  ),
                  child: Text(
                    '${_data.sinLeer}',
                    textAlign: TextAlign.center,
                    style: MpTokens.micro.copyWith(
                      color: const Color(0xFFFFFFFF),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── Categorías ────────────────────────────────────────────────────────────

  static const _categoriaIconos = {
    ActividadTipo.candidatos: CupertinoIcons.person,
    ActividadTipo.entrevistas: CupertinoIcons.calendar,
    ActividadTipo.vacantes: CupertinoIcons.briefcase,
    ActividadTipo.sistema: CupertinoIcons.settings,
  };

  static const _categoriaNombres = {
    ActividadTipo.candidatos: 'Candidatos',
    ActividadTipo.entrevistas: 'Entrevistas',
    ActividadTipo.vacantes: 'Vacantes',
    ActividadTipo.sistema: 'Sistema',
  };

  Widget _categorias() {
    final s = context.mp;

    Widget item({
      required IconData icon,
      required String label,
      required int count,
      required bool active,
      required VoidCallback onTap,
    }) {
      final color = active ? s.accent : s.textSecondary;

      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 23, color: color),
                  if (count > 0)
                    Positioned(
                      top: -7,
                      right: -11,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(minWidth: 17),
                        decoration: BoxDecoration(
                          color: MpTokens.primary,
                          borderRadius:
                              BorderRadius.circular(MpTokens.radiusPill),
                        ),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: MpTokens.micro.copyWith(
                            color: const Color(0xFFFFFFFF),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: MpTokens.micro.copyWith(
                    color: color,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 2.5,
                width: 30,
                decoration: BoxDecoration(
                  color: active ? s.accent : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(MpTokens.radiusPill),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: item(
            icon: CupertinoIcons.waveform,
            label: 'Todo',
            count: _data.items.length,
            active: _filtro == null,
            onTap: () => setState(() => _filtro = null),
          ),
        ),
        for (final tipo in ActividadTipo.values)
          Expanded(
            child: item(
              icon: _categoriaIconos[tipo]!,
              label: _categoriaNombres[tipo]!,
              count: _data.contarDe(tipo),
              active: _filtro == tipo,
              onTap: () => setState(() => _filtro = tipo),
            ),
          ),
      ],
    );
  }

  // ── Listado ───────────────────────────────────────────────────────────────

  List<Widget> _listado() {
    final s = context.mp;
    final visibles = _visibles;

    if (visibles.isEmpty) {
      return [
        MpCard(
          padding: const EdgeInsets.symmetric(vertical: MpTokens.space24),
          child: MpEmptyState(
            icon: _data.error
                ? CupertinoIcons.exclamationmark_triangle
                : CupertinoIcons.bell,
            title: _data.error
                ? 'No pudimos cargar tu actividad'
                : 'Sin actividad todavía',
            message: _data.error
                ? 'Revisá tu conexión y volvé a intentar.'
                : 'Cuando haya movimiento en tus vacantes y candidatos lo vas a ver acá.',
            actionLabel: _data.error ? 'Reintentar' : null,
            onAction: _data.error ? _load : null,
          ),
        ),
      ];
    }

    // Agrupado por Hoy / Ayer / Anteriores, como el mockup.
    final grupos = <String, List<Actividad>>{};
    for (final item in visibles) {
      grupos.putIfAbsent(item.grupo, () => []).add(item);
    }

    final orden = ['Hoy', 'Ayer', 'Anteriores'];
    final widgets = <Widget>[];

    for (final grupo in orden) {
      final items = grupos[grupo];
      if (items == null || items.isEmpty) continue;

      widgets
        ..add(
          Padding(
            padding: const EdgeInsets.only(bottom: MpTokens.space12),
            child: Text(
              grupo,
              style: MpTokens.h2.copyWith(color: s.text, fontSize: 18),
            ),
          ),
        )
        ..add(
          MpRowGroup(
            dividerIndent: 62,
            rows: [for (final item in items) _fila(item)],
          ),
        )
        ..add(const SizedBox(height: MpTokens.space20));
    }

    return widgets;
  }

  static const _tipoColores = {
    ActividadTipo.candidatos: MpTokens.primary,
    ActividadTipo.entrevistas: MpTokens.catGreen,
    ActividadTipo.vacantes: MpTokens.catOrange,
    ActividadTipo.sistema: MpTokens.catBlue,
  };

  MpListRow _fila(Actividad item) {
    return MpListRow(
      leading: MpIconTile(
        icon: _categoriaIconos[item.tipo]!,
        color: _tipoColores[item.tipo]!,
        size: 38,
        circular: true,
        // Las no leídas se marcan con el ícono relleno.
        solid: !item.leida,
      ),
      title: item.titulo,
      // Los títulos reales son frases, no etiquetas: en una línea se cortaban.
      titleMaxLines: 2,
      subtitle: item.detalle,
      trailingText: item.hora,
      showChevron: false,
    );
  }
}
