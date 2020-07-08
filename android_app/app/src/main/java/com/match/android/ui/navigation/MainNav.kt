package com.match.android.ui.navigation

import io.reactivex.subjects.PublishSubject
import io.reactivex.subjects.PublishSubject.create

class MainNav {
    val navigationCommands: PublishSubject<NavigationCommand> = create()

    fun navigate(command: NavigationCommand) {
        navigationCommands.onNext(command)
    }
}
