//
//  CultifyApp.swift
//  Cultify
//
//  Created by Sudhanva  Acharya on 17/05/26.
//

import SwiftUI

@main
struct CultifyApp: App {
    @State private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .preferredColorScheme(.light)
                .tint(Theme.accent)
        }
    }
}
