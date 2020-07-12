package com.match.android.ui.home

import androidx.compose.Immutable
import androidx.lifecycle.LiveData
import androidx.lifecycle.ViewModel
import com.match.android.ble.BleManager
import com.match.android.extensions.rx.toLiveData
import com.match.android.services.BleId
import com.match.android.system.Resources
import com.match.android.ui.navigation.MainNav
import io.reactivex.Observable
import io.reactivex.rxkotlin.Observables

@Immutable
data class HomeViewState(val myId: String, val discovered: List<String>)

class HomeViewModel(
    nav: MainNav,
    resources: Resources,
    bleManager: BleManager
) : ViewModel() {
    private val discoveredBleIds: Observable<List<BleId>> =
        bleManager.scannerObservable.scan(emptyList(), { acc, el ->
            acc + el
        })

    val state: LiveData<HomeViewState> =
        Observables.combineLatest(bleManager.advertiserObservable, discoveredBleIds)
            .map { (myId, discovered) ->
                HomeViewState(myId.toString(), discovered.map { it.toString()} )
            }
            .toLiveData()
}
