import 'package:flutter/cupertino.dart';

import '../../models/models.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../chat_inmail_screen.dart';
import 'empresa_mensajes_data.dart';

/// Mensajes de Empresa — lista de conversaciones a pantalla completa.
///
/// DERIVACIÓN CONTROLADA de `mensaes especiales.png` (38. Mensajes), que es de
/// escritorio y tiene tres columnas. En móvil se toma SÓLO la columna de
/// conversaciones y se lleva a pantalla completa; al tocar una, el chat abre
/// también a pantalla completa (`ChatInmailScreen`, la lógica que ya existe).
///
/// Sin conversaciones inventadas: todo sale de `messages` + `users`.
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 12/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
class EmpresaMensajesScreen extends StatefulWidget {
  final MensajesData? previewData;

  const EmpresaMensajesScreen({super.key, this.previewData});

  @override
  State<EmpresaMensajesScreen> createState() => _EmpresaMensajesScreenState();
}

class _EmpresaMensajesScreenState extends State<EmpresaMensajesScreen> {
  MensajesData _data = MensajesData.empty;
  bool _loading = true;

  final _buscador = TextEditingController();
  String _query = '';

  /// 0 = Todos · 1 = Sin leer
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

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.previewData != null) return;
    if (!mounted) return;
    setState(() => _loading = true);
    final data = await loadEmpresaConversaciones();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  List<Conversacion> get _visibles {
    var lista = _data.conversaciones;
    if (_filtro == 1) {
      lista = lista.where((c) => c.sinLeer > 0).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      lista = lista
          .where((c) =>
              c.nombre.toLowerCase().contains(q) ||
              c.ultimoMensaje.toLowerCase().contains(q))
          .toList();
    }
    return lista;
  }

  Future<void> _abrirChat(Conversacion c) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatInmailScreen(
          targetUser: NexUser(
            id: c.otroId,
            name: c.nombre,
            headline: c.headline,
            avatarUrl: c.avatar,
          ),
        ),
      ),
    );
    // Al volver puede haber cambiado el estado de lectura.
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 15))
            : Column(
                children: [
                  _encabezado(),
                  const SizedBox(height: MpTokens.space12),
                  _buscadorYFiltros(),
                  const SizedBox(height: MpTokens.space12),
                  Expanded(child: _lista()),
                ],
              ),
      ),
    );
  }

  Widget _encabezado() {
    final s = context.mp;
    final sinLeer = _data.totalSinLeer;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
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
                Text('Mensajes', style: MpTokens.h1.copyWith(color: s.text)),
                const SizedBox(height: MpTokens.space4),
                Text(
                  sinLeer > 0
                      ? '$sinLeer sin leer'
                      : 'Comunicate con el talento y avanzá en el proceso.',
                  style: MpTokens.body.copyWith(
                    color: sinLeer > 0 ? MpTokens.primary : s.textSecondary,
                    fontSize: 14,
                    fontWeight:
                        sinLeer > 0 ? FontWeight.w600 : FontWeight.w400,
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

  Widget _buscadorYFiltros() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MpTokens.screenPadding,
      ),
      child: Column(
        children: [
          MpTextField(
            controller: _buscador,
            placeholder: 'Buscar conversación…',
            icon: CupertinoIcons.search,
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: MpTokens.space12),
          MpSegmentedFilter(
            options: [
              MpFilterOption('Todos', count: _data.conversaciones.length),
              MpFilterOption('Sin leer', count: _data.totalSinLeer),
            ],
            selectedIndex: _filtro,
            onChanged: (i) => setState(() => _filtro = i),
          ),
        ],
      ),
    );
  }

  Widget _lista() {
    final visibles = _visibles;

    if (visibles.isEmpty) {
      return SingleChildScrollView(
        child: MpEmptyState(
          icon: _data.error
              ? CupertinoIcons.exclamationmark_triangle
              : CupertinoIcons.chat_bubble_2,
          title: _data.error
              ? 'No pudimos cargar tus mensajes'
              : (_data.conversaciones.isEmpty
                  ? 'Todavía no tenés conversaciones'
                  : 'Sin resultados'),
          message: _data.error
              ? 'Revisá tu conexión y volvé a intentar.'
              : (_data.conversaciones.isEmpty
                  ? 'Cuando escribas a un candidato desde el feed, la conversación aparece acá.'
                  : 'Probá con otra búsqueda o cambiá el filtro.'),
          actionLabel: _data.error ? 'Reintentar' : null,
          onAction: _data.error ? _load : null,
        ),
      );
    }

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

  Widget _fila(Conversacion c) {
    final s = context.mp;
    final noLeido = c.sinLeer > 0;

    return MpCard(
      radius: MpTokens.radiusLG,
      padding: const EdgeInsets.all(MpTokens.space12),
      onTap: () => _abrirChat(c),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mismo criterio que Pipeline/Feed: un candidato confidencial no
          // muestra su nombre ni su foto real en la lista, aunque el chat que
          // se abre al tocar sigue usando el dato real (`_abrirChat`).
          c.confidencial
              ? const MpIconTile(
                  icon: CupertinoIcons.lock_fill,
                  color: MpTokens.catIndigo,
                  size: 46,
                )
              : MpAvatar(
                  name: c.nombre,
                  size: 46,
                  image: (c.avatar?.isNotEmpty ?? false)
                      ? NetworkImage(c.avatar!)
                      : null,
                ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.confidencial ? 'Candidato confidencial' : c.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MpTokens.title.copyWith(
                          color: s.text,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: MpTokens.space8),
                    Text(
                      c.hora,
                      style: MpTokens.micro.copyWith(
                        color: noLeido ? MpTokens.primary : s.textTertiary,
                        fontWeight:
                            noLeido ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (!c.confidencial && c.headline.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    c.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MpTokens.micro.copyWith(
                      color: MpTokens.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.ultimoEsMio) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 4),
                        child: Icon(
                          CupertinoIcons.reply,
                          size: 12,
                          color: s.textTertiary,
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        c.ultimoMensaje,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MpTokens.caption.copyWith(
                          color: noLeido ? s.text : s.textSecondary,
                          fontSize: 13,
                          fontWeight:
                              noLeido ? FontWeight.w600 : FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (noLeido) ...[
                      const SizedBox(width: MpTokens.space8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        constraints: const BoxConstraints(minWidth: 20),
                        decoration: BoxDecoration(
                          color: MpTokens.primary,
                          borderRadius:
                              BorderRadius.circular(MpTokens.radiusPill),
                        ),
                        child: Text(
                          '${c.sinLeer}',
                          textAlign: TextAlign.center,
                          style: MpTokens.micro.copyWith(
                            color: const Color(0xFFFFFFFF),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
