import SwiftUI
import Observation

@MainActor
@Observable
final class AnnotationStore {
    var annotations: [Annotation] = []
    var selectedTool: AnnotationTool = .arrow
    var selectedColor: Color = .red
    var lineWidth: CGFloat = 2

    private var undoStack: [[Annotation]] = []

    func add(_ annotation: Annotation) {
        undoStack.append(annotations)
        annotations.append(annotation)
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        annotations = previous
    }

    var canUndo: Bool { !undoStack.isEmpty }

    var nextCalloutNumber: Int {
        annotations.filter { if case .callout = $0 { true } else { false } }.count + 1
    }
}
