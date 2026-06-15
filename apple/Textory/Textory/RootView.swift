import SwiftUI

/// Top-level view that switches on `AuthStore.state`.
struct RootView: View {
    var authStore: AuthStore

    var body: some View {
        switch authStore.state {
        case .loading:
            ProgressView()
        case .anonymous:
            LoginView(authStore: authStore)
        case .pending:
            StatusMessageView(
                title: "Awaiting approval",
                message: "Your account has been created and is waiting for admin approval. Check back later.",
                authStore: authStore
            )
        case .rejected:
            StatusMessageView(
                title: "Access denied",
                message: "Your account request was not approved.",
                authStore: authStore
            )
        case .approved:
            ApprovedView(authStore: authStore)
        }
    }
}

/// Hosts the signed-in snippet UI, owning a `SnippetStore` for the lifetime
/// of the approved session (created once via `@State`, not on every
/// `RootView` body evaluation).
private struct ApprovedView: View {
    var authStore: AuthStore
    @State private var snippetStore: SnippetStore?

    var body: some View {
        NavigationStack {
            if let snippetStore {
                SnippetListView(snippetStore: snippetStore, authStore: authStore)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if snippetStore == nil {
                snippetStore = SnippetStore(api: authStore.api)
            }
        }
    }
}

/// Shared full-screen message used for the pending/rejected states, with a
/// sign-out action so the user isn't stuck.
private struct StatusMessageView: View {
    let title: String
    let message: String
    var authStore: AuthStore

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title2)
                .bold()
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Sign Out") {
                Task { await authStore.logout() }
            }
        }
        .padding()
        .frame(maxWidth: 400)
    }
}
