import SwiftUI

#if os(iOS)
import UIKit

/// Wraps `UIImagePickerController` to capture a photo with the camera,
/// falling back to the photo library when the camera is unavailable (e.g.
/// in the iOS Simulator).
struct ImagePickerView: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

#else
import AppKit

/// Helpers for picking an image file on macOS, where most Macs lack a rear
/// camera suitable for document scanning.
enum ImageFilePicker {
    /// Presents an `NSOpenPanel` for selecting an image file. Returns the
    /// loaded `NSImage`, or `nil` if the user cancelled or the file couldn't
    /// be loaded.
    @MainActor
    static func pickImage() -> NSImage? {
        let panel = NSOpenPanel()
        panel.title = "Import Image"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.jpeg, .png, .webP, .image]

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return NSImage(contentsOf: url)
    }
}
#endif

/// Shared helper to downscale a captured/imported image and encode it as
/// JPEG for the `/api/ocr` endpoint (which limits decoded images to ~5MB).
enum ImageEncoding {
    /// Maximum length of the image's longer edge after downscaling.
    static let maxDimension: CGFloat = 1600

    /// JPEG compression quality.
    static let jpegQuality: CGFloat = 0.7

    /// Media type reported to `/api/ocr` for the encoded JPEG data.
    static let mediaType = "image/jpeg"

    #if os(iOS)
    /// Downscales `image` to fit within `maxDimension` on its longer edge,
    /// JPEG-encodes it, and returns the base64-encoded string.
    static func base64JPEG(from image: UIImage) -> String? {
        let resized = resize(image)
        guard let data = resized.jpegData(compressionQuality: jpegQuality) else { return nil }
        return data.base64EncodedString()
    }

    private static func resize(_ image: UIImage) -> UIImage {
        let size = image.size
        let longestEdge = max(size.width, size.height)
        guard longestEdge > maxDimension else { return image }

        let scale = maxDimension / longestEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    #else
    /// Downscales `image` to fit within `maxDimension` on its longer edge,
    /// JPEG-encodes it, and returns the base64-encoded string.
    static func base64JPEG(from image: NSImage) -> String? {
        let resized = resize(image)
        guard let tiffData = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality]) else {
            return nil
        }
        return data.base64EncodedString()
    }

    private static func resize(_ image: NSImage) -> NSImage {
        let size = image.size
        let longestEdge = max(size.width, size.height)
        guard longestEdge > maxDimension else { return image }

        let scale = maxDimension / longestEdge
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                    from: NSRect(origin: .zero, size: size),
                    operation: .copy,
                    fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
    #endif
}
