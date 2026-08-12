import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/ds/mploya_ds.dart';

/// Preferencias de cuenta de la Empresa, tal como están en `public.users`.
@immutable
class ConfiguracionEmpresa {
  final bool push;
  final bool email;
  final bool alertas;
  final bool contratacionCiega;
  final bool contratando;

  /// No se pudo leer la fila.
  final bool error;

  const ConfiguracionEmpresa({
    this.push = false,
    this.email = false,
    this.alertas = false,
    this.contratacionCiega = false,
    this.contratando = false,
    this.error = false,
  });
}

/// Las cinco columnas booleanas que la app ya lee y escribe.
const _columnas = {
  'push': 'push_enabled',
  'email': 'email_notifications_enabled',
  'alertas': 'job_alerts_enabled',
  'ciega': 'blind_hiring_mode',
  'contratando': 'is_hiring',
};

Future<ConfiguracionEmpresa> loadConfiguracion() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return const ConfiguracionEmpresa(error: true);

  try {
    final fila = await client
        .from('users')
        .select(_columnas.values.join(', '))
        .eq('id', uid)
        .maybeSingle();

    if (fila == null) return const ConfiguracionEmpresa(error: true);

    return ConfiguracionEmpresa(
      push: fila[_columnas['push']] == true,
      email: fila[_columnas['email']] == true,
      alertas: fila[_columnas['alertas']] == true,
      contratacionCiega: fila[_columnas['ciega']] == true,
      contratando: fila[_columnas['contratando']] == true,
    );
  } catch (e) {
    debugPrint('configuracion · users: $e');
    return const ConfiguracionEmpresa(error: true);
  }
}

/// Escribe UNA preferencia. Devuelve `false` si la base la rechazó, para que la
/// UI pueda revertir el interruptor en vez de mostrar un estado que no se
/// guardó.
Future<bool> guardarPreferencia(String columna, bool valor) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return false;

  try {
    await client.from('users').update({columna: valor}).eq('id', uid);
    return true;
  } catch (e) {
    debugPrint('configuracion · update $columna: $e');
    return false;
  }
}

/// Configuración de cuenta de la Empresa.
///
/// DERIVACIÓN CONTROLADA de `configuracion y privacidad.png` (58). Ojo: ese PNG
/// es del rol CANDIDATO —su bloque principal es la visibilidad del propio perfil
/// para que lo encuentren las empresas—, así que se conserva su estructura
/// (secciones con interruptores y filas de cuenta) y se cambia el contenido por
/// las preferencias que una empresa sí tiene.
///
/// NO DUPLICA "Editar perfil": eso es la información pública de la empresa;
/// esto es cómo se comporta la cuenta.
///
/// REGLA APLICADA: cada interruptor lee su valor real de `public.users` y lo
/// escribe al tocarlo. Si la base rechaza el cambio, el interruptor vuelve
/// atrás y se avisa — nunca queda encendido algo que no se guardó. Del mockup se
/// omiten los cuatro modos de visibilidad de perfil, los hashtags sugeridos por
/// IA, la autenticación en dos pasos, las sesiones activas y "descargar mis
/// datos": ninguno tiene columna ni endpoint.
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ CONGELADA el 12/8/2026 — diseño Y comportamiento aprobados.           ║
/// ║ No modificar salvo bug funcional o responsive concreto y demostrable. ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
class EmpresaConfiguracionScreen extends StatefulWidget {
  /// Datos ya resueltos, para los golden tests.
  final ConfiguracionEmpresa? previewData;

  const EmpresaConfiguracionScreen({super.key, this.previewData});

  @override
  State<EmpresaConfiguracionScreen> createState() =>
      _EmpresaConfiguracionScreenState();
}

class _EmpresaConfiguracionScreenState
    extends State<EmpresaConfiguracionScreen> {
  ConfiguracionEmpresa _data = const ConfiguracionEmpresa();
  bool _loading = true;
  String? _aviso;

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
    final data = await loadConfiguracion();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  Future<void> _cambiar(String clave, bool valor) async {
    if (widget.previewData != null) return;

    // Optimista, pero reversible: si la base falla, vuelve.
    final previo = _data;
    setState(() {
      _aviso = null;
      _data = _con(clave, valor);
    });

    final ok = await guardarPreferencia(_columnas[clave]!, valor);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _data = previo;
        _aviso = 'No pudimos guardar ese cambio.';
      });
    }
  }

  ConfiguracionEmpresa _con(String clave, bool valor) {
    return ConfiguracionEmpresa(
      push: clave == 'push' ? valor : _data.push,
      email: clave == 'email' ? valor : _data.email,
      alertas: clave == 'alertas' ? valor : _data.alertas,
      contratacionCiega:
          clave == 'ciega' ? valor : _data.contratacionCiega,
      contratando: clave == 'contratando' ? valor : _data.contratando,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MpSurface(
      style: MpSurfaceStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: MpTokens.lightBg,
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
                        MpTokens.space8,
                        MpTokens.screenPadding,
                        MpTokens.space32,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(_cuerpo()),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  List<Widget> _cuerpo() {
    final s = context.mp;

    if (_data.error) {
      return [
        _encabezado(),
        Padding(
          padding: const EdgeInsets.only(top: MpTokens.space32),
          child: MpEmptyState(
            icon: CupertinoIcons.exclamationmark_triangle,
            title: 'No pudimos cargar tu configuración',
            message: 'Sin poder leer tus preferencias no se muestran '
                'interruptores: encenderlos sin saber su estado real sería '
                'peor que no mostrarlos.',
            actionLabel: 'Reintentar',
            onAction: _load,
          ),
        ),
      ];
    }

    return [
      _encabezado(),
      if (_aviso != null) ...[
        const SizedBox(height: MpTokens.space16),
        MpBanner(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: 'No se guardó',
          message: _aviso!,
          color: MpTokens.danger,
          onDismiss: () => setState(() => _aviso = null),
        ),
      ],
      const SizedBox(height: MpTokens.space24),
      Text(
        'Notificaciones',
        style: MpTokens.h2.copyWith(color: s.text, fontSize: 17),
      ),
      const SizedBox(height: MpTokens.space12),
      MpCard(
        child: Column(
          children: [
            _interruptor(
              icon: CupertinoIcons.bell_fill,
              color: MpTokens.primary,
              titulo: 'Notificaciones push',
              detalle: 'Avisos en el teléfono.',
              valor: _data.push,
              clave: 'push',
            ),
            _divisor(),
            _interruptor(
              icon: CupertinoIcons.mail,
              color: MpTokens.catBlue,
              titulo: 'Correos',
              detalle: 'Resúmenes y avisos por email.',
              valor: _data.email,
              clave: 'email',
            ),
            _divisor(),
            _interruptor(
              icon: CupertinoIcons.briefcase,
              color: MpTokens.catGreen,
              titulo: 'Alertas de candidatos',
              detalle: 'Avisos cuando aparece talento afín.',
              valor: _data.alertas,
              clave: 'alertas',
            ),
          ],
        ),
      ),
      const SizedBox(height: MpTokens.space24),
      Text(
        'Reclutamiento',
        style: MpTokens.h2.copyWith(color: s.text, fontSize: 17),
      ),
      const SizedBox(height: MpTokens.space12),
      MpCard(
        child: Column(
          children: [
            _interruptor(
              icon: CupertinoIcons.checkmark_seal_fill,
              color: MpTokens.catGreen,
              titulo: 'Estamos contratando',
              detalle: 'Muestra el distintivo en tu perfil y en el feed.',
              valor: _data.contratando,
              clave: 'contratando',
            ),
            _divisor(),
            _interruptor(
              icon: CupertinoIcons.eye_slash_fill,
              color: MpTokens.catIndigo,
              titulo: 'Contratación a ciegas',
              detalle: 'Oculta nombre y foto de los candidatos hasta la '
                  'entrevista, para reducir sesgos.',
              valor: _data.contratacionCiega,
              clave: 'ciega',
            ),
          ],
        ),
      ),
      const SizedBox(height: MpTokens.space24),
      _queNoEsta(),
    ];
  }

  Widget _divisor() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MpTokens.space12),
      child: Container(height: 1, color: context.mp.border),
    );
  }

  Widget _encabezado() {
    final s = context.mp;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (Navigator.of(context).canPop()) ...[
          MpIconButton(
            icon: CupertinoIcons.chevron_left,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: MpTokens.space12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configuración', style: MpTokens.h1.copyWith(color: s.text)),
              const SizedBox(height: MpTokens.space4),
              Text(
                'Cómo se comporta tu cuenta.',
                style: MpTokens.body.copyWith(
                  color: s.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _interruptor({
    required IconData icon,
    required Color color,
    required String titulo,
    required String detalle,
    required bool valor,
    required String clave,
  }) {
    final s = context.mp;

    return Row(
      children: [
        MpIconTile(icon: icon, color: color, size: 40),
        const SizedBox(width: MpTokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titulo,
                style: MpTokens.title.copyWith(color: s.text, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                detalle,
                style: MpTokens.caption.copyWith(color: s.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: MpTokens.space8),
        CupertinoSwitch(
          value: valor,
          activeTrackColor: s.accent,
          onChanged: (v) => _cambiar(clave, v),
        ),
      ],
    );
  }

  Widget _queNoEsta() {
    final s = context.mp;

    return MpBanner(
      icon: CupertinoIcons.info,
      title: 'Qué no está acá todavía',
      message: 'Cambiar contraseña, autenticación en dos pasos, sesiones '
          'activas, descargar tus datos y eliminar la cuenta no tienen soporte '
          'todavía, así que no se ofrecen como opciones que no harían nada.',
      color: s.textTertiary,
    );
  }
}
