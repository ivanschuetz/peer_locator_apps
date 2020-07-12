package com.match.android.ble

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.Build.VERSION.SDK_INT
import android.os.Build.VERSION_CODES.O
import android.os.IBinder

interface BleService {
    fun setCoordinator(coordinator: BleCoordinator)
}

class BleServiceImpl: Service(), BleService {
    private val binder: IBinder = LocalBinder()

    private var bleCoordinator: BleCoordinator? = null

    inner class LocalBinder : Binder() {
        val service: BleServiceImpl = this@BleServiceImpl
    }

    override fun onBind(intent: Intent) = binder

    fun startForegroundNotificationIfNeeded(id: Int, notification: Notification) {
        if (SDK_INT >= O) {
            startForeground(id, notification)
        }
    }

    override fun setCoordinator(coordinator: BleCoordinator) {
        this.bleCoordinator = coordinator
    }
}
