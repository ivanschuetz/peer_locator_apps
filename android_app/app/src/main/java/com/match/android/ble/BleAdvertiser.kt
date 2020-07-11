package com.match.android.ble

import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY
import android.bluetooth.le.AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM
import android.bluetooth.le.BluetoothLeAdvertiser
import android.os.ParcelUuid
import com.match.android.ble.BleUuids.SERVICE_UUID
import com.match.android.services.BleId

interface BleAdvertiser  {
    fun start(bleId: BleId)
    fun stop()
}

class BleAdvertiserImpl(
    private val advertiser: BluetoothLeAdvertiser
) : BleAdvertiser {
    override fun start(bleId: BleId) {
        advertiser.startAdvertising(advertisingSettings(), advertisingData(bleId),
            advertisingCallback)
    }

    override fun stop() {
        advertiser.stopAdvertising(advertisingCallback)
    }

    private fun advertisingData(bleId: BleId): AdvertiseData = AdvertiseData.Builder()
        .setIncludeDeviceName(false)
        .addServiceUuid(ParcelUuid(SERVICE_UUID))
        .addServiceData(ParcelUuid(SERVICE_UUID), bleId.data)
        .build()

    private fun advertisingSettings(): AdvertiseSettings = AdvertiseSettings.Builder()
        .setAdvertiseMode(ADVERTISE_MODE_LOW_LATENCY)
        .setTxPowerLevel(ADVERTISE_TX_POWER_MEDIUM)
        .setConnectable(true)
        .setTimeout(0)
        .build()


    private val advertisingCallback: AdvertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            super.onStartSuccess(settingsInEffect)
        }

        override fun onStartFailure(errorCode: Int) {
            super.onStartFailure(errorCode)
        }
    }
}
