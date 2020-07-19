package com.match.android.ui.home

import android.graphics.PointF
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.compose.Composable
import androidx.compose.Immutable
import androidx.compose.Recomposer.Companion.current
import androidx.compose.getValue
import androidx.fragment.app.Fragment
import androidx.lifecycle.LiveData
import androidx.ui.core.Alignment
import androidx.ui.core.Modifier
import androidx.ui.core.setContent
import androidx.ui.foundation.Box
import androidx.ui.foundation.Text
import androidx.ui.foundation.shape.corner.CircleShape
import androidx.ui.graphics.Color
import androidx.ui.layout.Column
import androidx.ui.layout.Stack
import androidx.ui.layout.fillMaxWidth
import androidx.ui.layout.offset
import androidx.ui.layout.preferredSize
import androidx.ui.layout.wrapContentSize
import androidx.ui.livedata.observeAsState
import androidx.ui.unit.dp
import com.match.android.R.layout.fragment_home
import com.match.android.services.BleId
import org.koin.androidx.viewmodel.ext.android.viewModel

class HomeFragment : Fragment() {
    private val viewModel by viewModel<HomeViewModel>()

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? =
        inflater.inflate(fragment_home, container, false).apply {
            (this as ViewGroup).setContent(current()) {
                HomeView(viewModel.state, viewModel.radarViewItems)
            }
        }

    @Composable
    fun HomeView(stateLiveData: LiveData<HomeViewState>, radar: LiveData<List<RadarForViewItem>>) {
        val state by stateLiveData.observeAsState(initial = HomeViewState("", emptyList()))
        Column {
            Text("state: $state")
            RadarView(radar)
        }
    }

    @Composable
    fun RadarView(radarLiveData: LiveData<List<RadarForViewItem>>) {
        val radar by radarLiveData.observeAsState(initial = emptyList())

        Stack(modifier = Modifier.fillMaxWidth() + Modifier.wrapContentSize(Alignment.Center)) {
            Box(
                modifier = Modifier.preferredSize(300.dp),
                backgroundColor = Color.LightGray,
                shape = CircleShape
            )

            for (radarItem in radar) {
                Box(
                    modifier = Modifier.preferredSize(10.dp) + Modifier.offset(radarItem.loc.x.dp, radarItem.loc.y.dp),
                    backgroundColor = Color.Green,
                    shape = CircleShape
                )
            }
        }
    }
}

@Immutable
data class RadarForViewItem(
    val id: BleId,
    val loc: PointF
)
