import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/error_handler.dart';

void main() {
  late MployaErrorHandler handler;

  setUp(() {
    handler = MployaErrorHandler.instance;
  });

  group('handleSupabase', () {
    test('detects expired JWT session', () {
      final result = handler.handleSupabase('PGRST301: JWT expired');
      expect(result, contains('expir'));
    });

    test('detects jwt keyword', () {
      final result = handler.handleSupabase('invalid jwt token');
      expect(result, contains('expir'));
    });

    test('detects RLS policy violation (42501)', () {
      final result = handler.handleSupabase('42501: new row violates row-level security policy');
      expect(result, contains('permiso'));
    });

    test('detects rls keyword', () {
      final result = handler.handleSupabase('RLS violation on table users');
      expect(result, contains('permiso'));
    });

    test('detects policy keyword', () {
      final result = handler.handleSupabase('Policy check failed');
      expect(result, contains('permiso'));
    });

    test('detects duplicate key violation (23505)', () {
      final result = handler.handleSupabase('23505: duplicate key value violates unique constraint');
      expect(result, contains('existe'));
    });

    test('detects duplicate keyword', () {
      final result = handler.handleSupabase('Duplicate entry found');
      expect(result, contains('existe'));
    });

    test('detects foreign key violation (23503)', () {
      final result = handler.handleSupabase('23503: insert or update on table violates foreign key constraint');
      expect(result, contains('Referencia'));
    });

    test('detects timeout', () {
      final result = handler.handleSupabase('Connection timed out after 30000ms');
      expect(result, contains('tard'));
    });

    test('detects socket error', () {
      final result = handler.handleSupabase('SocketException: Connection refused');
      expect(result, contains('conexi'));
    });

    test('detects network error', () {
      final result = handler.handleSupabase('Network is unreachable');
      expect(result, contains('conexi'));
    });

    test('detects connection error', () {
      final result = handler.handleSupabase('Connection reset by peer');
      expect(result, contains('conexi'));
    });

    test('detects storage/bucket error', () {
      final result = handler.handleSupabase('storage error: bucket not found');
      expect(result, contains('archivo'));
    });

    test('detects email already registered', () {
      final result = handler.handleSupabase('User with this email already exists');
      expect(result, contains('email'));
    });

    test('returns generic for unknown error', () {
      final result = handler.handleSupabase('Something weird happened xyz');
      expect(result, contains('Algo'));
    });

    test('handles empty string', () {
      final result = handler.handleSupabase('');
      expect(result, contains('Algo'));
    });

    test('is case insensitive for jwt', () {
      final result = handler.handleSupabase('PGRST301: JWT EXPIRED');
      expect(result, contains('expir'));
    });

    test('is case insensitive for timeout', () {
      final result = handler.handleSupabase('TIMEOUT');
      expect(result, contains('tard'));
    });

    test('priority: jwt before generic network', () {
      final result = handler.handleSupabase('jwt connection error');
      expect(result, contains('expir'));
    });
  });
}
