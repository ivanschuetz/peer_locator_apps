package com.match.android.ui.home

import androidx.fragment.app.Fragment
import org.koin.androidx.viewmodel.ext.android.viewModel

class HomeFragment : Fragment() {
    private val viewModel by viewModel<HomeViewModel>()
}
