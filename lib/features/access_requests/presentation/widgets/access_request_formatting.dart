import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/generated/l10n.dart';

/// [value] in the local time, in the language of the app.
String formatRequestDate(BuildContext context, DateTime value) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_Hm().format(value.toLocal());

/// The label of a level: "Read", "Write", or the raw value of a level the app does not know.
String requestLevelLabel(S s, String level) => switch (level) {
  'read' => s.access_requests_level_read,
  'write' => s.access_requests_level_write,
  _ => level,
};

/// The level inside a sentence: "read", "write", or the raw value of a level the app does not know.
String requestLevelInSentence(S s, String level) => switch (level) {
  'read' => s.access_requests_level_read_in_sentence,
  'write' => s.access_requests_level_write_in_sentence,
  _ => level,
};
