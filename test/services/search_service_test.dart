import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/search_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Unit tests para SearchService — modelo SearchResults y lógica de búsqueda
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('SearchResults model', () {
    test('empty factory creates valid empty state', () {
      final r = SearchResults.empty();
      expect(r.isEmpty, true);
      expect(r.hasResults, false);
      expect(r.hasError, false);
      expect(r.isLoading, false);
      expect(r.users, isEmpty);
      expect(r.query, isNull);
    });

    test('loading state is not empty', () {
      final r = SearchResults(isLoading: true);
      expect(r.isEmpty, false);
      expect(r.isLoading, true);
      expect(r.hasResults, false);
    });

    test('error state has error', () {
      final r = SearchResults(error: 'Connection timeout', query: 'flutter');
      expect(r.hasError, true);
      expect(r.error, 'Connection timeout');
      expect(r.isEmpty, false);
    });

    test('results state has data', () {
      final r = SearchResults(
        users: [
          {'id': '1', 'name': 'Juan'},
          {'id': '2', 'name': 'María'},
        ],
        query: 'flutter',
        totalCount: 2,
      );
      expect(r.hasResults, true);
      expect(r.isEmpty, false);
      expect(r.hasError, false);
      expect(r.users.length, 2);
      expect(r.totalCount, 2);
    });

    test('empty users with no loading or error is empty', () {
      final r = SearchResults(users: [], query: 'xyz');
      expect(r.isEmpty, true);
    });
  });

  group('SearchService singleton', () {
    test('instance is singleton', () {
      final a = SearchService.instance;
      final b = SearchService.instance;
      expect(identical(a, b), true);
    });

    test('recentSearches starts empty', () {
      expect(SearchService.instance.recentSearches, isEmpty);
    });

    test('clearRecent clears searches', () {
      SearchService.instance.clearRecent();
      expect(SearchService.instance.recentSearches, isEmpty);
    });

    test('cancel does not throw', () {
      expect(() => SearchService.instance.cancel(), returnsNormally);
    });
  });
}
