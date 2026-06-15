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

/// Response shape for `POST /api/auth/register` and `POST /api/auth/login`.
struct AuthResponse: Codable {
    let token: String
    let user: User
}
