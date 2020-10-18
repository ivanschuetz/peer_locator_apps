package com.match.android.ui.home

import android.graphics.PointF
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
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.scan

data class HomeViewState(val myId: String, val discovered: List<String>)

@FlowPreview
class HomeViewModel(
    nav: MainNav,
    resources: Resources,
    bleManager: BleManager
) : ViewModel() {

    val distanceText: LiveData<String> = bleManager.scannerObservable.asFlow()
        .map { "${it.distance}m" }
        .asLiveData()

    private val discoveredBleIds: Flow<List<BleId>> =
        bleManager.scannerObservable.asFlow().scan(emptyList(), { acc, el ->
            acc + el.id
        })

    val state: LiveData<HomeViewState> =
        bleManager.advertiserObservable.asFlow().combine(discoveredBleIds) { myId, discovered ->
            HomeViewState(myId.toString(), discovered.map { it.toString() })
        }.asLiveData()

    val radarViewItems: LiveData<List<RadarForViewItem>> =
        bleManager.scannerObservable.asFlow().scan(HashMap<BleId, RadarItem>(), { acc, bleId ->
            val dict: HashMap<BleId, RadarItem> = acc
//            dict[bleId.id] = RadarItem(bleId.id, PointF(bleId.distance, bleId.distance))
            dict
        }).map {
            it.values.toList().map { it.toRadarForViewItem() }
        }.asLiveData()
}

data class RadarItem(
    val id: BleId,
    val loc: PointF
)

val maxRadius: Float = 6000f
val viewRadius: Float = 150f // TODO: ensure same as in RadarView

fun RadarItem.toRadarForViewItem(): RadarForViewItem {
    val multiplier = viewRadius / maxRadius
    return RadarForViewItem(
        id,
        PointF(viewRadius + loc.x * multiplier, viewRadius - loc.y * multiplier)
    )
}
