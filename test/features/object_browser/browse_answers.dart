import 'dart:io';

import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_container.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_detail.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';

/// Studio's answers for the Browse tests, read through the app's readers: the answers recorded against tool/studio-dev
/// (#49) in test/fixtures/studio, and the hand-written ones (#48) under its handwritten folder, named with that
/// folder, as `handwritten/mssql/meta`.
String _answer(String name) => File('test/fixtures/studio/$name.json').readAsStringSync();

ProviderMeta metaAnswer(String name) => ProviderMetaJson.read(_answer(name));

List<ObjectContainer> containersAnswer(String name) => ObjectBrowserJson.containers(_answer(name));

Map<String, KindCount> countsAnswer(String name) => ObjectBrowserJson.counts(_answer(name));

ObjectSource sourceAnswer(String name) => ObjectBrowserJson.source(_answer(name));

List<DatabaseObject> objectsAnswer(String name) => ObjectBrowserJson.objects(_answer(name));

ObjectDetail detailAnswer(String name) => ObjectBrowserJson.detail(_answer(name));
