package com.match.android.ble

import android.app.Application
import com.match.android.system.log.log
import io.reactivex.disposables.CompositeDisposable
import io.reactivex.rxkotlin.plusAssign
import io.reactivex.rxkotlin.subscribeBy

interface BleManager

class BleManagerImpl(
    private val blePreconditions: BlePreconditionsNotifier,
    private val app: Application,
    private val bleServiceManager: BleServiceManager
) : BleManager {

    private val disposables = CompositeDisposable()

    init {
        startBleWhenEnabled()
    }

    private fun startBleWhenEnabled() {
        disposables += blePreconditions.bleEnabled
            .take(1)
            .subscribeBy(onNext = {
                log.i("BlePreconditions met - starting BLE")
                bleServiceManager.startService(app)
            }, onError = {
                log.i("Error enabling bluetooth: $it")
            })
    }
}
