package com.match.android

import com.match.android.ble.BleManager

class NotReferencedDependenciesActivator(
    bleManager: BleManager
) {
    init {
        listOf(bleManager).forEach { it.toString() }
    }

    fun activate() {}
}
