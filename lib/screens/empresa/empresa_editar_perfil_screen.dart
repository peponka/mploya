import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../services/my_profile_service.dart';
import '../../widgets/ds/mploya_ds.dart';

/// Guarda los campos editables de la empresa.
///
/// Escribe SÓLO columnas que después se leen de vuelta igual. Devuelve `false`
/// si la base rechazó el cambio.
Future<bool> guardarPerfilEmpresa({
  required String nombre,
  required String titular,
  required String descripcion,
  required String ubicacion,
  required List<String> tags,
  required bool contratando,
}) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return false;

  String? nn(String v) => v.trim().isEmpty ? null : v.trim();

  try {
    await updateMyCompanyProfile(
      company: nombre.trim(),
      headline: nn(titular),
      about: nn(descripcion),
      tags: tags.isEmpty ? null : tags,
      location: nn(ubicacion),
      isHiring: contratando,
      updateLocation: true,
      completeOnboarding: false,
      client: client,
    );
    return true;
  } catch (e) {
    debugPrint('editar perfil empresa · update: $e');
    return false;
  }
}

/// Edición del perfil de Empresa (móvil).
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 11/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// DERIVACIÓN CONTROLADA de `perfil empresa premium.png` (39), con `cultura de
/// la empresa.png` (40) y `beneficios.png` (41) auditados para decidir qué entra.
///
/// AUDITORÍA — es lo que define esta pantalla. `public.users` guarda de una
/// empresa: `name`, `company`, `headline`, `about`, `location`, `tags`,
/// `is_hiring`. Nada más. Los dos PNG de Cultura y Beneficios piden valores con
/// ícono y descripción, galería de "cómo trabajamos", historias del equipo en
/// video, eventos, cinco categorías de beneficio y ocho beneficios destacados:
/// ninguno tiene columna, tabla ni endpoint.
///
/// Y hay un problema previo, en el formulario legacy: `CompanyProfileFormScreen`
/// muestra once campos (tamaño, cultura, beneficios, web, fundación, stack…)
/// pero **concatena seis de ellos dentro de `about`**. Se escriben, sí, pero
/// mezclados en un texto libre: al volver a abrir no se pueden separar, así que
/// no son campos editables — son un párrafo. Esta pantalla no repite eso: cada
/// campo que muestra se lee y se escribe uno a uno.
///
/// ADENDA 29/8/2026 — Cultura y valores dejaron de estar entre lo omitido:
/// tienen su propio editor y su propia tabla (ver `_queFaltaGuardar()`). Esta
/// pantalla sigue sin tocarlos porque no viven en `users`.
class EmpresaEditarPerfilScreen extends StatefulWidget {
  /// Empresa ya cargada (la trae el Perfil de Empresa, que la acaba de leer).
  final NexUser empresa;

  /// Sólo para los golden tests: no escribe en la base.
  final bool previewMode;

  const EmpresaEditarPerfilScreen({
    super.key,
    required this.empresa,
    this.previewMode = false,
  });

  @override
  State<EmpresaEditarPerfilScreen> createState() =>
      _EmpresaEditarPerfilScreenState();
}

class _EmpresaEditarPerfilScreenState extends State<EmpresaEditarPerfilScreen> {
  late final _nombre = TextEditingController(text: widget.empresa.name);
  late final _titular = TextEditingController(text: widget.empresa.headline);
  late final _descripcion =
      TextEditingController(text: widget.empresa.about ?? '');
  late final _ubicacion =
      TextEditingController(text: widget.empresa.location ?? '');
  final _nuevaEtiqueta = TextEditingController();

  late final _tags = <String>[
    for (final t in widget.empresa.tags) t.replaceAll('#', '').trim(),
  ]..removeWhere((t) => t.isEmpty);

  late bool _contratando = widget.empresa.isHiring;

  bool _guardando = false;
  String? _aviso;

  @override
  void dispose() {
    _nombre.dispose();
    _titular.dispose();
    _descripcion.dispose();
    _ubicacion.dispose();
    _nuevaEtiqueta.dispose();
    super.dispose();
  }

  bool get _valido => _nombre.text.trim().isNotEmpty;

  void _agregarEtiqueta() {
    final texto = _nuevaEtiqueta.text.replaceAll('#', '').trim();
    if (texto.isEmpty) return;
    // Sin distinguir tildes ni mayúsculas: "diseño" y "Diseño" son la misma.
    final normal = _normalizar(texto);
    if (_tags.any((t) => _normalizar(t) == normal)) {
      _nuevaEtiqueta.clear();
      setState(() {});
      return;
    }
    setState(() {
      _tags.add(texto);
      _nuevaEtiqueta.clear();
    });
  }

  static String _normalizar(String v) {
    const con = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const sin = 'aaaaaeeeeiiiiooooouuuunc';
    var r = v.toLowerCase().trim();
    for (var i = 0; i < con.length; i++) {
      r = r.replaceAll(con[i], sin[i]);
    }
    return r;
  }

  Future<void> _guardar() async {
    if (!_valido || _guardando) return;
    FocusScope.of(context).unfocus();

    if (widget.previewMode) return;

    setState(() {
      _guardando = true;
      _aviso = null;
    });

    final ok = await guardarPerfilEmpresa(
      nombre: _nombre.text,
      titular: _titular.text,
      descripcion: _descripcion.text,
      ubicacion: _ubicacion.text,
      tags: _tags,
      contratando: _contratando,
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

  // ── Build ───────────────────────────────────────────────────────────────────

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
                  title: 'Editar perfil',
                  subtitle: 'Lo que ven los candidatos de tu empresa.',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
              Expanded(
                child: CustomScrollView(
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
          title: 'No se pudo guardar',
          message: _aviso!,
          color: MpTokens.danger,
        ),
        const SizedBox(height: MpTokens.space20),
      ],
      const MpFieldLabel('Nombre de la empresa'),
      MpTextField(
        controller: _nombre,
        placeholder: 'Ej: NovaTech',
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: MpTokens.space20),
      const MpFieldLabel(
        'Titular',
        helper: 'Una línea. Es lo primero que se lee debajo del nombre.',
      ),
      MpTextField(
        controller: _titular,
        placeholder: 'Ej: Tecnología que impulsa el futuro',
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: MpTokens.space20),
      const MpFieldLabel('Sobre la empresa'),
      MpTextField(
        controller: _descripcion,
        placeholder: 'Qué hacen, cómo trabajan, qué los hace distintos…',
        maxLines: 6,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: MpTokens.space20),
      const MpFieldLabel('Ubicación'),
      MpTextField(
        controller: _ubicacion,
        placeholder: 'Ej: Buenos Aires, Argentina',
        icon: CupertinoIcons.placemark,
      ),
      const SizedBox(height: MpTokens.space20),
      const MpFieldLabel(
        'En qué buscás',
        helper: 'Habilidades y áreas. También alimentan el match.',
      ),
      MpTextField(
        controller: _nuevaEtiqueta,
        placeholder: 'Escribí una y agregala',
        icon: CupertinoIcons.tag,
        trailingIcon: CupertinoIcons.add_circled_solid,
        onTrailingTap: _agregarEtiqueta,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: MpTokens.space12),
      if (_tags.isEmpty)
        Text(
          'Todavía no agregaste ninguna.',
          style: MpTokens.caption.copyWith(color: s.textTertiary),
        )
      else
        Wrap(
          spacing: MpTokens.space8,
          runSpacing: MpTokens.space8,
          children: [
            for (final t in _tags)
              MpTagChip(
                label: t,
                onRemove: () => setState(() => _tags.remove(t)),
              ),
          ],
        ),
      const SizedBox(height: MpTokens.space24),
      MpCard(
        child: Row(
          children: [
            const MpIconTile(
              icon: CupertinoIcons.briefcase_fill,
              color: MpTokens.catGreen,
              size: 42,
            ),
            const SizedBox(width: MpTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Estamos contratando',
                    style: MpTokens.title.copyWith(color: s.text, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Muestra el distintivo en tu perfil y en el feed.',
                    style: MpTokens.caption.copyWith(color: s.textSecondary),
                  ),
                ],
              ),
            ),
            CupertinoSwitch(
              value: _contratando,
              activeTrackColor: s.accent,
              onChanged: (v) => setState(() => _contratando = v),
            ),
          ],
        ),
      ),
      const SizedBox(height: MpTokens.space24),
      _queFaltaGuardar(),
    ];
  }

  /// ADENDA 29/8/2026 — Cultura, valores, año de fundación y cantidad de
  /// empleados YA tienen dónde guardarse (`046_company_culture.sql`), en su
  /// propio editor (`EmpresaCulturaEditorScreen`, entrada desde "Cultura de
  /// la empresa" en el Perfil de Empresa) — no se movieron a ESTE formulario
  /// porque no son campos de `users`, son otra tabla. Beneficios y oficinas
  /// con dirección siguen sin tener dónde guardarse.
  Widget _queFaltaGuardar() {
    final s = context.mp;

    return MpBanner(
      icon: CupertinoIcons.info,
      title: 'Qué todavía no se puede cargar acá',
      message: 'Beneficios y oficinas con dirección no tienen dónde '
          'guardarse todavía. Cultura, valores, año de fundación y cantidad '
          'de empleados sí se cargan, pero desde "Cultura de la empresa" en '
          'tu Perfil de Empresa — no desde este formulario.',
      color: s.textTertiary,
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
              onPressed: _valido ? _guardar : null,
            ),
          ),
        ],
      ),
    );
  }
}
