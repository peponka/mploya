import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/content_moderation_service.dart';

/// Tests unitarios para ContentModerationService â€” filtro local (sin Edge Function).
///
/// Estos tests validan la moderaciÃ³n client-side que funciona sin red.
/// El filtro IA (Edge Function) se testea por separado con integration tests.
void main() {
  late ContentModerationService service;

  setUp(() {
    service = ContentModerationService.instance;
  });

  group('ContentModerationService â€” moderateLocal', () {
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // CLEAN â€” Mensajes normales que deben pasar
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    group('clean messages', () {
      test('passes normal professional message', () {
        final result = service.moderateLocal('Hola, me interesa la vacante de Flutter Developer.');
        expect(result.isClean, true);
        expect(result.result, ModerationResult.clean);
      });

      test('passes empty string', () {
        final result = service.moderateLocal('');
        expect(result.isClean, true);
      });

      test('passes whitespace-only string', () {
        final result = service.moderateLocal('   ');
        expect(result.isClean, true);
      });

      test('passes normal greeting', () {
        final result = service.moderateLocal('Buenas tardes, Â¿cÃ³mo estÃ¡s?');
        expect(result.isClean, true);
      });

      test('passes technical content', () {
        final result = service.moderateLocal(
          'Tengo experiencia en Dart, Kotlin y SwiftUI. '
          'Mi stack incluye Supabase, Firebase y AWS.',
        );
        expect(result.isClean, true);
      });

      test('passes salary negotiation', () {
        final result = service.moderateLocal(
          'El rango salarial es de USD 5K-8K mensuales, negociable.',
        );
        expect(result.isClean, true);
      });
    });

    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // BLOCKED â€” Hate speech, insultos graves
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    group('blocked â€” hate speech', () {
      test('blocks severe insults (ES)', () {
        final result = service.moderateLocal('Sos un hijo de puta');
        expect(result.isBlocked, true);
        expect(result.category, 'hate_speech');
      });

      test('blocks racial slurs', () {
        final result = service.moderateLocal('Ese negro de mierda no sirve');
        expect(result.isBlocked, true);
        expect(result.category, 'hate_speech');
      });

      test('blocks threats', () {
        final result = service.moderateLocal('te voy a matar si no me contratas');
        expect(result.isBlocked, true);
        expect(result.category, 'hate_speech');
      });

      test('blocks self-harm encouragement', () {
        final result = service.moderateLocal('kys nobody wants you');
        expect(result.isBlocked, true);
        expect(result.category, 'hate_speech');
      });

      test('blocks English profanity', () {
        final result = service.moderateLocal('go fuck yourself');
        expect(result.isBlocked, true);
      });

      test('blocks Portuguese profanity', () {
        final result = service.moderateLocal('vai se foder');
        expect(result.isBlocked, true);
      });

      test('blocks discrimination phrases', () {
        final result = service.moderateLocal('fuera extranjeros de este trabajo');
        expect(result.isBlocked, true);
      });
    });

    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // BLOCKED â€” NSFW content
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    group('blocked â€” NSFW', () {
      test('blocks explicit content terms', () {
        final result = service.moderateLocal('mandame nudes y hablamos');
        expect(result.isBlocked, true);
        expect(result.category, 'nsfw');
      });

      test('blocks adult content references', () {
        final result = service.moderateLocal('tengo contenido adulto premium');
        expect(result.isBlocked, true);
        expect(result.category, 'nsfw');
      });

      test('provides appropriate reason for NSFW block', () {
        final result = service.moderateLocal('mirÃ¡ este porno gratis');
        expect(result.isBlocked, true);
        expect(result.reason, contains('red profesional'));
      });
    });

    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // FLAGGED â€” Spam (se envÃ­a pero se reporta)
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    group('flagged â€” spam', () {
      test('flags MLM/pyramid scheme language', () {
        final result = service.moderateLocal('Unite al multinivel, ganÃ¡ dinero fÃ¡cil');
        expect(result.isFlagged, true);
        expect(result.category, 'spam');
      });

      test('flags crypto scams', () {
        final result = service.moderateLocal('inversiÃ³n garantizada en bitcoin gratis');
        expect(result.isFlagged, true);
        expect(result.category, 'spam');
      });

      test('flags WhatsApp redirects', () {
        final result = service.moderateLocal('Mandame tu CV a mi whatsapp');
        expect(result.isFlagged, true);
        expect(result.category, 'spam');
      });

      test('flags OnlyFans references', () {
        final result = service.moderateLocal('Seguime en onlyfans para mÃ¡s');
        expect(result.isFlagged, true);
        expect(result.category, 'spam');
      });
    });

    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // FLAGGED â€” Style issues
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    group('flagged â€” style', () {
      test('flags ALL CAPS messages (aggressiveness)', () {
        final result = service.moderateLocal('NECESITO TRABAJO AHORA MISMO POR FAVOR');
        expect(result.isFlagged, true);
        expect(result.category, 'style');
      });

      test('does NOT flag short all-caps (under 10 chars)', () {
        final result = service.moderateLocal('OK GRACIAS');
        expect(result.isClean, true);
      });

      test('flags excessive character repetition', () {
        final result = service.moderateLocal('aaaaaaaaaa no me contestan');
        expect(result.isFlagged, true);
        expect(result.category, 'spam');
      });
    });

    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // Case insensitivity
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    group('case insensitivity', () {
      test('detects blocked patterns regardless of case', () {
        final result = service.moderateLocal('HIJO DE PUTA sos');
        expect(result.isBlocked, true);
      });

      test('detects spam patterns regardless of case', () {
        final result = service.moderateLocal('BITCOIN GRATIS para todos');
        expect(result.isFlagged, true);
      });
    });

    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    // ModerationResponse model
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    group('ModerationResponse model', () {
      test('clean response has correct flags', () {
        const r = ModerationResponse(result: ModerationResult.clean);
        expect(r.isClean, true);
        expect(r.isFlagged, false);
        expect(r.isBlocked, false);
        expect(r.reason, isNull);
        expect(r.category, isNull);
      });

      test('blocked response has reason and category', () {
        const r = ModerationResponse(
          result: ModerationResult.blocked,
          reason: 'Test reason',
          category: 'test_cat',
        );
        expect(r.isBlocked, true);
        expect(r.isClean, false);
        expect(r.reason, 'Test reason');
        expect(r.category, 'test_cat');
      });

      test('flagged response has correct flags', () {
        const r = ModerationResponse(
          result: ModerationResult.flagged,
          reason: 'Flagged reason',
          category: 'spam',
        );
        expect(r.isFlagged, true);
        expect(r.isClean, false);
        expect(r.isBlocked, false);
      });
    });
  });
}
