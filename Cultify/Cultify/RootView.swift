import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            // DEV: auth gate bypassed — go straight to home.
            // To re-enable, swap MainTabView() back for the splash/Login flow.
            MainTabView()
        }
        .task {
            await session.restore()
            if session.user == nil {
                session.mockSignIn()
            }
        }
    }
}
