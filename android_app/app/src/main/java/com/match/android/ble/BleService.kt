package com.match.android.ble

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.IBinder
import com.match.android.services.BleId

interface BleService {
    fun start(bleId: BleId)
    fun stop()
}

class BleServiceImpl: Service(), BleService {
    private val binder: IBinder = LocalBinder()

    private var bleManager: BleCoordinator? = null

    override fun onBind(intent: Intent) = binder

    fun startForegroundNotificationIfNeeded(id: Int, notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForeground(id, notification)
        }
    }

    override fun start(bleId: BleId) {
        this.bleManager = BleManagerFactoryImpl().create(this)?.apply {
            start(bleId)
        }
    }

    override fun stop() {
        bleManager?.stop()
    }

    inner class LocalBinder : Binder() {
        val service: BleService = this@BleServiceImpl
    }
}
