import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/widgets/ds/mploya_ds.dart';

/// Smoke test del sistema de diseño.
///
/// No valida estética — eso se compara contra el PNG. Valida que cada
/// componente RENDERIZA sin excepciones en las tres superficies, que es lo que
/// `flutter analyze` no puede probar.

Widget _host(MpSurfaceKind surface, Widget child) {
  return CupertinoApp(
    home: MpScaffold(
      surface: surface,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [child]),
        ),
      ),
    ),
  );
}

const _surfaces = [
  MpSurfaceKind.auth,
  MpSurfaceKind.light,
  MpSurfaceKind.dark,
];

void main() {
  group('renderiza en las tres superficies', () {
    final cases = <String, Widget>{
      'botones': const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MpButton(label: 'Primario', trailingArrow: true),
          MpButton(label: 'Contorno', variant: MpButtonVariant.outline),
          MpButton(label: 'Neutro', variant: MpButtonVariant.neutral),
          MpButton(label: 'Fantasma', variant: MpButtonVariant.ghost),
          MpButton(label: 'Cargando', loading: true),
        ],
      ),
      'sociales': const Column(
        children: [
          MpSocialButton(
            provider: MpSocialProvider.google,
            label: 'Continuar con Google',
          ),
          MpSocialButton(
            provider: MpSocialProvider.apple,
            label: 'Continuar con Apple',
          ),
        ],
      ),
      'tarjetas': const Column(
        children: [
          MpCard(child: Text('tarjeta')),
          MpStatTile(
            icon: CupertinoIcons.briefcase,
            color: MpTokens.primary,
            value: '24',
            label: 'Vacantes activas',
            linkLabel: 'Ver todas',
          ),
          MpSectionHeader(title: 'Pipeline', actionLabel: 'Ver todo'),
          MpHeroBand(
            metrics: [
              MpHeroMetric(
                icon: CupertinoIcons.briefcase,
                label: 'Búsquedas',
                value: '12',
                delta: '+2',
              ),
              MpHeroMetric(
                icon: CupertinoIcons.person_2,
                label: 'Presentados',
                value: '28',
              ),
            ],
          ),
        ],
      ),
      'filas': const MpRowGroup(
        rows: [
          MpListRow(title: 'TechPro', subtitle: 'Senior Backend', trailingText: 'Hace 2h'),
          MpListRow(title: 'NovaSoft', subtitle: 'DevOps Engineer'),
        ],
      ),
      'chips': const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          MpStatusBadge(label: 'Activo', status: MpStatus.active),
          MpStatusBadge(label: 'En pausa', status: MpStatus.paused),
          MpStatusBadge(label: 'Finalizado', status: MpStatus.finished),
          MpTypeChip(label: 'Entrevista', color: MpTokens.primary),
          MpTagChip(label: 'Figma'),
          MpTagChip(label: 'Agregar', isAction: true),
          MpCountBadge(count: 18),
        ],
      ),
      'formulario': Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MpFieldLabel('Email', helper: 'Lo usamos para avisarte'),
          const MpTextField(
            placeholder: 'Tu email',
            icon: CupertinoIcons.mail,
            iconDivider: true,
          ),
          const MpTextField(placeholder: 'Con error', errorText: 'Requerido'),
          const MpTextField(placeholder: 'Multilínea', maxLines: 3, counter: '0/200'),
          const MpSelectField(value: 'Remoto', icon: CupertinoIcons.globe),
          MpCheckbox(value: true, onChanged: (_) {}, label: 'Acepto'),
          MpOptionCard(
            label: 'Tiempo completo',
            icon: CupertinoIcons.clock,
            selected: true,
            onTap: () {},
          ),
          const MpStepper(
            steps: [MpStep('Información'), MpStep('Descripción'), MpStep('Publicar')],
            currentIndex: 1,
          ),
        ],
      ),
      'feedback': const Column(
        children: [
          MpProgressBar(value: 0.6),
          MpFunnelBar(
            segments: [
              MpFunnelSegment(fraction: 0.4, color: MpTokens.primary),
              MpFunnelSegment(fraction: 0.3, color: MpTokens.info),
            ],
          ),
          MpProgressRing(value: 0.92, center: Text('92%')),
          MpBanner(
            icon: CupertinoIcons.person_2,
            title: 'Sumá nuevos clientes',
            message: 'Agregá empresas.',
            actionLabel: 'Agregar',
          ),
          MpAiCard(title: 'Asistente IA', tag: 'BETA', child: Text('sugerencia')),
        ],
      ),
      'marca': const Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          MpWordmark(style: MpWordmarkStyle.dotAi),
          MpWordmark(style: MpWordmarkStyle.product),
          MpLogoMark(size: 56),
          MpCompanyLogo(name: 'TechPro', color: MpTokens.primary),
          MpAvatar(name: 'Ana', ring: true, online: true),
          MpVerifiedBadge(),
        ],
      ),
    };

    for (final surface in _surfaces) {
      for (final entry in cases.entries) {
        testWidgets('${entry.key} · ${surface.name}', (tester) async {
          await tester.pumpWidget(_host(surface, entry.value));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('barra inferior exige 4 pestañas', (tester) async {
    expect(
      () => MpBottomNav(
        items: const [MpNavItem(icon: CupertinoIcons.home, label: 'Inicio')],
        currentIndex: 0,
        onTap: (_) {},
      ),
      throwsAssertionError,
    );
  });

  testWidgets('barra inferior renderiza para los tres roles', (tester) async {
    for (final role in MpRole.values) {
      await tester.pumpWidget(
        CupertinoApp(
          home: MpScaffold(
            surface: role.surface,
            bottomBar: MpBottomNav(
              items: role.navItems(unreadMessages: 3),
              currentIndex: 0,
              onTap: (_) {},
              centerLabel: role.centerLabel,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'rol ${role.name}');
    }
  });

  testWidgets('la superficie oscura no depende del tema del sistema', (tester) async {
    // El feed debe seguir siendo oscuro con la app en claro: es la regla que
    // más fácil se rompe al migrar pantallas.
    await tester.pumpWidget(
      const CupertinoApp(
        theme: CupertinoThemeData(brightness: Brightness.light),
        home: MpScaffold(
          surface: MpSurfaceKind.dark,
          child: _Probe(),
        ),
      ),
    );

    final probe = tester.widget<Container>(find.byKey(const Key('probe')));
    final decoration = probe.decoration as BoxDecoration;
    expect(decoration.color, MpTokens.darkCard);
  });
}

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('probe'),
      decoration: BoxDecoration(color: context.mp.card),
    );
  }
}
