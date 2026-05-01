import SwiftUI
import AppKit
import CoreImage.CIFilterBuiltins

struct AnnotationCanvas: View {
    let image: NSImage
    @Bindable var store: AnnotationStore

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var pendingTextOrigin: CGPoint?
    @State private var pendingText: String = ""
    @FocusState private var textFieldFocused: Bool
    @State private var blurCache: [UUID: NSImage] = [:]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                // Blur annotation layers rendered beneath other annotations
                ForEach(store.annotations, id: \.id) { annotation in
                    if case .blur(let b) = annotation, let blurred = blurCache[b.id] {
                        Image(nsImage: blurred)
                            .resizable()
                            .frame(width: b.rect.width, height: b.rect.height)
                            .position(x: b.rect.midX, y: b.rect.midY)
                    }
                }

                // In-progress blur preview
                if case .blur = store.selectedTool, let s = dragStart, let c = dragCurrent {
                    let rect = selectionRect(s, c)
                    if rect.width > 4 && rect.height > 4 {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    }
                }

                Canvas { ctx, _ in
                    for a in store.annotations { a.draw(in: &ctx) }
                    if let preview = inProgressAnnotation() { preview.draw(in: &ctx) }
                }

                if let origin = pendingTextOrigin {
                    TextField("Type text…", text: $pendingText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(store.selectedColor)
                        .frame(width: 200)
                        .position(x: origin.x + 100, y: origin.y + 10)
                        .focused($textFieldFocused)
                        .onSubmit { commitText(at: origin) }
                }
            }
            .gesture(dragGesture(geo: geo))
            .simultaneousGesture(clickGesture(geo: geo))
            .onTapGesture { }
            .onChange(of: store.annotations.count) { _, _ in
                rebuildBlurCache(canvasSize: geo.size)
            }
        }
    }

    // MARK: – Blur cache

    private func rebuildBlurCache(canvasSize: CGSize) {
        let scaleX = image.size.width / canvasSize.width
        let scaleY = image.size.height / canvasSize.height
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()

        for annotation in store.annotations {
            guard case .blur(let b) = annotation, blurCache[b.id] == nil else { continue }

            let imgRect = CGRect(
                x: b.rect.minX * scaleX, y: b.rect.minY * scaleY,
                width: b.rect.width * scaleX, height: b.rect.height * scaleY
            )
            // CIImage has flipped y relative to NSImage
            let flippedY = image.size.height - imgRect.maxY
            let ciRect = CGRect(x: imgRect.minX, y: flippedY,
                                width: imgRect.width, height: imgRect.height)

            let filter = CIFilter.pixellate()
            filter.inputImage = ciImage.cropped(to: ciRect)
            filter.scale = Float(max(imgRect.width, imgRect.height) / 10)

            guard let output = filter.outputImage,
                  let cg = context.createCGImage(output, from: ciRect) else { continue }

            let result = NSImage(cgImage: cg, size: b.rect.size)
            blurCache[b.id] = result
        }
        // Remove stale entries
        let ids = Set(store.annotations.map { $0.id })
        blurCache = blurCache.filter { ids.contains($0.key) }
    }

    // MARK: – In-progress preview

    private func inProgressAnnotation() -> Annotation? {
        guard let s = dragStart, let c = dragCurrent else { return nil }
        let rect = selectionRect(s, c)
        switch store.selectedTool {
        case .arrow:
            return .arrow(.init(start: s, end: c, color: store.selectedColor, lineWidth: store.lineWidth))
        case .rectangle:
            return .rect(.init(rect: rect, color: store.selectedColor, lineWidth: store.lineWidth))
        case .highlight:
            return .highlight(.init(rect: rect))
        case .text, .blur, .callout:
            return nil
        }
    }

    private func selectionRect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    // MARK: – Gestures

    private func dragGesture(geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .onChanged { v in
                if dragStart == nil { dragStart = v.startLocation }
                dragCurrent = v.location
            }
            .onEnded { v in
                defer { dragStart = nil; dragCurrent = nil }
                guard store.selectedTool != .text, store.selectedTool != .callout,
                      let s = dragStart else { return }
                let e = v.location
                let rect = selectionRect(s, e)
                guard rect.width > 4 || rect.height > 4 else { return }
                commit(start: s, end: e, rect: rect, canvasSize: geo.size)
            }
    }

    private func clickGesture(geo: GeometryProxy) -> some Gesture {
        SpatialTapGesture(coordinateSpace: .local)
            .onEnded { value in
                switch store.selectedTool {
                case .text:
                    pendingTextOrigin = value.location
                    pendingText = ""
                    textFieldFocused = true
                case .callout:
                    store.add(.callout(.init(center: value.location,
                                            number: store.nextCalloutNumber,
                                            color: store.selectedColor)))
                default:
                    break
                }
            }
    }

    // MARK: – Commit

    private func commit(start: CGPoint, end: CGPoint, rect: CGRect, canvasSize: CGSize) {
        switch store.selectedTool {
        case .arrow:
            store.add(.arrow(.init(start: start, end: end, color: store.selectedColor, lineWidth: store.lineWidth)))
        case .rectangle:
            store.add(.rect(.init(rect: rect, color: store.selectedColor, lineWidth: store.lineWidth)))
        case .highlight:
            store.add(.highlight(.init(rect: rect)))
        case .blur:
            store.add(.blur(.init(rect: rect)))
        case .text, .callout:
            break
        }
    }

    private func commitText(at origin: CGPoint) {
        let trimmed = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            store.add(.text(.init(origin: origin, content: trimmed,
                                  color: store.selectedColor, fontSize: 16)))
        }
        pendingTextOrigin = nil
        pendingText = ""
        textFieldFocused = false
    }
}
