package com.match.android.ble

import io.reactivex.Observable
import io.reactivex.subjects.BehaviorSubject
import io.reactivex.subjects.BehaviorSubject.create

interface BlePreconditionsNotifier {
    val bleEnabled: Observable<Unit>

    fun notifyBleEnabled()
}

class BlePreconditionsNotifierImpl: BlePreconditionsNotifier {

    override val bleEnabled: BehaviorSubject<Unit> = create()

    override fun notifyBleEnabled() {
        bleEnabled.onNext(Unit)
    }
}
