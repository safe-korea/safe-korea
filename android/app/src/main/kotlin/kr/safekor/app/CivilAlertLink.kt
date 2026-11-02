package kr.safekor.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject

/** Stores only normalized type/time/hash. Raw notification text never leaves the callback. */
object CivilAlertLink {
    private const val PREFS = "civil_alert_link_v1"
    private const val NOTIFICATION_ID = 74003
    var sink: EventChannel.EventSink? = null
    var foreground = false
    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    fun enabled(c: Context) = prefs(c).getBoolean("enabled", false)
    fun setEnabled(c: Context, enabled: Boolean) {
        prefs(c).edit().putBoolean("enabled", enabled).apply()
        if (!enabled) { prefs(c).edit().remove("pending").remove("lastId").apply(); manager(c).cancel(NOTIFICATION_ID) }
    }
    private fun manager(c: Context) = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    fun access(c: Context): Boolean {
        val component = ComponentName(c, CivilAlertListener::class.java)
        if (Build.VERSION.SDK_INT >= 27) return manager(c).isNotificationListenerAccessGranted(component)
        return (Settings.Secure.getString(c.contentResolver, "enabled_notification_listeners") ?: "")
            .split(':').any { ComponentName.unflattenFromString(it) == component }
    }
    fun sourceInstalled(c: Context) = CivilAlertParser.sources.any { pkg ->
        try {
            val info = c.packageManager.getApplicationInfo(pkg, 0)
            info.flags and (android.content.pm.ApplicationInfo.FLAG_SYSTEM or android.content.pm.ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
        } catch (_: Exception) { false }
    }
    fun status(c: Context) = mapOf("enabled" to enabled(c), "accessGranted" to access(c), "sourceInstalled" to sourceInstalled(c), "canNotify" to manager(c).areNotificationsEnabled())
    fun openSettings(c: Context) {
        c.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
    fun pending(c: Context): Map<String, Any>? {
        if (!enabled(c) || !access(c)) return null
        val raw = prefs(c).getString("pending", null) ?: return null
        return try {
            val obj = JSONObject(raw)
            if (obj.getLong("expiresAtMs") <= System.currentTimeMillis()) { prefs(c).edit().remove("pending").apply(); null }
            else obj.keys().asSequence().associateWith { obj.get(it) }
        } catch (_: Exception) { null }
    }
    fun acknowledge(c: Context, id: String) {
        if (pending(c)?.get("id") == id) prefs(c).edit().remove("pending").apply()
        manager(c).cancel(NOTIFICATION_ID)
    }
    fun deliver(c: Context, id: String, kind: String, whenMs: Long, pkg: String) {
        val now = System.currentTimeMillis()
        if (prefs(c).getString("lastId", null) == id) return
        val record = mapOf<String, Any>("id" to id, "kind" to kind, "receivedAtMs" to whenMs,
            "expiresAtMs" to now + 120000L, "sourcePackage" to pkg, "source" to "system_cell_broadcast")
        prefs(c).edit().putString("lastId", id).putString("pending", JSONObject(record).toString()).apply()
        Handler(Looper.getMainLooper()).post { sink?.success(record) }
        if (foreground) return
        // No background activity launch and no duplicate siren. The original
        // system emergency alert remains in charge of its alarm and presentation.
        if (Build.VERSION.SDK_INT >= 33 && c.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) return
        val channel = "civil_alert_response_v1"
        if (Build.VERSION.SDK_INT >= 26) {
            val nc = NotificationChannel(channel, "시스템 경보의 대피 안내", NotificationManager.IMPORTANCE_HIGH)
            nc.setSound(null, null); nc.enableVibration(false); manager(c).createNotificationChannel(nc)
        }
        val intent = Intent(c, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pi = PendingIntent.getActivity(c, NOTIFICATION_ID, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, channel) else Notification.Builder(c)
        val notification = builder.setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("민방공 경보 · 대피 안내")
            .setContentText("현재 상황에 맞는 행동을 확인하세요.")
            .setContentIntent(pi).setAutoCancel(true).setOnlyAlertOnce(true).build()
        try { manager(c).notify(NOTIFICATION_ID, notification) } catch (_: SecurityException) {
            // Permission can change after the initial check; pending guidance remains available.
        }
    }
}
