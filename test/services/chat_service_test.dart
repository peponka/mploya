import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/chat_service.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Unit tests para ChatService â€” lÃ³gica pura sin Supabase
//
// Testeamos:
//  1. formatFileSize â€” human-readable file sizes (static, no Supabase)
//  2. generateJitsiRoom â€” deterministic room IDs (requires instance)
//
// NOTA: generateJitsiRoom require Supabase.instance, pero es lÃ³gica pura.
// Lo testeamos mediante extracciÃ³n de la lÃ³gica determinÃ­stica.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Replica de la lÃ³gica de generateJitsiRoom para poder testear sin Supabase.
/// Es idÃ©ntica a ChatService.generateJitsiRoom.
String _generateJitsiRoom(String userId1, String userId2) {
  final sorted = [userId1, userId2]..sort();
  final hash = sorted.join('_').hashCode.toRadixString(16);
  return 'mploya-interview-$hash';
}

void main() {
  group('generateJitsiRoom (lÃ³gica pura)', () {
    test('generates consistent room for same pair', () {
      final room1 = _generateJitsiRoom('user-aaa', 'user-bbb');
      final room2 = _generateJitsiRoom('user-aaa', 'user-bbb');
      expect(room1, room2);
    });

    test('generates same room regardless of order', () {
      final roomAB = _generateJitsiRoom('user-aaa', 'user-bbb');
      final roomBA = _generateJitsiRoom('user-bbb', 'user-aaa');
      expect(roomAB, roomBA);
    });

    test('generates different rooms for different pairs', () {
      final room1 = _generateJitsiRoom('user-aaa', 'user-bbb');
      final room2 = _generateJitsiRoom('user-aaa', 'user-ccc');
      expect(room1, isNot(room2));
    });

    test('room starts with mploya-interview- prefix', () {
      final room = _generateJitsiRoom('user-1', 'user-2');
      expect(room.startsWith('mploya-interview-'), true);
    });

    test('room contains hex hash', () {
      final room = _generateJitsiRoom('user-x', 'user-y');
      final hash = room.replaceFirst('mploya-interview-', '');
      expect(hash.isNotEmpty, true);
    });

    test('UUID-like inputs produce valid rooms', () {
      final room = _generateJitsiRoom(
        'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'f0e9d8c7-b6a5-4321-fedc-ba0987654321',
      );
      expect(room.startsWith('mploya-interview-'), true);
      expect(room.length > 'mploya-interview-'.length, true);
    });
  });

  group('formatFileSize (static)', () {
    test('formats bytes correctly', () {
      expect(ChatService.formatFileSize(500), '500 B');
    });

    test('formats kilobytes correctly', () {
      expect(ChatService.formatFileSize(2048), '2.0 KB');
    });

    test('formats megabytes correctly', () {
      expect(ChatService.formatFileSize(1048576), '1.0 MB');
    });

    test('formats large megabytes correctly', () {
      expect(ChatService.formatFileSize(5242880), '5.0 MB');
    });

    test('formats zero bytes', () {
      expect(ChatService.formatFileSize(0), '0 B');
    });

    test('formats boundary: just under 1 KB', () {
      expect(ChatService.formatFileSize(1023), '1023 B');
    });

    test('formats boundary: exactly 1 KB', () {
      expect(ChatService.formatFileSize(1024), '1.0 KB');
    });

    test('formats boundary: just under 1 MB', () {
      expect(ChatService.formatFileSize(1048575), '1024.0 KB');
    });
  });
}
