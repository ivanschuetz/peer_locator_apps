package com.match.android.ble

import android.app.Application
import com.match.android.services.BleId
import com.match.android.system.log.LogTag
import com.match.android.system.log.LogTag.PERM
import com.match.android.system.log.log
import io.reactivex.Observable
import io.reactivex.disposables.CompositeDisposable
import io.reactivex.rxkotlin.plusAssign
import io.reactivex.rxkotlin.subscribeBy
import io.reactivex.subjects.PublishSubject
import io.reactivex.subjects.PublishSubject.create

interface BleManager {
    val advertiserObservable: Observable<BleId>
    val scannerObservable: Observable<BleId>
}

class BleManagerImpl(
    private val blePreconditions: BlePreconditionsNotifier,
    private val app: Application,
    private val bleServiceManager: BleServiceManager
) : BleManager, BleServiceManagerObserver {

    override val advertiserObservable: PublishSubject<BleId> = create()
    override val scannerObservable: PublishSubject<BleId> = create()

    private val disposables = CompositeDisposable()

    init {
        bleServiceManager.register(this)
        startBleWhenEnabled()
    }

    private fun startBleWhenEnabled() {
        disposables += blePreconditions.bleEnabled
            .take(1)
            .subscribeBy(onNext = {
                log.i("BlePreconditions met - starting BLE", PERM)
                bleServiceManager.startService(app)
            }, onError = {
                log.i("Error enabling bluetooth: $it", PERM)
            })
    }

    override fun onAdvertised(bleId: BleId) {
        advertiserObservable.onNext(bleId)
    }

    override fun onDiscovered(bleId: BleId) {
        scannerObservable.onNext(bleId)
    }
}
