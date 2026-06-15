import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Sheet for composing a new snippet: paste or type content, derive a title
/// from the first non-empty line, then save.
///
/// `initialContent` lets a later chunk present this view pre-filled with
/// extracted text (e.g. from a share extension or OCR flow).
struct AddSnippetView: View {
    var snippetStore: SnippetStore
    @Environment(\.dismiss) private var dismiss

    @State private var content: String
    @State private var isSaving = false

    init(snippetStore: SnippetStore, initialContent: String = "") {
        self.snippetStore = snippetStore
        _content = State(initialValue: initialContent)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $content)
                    .font(.system(.body, design: .monospaced))
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .overlay(alignment: .topLeading) {
                        if content.isEmpty {
                            Text("Paste or type a snippet…")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }

                if let errorMessage = snippetStore.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
            .padding()
            .navigationTitle("New Snippet")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Button("Paste") { pasteFromClipboard() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .disabled(!canSave)
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func pasteFromClipboard() {
        #if os(iOS)
        if let text = UIPasteboard.general.string {
            content = text
        }
        #else
        if let text = NSPasteboard.general.string(forType: .string) {
            content = text
        }
        #endif
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }

        let title = derivedTitle()
        if await snippetStore.add(title: title, content: content) != nil {
            dismiss()
        }
    }

    /// The first non-empty line of `content`, trimmed and truncated to the
    /// 200-character title limit enforced by the API.
    private func derivedTitle() -> String {
        let firstNonEmptyLine = content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""

        if firstNonEmptyLine.count > 200 {
            return String(firstNonEmptyLine.prefix(200))
        }
        return firstNonEmptyLine.isEmpty ? "Untitled" : firstNonEmptyLine
    }
}
