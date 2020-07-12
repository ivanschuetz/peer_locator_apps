package com.match.android.ble

import com.match.android.services.BleId
import io.reactivex.Observable

interface BleCoordinator {
    val myId: Observable<BleId>

    fun start(bleId: BleId)
    fun stop()
}

class BleCoordinatorImpl(
    private val central: BleCentral,
    private val advertiser: BleAdvertiser
) : BleCoordinator {
    override val myId: Observable<BleId> = advertiser.myId

    override fun start(bleId: BleId) {
        central.start()
        advertiser.start(bleId)
    }

    override fun stop() {
        central.stop()
        advertiser.stop()
    }
}
