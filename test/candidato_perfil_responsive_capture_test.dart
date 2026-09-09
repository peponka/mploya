import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/preview/preview_fixtures.dart';
import 'package:mploya/screens/profile_screen.dart';
import 'package:mploya/services/portfolio_service.dart';
import 'package:mploya/widgets/candidato/cand_ui.dart';

import 'candidato_productivo_host.dart';
import 'mp_golden_host.dart';

const _destino = 'test/failures/candidato_perfil_capture/current';

const _medidas = <String, Size>{
  'mobile_400': Size(400, 900),
  'mobile_424': Size(424, 900),
  'mobile_430': Size(430, 932),
  'tablet_768': Size(768, 1024),
  'desktop_1440': Size(1440, 900),
};

final _portfolioPreview = [
  PortfolioVideo(
    id: 'preview-portfolio-01',
    userId: previewCandidato['id'] as String,
    videoUrl: 'preview-video-01',
    title: 'Dashboard Analytics B2B',
    description: 'Incremento 40% en adopcion',
    createdAt: DateTime(2026, 8, 12),
  ),
  PortfolioVideo(
    id: 'preview-portfolio-02',
    userId: previewCandidato['id'] as String,
    videoUrl: 'preview-video-02',
    title: 'Rediseno App Movil',
    description: 'Mejora 35% en conversion',
    createdAt: DateTime(2026, 8, 10),
  ),
  PortfolioVideo(
    id: 'preview-portfolio-03',
    userId: previewCandidato['id'] as String,
    videoUrl: 'preview-video-03',
    title: 'Modulo IA Predictiva',
    description: 'Reduccion 25% en churn',
    createdAt: DateTime(2026, 8, 7),
  ),
];

void main() {
  setUpAll(() async {
    candPrepararEntorno();
    await loadMpFonts();
  });

  ProfileScreen perfil() => ProfileScreen(
        previewData: ProfilePreviewData(
          usuario: previewCandidato,
          portfolio: _portfolioPreview,
          viewCount: 128,
        ),
      );

  for (final medida in _medidas.entries) {
    testWidgets('captura perfil candidato ${medida.key}', (tester) async {
      await pumpCandidato(
        tester,
        medida.value,
        perfil(),
        destino: CandDestino.perfil,
      );
      candSinExcepciones(tester, 'Perfil ${medida.key}');
      await candCapturar(tester, '$_destino/${medida.key}.png');
    });
  }
}
