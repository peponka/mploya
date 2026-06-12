import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/models/models.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Unit tests para resolveVideoUrl â€” lÃ³gica de bypass CORS
//
// Testeamos:
//  1. URLs vÃ¡lidas pasan sin cambio
//  2. URLs de dominios CORS-bloqueados se reemplazan con asset local
//  3. URLs nulas/vacÃ­as retornan string vacÃ­o
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

void main() {
  group('resolveVideoUrl', () {
    test('valid Supabase URL passes through unchanged', () {
      const url = 'https://qclipzefqndcefwwixdy.supabase.co/storage/v1/object/public/videos/pitch.mp4';
      expect(resolveVideoUrl(url), url);
    });

    test('generic valid URL passes through unchanged', () {
      const url = 'https://example.com/video.mp4';
      expect(resolveVideoUrl(url), url);
    });

    test('null URL returns empty string', () {
      expect(resolveVideoUrl(null), '');
    });

    test('empty URL returns empty string', () {
      expect(resolveVideoUrl(''), '');
    });

    test('commondatastorage URL is replaced with local asset', () {
      const url = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      expect(resolveVideoUrl(url), 'asset:assets/videos/mock_pitch.mp4');
    });

    test('flutter.github.io URL is replaced with local asset', () {
      const url = 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';
      expect(resolveVideoUrl(url), 'asset:assets/videos/mock_pitch.mp4');
    });

    test('URL containing blocked domain substring is caught', () {
      const url = 'https://cdn.commondatastorage.example.com/video.mp4';
      expect(resolveVideoUrl(url), 'asset:assets/videos/mock_pitch.mp4');
    });

    test('YouTube URLs pass through (not blocked)', () {
      const url = 'https://www.youtube.com/watch?v=test';
      expect(resolveVideoUrl(url), url);
    });
  });
}
