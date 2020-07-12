package com.match.android.ble

import android.app.Activity
import android.app.Activity.RESULT_CANCELED
import android.app.Activity.RESULT_OK
import android.bluetooth.BluetoothAdapter.ACTION_REQUEST_ENABLE
import android.content.Intent
import com.match.RequestCodes
import com.match.android.ble.extensions.bluetoothManager
import com.match.android.system.log.LogTag.PERM
import com.match.android.system.log.log
import kotlinx.coroutines.channels.BroadcastChannel
import kotlinx.coroutines.channels.sendBlocking
import kotlinx.coroutines.runBlocking

interface BleEnabler {
    val observable: BroadcastChannel<Boolean>

    fun enable(activity: Activity)
    fun notifyWillNotBeEnabled()
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?)
}

class BleEnablerImpl : BleEnabler {
    private val requestCode = RequestCodes.enableBluetooth

    override val observable: BroadcastChannel<Boolean> = BroadcastChannel(1)

    override fun enable(activity: Activity) {
        val adapter = activity.bluetoothManager?.adapter

        if (adapter != null) {
            if (adapter.isEnabled) {
                log.d("Bluetooth is enabled", PERM)
                observable.sendBlocking(true)

            } else {
                log.d("Bluetooth not enabled. Requesting...", PERM)
                val enableBluetoothIntent = Intent(ACTION_REQUEST_ENABLE)
                activity.startActivityForResult(enableBluetoothIntent, requestCode)
            }
        } else {
            // No BT adapter
            observable.sendBlocking(false)
        }
    }

    /**
     * Update state if for reasons extraneous to this class, BT will not be enabled.
     * Currently when required permissions are not granted.
     */
    override fun notifyWillNotBeEnabled() {
        runBlocking { observable.send(false) }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == requestCode) {
            when (resultCode) {
                RESULT_OK -> observable.offer(true)
                RESULT_CANCELED -> observable.sendBlocking(false)
                else -> throw Exception("Unexpected result code: $resultCode")
            }
        }
    }
}
