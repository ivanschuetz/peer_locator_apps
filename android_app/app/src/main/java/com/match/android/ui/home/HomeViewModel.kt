package com.match.android.ui.home

import androidx.lifecycle.ViewModel
import com.match.android.ui.navigation.MainNav
import io.reactivex.disposables.CompositeDisposable
import com.match.android.system.Resources

class HomeViewModel(
    private val nav: MainNav,
    private val resources: Resources
) : ViewModel() {
    private val disposables = CompositeDisposable()
}
