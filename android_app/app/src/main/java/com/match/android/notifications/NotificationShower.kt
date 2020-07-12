package com.match.android.notifications

import android.app.Notification
import android.app.PendingIntent
import android.app.PendingIntent.FLAG_UPDATE_CURRENT
import android.content.Context
import android.content.Intent
import android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP
import androidx.core.app.NotificationCompat.Builder
import androidx.core.app.NotificationCompat.PRIORITY_DEFAULT
import androidx.core.app.NotificationCompat.PRIORITY_HIGH
import androidx.core.app.NotificationCompat.PRIORITY_LOW
import androidx.core.app.NotificationCompat.PRIORITY_MAX
import androidx.core.app.NotificationCompat.PRIORITY_MIN
import androidx.core.app.NotificationManagerCompat
import com.match.android.MainActivity
import com.match.android.notifications.NotificationPriority.DEFAULT
import com.match.android.notifications.NotificationPriority.HIGH
import com.match.android.notifications.NotificationPriority.LOW
import com.match.android.notifications.NotificationPriority.MAX
import com.match.android.notifications.NotificationPriority.MIN

interface NotificationShower {
    fun showNotification(id: Int, config: NotificationConfig)
    // To be used only if context requires directly notification, e.g. for Service.startForeground
    // Otherwise, use showNotification()
    fun crateNotification(config: NotificationConfig): Notification
}

class NotificationsShowerImpl (private val context: Context): NotificationShower {

    override fun showNotification(id: Int, config: NotificationConfig) {
        with(NotificationManagerCompat.from(context)) {
            notify(id, crateNotification(config))
        }
    }

    override fun crateNotification(config: NotificationConfig): Notification =
        notificationBuilder(config).build()

    private fun pendingIntent(args: NotificationIntentArgs?): PendingIntent =
        PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java).apply {
                flags = FLAG_ACTIVITY_SINGLE_TOP
                if (args != null) {
                    putExtra(args.key.toString(), args.value)
                }
            }, FLAG_UPDATE_CURRENT
        )

    private fun notificationBuilder(config: NotificationConfig): Builder =
        Builder(context, config.channelId.toString())
            .setSmallIcon(config.smallIcon)
            .setContentTitle(config.title)
            .setContentText(config.text)
            .setPriority(config.priority.toInt())
            .setContentIntent(pendingIntent(config.intentArgs))
            .setChannelId(config.channelId.toString())
            .setAutoCancel(true)
}

private fun NotificationPriority.toInt() = when (this) {
    DEFAULT -> PRIORITY_DEFAULT
    LOW -> PRIORITY_LOW
    MIN -> PRIORITY_MIN
    HIGH -> PRIORITY_HIGH
    MAX -> PRIORITY_MAX
}
