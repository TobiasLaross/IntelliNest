//
//  FlowIndicatorView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-12-20.
//

import SwiftUI

struct FlowIndicatorView: View {
    @State private var pulsate: [Bool]
    @Binding var isFlowing: Bool
    var flowIntensity: Double
    let arrowCount: Int

    var body: some View {
        if isFlowing {
            HStack(spacing: 14) {
                ForEach(0 ..< arrowCount, id: \.self) { index in
                    ArrowShape()
                        .frame(width: 12, height: 6)
                        .foregroundStyle(.yellow)
                        .scaleEffect(pulsate[index] ? 1.2 : 0.8)
                        .opacity(pulsate[index] ? 1 : 0)
                }
            }
            .onAppear {
                startAnimating()
            }
        }
    }

    private func startAnimating() {
        Task { @MainActor in
            for index in 0 ..< arrowCount {
                try? await Task.sleep(seconds: 0.25)
                withAnimation(.easeInOut(duration: 1 / (3 * max(flowIntensity, 0.05)))
                    .repeatForever(autoreverses: false)) {
                        pulsate[index].toggle()
                    }
            }
        }
    }

    init(isFlowing: Binding<Bool>, flowIntensity: Double, arrowCount: Int) {
        self._pulsate = State(initialValue: Array(repeating: false, count: arrowCount))
        self._isFlowing = isFlowing
        self.flowIntensity = flowIntensity
        self.arrowCount = arrowCount
    }
}

private struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height / 2))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width / 4, y: rect.height / 2))
        path.addLine(to: CGPoint(x: 0, y: 0))
        return path
    }
}

#Preview {
    FlowIndicatorView(isFlowing: .constant(true), flowIntensity: 1, arrowCount: 3)
}
