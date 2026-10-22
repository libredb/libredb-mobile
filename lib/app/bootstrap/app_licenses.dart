import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the app's own licence to the licences page.
///
/// The NOTICE asset holds the Elastic License 2.0 statement of LibreDB Mobile and, in full, the MIT notice of the
/// flutter-bloc-advanced template the app grew from, which must travel with every copy of the app. Flutter's
/// generated licences cover the pub dependencies, not the app's own source.
void registerAppLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const ['libredb_mobile'], await rootBundle.loadString('NOTICE'));
  });
}
