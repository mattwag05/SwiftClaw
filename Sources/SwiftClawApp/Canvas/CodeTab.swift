import SwiftUI

/// Canvas Code tab — shows the file currently being written with line numbers
/// and a "writing" / "done" status badge.
struct CodeTab: View {
    let writingFile: (path: String, partial: String)?

    var body: some View {
        if let file = writingFile {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(file.path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("writing…")
                        .font(.system(.caption2, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            let lines = file.partial.components(separatedBy: "\n")
                            ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                                HStack(alignment: .top, spacing: 0) {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                        .frame(minWidth: 32, alignment: .trailing)
                                        .padding(.trailing, 12)
                                    Text(line)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 1)
                                .id(idx)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .onChange(of: file.partial) { _, _ in
                        let lines = file.partial.components(separatedBy: "\n")
                        withAnimation { proxy.scrollTo(lines.count - 1, anchor: .bottom) }
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "No file writing",
                systemImage: "doc.text",
                description: Text("The Code tab shows live content while the model writes a file.")
            )
        }
    }
}
