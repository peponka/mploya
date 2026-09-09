import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import '../../models/models.dart';
import '../../services/company_culture_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/ds/mploya_ds.dart';
import '../micro_pitch_web_stub.dart'
    if (dart.library.html) '../micro_pitch_web_recorder.dart';

/// Editor de "Cultura de la Empresa" (Pantalla 40).
///
/// Construida el 29/8/2026 a pedido explícito de Pedro. Hasta ahora esta
/// pantalla se omitía A PROPÓSITO (ver `empresa_perfil_screen.dart` y
/// `empresa_editar_perfil_screen.dart`, sección "OMITIDO, y por qué") porque
/// no existía tabla para el video institucional, los valores ni las
/// historias del equipo. Migración `046_company_culture.sql` agrega el
/// modelo real; `CompanyCultureService` lee y escribe contra eso.
///
/// Sin datos de muestra en ningún lado: si algo no se cargó todavía, se
/// muestra vacío con una acción para agregarlo — nunca un placeholder que
/// parezca contenido real.
///
/// Iconos de "valores": set fijo y chico (no hay picker de íconos en el
/// mockup, y agregar uno completo sería inventar UI que no está pedida).
const List<IconData> kCompanyValorIconos = [
  CupertinoIcons.star_fill,
  CupertinoIcons.bolt_fill,
  CupertinoIcons.heart_fill,
  CupertinoIcons.person_3_fill,
  CupertinoIcons.rosette,
  CupertinoIcons.leaf_arrow_circlepath,
];

String keyForCultureValorIcon(IconData icon) {
  final i = kCompanyValorIconos.indexOf(icon);
  return i == -1 ? 'star' : 'v$i';
}

IconData iconForCultureValorKey(String key) {
  if (key.startsWith('v')) {
    final i = int.tryParse(key.substring(1));
    if (i != null && i >= 0 && i < kCompanyValorIconos.length) {
      return kCompanyValorIconos[i];
    }
  }
  return CupertinoIcons.star_fill;
}

class EmpresaCulturaEditorScreen extends StatefulWidget {
  final NexUser empresa;

  /// Datos ya resueltos, para los golden tests: si llegan, no se consulta
  /// Supabase y las acciones de guardar/subir no hacen nada real.
  final CompanyCulture? previewCulture;
  final List<CompanyCultureStory>? previewStories;
  final bool previewMode;

  const EmpresaCulturaEditorScreen({
    super.key,
    required this.empresa,
    this.previewCulture,
    this.previewStories,
    this.previewMode = false,
  });

  @override
  State<EmpresaCulturaEditorScreen> createState() =>
      _EmpresaCulturaEditorScreenState();
}

class _CulturaValorDraft {
  IconData icon;
  final TextEditingController titulo;
  final TextEditingController descripcion;

  _CulturaValorDraft({required this.icon, String? titulo, String? descripcion})
      : titulo = TextEditingController(text: titulo ?? ''),
        descripcion = TextEditingController(text: descripcion ?? '');

  void dispose() {
    titulo.dispose();
    descripcion.dispose();
  }
}

class _EmpresaCulturaEditorScreenState
    extends State<EmpresaCulturaEditorScreen> {
  bool _cargando = true;
  bool _guardando = false;
  String? _aviso;

  String? _introVideoUrl;
  int? _introVideoDuration;
  bool _subiendoIntro = false;

  late final List<_CulturaValorDraft> _valores;
  final _fundacion = TextEditingController();
  final _empleados = TextEditingController();
  final _crecimiento = TextEditingController();

  List<CompanyCultureStory> _historias = [];
  bool _subiendoHistoria = false;

  @override
  void initState() {
    super.initState();
    _valores = [];
    _cargar();
  }

  @override
  void dispose() {
    for (final v in _valores) {
      v.dispose();
    }
    _fundacion.dispose();
    _empleados.dispose();
    _crecimiento.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    CompanyCulture? culture;
    List<CompanyCultureStory> historias;

    if (widget.previewCulture != null || widget.previewStories != null) {
      culture = widget.previewCulture;
      historias = widget.previewStories ?? const [];
    } else {
      culture = await CompanyCultureService.instance.getMyCulture();
      historias = await CompanyCultureService.instance.getMyStories();
    }

    if (!mounted) return;
    setState(() {
      _introVideoUrl = culture?.introVideoUrl;
      _introVideoDuration = culture?.introVideoDurationSeconds;
      _fundacion.text = culture?.foundedYear?.toString() ?? '';
      _empleados.text = culture?.employeeCount?.toString() ?? '';
      _crecimiento.text = culture?.growthPercentage?.toString() ?? '';
      for (final valor in culture?.valores ?? const []) {
        _valores.add(_CulturaValorDraft(
          icon: iconForCultureValorKey(valor.iconKey),
          titulo: valor.titulo,
          descripcion: valor.descripcion,
        ));
      }
      _historias = historias;
      _cargando = false;
    });
  }

  // ── Video institucional ──────────────────────────────────────────────────

  Future<void> _elegirVideoIntro() async {
    final origen = await _preguntarOrigenVideo();
    if (origen == null) return;

    final video = await _tomarVideo(fromCamera: origen);
    if (video == null || !mounted) return;

    setState(() => _subiendoIntro = true);

    if (widget.previewMode) {
      setState(() {
        _introVideoUrl = video.path;
        _introVideoDuration = null;
        _subiendoIntro = false;
      });
      return;
    }

    final url = await StorageService.instance
        .uploadCultureVideo(widget.empresa.id, video, slot: 'intro');

    if (!mounted) return;
    setState(() {
      _subiendoIntro = false;
      if (url != null) {
        _introVideoUrl = url;
        // Video nuevo: la duración vieja ya no corresponde. No se inventa
        // una nueva — queda null hasta que haya una forma real de medirla.
        _introVideoDuration = null;
      } else {
        _aviso = 'No pudimos subir el video. Probá de nuevo.';
      }
    });
  }

  // ── Valores ───────────────────────────────────────────────────────────────

  void _agregarValor() {
    if (_valores.length >= CompanyCultureService.maxStories) return;
    setState(() {
      _valores.add(_CulturaValorDraft(icon: kCompanyValorIconos.first));
    });
  }

  void _quitarValor(_CulturaValorDraft v) {
    setState(() {
      _valores.remove(v);
      v.dispose();
    });
  }

  // ── Historias del equipo ─────────────────────────────────────────────────

  Future<void> _agregarHistoria() async {
    if (_historias.length >= CompanyCultureService.maxStories) return;

    final datos = await _preguntarDatosHistoria();
    if (datos == null) return;

    final origen = await _preguntarOrigenVideo();
    if (origen == null) return;
    final video = await _tomarVideo(fromCamera: origen);
    if (video == null || !mounted) return;

    setState(() => _subiendoHistoria = true);

    if (widget.previewMode) {
      setState(() {
        _historias = [
          ..._historias,
          CompanyCultureStory(
            id: 'preview-${_historias.length}',
            companyUserId: widget.empresa.id,
            memberName: datos.$1,
            memberRole: datos.$2,
            quote: datos.$3,
            videoUrl: video.path,
            sortOrder: _historias.length,
            createdAt: DateTime.now(),
          ),
        ];
        _subiendoHistoria = false;
      });
      return;
    }

    final url = await StorageService.instance
        .uploadCultureVideo(widget.empresa.id, video, slot: 'story');

    if (!mounted) return;
    if (url == null) {
      setState(() {
        _subiendoHistoria = false;
        _aviso = 'No pudimos subir el video. Probá de nuevo.';
      });
      return;
    }

    final creada = await CompanyCultureService.instance.addStory(
      memberName: datos.$1,
      memberRole: datos.$2,
      quote: datos.$3,
      videoUrl: url,
    );

    if (!mounted) return;
    setState(() {
      _subiendoHistoria = false;
      if (creada != null) {
        _historias = [..._historias, creada];
      } else {
        _aviso = 'No pudimos guardar la historia. Probá de nuevo.';
      }
    });
  }

  Future<void> _eliminarHistoria(CompanyCultureStory h) async {
    final confirmar = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('¿Eliminar historia?'),
        content: Text('Se va a borrar el video de ${h.memberName}.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Eliminar'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    if (widget.previewMode) {
      setState(() => _historias = _historias.where((x) => x.id != h.id).toList());
      return;
    }

    final ok = await CompanyCultureService.instance.deleteStory(h.id);
    if (!mounted) return;
    if (ok) {
      setState(() => _historias = _historias.where((x) => x.id != h.id).toList());
    } else {
      setState(() => _aviso = 'No pudimos eliminar la historia. Probá de nuevo.');
    }
  }

  // ── Helpers de captura ───────────────────────────────────────────────────

  /// `true` = cámara, `false` = galería, `null` = canceló.
  Future<bool?> _preguntarOrigenVideo() {
    return showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Video'),
        message: const Text('Grabá uno nuevo o elegí uno de tu galería.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Grabar video'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Elegir de galería'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, null),
          isDestructiveAction: true,
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Future<XFile?> _tomarVideo({required bool fromCamera}) async {
    if (fromCamera) {
      if (kIsWeb) return WebRecorderHelper.recordVideo(context);
      return ImagePicker().pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 90),
      );
    }
    return ImagePicker().pickVideo(source: ImageSource.gallery);
  }

  /// Devuelve (nombre, rol, cita) o `null` si canceló.
  Future<(String, String?, String?)?> _preguntarDatosHistoria() async {
    final nombre = TextEditingController();
    final rol = TextEditingController();
    final cita = TextEditingController();

    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Historia del equipo'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              CupertinoTextField(controller: nombre, placeholder: 'Nombre'),
              const SizedBox(height: 8),
              CupertinoTextField(controller: rol, placeholder: 'Rol (opcional)'),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: cita,
                placeholder: 'Una frase corta (opcional)',
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Continuar'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (ok != true || nombre.text.trim().isEmpty) return null;
    return (
      nombre.text.trim(),
      rol.text.trim().isEmpty ? null : rol.text.trim(),
      cita.text.trim().isEmpty ? null : cita.text.trim(),
    );
  }

  // ── Guardar ──────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (_guardando) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _guardando = true;
      _aviso = null;
    });

    if (widget.previewMode) {
      setState(() => _guardando = false);
      Navigator.pop(context, true);
      return;
    }

    final valores = _valores
        .where((v) => v.titulo.text.trim().isNotEmpty)
        .map((v) => CompanyCultureValor(
              iconKey: keyForCultureValorIcon(v.icon),
              titulo: v.titulo.text.trim(),
              descripcion: v.descripcion.text.trim(),
            ))
        .toList();

    final ok = await CompanyCultureService.instance.saveMyCulture(
      introVideoUrl: _introVideoUrl,
      introVideoDurationSeconds: _introVideoDuration,
      valores: valores,
      foundedYear: int.tryParse(_fundacion.text.trim()),
      employeeCount: int.tryParse(_empleados.text.trim()),
      growthPercentage: double.tryParse(_crecimiento.text.trim()),
    );

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _guardando = false;
      _aviso = 'No pudimos guardar los cambios. Probá de nuevo en un momento.';
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: MpTokens.lightBg,
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
                  title: 'Cultura de la empresa',
                  subtitle: 'Video institucional, valores y el equipo.',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
              Expanded(
                child: _cargando
                    ? const Center(child: CupertinoActivityIndicator())
                    : CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              MpTokens.screenPadding,
                              MpTokens.space16,
                              MpTokens.screenPadding,
                              MpTokens.space24 +
                                  MediaQuery.of(context).viewInsets.bottom,
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
    final s = context.mp;

    return [
      if (_aviso != null) ...[
        MpBanner(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: 'Ojo',
          message: _aviso!,
          color: MpTokens.danger,
        ),
        const SizedBox(height: MpTokens.space20),
      ],
      const MpFieldLabel(
        'Video institucional',
        helper: 'El primer video que ve un candidato al entrar a esta pantalla.',
      ),
      _tarjetaVideoIntro(),
      const SizedBox(height: MpTokens.space24),
      MpSectionHeader(
        title: 'Valores de la empresa',
        subtitle: 'Hasta ${CompanyCultureService.maxStories}.',
      ),
      const SizedBox(height: MpTokens.space12),
      for (final v in _valores) ...[
        _tarjetaValor(v),
        const SizedBox(height: MpTokens.space12),
      ],
      if (_valores.length < CompanyCultureService.maxStories)
        MpButton(
          label: 'Agregar valor',
          icon: CupertinoIcons.add,
          variant: MpButtonVariant.neutral,
          expand: true,
          onPressed: _agregarValor,
        ),
      const SizedBox(height: MpTokens.space24),
      MpSectionHeader(title: 'Datos de la empresa', subtitle: 'Opcional.'),
      const SizedBox(height: MpTokens.space12),
      const MpFieldLabel('Año de fundación'),
      MpTextField(
        controller: _fundacion,
        placeholder: 'Ej: 2018',
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: MpTokens.space16),
      const MpFieldLabel('Cantidad de empleados'),
      MpTextField(
        controller: _empleados,
        placeholder: 'Ej: 45',
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: MpTokens.space16),
      const MpFieldLabel(
        'Crecimiento anual (%)',
        helper: 'Sólo si lo tenés medido — no se inventa.',
      ),
      MpTextField(
        controller: _crecimiento,
        placeholder: 'Ej: 30',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      const SizedBox(height: MpTokens.space24),
      MpSectionHeader(
        title: 'Historias del equipo',
        subtitle: 'Videos cortos de integrantes contando cómo es trabajar acá.',
      ),
      const SizedBox(height: MpTokens.space12),
      if (_historias.isEmpty)
        Text(
          'Todavía no hay ninguna historia cargada.',
          style: MpTokens.caption.copyWith(color: s.textTertiary),
        )
      else
        for (final h in _historias) ...[
          _filaHistoria(h),
          const SizedBox(height: MpTokens.space12),
        ],
      const SizedBox(height: MpTokens.space8),
      if (_historias.length < CompanyCultureService.maxStories)
        MpButton(
          label: _subiendoHistoria ? 'Subiendo…' : 'Agregar historia',
          icon: CupertinoIcons.add,
          variant: MpButtonVariant.neutral,
          expand: true,
          loading: _subiendoHistoria,
          onPressed: _subiendoHistoria ? null : _agregarHistoria,
        ),
    ];
  }

  Widget _tarjetaVideoIntro() {
    final s = context.mp;
    final tiene = _introVideoUrl?.isNotEmpty ?? false;

    return MpCard(
      child: Row(
        children: [
          MpIconTile(
            icon: tiene ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.videocam,
            color: tiene ? MpTokens.success : s.accent,
            size: 42,
          ),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tiene ? 'Video cargado' : 'Todavía no hay video',
                  style: MpTokens.title.copyWith(color: s.text, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  tiene
                      ? 'Se muestra como héroe de esta pantalla.'
                      : 'Grabalo o subilo desde la galería.',
                  style: MpTokens.caption.copyWith(color: s.textSecondary),
                ),
              ],
            ),
          ),
          MpButton(
            label: tiene ? 'Reemplazar' : 'Agregar',
            size: MpButtonSize.small,
            variant: MpButtonVariant.outline,
            loading: _subiendoIntro,
            onPressed: _subiendoIntro ? null : _elegirVideoIntro,
          ),
        ],
      ),
    );
  }

  Widget _tarjetaValor(_CulturaValorDraft v) {
    final s = context.mp;

    return MpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: MpTokens.space8,
                  children: [
                    for (final icon in kCompanyValorIconos)
                      GestureDetector(
                        onTap: () => setState(() => v.icon = icon),
                        child: MpIconTile(
                          icon: icon,
                          color: icon == v.icon ? s.accent : s.textTertiary,
                          size: 32,
                          solid: icon == v.icon,
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _quitarValor(v),
                child: Icon(CupertinoIcons.xmark_circle_fill, color: s.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: MpTokens.space12),
          MpTextField(controller: v.titulo, placeholder: 'Título — ej: Trabajo en equipo'),
          const SizedBox(height: MpTokens.space8),
          MpTextField(
            controller: v.descripcion,
            placeholder: 'Descripción corta',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _filaHistoria(CompanyCultureStory h) {
    final s = context.mp;

    return MpCard(
      child: Row(
        children: [
          const MpIconTile(icon: CupertinoIcons.play_circle_fill, color: MpTokens.catGreen, size: 42),
          const SizedBox(width: MpTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  h.memberName,
                  style: MpTokens.title.copyWith(color: s.text, fontSize: 15),
                ),
                if (h.memberRole != null)
                  Text(
                    h.memberRole!,
                    style: MpTokens.caption.copyWith(color: s.textSecondary),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _eliminarHistoria(h),
            child: Icon(CupertinoIcons.trash, color: MpTokens.danger, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _barraAcciones() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        MpTokens.screenPadding,
        MpTokens.space12,
        MpTokens.screenPadding,
        MediaQuery.of(context).padding.bottom + MpTokens.space12,
      ),
      decoration: BoxDecoration(
        color: context.mp.card,
        border: Border(top: BorderSide(color: context.mp.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: MpButton(
              label: 'Cancelar',
              variant: MpButtonVariant.neutral,
              expand: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(width: MpTokens.space8),
          Expanded(
            child: MpButton(
              label: 'Guardar',
              icon: CupertinoIcons.check_mark,
              expand: true,
              loading: _guardando,
              onPressed: _guardar,
            ),
          ),
        ],
      ),
    );
  }
}
