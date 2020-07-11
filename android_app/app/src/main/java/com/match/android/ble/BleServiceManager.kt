package com.match.android.ble

import android.app.Application
import android.content.ComponentName
import android.content.Context.BIND_AUTO_CREATE
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import com.match.android.ble.BleServiceImpl.LocalBinder
import com.match.android.services.BleIdService

interface BleServiceManager {
    fun startService(app: Application): Boolean
}

class BleServiceManagerImpl(
    // Not ideal: this class shouldn't be generating ids, only manage exactly the service
    // it should only forward id from outside to service.
    // we probably should have a listener for onServiceReady(BleCoordinator) -> Unit
    // and then call bleCoordinator.start(bleId) (or similar).
    private val bleIdService: BleIdService
) : BleServiceManager {

    private var service: BleService? = null

    override fun startService(app: Application): Boolean {
        val intent = Intent(app, BleServiceImpl::class.java)
        return app.bindService(intent, serviceConnection, BIND_AUTO_CREATE)
    }

    private val serviceConnection: ServiceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            val service: BleService = (binder as LocalBinder).service
            this@BleServiceManagerImpl.service = service
            service.start(bleIdService.bleId())
        }

        override fun onServiceDisconnected(name: ComponentName?) {}
    }
}
