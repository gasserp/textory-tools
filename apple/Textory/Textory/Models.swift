import Foundation

/// Mirrors `UserDoc["status"]` from `api/src/shared/auth.ts`.
enum UserStatus: String, Codable {
    case pending
    case approved
    case rejected
}

/// Mirrors the JSON shape returned by `toClientUser` in `api/src/functions/users.ts`.
struct User: Codable, Identifiable, Equatable {
    let id: String
    let githubLogin: String
    let username: String?
    let status: UserStatus
    let role: String
    let quotaBytes: Int
    let usedBytes: Int
    let plan: String
    let hasAnthropicKey: Bool
    let hasPassword: Bool
    let autoClassify: Bool?
    let createdAt: String
    let cliTokenCreatedAt: String?
    /// Whether the *account* has an active second factor.
    ///
    /// Optional because a backend that predates 2FA omits these three keys
    /// entirely; `nil` must never be read as "satisfied".
    let mfaEnabled: Bool?
    /// Whether *this session* has satisfied 2FA.
    let mfaSatisfied: Bool?
    let recoveryCodesRemaining: Int?
}

/// Mirrors `SnippetDoc` from `plan/00-conventions.md` / `api/src/shared/quota.ts`.
struct Snippet: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    var title: String
    var content: String
    let contentBytes: Int
    var category: String?
    var tags: [String]
    var summary: String?
    let createdAt: String
    let updatedAt: String
}

/// A session: the `{ token, user }` shape returned by `POST /api/auth/register`,
/// `POST /api/auth/login` (when no second factor is demanded) and
/// `POST /api/auth/2fa/verify`.
struct AuthResponse: Codable {
    let token: String
    let user: User
}

/// The `{ status: "mfa_required", challenge, expiresIn }` shape returned by
/// `POST /api/auth/login` once `MFA_MODE=required` and the account has an
/// active factor (`docs/AUTH_CONTRACT.md` §2.3, §2.7).
///
/// The challenge is not a session: it is single-use, expires in `expiresIn`
/// seconds, and is accepted by `POST /api/auth/2fa/verify` and nothing else.
struct TwoFactorChallenge: Codable {
    let challenge: String
    let expiresIn: Int
}

/// What `POST /api/auth/login` can return.
///
/// Both shapes come back as `200`, so the status code cannot discriminate them.
/// Decoding `AuthResponse` unconditionally — as this app did before the
/// challenge flow existed — fails outright against a server with 2FA
/// enforcement on, which is why this is a sum type rather than a struct with
/// optional fields: there is no valid response carrying both a token and a
/// challenge, and the compiler should say so.
enum LoginResponse: Decodable {
    /// No second factor was demanded; the session is usable immediately.
    case session(AuthResponse)
    /// The password was accepted but a second factor is required.
    case challenge(TwoFactorChallenge)

    private enum CodingKeys: String, CodingKey {
        case status
    }

    private static let challengeStatus = "mfa_required"

    init(from decoder: Decoder) throws {
        // Keyed on `status`, not on the presence of `challenge`: a body that
        // announces itself as a challenge but decodes as a session (or vice
        // versa) should be a decoding error, not a silently mis-read login.
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decodeIfPresent(String.self, forKey: .status)

        if status == Self.challengeStatus {
            self = .challenge(try TwoFactorChallenge(from: decoder))
        } else {
            self = .session(try AuthResponse(from: decoder))
        }
    }
}

/// `GET /api/auth/capabilities` (`docs/AUTH_CONTRACT.md` §1).
///
/// Presentation only, never a security control: the server is the sole party
/// that can enforce 2FA, and this just tells the client whether it is worth
/// drawing a wall. A 404, a network error or a malformed body means
/// `mfa: "unsupported"`.
struct Capabilities: Codable {
    let webPasswordLogin: Bool
    let mfa: String

    static let unsupported = Capabilities(webPasswordLogin: false, mfa: "unsupported")

    var mfaRequired: Bool { mfa == "required" }
}
