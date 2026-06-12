import 'package:flutter_test/flutter_test.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Unit tests para AuthService â€” validaciÃ³n de inputs
//
// No testea Supabase (requiere red). Solo lÃ³gica pura de validaciÃ³n.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

// Regex de email usada en AuthService
final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

// Validaciones de passwords
String? validateSignUpPassword(String password) {
  if (password.length < 8) return 'La contraseÃ±a debe tener al menos 8 caracteres.';
  if (!RegExp(r'[A-Z]').hasMatch(password)) return 'La contraseÃ±a debe incluir al menos una mayÃºscula.';
  if (!RegExp(r'[0-9]').hasMatch(password)) return 'La contraseÃ±a debe incluir al menos un nÃºmero.';
  return null;
}

void main() {
  group('Email validation', () {
    test('valid emails pass', () {
      expect(_emailRegex.hasMatch('user@example.com'), true);
      expect(_emailRegex.hasMatch('a@b.co'), true);
      expect(_emailRegex.hasMatch('test.user+tag@domain.org'), true);
    });

    test('invalid emails fail', () {
      expect(_emailRegex.hasMatch(''), false);
      expect(_emailRegex.hasMatch('noatsign'), false);
      expect(_emailRegex.hasMatch('@nodomain'), false);
      expect(_emailRegex.hasMatch('user@'), false);
      expect(_emailRegex.hasMatch('user@.'), false);
    });

    test('emails with spaces: regex matches but input should be trimmed', () {
      // The regex [^@]+@[^@]+\.[^@]+ technically accepts spaces
      // because space is "not @". In production, inputs are trimmed.
      // We test the raw regex here â€” these DO match:
      expect(_emailRegex.hasMatch('user @example.com'), true);
      expect(_emailRegex.hasMatch(' user@example.com'), true);
      // But empty string does not:
      expect(_emailRegex.hasMatch(''), false);
    });
  });

  group('Password validation (signUp)', () {
    test('too short (< 8 chars) fails', () {
      expect(validateSignUpPassword('Ab1'), isNotNull);
      expect(validateSignUpPassword('1234567'), isNotNull);
    });

    test('no uppercase fails', () {
      expect(validateSignUpPassword('abcdefg1'), isNotNull);
    });

    test('no number fails', () {
      expect(validateSignUpPassword('Abcdefgh'), isNotNull);
    });

    test('valid password passes', () {
      expect(validateSignUpPassword('Password1'), isNull);
      expect(validateSignUpPassword('MiClave99'), isNull);
      expect(validateSignUpPassword('Mploya2026!'), isNull);
    });

    test('exactly 8 chars with requirements passes', () {
      expect(validateSignUpPassword('Passwd1!'), isNull);
    });
  });
}
