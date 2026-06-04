//
//  whoosh_iosApp.swift
//  whoosh-ios
//
//  Created by Brayden Pelt on 6/2/26.
//

import SwiftUI

@main
struct whoosh_iosApp: App {
    @StateObject private var model = AppModel()
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}
