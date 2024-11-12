import SwiftUI

struct INText: View {
    let text: String
    let foregroundStyle: Color
    let font: Font
    let lineLimit: Int
    let multilineTextAlignment: TextAlignment

    init(_ text: String,
         foregroundStyle: Color = .white,
         font: Font? = nil,
         lineLimit: Int = 1,
         multilineTextAlignment: TextAlignment = .center) {
        self.text = text
        self.foregroundStyle = foregroundStyle
        self.font = font ?? .buttonFontMedium
        self.lineLimit = lineLimit
        self.multilineTextAlignment = multilineTextAlignment
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(foregroundStyle)
            .lineLimit(lineLimit)
            .multilineTextAlignment(multilineTextAlignment)
    }
}
