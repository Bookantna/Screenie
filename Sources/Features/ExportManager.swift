import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ExportManager {
    /// Renders the screenshot with annotations at the image's native point size.
    /// Annotations are in canvas coordinate space and are scaled to image space.
    func render(image: NSImage, annotations: [Annotation], canvasSize: CGSize) -> NSImage {
        let imgSize = image.size
        let scaleX = imgSize.width / canvasSize.width
        let scaleY = imgSize.height / canvasSize.height

        // Render annotation layer at canvas size via ImageRenderer, then scale up.
        let annotationLayer = ImageRenderer(
            content: AnnotationLayerView(annotations: annotations, size: canvasSize)
        )
        annotationLayer.scale = 1

        let output = NSImage(size: imgSize)
        output.lockFocus()
        defer { output.unlockFocus() }

        // Draw the original screenshot
        image.draw(in: NSRect(origin: .zero, size: imgSize))

        // Draw scaled annotation overlay
        if let cgAnnotations = annotationLayer.cgImage {
            let ctx = NSGraphicsContext.current!.cgContext
            // Flip for NSGraphicsContext (bottom-left origin)
            ctx.saveGState()
            ctx.translateBy(x: 0, y: imgSize.height)
            ctx.scaleBy(x: scaleX, y: -scaleY)
            ctx.draw(cgAnnotations, in: CGRect(origin: .zero, size: canvasSize))
            ctx.restoreGState()
        }

        return output
    }

    func copyToClipboard(_ image: NSImage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    func saveAsPNG(_ image: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.png]
        panel.nameFieldStringValue = "Screenshot \(formattedTime())"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    private func formattedTime() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return f.string(from: Date())
    }
}

private struct AnnotationLayerView: View {
    let annotations: [Annotation]
    let size: CGSize

    var body: some View {
        Canvas { ctx, _ in
            for annotation in annotations {
                annotation.draw(in: &ctx)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
