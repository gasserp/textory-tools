import SwiftUI

/// Lists the current user's snippets newest-first, with pull-to-refresh,
/// add, and swipe-to-delete.
struct SnippetListView: View {
    var snippetStore: SnippetStore
    var authStore: AuthStore

    @State private var showAddSnippet = false
    @State private var showScan = false

    var body: some View {
        List {
            if let errorMessage = snippetStore.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            ForEach(snippetStore.snippets) { snippet in
                NavigationLink {
                    SnippetDetailView(snippet: snippet)
                } label: {
                    SnippetRow(snippet: snippet)
                }
            }
            .onDelete { offsets in
                Task {
                    for index in offsets {
                        await snippetStore.remove(id: snippetStore.snippets[index].id)
                    }
                }
            }
        }
        .navigationTitle("Snippets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSnippet = true
                } label: {
                    Label("Add Snippet", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showScan = true
                } label: {
                    #if os(macOS)
                    Label("Import Image", systemImage: "doc.viewfinder")
                    #else
                    Label("Scan", systemImage: "doc.viewfinder")
                    #endif
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Sign Out") {
                    Task { await authStore.logout() }
                }
            }
        }
        .refreshable {
            await snippetStore.load()
        }
        .task {
            await snippetStore.load()
        }
        .sheet(isPresented: $showAddSnippet) {
            AddSnippetView(snippetStore: snippetStore)
                #if os(macOS)
                .frame(minWidth: 480, minHeight: 360)
                #endif
        }
        .sheet(isPresented: $showScan) {
            ScanView(snippetStore: snippetStore, api: authStore.api)
                #if os(macOS)
                .frame(minWidth: 480, minHeight: 360)
                #endif
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: AppCommand.newSnippet)) { _ in
            showAddSnippet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: AppCommand.refreshSnippets)) { _ in
            Task { await snippetStore.load() }
        }
        #endif
        .overlay {
            if snippetStore.snippets.isEmpty && snippetStore.errorMessage == nil {
                ContentUnavailableView(
                    "No Snippets",
                    systemImage: "doc.text",
                    description: Text("Tap + to add your first snippet.")
                )
            }
        }
    }
}

/// A single row showing a snippet's title, summary (if present), and tags.
private struct SnippetRow: View {
    let snippet: Snippet

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snippet.title)
                .font(.headline)
                .lineLimit(1)

            if let summary = snippet.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !snippet.tags.isEmpty {
                Text(snippet.tags.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }
}
