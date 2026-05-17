import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    static let shared = SessionStore()

    private(set) var token: String?
    var user: User?
    var isResolving = true

    private let tokenKey = "cultify_jwt"

    init() {
        self.token = Keychain.get(tokenKey)
    }

    func restore() async {
        isResolving = true
        defer { isResolving = false }
        guard token != nil else {
            user = nil
            return
        }
        do {
            user = try await APIClient.shared.me()
        } catch {
            signOut()
        }
    }

    func signIn(token: String, user: User) {
        self.token = token
        self.user = user
        Keychain.set(token, for: tokenKey)
    }

    func signOut() {
        token = nil
        user = nil
        Keychain.delete(tokenKey)
    }

    /// DEV helper — sets a placeholder user so the UI renders even without a
    /// real backend session. Network calls will still 401 silently.
    func mockSignIn() {
        guard user == nil else { return }
        user = User(id: "dev-local", email: "dev@cultify.me", name: "Sudhanva")
    }
}
