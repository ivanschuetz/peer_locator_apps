package com.match.android.ui.home

import android.graphics.PointF
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.match.android.R.layout.fragment_home
import com.match.android.services.BleId
import org.koin.androidx.viewmodel.ext.android.viewModel

class HomeFragment : Fragment() {
    private val viewModel by viewModel<HomeViewModel>()

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? =
        inflater.inflate(fragment_home, container, false).apply {
        }
}

data class RadarForViewItem(
    val id: BleId,
    val loc: PointF
)
