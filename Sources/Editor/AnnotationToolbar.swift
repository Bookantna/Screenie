import SwiftUI

struct AnnotationToolbar: View {
    @Bindable var store: AnnotationStore

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AnnotationTool.allCases, id: \.self) { tool in
                Button {
                    store.selectedTool = tool
                } label: {
                    Image(systemName: tool.icon)
                        .frame(width: 28, height: 28)
                        .background(store.selectedTool == tool ? Color.accentColor.opacity(0.2) : .clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(tool.label)
            }

            Divider().frame(height: 20).padding(.horizontal, 4)

            ColorPicker("", selection: $store.selectedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 28, height: 28)
                .help("Stroke color")

            Divider().frame(height: 20).padding(.horizontal, 4)

            Stepper(value: $store.lineWidth, in: 1...8, step: 1) {
                Text("\(Int(store.lineWidth))px")
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 30)
            }
            .help("Stroke width")

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
