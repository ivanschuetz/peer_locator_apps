package com.match.android.ble

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattCharacteristic.PERMISSION_READ
import android.bluetooth.BluetoothGattCharacteristic.PROPERTY_READ
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothGattService.SERVICE_TYPE_PRIMARY
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanRecord
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.bluetooth.le.ScanSettings.CALLBACK_TYPE_ALL_MATCHES
import android.bluetooth.le.ScanSettings.MATCH_MODE_AGGRESSIVE
import android.bluetooth.le.ScanSettings.MATCH_NUM_MAX_ADVERTISEMENT
import android.bluetooth.le.ScanSettings.SCAN_MODE_LOW_LATENCY
import android.content.Context
import android.content.Context.BLUETOOTH_SERVICE
import android.os.ParcelUuid
import com.match.android.ble.BleUuids.CHARACTERISTIC_UUID
import com.match.android.ble.BleUuids.SERVICE_UUID
import com.match.android.ble.extensions.openGattServerForWrites
import com.match.android.services.BleId
import com.match.android.system.log.log

interface BleCentral {
    fun start(): Boolean
    fun stop()

    fun register(observer: BleCentralObserver)
}

interface BleCentralObserver {
    fun onDiscovered(bleId: BleId)
}

class BleCentralImpl(private val context: Context) : BleCentral {
    private var bluetoothGattServer: BluetoothGattServer? = null
    private var scanner: BluetoothLeScanner? = null

    private var observer: BleCentralObserver? = null

    /**
     * @return true if start success
     */
    override fun start(): Boolean {
        if (!initScannerIfNeeded()) return false

        bluetoothGattServer = createGattServer(
            (context.getSystemService(BLUETOOTH_SERVICE) as BluetoothManager),
            createService()
        )
        startScan()
        return true
    }

    private fun initScannerIfNeeded(): Boolean {
        if (scanner == null) {
            scanner = BluetoothAdapter.getDefaultAdapter()?.bluetoothLeScanner.also {
                if (it == null) {
                    log.e("Couldn't initialize scanner")
                    return false
                }
            }
            return true
        } else {
            return true
        }
    }

    override fun stop() {
        scanner?.stopScan(scanCallback)
    }

    override fun register(observer: BleCentralObserver) {
        this.observer = observer
    }

    private fun startScan() {
        scanner?.startScan(
            listOf(
                ScanFilter.Builder().setServiceUuid(ParcelUuid(SERVICE_UUID)).build()
            ), scanSettings(), scanCallback
        )
    }

    private fun scanSettings(): ScanSettings = ScanSettings.Builder().apply {
        setScanMode(SCAN_MODE_LOW_LATENCY)
        setCallbackType(CALLBACK_TYPE_ALL_MATCHES)
        setMatchMode(MATCH_MODE_AGGRESSIVE)
        setNumOfMatches(MATCH_NUM_MAX_ADVERTISEMENT)
    }.build()

    private fun createGattServer(bluetoothManager: BluetoothManager, service: BluetoothGattService)
            : BluetoothGattServer =
        bluetoothManager.openGattServerForWrites(context, onValue = {
            // iOS wrote an identifier
            observer?.onDiscovered(BleId(it))
        }).apply {
            clearServices()
            addService(service)
        }

    private fun createService(): BluetoothGattService =
        BluetoothGattService(SERVICE_UUID, SERVICE_TYPE_PRIMARY).apply {
            addCharacteristic(
                BluetoothGattCharacteristic(
                    CHARACTERISTIC_UUID, PROPERTY_READ,
                    PERMISSION_READ
                )
            )
        }

    private var scanCallback = object : ScanCallback() {
        override fun onScanFailed(errorCode: Int) {
            super.onScanFailed(errorCode)
            log.e("onScanFailed, errorCode: $errorCode")
            if (errorCode == SCAN_FAILED_APPLICATION_REGISTRATION_FAILED) {
                startScan()
            }
        }

        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            super.onScanResult(callbackType, result)
            val bleId = result?.scanRecord?.extractBleId()
            if (bleId != null) {
                // We detected an Android identifier
                observer?.onDiscovered(bleId)
            }
        }
    }

    private fun ScanRecord.extractBleId(): BleId? {
        val serviceData: ByteArray = serviceData[ParcelUuid(SERVICE_UUID)] ?: return null
        val bleIdByteCount = 32
        if (serviceData.size < bleIdByteCount) return null
        return BleId(serviceData.sliceArray(0 until bleIdByteCount))
    }
}
