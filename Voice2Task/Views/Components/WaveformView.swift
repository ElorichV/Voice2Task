import SwiftUI

struct WaveformView: View {
    let level: Float
    @State private var history = Array(repeating: Float(0.08), count: 24)

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(history.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.accentColor.opacity(0.45 + Double(history[index]) * 0.55))
                    .frame(width: 4, height: max(4, CGFloat(history[index]) * 48))
            }
        }
        .frame(height: 52)
        .onChange(of: level) { _, newLevel in
            withAnimation(.linear(duration: 0.08)) {
                history.removeFirst()
                history.append(max(0.08, min(newLevel, 1)))
            }
        }
        .accessibilityLabel("Forma de onda de audio")
    }
}
