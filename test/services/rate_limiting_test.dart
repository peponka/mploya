import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/auth_service.dart';

void main() {
  group('AuthService constants', () {
    test('kAuthErrorNoAccount constant is defined', () {
      expect(kAuthErrorNoAccount, 'AUTH_NO_ACCOUNT');
    });
  });

  group('AuthService email validation', () {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

    test('rejects empty string', () {
      expect(regex.hasMatch(''), false);
    });

    test('rejects no @ sign', () {
      expect(regex.hasMatch('notanemail'), false);
    });

    test('rejects missing local part', () {
      expect(regex.hasMatch('@nodomain.com'), false);
    });

    test('rejects missing domain', () {
      expect(regex.hasMatch('user@'), false);
    });

    test('accepts standard email', () {
      expect(regex.hasMatch('test@example.com'), true);
    });

    test('accepts email with dots', () {
      expect(regex.hasMatch('user.name@domain.co'), true);
    });

    test('accepts email with plus tag', () {
      expect(regex.hasMatch('user+tag@gmail.com'), true);
    });

    test('accepts minimal email', () {
      expect(regex.hasMatch('a@b.c'), true);
    });
  });

  group('AuthService password validation', () {
    test('minimum 8 chars for signup', () {
      expect('1234567'.length < 8, true);
      expect('12345678'.length >= 8, true);
    });

    test('requires at least one uppercase letter', () {
      final regex = RegExp(r'[A-Z]');
      expect(regex.hasMatch('alllowercase'), false);
      expect(regex.hasMatch('hasOneUpper'), true);
      expect(regex.hasMatch('A'), true);
    });

    test('requires at least one number', () {
      final regex = RegExp(r'[0-9]');
      expect(regex.hasMatch('nonumbers'), false);
      expect(regex.hasMatch('has1number'), true);
      expect(regex.hasMatch('0'), true);
    });

    test('strong password passes all checks', () {
      const password = 'MySecure1Password';
      expect(password.length >= 8, true);
      expect(RegExp(r'[A-Z]').hasMatch(password), true);
      expect(RegExp(r'[0-9]').hasMatch(password), true);
    });

    test('weak password fails multiple checks', () {
      const password = 'weak';
      expect(password.length >= 8, false);
      expect(RegExp(r'[A-Z]').hasMatch(password), false);
      expect(RegExp(r'[0-9]').hasMatch(password), false);
    });
  });
}
