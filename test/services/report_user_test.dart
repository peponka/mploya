import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/report_user_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Unit tests para ReportUserService — enum ReportReason
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('ReportReason enum', () {
    test('has 6 reasons', () {
      expect(ReportReason.values.length, 6);
    });

    test('harassment value and label', () {
      expect(ReportReason.harassment.value, 'harassment');
      expect(ReportReason.harassment.label, 'Acoso o comportamiento abusivo');
    });

    test('spam value and label', () {
      expect(ReportReason.spam.value, 'spam');
      expect(ReportReason.spam.label, 'Spam o contenido no deseado');
    });

    test('fakeProfile value and label', () {
      expect(ReportReason.fakeProfile.value, 'fake_profile');
      expect(ReportReason.fakeProfile.label, 'Perfil falso o suplantación');
    });

    test('inappropriate value and label', () {
      expect(ReportReason.inappropriate.value, 'inappropriate');
      expect(ReportReason.inappropriate.label, 'Contenido inapropiado');
    });

    test('scam value and label', () {
      expect(ReportReason.scam.value, 'scam');
      expect(ReportReason.scam.label, 'Estafa o fraude');
    });

    test('other value and label', () {
      expect(ReportReason.other.value, 'other');
      expect(ReportReason.other.label, 'Otro motivo');
    });

    test('all values are unique', () {
      final values = ReportReason.values.map((r) => r.value).toSet();
      expect(values.length, 6);
    });

    test('all labels are non-empty', () {
      for (final reason in ReportReason.values) {
        expect(reason.label.isNotEmpty, true);
      }
    });
  });

  group('ReportUserService singleton', () {
    test('instance is singleton', () {
      final a = ReportUserService.instance;
      final b = ReportUserService.instance;
      expect(identical(a, b), true);
    });
  });
}
