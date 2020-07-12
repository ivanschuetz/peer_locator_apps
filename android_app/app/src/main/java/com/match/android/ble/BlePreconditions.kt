package com.match.android.ble

import android.app.Activity
import android.content.Intent
import com.match.android.ble.GrantedPermissions.ALL
import com.match.android.ble.GrantedPermissions.NONE
import com.match.android.ble.GrantedPermissions.ONLY_FOREGROUND
import com.match.android.system.log.LogTag.PERM
import com.match.android.system.log.log
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.channels.consumeEach
import kotlinx.coroutines.launch

class BlePreconditions(
    private val startPermissionsChecker: BlePermissionsManager,
    private val blePreconditionsNotifier: BlePreconditionsNotifier,
    private val bleEnabler: BleEnabler
) {

    fun onActivityCreated(activity: Activity) {
        GlobalScope.launch {
            observeBleEnabled()
        }
        GlobalScope.launch {
            showEnableBleAfterPermissions(activity)
        }
        // Temporarily here. It should be on demand.
        startPermissionsChecker.requestPermissionsIfNeeded(activity)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        bleEnabler.onActivityResult(requestCode, resultCode, data)
    }

    fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>,
                                           grantResults: IntArray, activity: Activity) {
        startPermissionsChecker.onRequestPermissionsResult(requestCode, permissions, grantResults,
            activity)
    }

    private suspend fun showEnableBleAfterPermissions(activity: Activity) {
        startPermissionsChecker.observable.consumeEach { permissions: GrantedPermissions ->
            log.i("Handling permissions result: $permissions", PERM)
            when (permissions) {
                ALL, ONLY_FOREGROUND -> bleEnabler.enable(activity)
                NONE -> bleEnabler.notifyWillNotBeEnabled()
            }
        }
    }

    private suspend fun observeBleEnabled() {
        bleEnabler.observable.consumeEach { bleEnabled ->
            if (bleEnabled) {
                blePreconditionsNotifier.notifyBleEnabled()
            } else {
                log.i("User didn't enable BLE", PERM)
                // TODO UX
            }
        }
    }
}
