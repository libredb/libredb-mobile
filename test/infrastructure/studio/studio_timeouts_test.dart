import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';

void main() {
  StudioConnection connection(String id, {Duration? queryTimeout}) =>
      StudioConnection(id: id, name: id, type: 'postgres', queryTimeout: queryTimeout);

  test("Studio's 60 second statement timeout plus a 15 second margin", () {
    expect(studioStatementReceiveTimeout, const Duration(seconds: 75));
  });

  group('ConnectionQueryTimeouts', () {
    late ConnectionQueryTimeouts timeouts;

    setUp(() => timeouts = ConnectionQueryTimeouts());

    test("waits a connection's own query timeout plus the 15 second margin", () {
      timeouts.replaceAll([connection('seed:slow', queryTimeout: const Duration(seconds: 120))]);

      expect(timeouts.statementReceiveTimeout('seed:slow'), const Duration(seconds: 135));
    });

    test('a timeout under 60 seconds is kept too, since Studio stops the statement then', () {
      timeouts.replaceAll([connection('seed:quick', queryTimeout: const Duration(seconds: 5))]);

      expect(timeouts.statementReceiveTimeout('seed:quick'), const Duration(seconds: 20));
    });

    test("waits 75 seconds for a connection Studio sent no query timeout for, or one it has not listed", () {
      timeouts.replaceAll([connection('seed:plain')]);

      expect(timeouts.statementReceiveTimeout('seed:plain'), studioStatementReceiveTimeout);
      expect(timeouts.statementReceiveTimeout('seed:unknown'), studioStatementReceiveTimeout);
    });

    test('each list replaces the one before it, so a timeout Studio no longer sends is dropped', () {
      timeouts.replaceAll([
        connection('seed:a', queryTimeout: const Duration(seconds: 120)),
        connection('seed:b', queryTimeout: const Duration(seconds: 90)),
      ]);

      timeouts.replaceAll([connection('seed:a')]);

      expect(timeouts.statementReceiveTimeout('seed:a'), studioStatementReceiveTimeout);
      expect(timeouts.statementReceiveTimeout('seed:b'), studioStatementReceiveTimeout);
    });
  });
}
