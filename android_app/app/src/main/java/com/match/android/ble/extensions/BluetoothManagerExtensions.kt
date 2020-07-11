package com.match.android.ble.extensions

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothManager
import android.content.Context

fun BluetoothManager.openGattServerForWrites(context: Context, onValue: (ByteArray) -> Unit)
        : BluetoothGattServer = openGattServer(context, object : BluetoothGattServerCallback() {
            override fun onCharacteristicWriteRequest(device: BluetoothDevice?,
                                                      requestId: Int,
                                                      characteristic: BluetoothGattCharacteristic?,
                                                      preparedWrite: Boolean,
                                                      responseNeeded: Boolean,
                                                      offset: Int,
                                                      value: ByteArray?) {
                super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite,
                    responseNeeded, offset, value)
                if (value != null) {
                    onValue(value)
                } else {
                    print("Written characteristic was null: $characteristic, device: $device")
                }
            }
        })
