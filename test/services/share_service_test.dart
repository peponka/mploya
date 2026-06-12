import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/share_service.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Unit tests para ShareService â€” generaciÃ³n de links y textos de sharing
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

void main() {
  final share = ShareService.instance;

  group('URL generation', () {
    test('profileUrl generates correct format', () {
      expect(share.profileUrl('abc123'), 'https://mploya.ai/p/abc123');
    });

    test('jobUrl generates correct format', () {
      expect(share.jobUrl('job456'), 'https://mploya.ai/j/job456');
    });
  });

  group('Share text', () {
    test('candidateShareText includes name and link', () {
      final text = share.candidateShareText(
        name: 'Juan PÃ©rez',
        headline: 'Flutter Developer',
        userId: 'uid123',
      );
      expect(text.contains('Juan PÃ©rez'), true);
      expect(text.contains('mploya.ai/p/uid123'), true);
      expect(text.contains('Video-Pitch'), true);
    });

    test('companyShareText includes name and link', () {
      final text = share.companyShareText(
        name: 'TechCorp',
        headline: 'Hiring top talent',
        userId: 'comp456',
      );
      expect(text.contains('TechCorp'), true);
      expect(text.contains('mploya.ai/p/comp456'), true);
    });

    test('empty headline does not add extra quotes line', () {
      final text = share.candidateShareText(
        name: 'MarÃ­a',
        headline: '',
        userId: 'uid789',
      );
      expect(text.contains('""'), false);
    });
  });
}
