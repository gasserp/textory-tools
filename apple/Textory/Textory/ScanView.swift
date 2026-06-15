import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Orchestrates the "scan to snippet" flow: capture/import an image, send it
/// to `/api/ocr` for text extraction, then present `AddSnippetView`
/// pre-filled with the extracted text so the user can review and save.
struct ScanView: View {
    var snippetStore: SnippetStore
    var api: APIClient

    @Environment(\.dismiss) private var dismiss

    #if os(iOS)
    @State private var showImagePicker = true
    #endif
    @State private var isExtracting = false
    @State private var extractedContent: ExtractedContent?
    @State private var errorMessage: String?
    @State private var needsAnthropicKey = false

    var body: some View {
        NavigationStack {
            Group {
                if isExtracting {
                    ProgressView("Extracting text…")
                        .padding()
                } else if needsAnthropicKey {
                    ContentUnavailableView {
                        Label("Anthropic API Key Required", systemImage: "key.slash")
                    } description: {
                        Text("To extract text from images, add your Anthropic API key in Settings on textory.dev, then try again.")
                    }
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Couldn't Extract Text", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    }
                } else {
                    #if os(iOS)
                    Color.clear
                    #else
                    macImportPrompt
                    #endif
                }
            }
            .navigationTitle("Scan")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showImagePicker) {
            ImagePickerView(
                onImagePicked: { image in
                    showImagePicker = false
                    Task { await extractText(from: image) }
                },
                onCancel: {
                    showImagePicker = false
                    dismiss()
                }
            )
            .ignoresSafeArea()
        }
        #endif
        .sheet(item: $extractedContent, onDismiss: { dismiss() }) { item in
            AddSnippetView(snippetStore: snippetStore, initialContent: item.text)
        }
    }

    #if !os(iOS)
    private var macImportPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Import an image to extract text from it.")
                .foregroundStyle(.secondary)
            Button("Choose Image…") {
                if let image = ImageFilePicker.pickImage() {
                    Task { await extractText(from: image) }
                } else {
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    #endif

    #if os(iOS)
    private func extractText(from image: UIImage) async {
        await runExtraction(base64: ImageEncoding.base64JPEG(from: image))
    }
    #else
    private func extractText(from image: NSImage) async {
        await runExtraction(base64: ImageEncoding.base64JPEG(from: image))
    }
    #endif

    private func runExtraction(base64: String?) async {
        guard let base64 else {
            errorMessage = "Couldn't encode the image."
            return
        }

        isExtracting = true
        errorMessage = nil
        needsAnthropicKey = false

        do {
            let text = try await api.extractText(imageBase64: base64, mediaType: ImageEncoding.mediaType)
            extractedContent = ExtractedContent(text: text)
        } catch let error as APIError where error.status == 409 {
            needsAnthropicKey = true
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }

        isExtracting = false
    }
}

/// Wraps extracted OCR text so it can be used with `sheet(item:)`.
private struct ExtractedContent: Identifiable {
    let text: String
    var id: String { text }
}
