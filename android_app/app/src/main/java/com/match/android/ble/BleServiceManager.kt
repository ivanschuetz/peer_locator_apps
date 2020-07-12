package com.match.android.ble

import android.app.Application
import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.content.Context.BIND_AUTO_CREATE
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import com.match.android.R.mipmap.ic_launcher_foreground
import com.match.android.R.string.foreground_service_notification_text
import com.match.android.R.string.foreground_service_notification_title
import com.match.android.ble.BleServiceImpl.LocalBinder
import com.match.android.notifications.LocalNotificationChannelId.FOREGROUND_SERVICE
import com.match.android.notifications.NotificationConfig
import com.match.android.notifications.NotificationPriority.HIGH
import com.match.android.notifications.NotificationShower
import com.match.android.notifications.StaticNotificationIds
import com.match.android.services.BleId
import com.match.android.services.BleIdService
import com.match.android.system.Resources

interface BleServiceManager {
    fun startService(app: Application): Boolean

    fun register(observer: BleServiceManagerObserver)
}

interface BleServiceManagerObserver {
    fun onAdvertised(bleId: BleId)
    fun onDiscovered(bleId: BleId)
}

class BleServiceManagerImpl(
    // Not ideal: this class shouldn't be generating ids, only manage exactly the service
    // it should only forward id from outside to service.
    // we probably should have a listener for onServiceReady(BleCoordinator) -> Unit
    // and then call bleCoordinator.start(bleId) (or similar).
    private val bleIdService: BleIdService,
    private val resources: Resources,
    private val notificationsShower: NotificationShower
) : BleServiceManager, BleCentralObserver, BleAdvertiserObserver {

    private var coordinator: BleCoordinator? = null

    private var observer: BleServiceManagerObserver? = null

    override fun startService(app: Application): Boolean {
        val intent = Intent(app, BleServiceImpl::class.java)
        return app.bindService(intent, serviceConnection, BIND_AUTO_CREATE)
    }

    private val serviceConnection: ServiceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            val service: BleServiceImpl = (binder as LocalBinder).service
            service.setCoordinator(initAndStartCoordinator(service))
            service.startForegroundNotificationIfNeeded(StaticNotificationIds.FG_SERVICE,
                foregroundNotification())
        }

        override fun onServiceDisconnected(name: ComponentName?) {}
    }

    private fun foregroundNotification(): Notification =
        notificationsShower.crateNotification(NotificationConfig(
            ic_launcher_foreground,
            resources.getString(foreground_service_notification_title),
            resources.getString(foreground_service_notification_text),
            HIGH,
            FOREGROUND_SERVICE,
            null
        ))

    private fun initAndStartCoordinator(context: Context): BleCoordinator {
        val coordinator = createCoordinator(context)
        this@BleServiceManagerImpl.coordinator = coordinator
        coordinator.start(bleIdService.bleId())
        return coordinator
    }

    private fun createCoordinator(context: Context): BleCoordinator = BleCoordinatorImpl(
        BleCentralImpl(context).apply {
            register(this@BleServiceManagerImpl)
        }, BleAdvertiserImpl().apply {
            register(this@BleServiceManagerImpl)
        }
    )

    override fun register(observer: BleServiceManagerObserver) {
        this.observer = observer
    }

    override fun onAdvertised(bleId: BleId) {
        observer?.onAdvertised(bleId)
    }

    override fun onDiscovered(bleId: BleId) {
        observer?.onDiscovered(bleId)
    }
}
