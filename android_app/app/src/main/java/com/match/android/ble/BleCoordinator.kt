package com.match.android.ble

import android.bluetooth.BluetoothAdapter
import android.content.Context
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

interface BleManagerFactory {
    fun create(context: Context): BleCoordinator?
}

class BleManagerFactoryImpl: BleManagerFactory {
    override fun create(context: Context): BleCoordinator? {
        val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        if (!bluetoothAdapter.supportsAdvertising()) return null

        val systemScanner = bluetoothAdapter.bluetoothLeScanner ?: return null
        val systemAdvertiser = bluetoothAdapter.bluetoothLeAdvertiser
            ?: return null

        val central = BleCentralImpl(context, systemScanner)
        val advertiser = BleAdvertiserImpl(systemAdvertiser)

        return BleCoordinatorImpl(central, advertiser)
    }
}

private fun BluetoothAdapter.supportsAdvertising() =
    isMultipleAdvertisementSupported && bluetoothLeAdvertiser != null
