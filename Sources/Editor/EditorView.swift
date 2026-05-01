import SwiftUI

struct EditorView: View {
    let image: NSImage
    let onClose: () -> Void
    let onPin: @MainActor (NSImage) -> Void

    @State private var store = AnnotationStore()
    @State private var showOCR = false
    @State private var ocrLines: [String] = []
    @State private var ocrRunning = false

    private let exporter = ExportManager()
    private let ocr = OCRManager()

    var body: some View {
        VStack(spacing: 0) {
            AnnotationToolbar(store: store)

            Divider()

            AnnotationCanvas(image: image, store: store)

            Divider()

            actionBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showOCR) {
            OCRResultView(lines: ocrLines, isRunning: ocrRunning)
        }
    }

    // MARK: – Action bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("Undo") { store.undo() }
                .disabled(!store.canUndo)
                .keyboardShortcut("z", modifiers: .command)

            Button { runOCR() } label: {
                Label("OCR", systemImage: "text.viewfinder")
            }
            .help("Extract text from image")

            Spacer()

            Button("Close") { onClose() }
                .keyboardShortcut(.escape, modifiers: [])

            Button("Pin") {
                let rendered = rendered()
                onPin(rendered)
            }
            .help("Float screenshot above all windows")

            Button("Save…") { exporter.saveAsPNG(rendered()) }

            Button("Copy") {
                exporter.copyToClipboard(rendered())
                onClose()
            }
            .keyboardShortcut("c", modifiers: .command)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: – Helpers

    private func rendered() -> NSImage {
        let size = EditorWindow.canvasSize(for: image)
        return exporter.render(image: image, annotations: store.annotations, canvasSize: size)
    }

    private func runOCR() {
        showOCR = true
        ocrRunning = true
        ocrLines = []
        Task {
            ocrLines = await ocr.recognizeText(in: image)
            ocrRunning = false
        }
    }
}

// MARK: – OCR sheet

private struct OCRResultView: View {
    let lines: [String]
    let isRunning: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var fullText: String { lines.joined(separator: "\n") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recognized Text")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            if isRunning {
                ProgressView("Recognizing…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if lines.isEmpty {
                Text("No text found.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(fullText)
                        .font(.system(size: 13, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }

            Divider()

            HStack {
                Spacer()
                Button(copied ? "Copied!" : "Copy All") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(fullText, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                }
                .disabled(lines.isEmpty || isRunning)
            }
            .padding()
        }
        .frame(width: 420, height: 320)
    }
}
