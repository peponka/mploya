import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/feed_service.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Unit tests para FeedService â€” lÃ³gica pura sin Supabase
//
// Testeamos:
//  1. sortByAffinity â€” ordenamiento por tags + premium + boost
//  2. applyCrossFilter â€” Ley de Cruce (candidato ve empresa, empresa ve candidato)
//  3. applyFilter â€” filtros Senior, Remoto, Tech, Fintech
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

void main() {
  final feed = FeedService.instance;

  group('sortByAffinity', () {
    test('premium users rank higher than non-premium', () {
      final users = [
        {'id': '1', 'is_premium': false, 'tags': <String>[], 'created_at': '2026-01-01T00:00:00Z'},
        {'id': '2', 'is_premium': true, 'tags': <String>[], 'created_at': '2026-01-01T00:00:00Z'},
      ];

      final sorted = feed.sortByAffinity(users, []);
      expect(sorted.first['id'], '2'); // Premium primero
    });

    test('shared tags increase affinity score', () {
      final users = [
        {'id': '1', 'is_premium': false, 'tags': ['python', 'aws'], 'created_at': '2026-01-01T00:00:00Z'},
        {'id': '2', 'is_premium': false, 'tags': ['flutter', 'dart', 'aws'], 'created_at': '2026-01-01T00:00:00Z'},
      ];

      final sorted = feed.sortByAffinity(users, ['flutter', 'dart', 'aws']);
      expect(sorted.first['id'], '2'); // 3 tags compartidos > 1
    });

    test('boost > premium > tags', () {
      final futureDate = DateTime.now().add(const Duration(days: 1)).toIso8601String();
      final users = [
        {'id': 'tags-only', 'is_premium': false, 'tags': ['flutter', 'dart'], 'created_at': '2026-01-01T00:00:00Z'},
        {'id': 'premium', 'is_premium': true, 'tags': <String>[], 'created_at': '2026-01-01T00:00:00Z'},
        {'id': 'boosted', 'is_premium': false, 'boost_ends_at': futureDate, 'tags': <String>[], 'created_at': '2026-01-01T00:00:00Z'},
      ];

      final sorted = feed.sortByAffinity(users, ['flutter', 'dart']);
      expect(sorted[0]['id'], 'boosted'); // +1000
      expect(sorted[1]['id'], 'premium'); // +100
      expect(sorted[2]['id'], 'tags-only'); // +20
    });

    test('expired boost does not contribute', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      final users = [
        {'id': 'expired', 'is_premium': false, 'boost_ends_at': pastDate, 'tags': <String>[], 'created_at': '2026-01-01T00:00:00Z'},
        {'id': 'normal', 'is_premium': false, 'tags': <String>[], 'created_at': '2026-01-02T00:00:00Z'},
      ];

      final sorted = feed.sortByAffinity(users, []);
      expect(sorted.first['id'], 'normal'); // MÃ¡s reciente, mismo score
    });
  });

  group('applyCrossFilter (Ley de Cruce)', () {
    final allUsers = [
      {'id': '1', 'account_type': 'candidato', 'video_url': 'https://video.mp4'},
      {'id': '2', 'account_type': 'empresa', 'video_url': 'https://video.mp4'},
      {'id': '3', 'account_type': 'headhunter', 'video_url': 'https://video.mp4'},
      {'id': '4', 'account_type': 'confidencial', 'video_url': 'https://video.mp4'},
      {'id': '5', 'account_type': 'candidato', 'video_url': null}, // Sin video â†’ excluido
    ];

    test('candidato sees only empresa/headhunter', () {
      final filtered = feed.applyCrossFilter(allUsers, 'candidato');
      final types = filtered.map((u) => u['account_type']).toSet();
      expect(types, {'empresa', 'headhunter'});
    });

    test('empresa sees candidato/confidencial', () {
      final filtered = feed.applyCrossFilter(allUsers, 'empresa');
      final types = filtered.map((u) => u['account_type']).toSet();
      expect(types, {'candidato', 'confidencial'});
    });

    test('users without video are excluded', () {
      final filtered = feed.applyCrossFilter(allUsers, 'empresa');
      expect(filtered.any((u) => u['id'] == '5'), false);
    });
  });

  group('applyFilter', () {
    final users = [
      {'id': '1', 'headline': 'Senior Fullstack Dev', 'tags': ['flutter', 'react'], 'open_to_work': false},
      {'id': '2', 'headline': 'Junior Designer', 'tags': ['remoto', 'figma'], 'open_to_work': true},
      {'id': '3', 'headline': 'CTO at Fintech Startup', 'tags': ['fintech', 'blockchain', 'cripto'], 'open_to_work': false},
      {'id': '4', 'headline': 'Marketing Manager', 'tags': ['marketing', 'growth'], 'open_to_work': false},
    ];

    test('filter 0 (Todos) returns all', () {
      expect(feed.applyFilter(users, 0).length, 4);
    });

    test('filter 1 (Senior) works', () {
      final result = feed.applyFilter(users, 1);
      expect(result.any((u) => u['id'] == '1'), true); // "Senior"
      expect(result.any((u) => u['id'] == '3'), true); // "CTO"
      expect(result.any((u) => u['id'] == '2'), false); // Junior
    });

    test('filter 2 (Remoto) matches open_to_work and remoto tag', () {
      final result = feed.applyFilter(users, 2);
      expect(result.any((u) => u['id'] == '2'), true); // open_to_work + tag remoto
    });

    test('filter 3 (Tech) matches tech tags', () {
      final result = feed.applyFilter(users, 3);
      expect(result.any((u) => u['id'] == '1'), true); // flutter, react
      expect(result.any((u) => u['id'] == '4'), false); // marketing
    });

    test('filter 4 (Fintech) matches fintech tags', () {
      final result = feed.applyFilter(users, 4);
      expect(result.any((u) => u['id'] == '3'), true); // fintech, blockchain
      expect(result.length, 1);
    });
  });
}
