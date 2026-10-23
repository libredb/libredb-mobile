import 'package:libredb_mobile/shared/models/query_id.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the first page sends only the offset, so Studio applies its default size', () {
    expect(QueryPage.first.toJson(), {'offset': 0});
  });

  test('the page after a result starts after the rows already shown, with the same size', () {
    const previous = QueryPagination(limit: 500, offset: 500, hasMore: true, totalReturned: 500, wasLimited: true);

    expect(QueryPage.after(previous), const QueryPage(limit: 500, offset: 1000));
  });

  test('an unlimited page says so', () {
    expect(const QueryPage(unlimited: true).toJson(), {'offset': 0, 'unlimited': true});
  });

  test('newQueryId gives a fresh UUID every time', () {
    final ids = {for (var i = 0; i < 100; i++) newQueryId()};

    expect(ids, hasLength(100));
    expect(ids.first, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
  });
}
