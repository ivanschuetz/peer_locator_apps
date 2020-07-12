package com.match.android.ble

import kotlinx.coroutines.channels.BroadcastChannel
import kotlinx.coroutines.channels.sendBlocking

interface BlePreconditionsNotifier {
    val bleEnabled: BroadcastChannel<Unit>

    fun notifyBleEnabled()
}

class BlePreconditionsNotifierImpl: BlePreconditionsNotifier {

    override val bleEnabled: BroadcastChannel<Unit> = BroadcastChannel(1)

    override fun notifyBleEnabled() {
        bleEnabled.sendBlocking(Unit)
    }
}
