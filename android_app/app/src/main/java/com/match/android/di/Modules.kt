package com.match.android.di

import android.app.Application
import android.content.Context.MODE_PRIVATE
import android.content.SharedPreferences
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.match.android.ble.BleEnabler
import com.match.android.ble.BleEnablerImpl
import com.match.android.ble.BleManager
import com.match.android.ble.BleManagerImpl
import com.match.android.ble.BlePermissionsManager
import com.match.android.ble.BlePermissionsManagerImpl
import com.match.android.ble.BlePreconditions
import com.match.android.ble.BlePreconditionsNotifier
import com.match.android.ble.BlePreconditionsNotifierImpl
import com.match.android.ble.BleServiceManager
import com.match.android.ble.BleServiceManagerImpl
import com.match.android.notifications.AppNotificationChannels
import com.match.android.notifications.NotificationChannelsCreator
import com.match.android.notifications.NotificationShower
import com.match.android.notifications.NotificationsShowerImpl
import com.match.android.services.BleIdService
import com.match.android.services.BleIdServiceImpl
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
    viewModel { HomeViewModel(get(), get(), get()) }
}

val systemModule = module {
    single { getSharedPrefs(androidApplication()) }
    single<Preferences> { PreferencesImpl(get(), get()) }
    single { Resources(androidApplication()) }
    single<EnvInfos> { EnvInfosImpl() }
    single { provideGson() }
    single { NotificationChannelsCreator(androidApplication()) }
    single(createdAtStart = true) { AppNotificationChannels(get(), get()) }
    single<NotificationShower> { NotificationsShowerImpl(get()) }
}

val uiModule = module {
    single { MainNav() }
}

val bleModule = module {
    single<BlePermissionsManager> { BlePermissionsManagerImpl() }
    single<BleEnabler> { BleEnablerImpl() }
    single { BlePreconditions(get(), get(), get()) }
    single<BlePreconditionsNotifier> { BlePreconditionsNotifierImpl() }
    single<BleServiceManager> { BleServiceManagerImpl(get(), get(), get()) }
    single<BleManager>(createdAtStart = true) { BleManagerImpl(get(), androidApplication(), get()) }
    single<BleIdService> { BleIdServiceImpl(get()) }
}

@ExperimentalUnsignedTypes
val appModule = listOf(
    viewModelModule,
    systemModule,
    uiModule,
    bleModule
)

fun getSharedPrefs(androidApplication: Application): SharedPreferences =
    androidApplication.getSharedPreferences("default", MODE_PRIVATE)

private fun provideGson(): Gson = GsonBuilder()
    .serializeNulls()
    .setLenient()
    .create()
