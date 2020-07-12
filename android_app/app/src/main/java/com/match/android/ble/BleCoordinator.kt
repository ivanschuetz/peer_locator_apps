package com.match.android.ble

import com.match.android.services.BleId

interface BleCoordinator {
    fun start(bleId: BleId)
    fun stop()
}

class BleCoordinatorImpl(
    private val central: BleCentral,
    private val advertiser: BleAdvertiser
) : BleCoordinator {
    override fun start(bleId: BleId) {
        central.start()
        advertiser.start(bleId)
    }

    override fun stop() {
        central.stop()
        advertiser.stop()
    }
}
