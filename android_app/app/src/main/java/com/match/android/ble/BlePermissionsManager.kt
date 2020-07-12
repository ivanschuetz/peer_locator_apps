package com.match.android.ble

import android.Manifest.permission.ACCESS_BACKGROUND_LOCATION
import android.Manifest.permission.ACCESS_COARSE_LOCATION
import android.Manifest.permission.BLUETOOTH
import android.app.Activity
import android.app.AlertDialog
import android.content.pm.PackageManager.PERMISSION_DENIED
import android.content.pm.PackageManager.PERMISSION_GRANTED
import android.os.Build.VERSION.SDK_INT
import android.os.Build.VERSION_CODES.Q
import androidx.annotation.StringRes
import androidx.core.app.ActivityCompat.checkSelfPermission
import androidx.core.app.ActivityCompat.requestPermissions
import androidx.core.app.ActivityCompat.shouldShowRequestPermissionRationale
import com.match.RequestCodes
import com.match.android.R.string.bluetooth_info_message
import com.match.android.R.string.bluetooth_info_title
import com.match.android.R.string.bluetooth_permission_info_message
import com.match.android.R.string.bluetooth_permission_info_title
import com.match.android.R.string.dont_allow
import com.match.android.R.string.ok
import com.match.android.ble.BlePermissionsManagerImpl.RationaleType.BASIC
import com.match.android.ble.BlePermissionsManagerImpl.RationaleType.BG
import com.match.android.ble.GrantedPermissions.ALL
import com.match.android.ble.GrantedPermissions.NONE
import com.match.android.ble.GrantedPermissions.ONLY_FOREGROUND
import com.match.android.system.log.LogTag.PERM
import com.match.android.system.log.log
import kotlinx.coroutines.channels.BroadcastChannel
import kotlinx.coroutines.channels.sendBlocking
import kotlinx.coroutines.runBlocking

// Final permission state, after possible rationale dialogs.
enum class GrantedPermissions { ALL, ONLY_FOREGROUND, NONE }

interface BlePermissionsManager {
    val observable: BroadcastChannel<GrantedPermissions>

    fun requestPermissionsIfNeeded(activity: Activity)

    fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>,
                                           grantResults: IntArray, activity: Activity)
}

class BlePermissionsManagerImpl : BlePermissionsManager {
    override val observable: BroadcastChannel<GrantedPermissions> = BroadcastChannel(1)

    private val requestCode = RequestCodes.onboardingPermissions

    private val basicPermissions: Array<String> = arrayOf(BLUETOOTH, ACCESS_COARSE_LOCATION)
    private val bgPermissions: Array<String> =
        if (SDK_INT >= Q) arrayOf(ACCESS_BACKGROUND_LOCATION) else emptyArray()

    private val permissions: Array<String> = basicPermissions + bgPermissions

    override fun requestPermissionsIfNeeded(activity: Activity) {
        if (hasAllPermissions(activity)) {
            // User already granted permissions
            log.d("User already granted all start permissions", PERM)
            observable.sendBlocking(ALL)
        } else {
            val rationaleType = rationaleType(activity)
            if (rationaleType != null) {
                // User denied without choosing "never ask again". This will always be true after
                // the first request, since it doesn't have "never ask again".
                showRationale(activity, rationaleType.dialogContents(activity))
            } else {
                // User has not been asked yet or denied checking "never ask again": let the system handle it
                // it will show a dialog or call directly onRequestPermissionsResult with the result.
                requestPermissions(activity, permissions, requestCode)
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>,
        grantResults: IntArray, activity: Activity
    ) {
        if (requestCode != this.requestCode) return
        when {
            grantResults.all { it == PERMISSION_GRANTED } -> observable.sendBlocking(ALL).also {
                log.i("Onboarding permissions granted", PERM)
            }
            grantResults.any { it == PERMISSION_DENIED } -> handlePermissionsDenied(activity)
            else -> log.e("Illegal state: permission result is not granted or denied.", PERM)
        }
    }

    private fun handlePermissionsDenied(activity: Activity) {
        val rationaleType = rationaleType(activity)
        if (rationaleType != null) {
            showRationale(activity, rationaleType.dialogContents(activity))
        } else {
            log.i("User denied permissions and selected don't ask again", PERM)
            updateStateOnPermissionsConfirmedlyDenied(activity)
        }
    }

    /**
     * Updates the final permission state, after the user either denies with "don't ask again"
     * or denies any of the rationale dialogs.
     */
    private fun updateStateOnPermissionsConfirmedlyDenied(activity: Activity) {
        val hasBasicPermissions = hasBasicPermissions(activity)
        val hasBgPermissions = hasBgPermissions(activity)
        // Blocking: permission events can be executed normally. Coroutines expect us to
        // use BroadcastChannel.send
        runBlocking {
            when {
                hasBasicPermissions && !hasBgPermissions -> observable.send(ONLY_FOREGROUND)
                !hasBasicPermissions && !hasBgPermissions -> observable.send(NONE)
                else -> error(
                    "To be in this funtion, a permission must have been denied and " +
                            "user can't allow only background permissions."
                )
            }
        }
    }

    // returns null if no rationale
    private fun rationaleType(activity: Activity): RationaleType? =
        when {
            // User selected "deny"
            basicPermissions.any {
                shouldShowRequestPermissionRationale(
                    activity,
                    it
                )
            } -> BASIC.also {
                log.d(
                    "Permissions were denied but we can ask again. Showing rationale.",
                    PERM
                )
            }

            // User selected "only while app is in foreground" (Android Q+)
            bgPermissions.any { shouldShowRequestPermissionRationale(activity, it) } -> BG.also {
                log.d(
                    "Running in background was denied but we can ask again. " +
                            "Showing rationale.", PERM
                )
            }

            // No rationale:
            // Denied with "don't ask again" OR
            // asking before permissions have been requested the first time OR
            // device policy doesn't allow permissions
            else -> null
        }

    private fun hasAllPermissions(activity: Activity): Boolean = permissions.all {
        checkSelfPermission(activity, it) == PERMISSION_GRANTED
    }

    private fun hasBasicPermissions(activity: Activity): Boolean = basicPermissions.all {
        checkSelfPermission(activity, it) == PERMISSION_GRANTED
    }

    private fun hasBgPermissions(activity: Activity): Boolean = bgPermissions.all {
        checkSelfPermission(activity, it) == PERMISSION_GRANTED
    }

    private fun showRationale(activity: Activity, contents: RationaleDialogContents) {
        AlertDialog.Builder(activity)
            .setTitle(contents.title)
            .setMessage(contents.message)
            .setPositiveButton(ok) { dialog, _ ->
                // After explaining, request again if they accept
                dialog.dismiss()
                requestPermissions(activity, permissions, requestCode)
            }
            .setNegativeButton(dont_allow) { dialog, _ ->
                // If the user doesn't accept the rationale, nothing happens.
                // The process starts again the next time they start the app.
                dialog.dismiss()
                contents.onDeny?.invoke()
            }
            .show()
    }

    private fun RationaleType.dialogContents(activity: Activity): RationaleDialogContents = when (this) {
        BASIC -> RationaleDialogContents(
            bluetooth_info_title,
            bluetooth_info_message,
            null
        )
        BG -> RationaleDialogContents(
            bluetooth_permission_info_title,
            bluetooth_permission_info_message,
            onDeny = {
                updateStateOnPermissionsConfirmedlyDenied(activity)
            })
    }

    private enum class RationaleType { BASIC, BG }

    private data class RationaleDialogContents(
        @StringRes val title: Int,
        @StringRes val message: Int,
        val onDeny: (() -> Unit)?
    )
}
