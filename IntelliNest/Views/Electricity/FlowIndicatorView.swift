import SwiftUI

struct FlowIndicatorView: View {
    let isFlowing: Bool
    /// Cycles per second — how fast each arrow travels the full track. Scaled by power upstream.
    var flowIntensity: Double
    let arrowCount: Int

    private let arrowWidth: CGFloat = 12
    private let arrowSpacing: CGFloat = 8

    private var trackWidth: CGFloat {
        CGFloat(max(arrowCount, 1)) * (arrowWidth + arrowSpacing)
    }

    var body: some View {
        if isFlowing {
            TimelineView(.animation(minimumInterval: nil)) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate * flowIntensity

                ZStack {
                    ForEach(0 ..< arrowCount, id: \.self) { index in
                        let progress = arrowProgress(phase: phase, index: index)
                        ArrowShape()
                            .frame(width: arrowWidth, height: 6)
                            .foregroundStyle(.yellow)
                            // Travel the length of the track and fade in/out at the ends so an arrow
                            // never pops into or out of existence mid-flow.
                            .offset(x: (progress - 0.5) * trackWidth)
                            .opacity(sin(progress * .pi))
                    }
                }
                .frame(width: trackWidth, height: 6)
            }
        }
    }

    /// Each arrow is offset along the cycle by an even fraction so they form a continuous stream.
    private func arrowProgress(phase: Double, index: Int) -> Double {
        guard arrowCount > 0 else { return 0 }
        let raw = (phase + Double(index) / Double(arrowCount)).truncatingRemainder(dividingBy: 1.0)
        return raw < 0 ? raw + 1 : raw
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
    FlowIndicatorView(isFlowing: true, flowIntensity: 1, arrowCount: 3)
}
