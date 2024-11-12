import SwiftUI

struct FlowIndicatorView: View {
    @Binding var isFlowing: Bool
    var flowIntensity: Double
    let arrowCount: Int

    var body: some View {
        if isFlowing {
            TimelineView(.animation(minimumInterval: nil)) { timeline in
                let date = timeline.date.timeIntervalSinceReferenceDate
                let phase = date * flowIntensity

                HStack {
                    ForEach(0 ..< arrowCount, id: \.self) { index in
                        ArrowShape()
                            .frame(width: 12, height: 6)
                            .foregroundStyle(.yellow)
                            .opacity(arrowOpacity(phase: phase, index: index))
                    }
                }
            }
        }
    }

    private func arrowOpacity(phase: Double, index: Int) -> Double {
        guard arrowCount > 0 else { return 0 }
        let position = (phase - Double(index) / Double(arrowCount)).truncatingRemainder(dividingBy: 1.0)
        return max(0, sin(position * 2 * .pi))
    }
}

private struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.width, y: rect.height / 2))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width / 4, y: rect.height / 2))
        path.closeSubpath()
        return path
    }
}

#Preview {
    FlowIndicatorView(isFlowing: .constant(true), flowIntensity: 1, arrowCount: 3)
}
