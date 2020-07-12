package com.match.android.ui.navigation

import kotlinx.coroutines.channels.BroadcastChannel
import kotlinx.coroutines.channels.sendBlocking

class MainNav {
    val navigationCommands: BroadcastChannel<NavigationCommand> = BroadcastChannel(1)

    fun navigate(command: NavigationCommand) {
        navigationCommands.sendBlocking(command)
    }
}
