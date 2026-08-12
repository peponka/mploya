import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/ds/mploya_ds.dart';
import '../camera_screen.dart';

/// Estado del video institucional de la empresa (`users.video_url`).
@immutable
class VideoPitchEmpresa {
  final String? videoUrl;
  final bool error;

  const VideoPitchEmpresa({this.videoUrl, this.error = false});

  bool get tieneVideo => videoUrl != null && videoUrl!.isNotEmpty;
}

Future<VideoPitchEmpresa> loadVideoPitch() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return const VideoPitchEmpresa(error: true);

  try {
    final fila = await client
        .from('users')
        .select('video_url')
        .eq('id', uid)
        .maybeSingle();
    final url = fila?['video_url']?.toString() ?? '';
    return VideoPitchEmpresa(videoUrl: url.isEmpty ? null : url);
  } catch (e) {
    debugPrint('video pitch · users: $e');
    return const VideoPitchEmpresa(error: true);
  }
}

/// Quita el video del perfil. No borra el archivo del bucket: sólo deja de
/// mostrarse, que es lo que la app puede garantizar desde el cliente.
Future<bool> quitarVideoPitch() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return false;

  try {
    await client.from('users').update({'video_url': null}).eq('id', uid);
    return true;
  } catch (e) {
    debugPrint('video pitch · quitar: $e');
    return false;
  }
}

/// Video pitch de la empresa.
///
/// RECONSTRUCCIÓN de `video pitch de tu empresa.png`, que es mobile, oscura y de
/// Empresa: título, tip, guía de cuatro puntos de qué contar, y el control de
/// grabación. Se conserva esa estructura y se quita el paso "3 de 3" del
/// onboarding, porque acá se entra desde el perfil, no desde el alta.
///
/// REEMPLAZA a "Equipo / Miembros / Roles", que quedó clasificada C: no existe
/// NINGUNA infraestructura de multitenancy —ni `company_members`, ni `team`, ni
/// roles, ni invitaciones—, así que una lista de miembros habría sido inventada
/// entera.
///
/// LÓGICA REUTILIZADA: la grabación es la misma [CameraScreen] que ya usan el
/// onboarding, el reto de pitch y el compositor; sube el video y actualiza
/// `users.video_url`. Acá no se reimplementa la cámara: se entra y se relee el
/// estado al volver.
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 12/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
class EmpresaVideoPitchScreen extends StatefulWidget {
  /// Datos ya resueltos, para los golden tests.
  final VideoPitchEmpresa? previewData;

  const EmpresaVideoPitchScreen({super.key, this.previewData});

  @override
  State<EmpresaVideoPitchScreen> createState() =>
      _EmpresaVideoPitchScreenState();
}

class _EmpresaVideoPitchScreenState extends State<EmpresaVideoPitchScreen> {
  VideoPitchEmpresa _data = const VideoPitchEmpresa();
  bool _loading = true;
  bool _quitando = false;
  String? _aviso;

  static const _guia = [
    'Presentá tu empresa y a qué se dedican',
    'Qué los hace únicos y por qué es un gran lugar para trabajar',
    'Qué tipo de talento están buscando',
    'Sé claro, auténtico y breve',
  ];

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
    final data = await loadVideoPitch();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  Future<void> _grabar() async {
    if (widget.previewData != null) return;
    await Navigator.of(context).push<bool>(
      CupertinoPageRoute(builder: (_) => const CameraScreen()),
    );
    // La cámara sube y guarda por su cuenta: al volver se relee el estado real
    // en vez de asumir que salió bien.
    await _load();
  }

  Future<void> _quitar() async {
    if (widget.previewData != null || _quitando) return;
    setState(() {
      _quitando = true;
      _aviso = null;
    });

    final ok = await quitarVideoPitch();
    if (!mounted) return;

    if (ok) {
      await _load();
      if (!mounted) return;
      setState(() => _quitando = false);
    } else {
      setState(() {
        _quitando = false;
        _aviso = 'No pudimos quitar el video. Probá de nuevo en un momento.';
      });
    }
  }

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
                  title: 'Video de tu empresa',
                  subtitle: 'Contales en 60 segundos quiénes son.',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CupertinoActivityIndicator(radius: 15))
                    : CustomScrollView(
                        slivers: [
                          CupertinoSliverRefreshControl(onRefresh: _load),
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
              if (!_loading) _barraAcciones(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _cuerpo() {
    if (_data.error) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: MpTokens.space32),
          child: MpEmptyState(
            icon: CupertinoIcons.exclamationmark_triangle,
            title: 'No pudimos leer tu video',
            message: 'Revisá tu conexión y volvé a intentar.',
            actionLabel: 'Reintentar',
            onAction: _load,
          ),
        ),
      ];
    }

    return [
      _estado(),
      if (_aviso != null) ...[
        const SizedBox(height: MpTokens.space16),
        MpBanner(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: 'No se pudo',
          message: _aviso!,
          color: MpTokens.danger,
          onDismiss: () => setState(() => _aviso = null),
        ),
      ],
      const SizedBox(height: MpTokens.space20),
      _guiaCard(),
      const SizedBox(height: MpTokens.space16),
      _visibilidad(),
    ];
  }

  Widget _estado() {
    final s = context.mp;
    final tiene = _data.tieneVideo;

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MpIconTile(
                icon: tiene
                    ? CupertinoIcons.checkmark_seal_fill
                    : CupertinoIcons.videocam,
                color: tiene ? MpTokens.success : MpTokens.premium,
                size: 46,
              ),
              const SizedBox(width: MpTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tiene ? 'Tu empresa tiene video' : 'Todavía sin video',
                      style: MpTokens.title.copyWith(color: s.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tiene
                          ? 'Los candidatos lo ven en tu perfil.'
                          : 'Las empresas con video reciben más postulaciones '
                              'porque se entiende quiénes son.',
                      style: MpTokens.caption.copyWith(
                        color: s.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tiene) ...[
            const SizedBox(height: MpTokens.space12),
            MpButton(
              label: 'Quitar del perfil',
              icon: CupertinoIcons.trash,
              variant: MpButtonVariant.neutral,
              size: MpButtonSize.small,
              expand: true,
              loading: _quitando,
              color: MpTokens.danger,
              onPressed: _quitar,
            ),
          ],
        ],
      ),
    );
  }

  Widget _guiaCard() {
    final s = context.mp;

    return MpCard(
      radius: MpTokens.radiusXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.play_rectangle_fill,
                size: 18,
                color: s.accent,
              ),
              const SizedBox(width: MpTokens.space8),
              Text(
                'Guía para tu video',
                style: MpTokens.title.copyWith(color: s.accent, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: MpTokens.space12),
          for (final punto in _guia)
            Padding(
              padding: const EdgeInsets.only(bottom: MpTokens.space8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    CupertinoIcons.checkmark_circle,
                    size: 16,
                    color: s.accent,
                  ),
                  const SizedBox(width: MpTokens.space8),
                  Expanded(
                    child: Text(
                      punto,
                      style: MpTokens.body.copyWith(
                        color: s.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _visibilidad() {
    final s = context.mp;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(CupertinoIcons.shield, size: 16, color: s.textTertiary),
        const SizedBox(width: MpTokens.space8),
        Expanded(
          child: Text(
            'Este video es visible en tu perfil para que los candidatos '
            'conozcan tu empresa.',
            style: MpTokens.micro.copyWith(color: s.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _barraAcciones() {
    final s = context.mp;

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
      child: MpButton(
        label: _data.tieneVideo ? 'Grabar uno nuevo' : 'Grabar video',
        icon: CupertinoIcons.videocam_fill,
        size: MpButtonSize.large,
        expand: true,
        onPressed: _data.error ? null : _grabar,
      ),
    );
  }
}
