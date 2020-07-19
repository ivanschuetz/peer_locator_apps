package com.match.android.ui.home

import android.graphics.PointF
import androidx.compose.Immutable
import androidx.lifecycle.LiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.asLiveData
import com.match.android.ble.BleManager
import com.match.android.services.BleId
import com.match.android.services.BleIdSerializer
import com.match.android.system.Resources
import com.match.android.system.log.log
import com.match.android.ui.navigation.MainNav
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.channels.BroadcastChannel
import kotlinx.coroutines.channels.ticker
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.asFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.flow.scan
import kotlinx.coroutines.flow.startWith
import kotlinx.coroutines.launch
import java.time.LocalDateTime

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
            acc + el.id
        })

    @FlowPreview
    val state: LiveData<HomeViewState> =
        bleManager.advertiserObservable.asFlow().combine(discoveredBleIds) { myId, discovered ->
            HomeViewState(myId.toString(), discovered.map { it.toString() })
        }.asLiveData()

    val bleId1 = BleIdSerializer.randomValidStringBasedBleId()
    val bleId2 = BleIdSerializer.randomValidStringBasedBleId()

    val tickerChannel = ticker(delayMillis = 1000, initialDelayMillis = 1000)

    val channel: BroadcastChannel<List<RadarForViewItem>> = BroadcastChannel(1)


    @FlowPreview
    val radarViewItems: LiveData<List<RadarForViewItem>> =
        channel.asFlow().onStart {
            emit(listOf(
                RadarItem(bleId1, PointF(1000f, 1000f)).toRadarForViewItem(),
                RadarItem(bleId2, PointF(-2000f, 3000f)).toRadarForViewItem()
            ))
        }.asLiveData()
//        flowOf(listOf(
//            RadarItem(bleId1, PointF(1000f, 1000f)).toRadarForViewItem(),
//            RadarItem(bleId2, PointF(-2000f, 3000f)).toRadarForViewItem()
//        )).asLiveData()

//        bleManager.scannerObservable.asFlow().scan(HashMap<BleId, RadarItem>(), { acc, bleId ->
//            val dict: HashMap<BleId, RadarItem> = acc
////            dict[bleId.id] = RadarItem(bleId.id, PointF(bleId.distance, bleId.distance))
//            dict[bleId.id] = RadarItem(bleId.id, PointF(1000f, 2000f))
//            dict
//        }).map {
//            it.values.toList().map { it.toRadarForViewItem() }
//        }.asLiveData()

    init {
        GlobalScope.launch {
            repeat(1) {
                tickerChannel.receive()
                channel.send(listOf(
                    RadarItem(bleId1, PointF(3000f, 0000f)).toRadarForViewItem(),
                    RadarItem(bleId2, PointF(-3000f, 0000f)).toRadarForViewItem()
                ))
            }
        }
    }
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
