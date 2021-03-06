package com.match.android.ble.extensions

import android.bluetooth.BluetoothManager
import android.content.Context
import com.match.android.system.log.log

val Context.bluetoothManager get(): BluetoothManager? =
    getSystemService(Context.BLUETOOTH_SERVICE).also {
        if (it == null) {
            log.e("Couldn't get bluetooth service")
        }
    }.let { service ->
        (service as? BluetoothManager).also { manager ->
            if (manager == null) {
                log.e("Service: $service hasn't expected class.")
            }
        }
    }
