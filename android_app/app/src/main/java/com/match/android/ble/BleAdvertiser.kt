package com.match.android.ble

import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY
import android.bluetooth.le.AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM
import android.bluetooth.le.BluetoothLeAdvertiser
import android.os.ParcelUuid
import com.match.android.ble.BleUuids.SERVICE_UUID
import com.match.android.services.BleId
import com.match.android.system.log.LogTag.BLE
import com.match.android.system.log.log
import io.reactivex.Observable
import io.reactivex.subjects.PublishSubject
import io.reactivex.subjects.PublishSubject.create
import java.nio.ByteBuffer
import java.util.UUID

interface BleAdvertiser  {
    val myId: Observable<BleId>
    fun start(bleId: BleId): Boolean
    fun stop()

    fun register(observer: BleAdvertiserObserver)
}

interface BleAdvertiserObserver {
    fun onAdvertised(bleId: BleId)
}

class BleAdvertiserImpl : BleAdvertiser {
    override val myId: PublishSubject<BleId> = create()

    private var advertiser: BluetoothLeAdvertiser? = null

    private var observer: BleAdvertiserObserver? = null

    override fun start(bleId: BleId): Boolean {
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return false
        if (!adapter.supportsAdvertising()) return false
        if (!initAdvertiserIfNeeded(adapter)) return false

        advertiser?.startAdvertising(advertisingSettings(), advertisingData(bleId),
            advertisingCallback)

        observer?.onAdvertised(bleId)

        return true
    }

    private fun initAdvertiserIfNeeded(adapter: BluetoothAdapter): Boolean {
        if (advertiser == null) {
            advertiser = adapter.bluetoothLeAdvertiser.also {
                if (it == null) {
                    log.e("Couldn't initialize advertiser")
                    return false
                }
            }
            return true
        } else {
            return true
        }
    }

    override fun stop() {
        advertiser?.stopAdvertising(advertisingCallback)
    }

    private fun advertisingData(bleId: BleId): AdvertiseData = AdvertiseData.Builder()
        .setIncludeDeviceName(false)
        .addServiceUuid(ParcelUuid(SERVICE_UUID))
        // TODO max length?
        .addServiceData(ParcelUuid(SERVICE_UUID), bleId.data.sliceArray(0..16))
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
            log.i("Start advertising success: $settingsInEffect", BLE)
        }

        override fun onStartFailure(errorCode: Int) {
            super.onStartFailure(errorCode)
            log.i("Start advertising failure: $errorCode", BLE)
        }
    }

    override fun register(observer: BleAdvertiserObserver) {
        this.observer = observer
    }
}

private fun BluetoothAdapter.supportsAdvertising() =
    isMultipleAdvertisementSupported && bluetoothLeAdvertiser != null
