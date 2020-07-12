package com.match.android.notifications

import android.app.NotificationManager.IMPORTANCE_DEFAULT
import android.os.Build.VERSION.SDK_INT
import android.os.Build.VERSION_CODES.N
import android.os.Build.VERSION_CODES.O
import androidx.annotation.RequiresApi
import com.match.android.R.string.foreground_service_notification_channel_description
import com.match.android.R.string.foreground_service_notification_channel_name
import com.match.android.notifications.LocalNotificationChannelId.FOREGROUND_SERVICE
import com.match.android.system.Resources

/**
 * Initializes the app's notification channels and provides their ids.
 */
class AppNotificationChannels(
    private val channelsCreator: NotificationChannelsCreator,
    private val resources: Resources
) {
    init {
        if (SDK_INT >= O) {
            channelConfigs().forEach {
                channelsCreator.createNotificationChannel(it)
            }
        }
    }

    @RequiresApi(N)
    private fun channelConfigs(): List<NotificationChannelConfig> = listOf(
        NotificationChannelConfig(
            FOREGROUND_SERVICE.toString(),
            resources.getString(foreground_service_notification_channel_name),
            resources.getString(foreground_service_notification_channel_description),
            IMPORTANCE_DEFAULT
        )
    )
}

enum class LocalNotificationChannelId {
    FOREGROUND_SERVICE
}
