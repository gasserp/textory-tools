import Foundation
import Observation

/// The overall authentication state of the app.
enum AuthState: Equatable {
    /// Initial state, before `bootstrap()` has resolved.
    case loading
    /// No valid session token; show the login/register flow.
    case anonymous
    /// Signed in, but the account is awaiting admin approval.
    case pending
    /// Signed in, but the account was rejected.
    case rejected
    /// Signed in and approved; carries the current user.
    case approved(User)
}

/// Observable session/auth state, backed by a Keychain-stored session token.
@MainActor
@Observable
final class AuthStore {
    private(set) var state: AuthState = .loading
    var errorMessage: String?

    let api: APIClient

    init(api: APIClient = APIClient()) {
        self.api = api
    }

    /// Reads any persisted token from the Keychain and resolves the current
    /// auth state by calling `GET /api/me`. Call once on app launch.
    func bootstrap() async {
        guard let token = Keychain.readToken() else {
            state = .anonymous
            return
        }

        api.token = token
        await refreshUser()
    }

    func login(username: String, password: String) async {
        errorMessage = nil
        do {
            let response = try await api.login(username: username, password: password)
            apply(response)
        } catch {
            errorMessage = (error as? APIError)?.message ?? error.localizedDescription
        }
    }

    func register(username: String, password: String, acceptTerms: Bool) async {
        errorMessage = nil
        do {
            let response = try await api.register(username: username, password: password, acceptTerms: acceptTerms)
            apply(response)
        } catch {
            errorMessage = (error as? APIError)?.message ?? error.localizedDescription
        }
    }

    func logout() async {
        errorMessage = nil
        try? await api.logout()
        api.token = nil
        Keychain.deleteToken()
        state = .anonymous
    }

    /// Stores the new session token and updates state from the returned user.
    private func apply(_ response: AuthResponse) {
        Keychain.saveToken(response.token)
        api.token = response.token
        state = AuthStore.state(for: response.user)
    }

    /// Re-fetches the current user (e.g. after bootstrap) and updates state.
    private func refreshUser() async {
        do {
            let user = try await api.me()
            state = AuthStore.state(for: user)
        } catch {
            // Token missing/invalid/expired: fall back to signed-out.
            api.token = nil
            Keychain.deleteToken()
            state = .anonymous
        }
    }

    private static func state(for user: User) -> AuthState {
        switch user.status {
        case .pending: return .pending
        case .rejected: return .rejected
        case .approved: return .approved(user)
        }
    }
}
