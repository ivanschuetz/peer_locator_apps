package com.match.android.ui.home

import androidx.compose.Immutable
import androidx.lifecycle.LiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.asLiveData
import com.match.android.ble.BleManager
import com.match.android.services.BleId
import com.match.android.system.Resources
import com.match.android.ui.navigation.MainNav
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.asFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.scan

@Immutable
data class HomeViewState(val myId: String, val discovered: List<String>)

class HomeViewModel(
    nav: MainNav,
    resources: Resources,
    bleManager: BleManager
) : ViewModel() {
    @FlowPreview
    private val discoveredBleIds: Flow<List<BleId>> =
        bleManager.scannerObservable.asFlow().scan(emptyList(), { acc, el ->
            acc + el
        })

    @FlowPreview
    val state: LiveData<HomeViewState> =
        bleManager.advertiserObservable.asFlow().combine(discoveredBleIds) { myId, discovered ->
            HomeViewState(myId.toString(), discovered.map { it.toString()} )
        }.asLiveData()
}
