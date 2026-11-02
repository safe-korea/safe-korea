package kr.safekor.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "kr.safekor.app/civil_alerts").setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(CivilAlertLink.status(this))
                "setEnabled" -> { CivilAlertLink.setEnabled(this, call.argument<Boolean>("enabled") == true); result.success(null) }
                "openSettings" -> { CivilAlertLink.openSettings(this); result.success(null) }
                "pending" -> result.success(CivilAlertLink.pending(this))
                "acknowledge" -> { CivilAlertLink.acknowledge(this, call.argument<String>("id") ?: ""); result.success(null) }
                else -> result.notImplemented()
            }
        }
        EventChannel(engine.dartExecutor.binaryMessenger, "kr.safekor.app/civil_alert_events").setStreamHandler(object: EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) { CivilAlertLink.sink = events }
            override fun onCancel(arguments: Any?) { CivilAlertLink.sink = null }
        })
    }
    override fun onResume() { super.onResume(); CivilAlertLink.foreground = true }
    override fun onPause() { CivilAlertLink.foreground = false; super.onPause() }
    override fun onDestroy() { CivilAlertLink.sink = null; super.onDestroy() }
}
