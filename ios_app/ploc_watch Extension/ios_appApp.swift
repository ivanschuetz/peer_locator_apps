//
//  ios_appApp.swift
//  ploc_watch Extension
//
//  Created by Ivan Schuetz on 30.08.20.
//  Copyright © 2020 com.schuetz. All rights reserved.
//

import SwiftUI

@main
struct ios_appApp: App {
    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
        }

        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
}
