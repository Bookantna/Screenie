import AppKit
import Observation

struct CaptureRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    var thumbnailData: Data   // PNG of a small thumbnail

    var thumbnail: NSImage? {
        NSImage(data: thumbnailData)
    }
}

@MainActor
@Observable
final class HistoryManager {
    private(set) var records: [CaptureRecord] = []
    private let maxCount = 20
    private let defaultsKey = "captureHistory"

    init() { load() }

    func add(_ image: NSImage) {
        guard let thumb = makeThumbnail(image),
              let png = thumb.pngData() else { return }
        let record = CaptureRecord(id: UUID(), date: Date(), thumbnailData: png)
        records.insert(record, at: 0)
        if records.count > maxCount { records = Array(records.prefix(maxCount)) }
        save()
    }

    func remove(_ record: CaptureRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func clearAll() {
        records = []
        save()
    }

    // MARK: – Private

    private func makeThumbnail(_ image: NSImage) -> NSImage? {
        let maxDim: CGFloat = 128
        let scale = min(maxDim / image.size.width, maxDim / image.size.height, 1.0)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let thumb = NSImage(size: size)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        thumb.unlockFocus()
        return thumb
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([CaptureRecord].self, from: data) else { return }
        records = decoded
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }
}
