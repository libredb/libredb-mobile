@Tags(['widget'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/di/app_scope.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/object_source_view.dart';
import 'package:libredb_mobile/features/settings/application/remove_my_data_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/storage/temporary_share_files.dart';
import 'package:libredb_mobile/shared/user_data/user_data_registry.dart';

import '../../support/test_env.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

const _subject = '6f1c9a52-0d7e-4b8e-9f43-2b0c4b1f7a10';

/// A view whose definition is longer than the 100,000 characters shared as text, so it is shared as a file.
final _longSource = ObjectSource(
  path: const ['sales', 'order_totals'],
  kind: 'view',
  parts: [
    SourceText(
      id: 'definition',
      label: 'Definition',
      text: 'SELECT ${'x' * 100000}',
      language: 'sql',
      origin: SourceOrigin.stored,
    ),
  ],
);

/// The share files of the app, which also say when a share has ended: a file share ends once its own file is removed,
/// after the share sheet has answered. A test waits on that event, never on a clock, since writing the file can take
/// seconds on a busy disk.
class _ShareFiles extends TemporaryShareFiles {
  final ended = Completer<void>();

  @override
  Future<void> delete(File file) async {
    try {
      await super.delete(file);
    } finally {
      ended.complete();
    }
  }
}

/// The local sign-in's dependencies, with [shareFiles] wherever the app uses its share files.
class _Dependencies extends LocalSignInDependencies {
  _Dependencies(this.shareFiles) : super(appConfig: const AppConfig.test());

  final _ShareFiles shareFiles;

  @override
  TemporaryShareFiles createTemporaryShareFiles() => shareFiles;
}

// Regression (#202): a source shared as a file stayed in the temporary directory after the share sheet closed, after
// the sign-out and after 'Remove my data', so the next account on the phone could read it.
void main() {
  late Directory temporary;
  late Directory support;
  late List<MethodCall> shareCalls;
  late _ShareFiles shareFiles;

  setUp(() {
    shareFiles = _ShareFiles();
    temporary = Directory.systemTemp.createTempSync('share_cleanup_temporary');
    support = Directory.systemTemp.createTempSync('share_cleanup_support');
    shareCalls = [];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathProviderChannel, (call) async {
      return switch (call.method) {
        'getTemporaryDirectory' => temporary.path,
        'getApplicationSupportDirectory' => support.path,
        _ => throw MissingPluginException(),
      };
    });
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      shareCalls.add(call);
      // share_plus on Android copies each file into `<cache>/share_plus`, the temporary directory, before it opens the
      // share sheet (share_plus 13.3.1 `Share.kt`, copyToShareCacheFolder), and leaves the copy until the next share.
      for (final path in ((call.arguments as Map)['paths'] as List?)?.cast<String>() ?? const <String>[]) {
        final copies = Directory('${temporary.path}/share_plus')..createSync(recursive: true);
        File(path).copySync('${copies.path}/${path.split('/').last}');
      }
      return 'dev.fluttercommunity.plus/share/success';
    });
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathProviderChannel, null);
    messenger.setMockMethodCallHandler(_shareChannel, null);
    for (final directory in [temporary, support]) {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    }
  });

  /// The files under the temporary directory, by their path below it.
  List<String> temporaryFiles() => [
    for (final file in temporary.listSync(recursive: true).whereType<File>())
      file.path.substring(temporary.path.length + 1),
  ]..sort();

  /// The app's scope with the long source on screen, signed in as the local sign-in signs in.
  Future<BuildContext> pumpSource(WidgetTester tester) async {
    TestEnv.authenticate();
    late BuildContext scope;
    await tester.pumpWidget(
      AppScope(
        dependencies: _Dependencies(shareFiles),
        defaultLocale: const Locale('en'),
        child: Builder(
          builder: (context) {
            scope = context;
            return MaterialApp(
              localizationsDelegates: const [
                S.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: S.delegate.supportedLocales,
              home: Scaffold(body: ObjectSourceView(source: _longSource)),
            );
          },
        ),
      ),
    );
    scope.read<SessionCubit>();
    await tester.pumpAndSettle();
    return scope;
  }

  /// Taps Share and waits until the share sheet has closed and the share has ended.
  Future<void> shareLongSource(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Share'));
      await shareFiles.ended.future;
    });
    await tester.pump();
    expect(shareCalls, hasLength(1));
    expect((shareCalls.single.arguments as Map)['paths'], hasLength(1));
  }

  testWidgets('a source shared as a file leaves only the share sheet copy once the sheet closes', (tester) async {
    await pumpSource(tester);

    await shareLongSource(tester);

    expect(temporaryFiles(), ['share_plus/order_totals-definition.sql']);
  });

  testWidgets('the sign-out removes the file a shared source left', (tester) async {
    final scope = await pumpSource(tester);
    await shareLongSource(tester);
    expect(temporaryFiles(), isNotEmpty);

    SignOutState? ended;
    await tester.runAsync(() async {
      final signOut = scope.read<SignOutBloc>();
      signOut.add(const SignOutRequested());
      ended = await signOut.stream.firstWhere((state) => state is SignOutDone);
    });

    expect(ended, isA<SignedOut>());
    expect(temporaryFiles(), isEmpty);
  });

  testWidgets("'Remove my data' removes the file a shared source left", (tester) async {
    final scope = await pumpSource(tester);
    await shareLongSource(tester);
    expect(temporaryFiles(), isNotEmpty);

    RemoveMyDataState? ended;
    await tester.runAsync(() async {
      final removeMyData = RemoveMyDataBloc(registry: scope.read<UserDataRegistry>());
      removeMyData.add(const RemoveMyDataRequested(subject: _subject));
      ended = await removeMyData.stream.firstWhere(
        (state) => state is RemoveMyDataDone || state is RemoveMyDataFailure,
      );
      await removeMyData.close();
    });

    expect(ended, isA<RemoveMyDataDone>());
    expect(temporaryFiles(), isEmpty);
  });
}
