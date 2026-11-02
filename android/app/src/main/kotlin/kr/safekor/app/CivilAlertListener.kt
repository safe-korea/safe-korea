package kr.safekor.app

import android.app.Notification
import android.content.pm.ApplicationInfo
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.security.MessageDigest

class CivilAlertListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!CivilAlertLink.enabled(this)) return
        if (sbn.packageName !in CivilAlertParser.sources) return
        // Inspect publisher identity BEFORE accessing notification extras.
        val info = try { packageManager.getApplicationInfo(sbn.packageName, 0) } catch (_: Exception) { return }
        val systemApp = info.flags and (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
        if (!CivilAlertParser.trustedSource(sbn.packageName, systemApp, info.uid == sbn.uid)) return
        val n = sbn.notification
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        if (!CivilAlertParser.fresh(n.`when`, sbn.postTime, System.currentTimeMillis())) return
        val extras = n.extras ?: return
        val text = try {
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
            val body = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString() ?: ""
            "$title\n$body"
        } catch (_: Exception) { return }
        val kind = CivilAlertParser.classify(text) ?: return
        val seed = "${sbn.packageName}|${sbn.key}|${n.`when`}|$text"
        val id = MessageDigest.getInstance("SHA-256").digest(seed.toByteArray()).joinToString("") { "%02x".format(it) }
        CivilAlertLink.deliver(this, id, kind, n.`when`, sbn.packageName)
    }
}
