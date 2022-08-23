import 'package:itunes_podcast_search/itunes_podcast_search.dart';
import 'package:test/test.dart';

void main() {
  group('Baseline search test', () {
    late Search search;

    setUp(() {
      search = Search(
        searchProvider:
           ITunesProvider(),
      );
    });

    test('Podcast index trending', () async {
      final result = await search.charts(queryParams: {'val': 'lightning'});

      expect(result.resultCount > 0, true);
    });

    test('Max one result test', () async {
      final result = await search.search('Forest 404');

      expect(result.resultCount, 1);
    });
  });
}
