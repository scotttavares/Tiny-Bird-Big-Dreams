import SwiftUI

/// The scrolling script. The line being read sits near the top edge, just under the lens.
struct PrompterView: View {
    let engine: PrompterEngine
    var fontSize: CGFloat = 34

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: fontSize * 0.5) {
                    ForEach(Array(engine.lines.enumerated()), id: \.offset) { index, line in
                        Text(line.text)
                            .font(.system(size: fontSize, weight: index == engine.currentLine ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(color(for: index))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                    }
                    // Room for the last line to reach the reading spot.
                    Color.clear.frame(height: 400)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
            }
            .scrollDisabled(engine.isPlaying)
            .scrollIndicators(.hidden)
            .onChange(of: engine.currentLine, initial: true) { _, line in
                withAnimation(.easeInOut(duration: 0.45)) {
                    reader.scrollTo(line, anchor: UnitPoint(x: 0, y: 0.08))
                }
            }
        }
        .background(Color("StageColor"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(engine.lines.indices.contains(engine.currentLine) ? engine.lines[engine.currentLine].text : "")
    }

    private func color(for index: Int) -> Color {
        if index == engine.currentLine { return .white }
        if index < engine.currentLine { return .white.opacity(0.3) }
        return .white.opacity(0.6)
    }
}
