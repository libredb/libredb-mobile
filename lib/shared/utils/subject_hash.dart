import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The SHA-256 hex of the identity provider's subject, which the device keys per-account data by, so the subject
/// itself is never stored.
String subjectHash(String subject) => sha256.convert(utf8.encode(subject)).toString();
