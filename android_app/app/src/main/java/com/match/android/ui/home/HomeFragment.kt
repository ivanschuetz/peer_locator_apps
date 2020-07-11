package com.match.android.ui.home

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.compose.Composable
import androidx.compose.Recomposer.Companion.current
import androidx.fragment.app.Fragment
import androidx.ui.core.setContent
import androidx.ui.foundation.Text
import com.match.android.R.layout.fragment_home
import org.koin.androidx.viewmodel.ext.android.viewModel

class HomeFragment : Fragment() {
    private val viewModel by viewModel<HomeViewModel>()

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?,
                              savedInstanceState: Bundle?): View? =
        inflater.inflate(fragment_home, container, false).apply {
            (this as ViewGroup).setContent(current()) {
                HomeView()
            }
        }

    @Composable
    private fun HomeView() {
        Text("Jetpack Compose")
    }
}
