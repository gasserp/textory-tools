import Foundation
import Observation

/// The overall authentication state of the app.
enum AuthState: Equatable {
    /// Initial state, before `bootstrap()` has resolved.
    case loading
    /// No valid session token; show the login/register flow.
    case anonymous
    /// The password was accepted and the server issued a 2FA challenge. Not a
    /// session — nothing is stored and no API call other than the verify route
    /// will accept the challenge.
    case awaitingSecondFactor
    /// Signed in, but the server requires 2FA and this session has not
    /// satisfied it. The API is walled to a handful of routes until the
    /// account enrols a factor.
    case mfaEnrollmentRequired
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

    /// What the server says it supports. Presentation only — the server is the
    /// only party that enforces anything (contract §1).
    private var capabilities: Capabilities = .unsupported

    /// The in-flight 2FA challenge, held only for the life of the login.
    private var pendingChallenge: String?
    private var challengeExpiresAt: Date?

    /// One string for every step-1 credential failure.
    ///
    /// The API returns an identical 401 body — and burns identical KDF time —
    /// for an unknown username and a wrong password (contract §2.1). Rendering
    /// whatever text the server hands back would put a client between that
    /// design and the user, ready to leak an account-enumeration oracle the
    /// day one of those messages diverges.
    private static let genericCredentialError = "Invalid username or password."

    // Note: the `APIClient()` fallback is constructed in the body rather than
    // as a default argument. A `@MainActor`-isolated default value crashes
    // SILGen in the Swift 6.1 toolchain (Xcode 16.4) used by CI, though it
    // compiles fine on newer toolchains.
    init(api: APIClient? = nil) {
        self.api = api ?? APIClient()
    }

    /// Reads any persisted token from the Keychain and resolves the current
    /// auth state by calling `GET /api/me`. Call once on app launch.
    func bootstrap() async {
        await loadCapabilities()

        guard let token = Keychain.readToken() else {
            state = .anonymous
            return
        }

        api.token = token
        await refreshUser()
    }

    /// Step 1 of password login.
    ///
    /// Under `MFA_MODE=required` an enrolled account gets a challenge here
    /// instead of a session; the password alone never produces one.
    func login(username: String, password: String) async {
        errorMessage = nil
        clearChallenge()

        // Re-read on every attempt: MFA_MODE is a server configuration change,
        // not a deploy, so it can flip while this app has been open for days.
        await loadCapabilities()

        do {
            switch try await api.login(username: username, password: password) {
            case .session(let response):
                apply(response)
            case .challenge(let issued):
                pendingChallenge = issued.challenge
                challengeExpiresAt = Date().addingTimeInterval(TimeInterval(issued.expiresIn))
                state = .awaitingSecondFactor
            }
        } catch {
            errorMessage = Self.loginErrorMessage(for: error)
        }
    }

    /// Step 2 of password login: a 6-digit TOTP code or a recovery code.
    func submitSecondFactor(_ code: String) async {
        errorMessage = nil

        // Authenticator apps render codes as "123 456", and a pasted recovery
        // code usually arrives with a trailing newline. The server compares
        // against a trimmed 6-digit string or a 32-char base32 code, neither of
        // which contains whitespace, so stripping it can only help.
        let entered = code.filter { !$0.isWhitespace }
        guard !entered.isEmpty else { return }

        guard let challenge = pendingChallenge, !isChallengeExpired else {
            // The server answers a stale challenge with the same "invalid code"
            // as a wrong digit, which reads as "you mistyped" for something
            // retyping cannot fix.
            abandonChallenge(reason: "Your sign-in request expired. Please sign in again.")
            return
        }

        do {
            let response = try await api.verifyTwoFactor(challenge: challenge, code: entered)
            clearChallenge()
            apply(response)
        } catch {
            errorMessage = Self.codeErrorMessage(for: error)
        }
    }

    /// Abandons the challenge and returns to the credential form.
    func cancelSecondFactor() {
        clearChallenge()
        errorMessage = nil
        state = .anonymous
    }

    func register(username: String, password: String, acceptTerms: Bool) async {
        errorMessage = nil
        do {
            let response = try await api.register(username: username, password: password, acceptTerms: acceptTerms)
            apply(response)
        } catch {
            // Not collapsed to the generic string: registration has no
            // credential to guess, and "username taken" / the format rules are
            // exactly what the user needs to see.
            errorMessage = (error as? APIError)?.message ?? error.localizedDescription
        }
    }

    func logout() async {
        errorMessage = nil
        clearChallenge()
        try? await api.logout()
        api.token = nil
        Keychain.deleteToken()
        state = .anonymous
    }

    /// Loads `/api/auth/capabilities`, keeping the previous value on failure.
    ///
    /// Errors are never cached (contract §1): a 404 from a backend that
    /// predates 2FA, a timeout and a malformed body all mean "assume the
    /// server is not enforcing", which is also the safe answer — a client-side
    /// wall in front of a server that is not walling anything locks users out
    /// of a working account.
    private func loadCapabilities() async {
        if let loaded = try? await api.capabilities() {
            capabilities = loaded
        }
    }

    private var isChallengeExpired: Bool {
        guard let challengeExpiresAt else { return true }
        return challengeExpiresAt <= Date()
    }

    private func clearChallenge() {
        pendingChallenge = nil
        challengeExpiresAt = nil
    }

    private func abandonChallenge(reason: String) {
        clearChallenge()
        state = .anonymous
        errorMessage = reason
    }

    /// Stores the new session token and updates state from the returned user.
    private func apply(_ response: AuthResponse) {
        Keychain.saveToken(response.token)
        api.token = response.token
        state = resolveState(for: response.user)
    }

    /// Re-fetches the current user (e.g. after bootstrap) and updates state.
    private func refreshUser() async {
        do {
            let user = try await api.me()
            state = resolveState(for: user)
        } catch {
            // Token missing/invalid/expired: fall back to signed-out.
            api.token = nil
            Keychain.deleteToken()
            state = .anonymous
        }
    }

    private func resolveState(for user: User) -> AuthState {
        // The wall only goes up when the server has declared it is enforcing.
        // A bare `mfaSatisfied != true` check would wall everyone under
        // MFA_MODE=optional, where the legacy login route issues an
        // unsatisfied — and entirely usable — session by design.
        if capabilities.mfaRequired && user.mfaSatisfied != true {
            return .mfaEnrollmentRequired
        }

        switch user.status {
        case .pending: return .pending
        case .rejected: return .rejected
        case .approved: return .approved(user)
        }
    }

    private static func loginErrorMessage(for error: Error) -> String {
        guard let apiError = error as? APIError else { return error.localizedDescription }
        // 429 ("too many attempts", "rate limit exceeded") is actionable and
        // says nothing about whether the account exists. 403 ("pending
        // approval", "rejected") is only reachable *after* correct credentials.
        return apiError.status == 401 ? genericCredentialError : apiError.message
    }

    private static func codeErrorMessage(for error: Error) -> String {
        guard let apiError = error as? APIError else { return error.localizedDescription }
        // The server deliberately answers a wrong code, a replayed code, a
        // consumed challenge and an expired one with the same 401, so a
        // guesser learns nothing about which of those they hit.
        return apiError.status == 401 ? "Invalid code." : apiError.message
    }
}
