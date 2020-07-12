package com.match.android.ble

import android.app.Application
import com.match.android.services.BleId
import com.match.android.system.log.LogTag.PERM
import com.match.android.system.log.log
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.channels.BroadcastChannel
import kotlinx.coroutines.channels.sendBlocking
import kotlinx.coroutines.flow.asFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.take
import kotlinx.coroutines.launch

interface BleManager {
    val advertiserObservable: BroadcastChannel<BleId>
    val scannerObservable: BroadcastChannel<BleId>
}

class BleManagerImpl(
    private val blePreconditions: BlePreconditionsNotifier,
    private val app: Application,
    private val bleServiceManager: BleServiceManager
) : BleManager, BleServiceManagerObserver {

    override val advertiserObservable: BroadcastChannel<BleId> = BroadcastChannel(1)
    override val scannerObservable: BroadcastChannel<BleId> = BroadcastChannel(1)

    init {
        bleServiceManager.register(this)
        GlobalScope.launch {
            startBleWhenEnabled()
        }
    }

    private suspend fun startBleWhenEnabled() {
        blePreconditions.bleEnabled.asFlow()
            .take(1)
            .collect {
                log.i("BlePreconditions met - starting BLE", PERM)
                bleServiceManager.startService(app)
            }
    }

    override fun onAdvertised(bleId: BleId) {
        advertiserObservable.sendBlocking(bleId)
    }

    override fun onDiscovered(bleId: BleId) {
        scannerObservable.sendBlocking(bleId)
    }
}
