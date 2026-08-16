import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/empresa/empresa_mensajes_data.dart';

void main() {
  group('privacidad de Empresa Mensajes', () {
    test('oculta todas las variantes confidenciales y stealth', () {
      for (final accountType in <String>[
        'confidencial',
        'confidential',
        'confidencial_premium',
        'confidential_hidden',
        'confidenc_custom',
        'stealth',
        'STEALTH',
        ' CONFIDENTIAL ',
        ' Confidencial_Premium ',
        ' stealth ',
      ]) {
        expect(
          empresaMensajeEsConfidencial(accountType),
          isTrue,
          reason: '$accountType debe ocultar la identidad en Mensajes',
        );
      }
    });

    test('no oculta cuentas públicas ni valores vacíos', () {
      for (final accountType in <String?>[
        'candidato',
        'empresa',
        'headhunter',
        ' candidato ',
        '',
        '   ',
        null,
      ]) {
        expect(
          empresaMensajeEsConfidencial(accountType),
          isFalse,
          reason: '$accountType no debe marcarse como confidencial',
        );
      }
    });
  });
}
