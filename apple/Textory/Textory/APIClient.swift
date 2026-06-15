import Foundation

/// A typed error thrown by `APIClient` for non-2xx responses.
///
/// The server returns errors as `{ "error": string }` (see
/// `api/src/shared/http.ts`); this captures both the HTTP status and the
/// decoded message (falling back to the raw body if it isn't JSON).
struct APIError: Error, LocalizedError {
    let status: Int
    let message: String

    var errorDescription: String? { message }
}

/// Thin async/await JSON client for the textory HTTP API.
///
/// All requests target `baseURL + "/api/..."`. When a session token is set,
/// it is sent via the `x-textory-token` header — Azure Static Web Apps
/// strips the `Authorization` header before it reaches managed functions,
/// so native clients must use this custom header (see
/// `api/src/shared/auth.ts`).
@MainActor
final class APIClient {
    /// Default API base URL. Override via the `TEXTORY_BASE_URL` environment
    /// variable (e.g. an Xcode scheme override) for local development.
    static let defaultBaseURL = URL(string: "https://textory.dev")!

    var baseURL: URL
    var token: String?

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL = APIClient.resolvedBaseURL(), token: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    /// Resolves the base URL from the `TEXTORY_BASE_URL` environment
    /// variable (settable via an Xcode scheme), falling back to
    /// `defaultBaseURL`.
    static func resolvedBaseURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["TEXTORY_BASE_URL"],
           let url = URL(string: override), !override.isEmpty {
            return url
        }
        return defaultBaseURL
    }

    // MARK: - Auth

    private struct RegisterRequest: Encodable {
        let username: String
        let password: String
        let acceptTerms: Bool
    }

    private struct LoginRequest: Encodable {
        let username: String
        let password: String
    }

    func register(username: String, password: String, acceptTerms: Bool) async throws -> AuthResponse {
        try await send(
            "POST", "/api/auth/register",
            body: RegisterRequest(username: username, password: password, acceptTerms: acceptTerms)
        )
    }

    func login(username: String, password: String) async throws -> AuthResponse {
        try await send(
            "POST", "/api/auth/login",
            body: LoginRequest(username: username, password: password)
        )
    }

    /// Calls `POST /api/auth/logout`. Errors are intentionally ignored by
    /// callers that just want to clear local state regardless of outcome.
    func logout() async throws {
        let _: EmptyResponse = try await sendNoBody("POST", "/api/auth/logout")
    }

    func me() async throws -> User {
        try await sendNoBody("GET", "/api/me")
    }

    // MARK: - Snippets

    private struct CreateSnippetRequest: Encodable {
        let title: String
        let content: String
        let tags: [String]
    }

    func listSnippets() async throws -> [Snippet] {
        try await sendNoBody("GET", "/api/snippets")
    }

    func createSnippet(title: String, content: String, tags: [String] = []) async throws -> Snippet {
        try await send(
            "POST", "/api/snippets",
            body: CreateSnippetRequest(title: title, content: content, tags: tags)
        )
    }

    /// Calls `DELETE /api/snippets/{id}`, which responds `204 No Content`.
    func deleteSnippet(id: String) async throws {
        let _: EmptyResponse = try await perform("DELETE", "/api/snippets/\(id)", httpBody: nil)
    }

    // MARK: - OCR

    private struct OcrRequest: Encodable {
        let imageBase64: String
        let mediaType: String
    }

    private struct OcrResponse: Decodable {
        let text: String
    }

    /// Calls `POST /api/ocr`, extracting text from the given base64-encoded
    /// image. `mediaType` must be one of `image/jpeg`, `image/png`, or
    /// `image/webp`. Throws `APIError(status: 409, ...)` if the user has not
    /// configured an Anthropic API key.
    func extractText(imageBase64: String, mediaType: String) async throws -> String {
        let response: OcrResponse = try await send(
            "POST", "/api/ocr",
            body: OcrRequest(imageBase64: imageBase64, mediaType: mediaType)
        )
        return response.text
    }

    // MARK: - Core request plumbing

    private struct EmptyResponse: Decodable {}

    /// Sends a request with no request body.
    private func sendNoBody<Response: Decodable>(
        _ method: String,
        _ path: String
    ) async throws -> Response {
        try await perform(method, path, httpBody: nil)
    }

    /// Sends a request with a JSON-encoded request body.
    private func send<Body: Encodable, Response: Decodable>(
        _ method: String,
        _ path: String,
        body: Body
    ) async throws -> Response {
        try await perform(method, path, httpBody: try encoder.encode(body))
    }

    private func perform<Response: Decodable>(
        _ method: String,
        _ path: String,
        httpBody: Data?
    ) async throws -> Response {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token {
            request.setValue(token, forHTTPHeaderField: "x-textory-token")
        }

        if let httpBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpBody
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(status: -1, message: "invalid response")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError(status: httpResponse.statusCode, message: Self.errorMessage(from: data, status: httpResponse.statusCode))
        }

        if data.isEmpty, let empty = EmptyResponse() as? Response {
            return empty
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError(status: httpResponse.statusCode, message: "failed to decode response: \(error.localizedDescription)")
        }
    }

    /// Decodes `{ "error": string }` bodies; falls back to a generic message
    /// keyed on the HTTP status for non-JSON or unexpected bodies.
    private static func errorMessage(from data: Data, status: Int) -> String {
        struct ErrorBody: Decodable { let error: String }
        if let body = try? JSONDecoder().decode(ErrorBody.self, from: data), !body.error.isEmpty {
            return body.error
        }
        return HTTPURLResponse.localizedString(forStatusCode: status)
    }
}
