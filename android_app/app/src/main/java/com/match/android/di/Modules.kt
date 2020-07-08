package com.match.android.di

import android.app.Application
import android.content.Context.MODE_PRIVATE
import android.content.SharedPreferences
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.match.android.system.EnvInfos
import com.match.android.system.EnvInfosImpl
import com.match.android.system.Preferences
import com.match.android.system.PreferencesImpl
import com.match.android.system.Resources
import com.match.android.ui.home.HomeViewModel
import com.match.android.ui.navigation.MainNav
import org.koin.android.ext.koin.androidApplication
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.dsl.module

val viewModelModule = module {
    viewModel { HomeViewModel(get(), get()) }
}

val systemModule = module {
    single { getSharedPrefs(androidApplication()) }
    single<Preferences> { PreferencesImpl(get(), get()) }
    single { Resources(androidApplication()) }
    single<EnvInfos> { EnvInfosImpl() }
    single { provideGson() }
}

val uiModule = module {
    single { MainNav() }
}

@ExperimentalUnsignedTypes
val appModule = listOf(
    viewModelModule,
    systemModule,
    uiModule
)

fun getSharedPrefs(androidApplication: Application): SharedPreferences =
    androidApplication.getSharedPreferences("default", MODE_PRIVATE)

private fun provideGson(): Gson = GsonBuilder()
    .serializeNulls()
    .setLenient()
    .create()
