package org.libredb.mobile

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.sentry.Sentry

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The native crash of the Sentry device check (docs/crash-reporting.md), only in a build with its define.
        SentryDeviceCheck.crashIfAsked(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // nativeSdkReady (lib/infrastructure/analytics/native_sentry_start.dart) asks whether MainApplication started
        // the native Sentry SDK before the Dart side starts its own.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.libredb.mobile/native_sentry")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEnabled" -> result.success(Sentry.isEnabled())
                    else -> result.notImplemented()
                }
            }
        SensitiveClipboard.register(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
    }
}
