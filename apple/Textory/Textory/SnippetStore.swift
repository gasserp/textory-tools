import Foundation
import Observation

/// Observable store for the current user's snippets, backed by `APIClient`.
@MainActor
@Observable
final class SnippetStore {
    private(set) var snippets: [Snippet] = []
    var errorMessage: String?

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    /// Fetches the current user's snippets (newest-first, per the API).
    func load() async {
        errorMessage = nil
        do {
            snippets = try await api.listSnippets()
        } catch {
            errorMessage = (error as? APIError)?.message ?? error.localizedDescription
        }
    }

    /// Creates a snippet and inserts it at the top of the list.
    @discardableResult
    func add(title: String, content: String, tags: [String] = []) async -> Snippet? {
        errorMessage = nil
        do {
            let created = try await api.createSnippet(title: title, content: content, tags: tags)
            snippets.insert(created, at: 0)
            return created
        } catch {
            errorMessage = (error as? APIError)?.message ?? error.localizedDescription
            return nil
        }
    }

    /// Deletes a snippet and removes it from the list.
    func remove(id: String) async {
        errorMessage = nil
        do {
            try await api.deleteSnippet(id: id)
            snippets.removeAll { $0.id == id }
        } catch {
            errorMessage = (error as? APIError)?.message ?? error.localizedDescription
        }
    }
}
