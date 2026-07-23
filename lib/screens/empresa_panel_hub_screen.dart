import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';
import '../widgets/web_ui.dart';
import 'empresa_panel_screen.dart';
import 'ats_dashboard_screen.dart';
import 'nueva_vacante_screen.dart';

/// Hub "Panel" para cuentas empresa/headhunter. Fusiona en una sola pestaña las
/// dos pantallas que antes se solapaban en la navegación ("Panel" de métricas y
/// "Dashboard" de pipeline), con un control segmentado arriba:
///   • Resumen  → EmpresaPanelScreen (KPIs, funnel, match del día, insights)
///   • Pipeline → AtsDashboardScreen (Kanban de candidatos + contactos + confidencial)
class EmpresaPanelHubScreen extends StatefulWidget {
  const EmpresaPanelHubScreen({super.key});

  @override
  State<EmpresaPanelHubScreen> createState() => _EmpresaPanelHubScreenState();
}

class _EmpresaPanelHubScreenState extends State<EmpresaPanelHubScreen> {
  int _seg = 0; // 0 = Resumen, 1 = Pipeline

  @override
  Widget build(BuildContext context) {
    return WebPage(
      title: 'Panel',
      // Ancho según la pestaña: Resumen = columna angosta centrada (compacto,
      // como la maqueta); Pipeline = ancho para que entren varias columnas del
      // board Kanban sin cortarse.
      maxWidth: _seg == 0 ? 620 : 1180,
      actions: [
        WebButton(
          icon: CupertinoIcons.add,
          label: 'Nueva vacante',
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => const NuevaVacanteScreen()),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Control segmentado Resumen / Pipeline ──
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _seg,
              backgroundColor: context.cardColor,
              thumbColor: MployaTheme.brandAccent,
              onValueChanged: (v) {
                if (v != null) setState(() => _seg = v);
              },
              children: {
                0: _segLabel('Resumen', _seg == 0),
                1: _segLabel('Pipeline', _seg == 1),
              },
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _seg,
              children: const [
                EmpresaPanelScreen(embedded: true),
                AtsDashboardScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segLabel(String text, bool active) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: active ? CupertinoColors.white : context.textSecondary,
          ),
        ),
      );
}
