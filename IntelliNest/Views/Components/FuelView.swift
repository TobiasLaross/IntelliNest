import SwiftUI

struct FuelView: View {
    var level: Int
    var maxLevel: Double
    var degreeRotation: Double
    var width: CGFloat
    var height: CGFloat

    private let fuelCornerRadius: CGFloat = 15

    init(level: Int, maxLevel: Int = 42, degreeRotation: Double = 0, width: CGFloat = 50, height: CGFloat = 90) {
        self.level = level
        self.maxLevel = Double(maxLevel)
        self.degreeRotation = degreeRotation
        self.width = width
        self.height = height
    }

    var body: some View {
        ZStack {
            Group {
                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: width, height: height, alignment: .bottom)
                    .cornerRadius(fuelCornerRadius)
                Rectangle()
                    .fill(Double(level) > 0.6 * maxLevel ? .green : Double(level) > 0.3 * maxLevel ? .yellow : .red)
                    .frame(width: width, height: height, alignment: .bottom)
                    .scaleEffect(CGSize(width: 1, height: CGFloat(level) / maxLevel), anchor: .bottom)
                    .cornerRadius(fuelCornerRadius)
            }
            .rotationEffect(.degrees(degreeRotation))

            Text("\(level)L")
                .font(Font.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.2)
                .foregroundColor(.white)
        }
    }
}
