import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialApp, ThemeData;

import '../screens/jobs_screen.dart';
import 'preview_fixtures.dart';

/// SHELL DEL MODO PREVIEW LOCAL.
///
/// Sólo se monta cuando `kPreviewMode` es `true` — ver `preview_flags.dart`.
/// No inicializa Supabase, no pide permisos, no toca red y no necesita sesión.
///
/// Qué hace:
///  · lista las cinco pantallas de Candidato;
///  · las renderiza dentro de un viewport del tamaño elegido (mobile, tablet o
///    desktop), para poder capturar las tres resoluciones sin redimensionar la
///    ventana del navegador;
///  · muestra siempre el cartel `PREVIEW LOCAL — DATOS FICTICIOS`.
///
/// Las pantallas reciben sus datos por el parámetro opcional `previewData`, el
/// mismo patrón que ya usan las pantallas de Empresa. Cuando ese parámetro
/// llega, la pantalla NO consulta Supabase: dibuja lo que le pasaron.
class PreviewApp extends StatelessWidget {
  const PreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mploya — preview local',
      theme: ThemeData(useMaterial3: true),
      home: const _PreviewHome(),
    );
  }
}

/// Tamaños de captura de la tanda.
enum PreviewViewport {
  mobile('Mobile', 390, 844),
  tablet('Tablet', 820, 1180),
  desktop('Desktop', 1440, 900);

  const PreviewViewport(this.etiqueta, this.ancho, this.alto);
  final String etiqueta;
  final double ancho;
  final double alto;

  String get medida => '${ancho.toInt()} × ${alto.toInt()}';
}

/// Una pantalla de la tanda, con su constructor ya cargado de fixtures.
class PreviewEntry {
  const PreviewEntry({
    required this.nombre,
    required this.construir,
    this.inyectada = true,
    this.nota,
  });

  final String nombre;
  final WidgetBuilder construir;

  /// `false` mientras la pantalla todavía no acepta `previewData`. Se muestra
  /// un cartel explicando qué falta, en vez de montarla y que quede colgada
  /// esperando a Supabase.
  final bool inyectada;
  final String? nota;
}

List<PreviewEntry> previewEntries() => [
  PreviewEntry(
    nombre: 'Inicio',
    inyectada: false,
    nota: 'Falta el parámetro previewData en HomeFeedScreen.',
    construir: (_) => const SizedBox.shrink(),
  ),
  PreviewEntry(
    nombre: 'Vacantes',
    construir: (_) => JobsScreen(
      previewData: JobsPreviewData(
        vacantes: previewVacantes,
        matchScores: previewMatchScores,
      ),
    ),
  ),
  PreviewEntry(
    nombre: 'Red',
    inyectada: false,
    nota: 'Falta el parámetro previewData en NetworkScreen.',
    construir: (_) => const SizedBox.shrink(),
  ),
  PreviewEntry(
    nombre: 'Mensajes',
    inyectada: false,
    nota: 'Falta el parámetro previewData en MessagingScreen.',
    construir: (_) => const SizedBox.shrink(),
  ),
  PreviewEntry(
    nombre: 'Perfil',
    inyectada: false,
    nota: 'Falta el parámetro previewData en ProfileScreen.',
    construir: (_) => const SizedBox.shrink(),
  ),
];

class _PreviewHome extends StatefulWidget {
  const _PreviewHome();

  @override
  State<_PreviewHome> createState() => _PreviewHomeState();
}

class _PreviewHomeState extends State<_PreviewHome> {
  int _pantalla = 1; // Vacantes: la única inyectada por ahora.
  PreviewViewport _viewport = PreviewViewport.mobile;

  @override
  Widget build(BuildContext context) {
    final entradas = previewEntries();
    final entrada = entradas[_pantalla];

    return Material(
      color: const Color(0xFF0E0E12),
      child: SafeArea(
        child: Column(
          children: [
            const PreviewBanner(),
            _barraDeControles(entradas),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _viewportBox(entrada),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barraDeControles(List<PreviewEntry> entradas) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < entradas.length; i++)
            _chip(
              texto: entradas[i].nombre,
              activo: i == _pantalla,
              atenuado: !entradas[i].inyectada,
              onTap: () => setState(() => _pantalla = i),
            ),
          const SizedBox(width: 24),
          for (final v in PreviewViewport.values)
            _chip(
              texto: '${v.etiqueta} · ${v.medida}',
              activo: v == _viewport,
              onTap: () => setState(() => _viewport = v),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String texto,
    required bool activo,
    required VoidCallback onTap,
    bool atenuado = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? const Color(0xFF4129F0) : const Color(0xFF1C1C22),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 13,
            fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
            color: atenuado
                ? const Color(0xFF6B7280)
                : const Color(0xFFF5F5F7),
          ),
        ),
      ),
    );
  }

  /// Renderiza la pantalla dentro de un recuadro del tamaño elegido, con un
  /// `MediaQuery` acorde: así el código responsive ve el ancho del viewport
  /// simulado y no el de la ventana real.
  Widget _viewportBox(PreviewEntry entrada) {
    final contenido = entrada.inyectada
        ? entrada.construir(context)
        : _pendiente(entrada);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A33)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: _viewport.ancho,
        height: _viewport.alto,
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(_viewport.ancho, _viewport.alto),
            devicePixelRatio: 1,
            textScaler: TextScaler.noScaling,
          ),
          child: CupertinoTheme(
            data: const CupertinoThemeData(brightness: Brightness.light),
            child: contenido,
          ),
        ),
      ),
    );
  }

  Widget _pendiente(PreviewEntry entrada) {
    return Container(
      color: const Color(0xFFF5F5F7),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.wrench, size: 40, color: Color(0xFF6B7280)),
          const SizedBox(height: 14),
          Text(
            '${entrada.nombre}: inyección pendiente',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entrada.nota ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartel obligatorio del modo preview. Aparece en todas las capturas.
class PreviewBanner extends StatelessWidget {
  const PreviewBanner({super.key});

  static const String texto = 'PREVIEW LOCAL — DATOS FICTICIOS';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF4129F0),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: const Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Color(0xFFFFFFFF),
        ),
      ),
    );
  }
}
