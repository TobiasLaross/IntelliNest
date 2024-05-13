import SwiftUI

struct INText: View {
    var text: String
    var font: Font

    init(_ text: String, font: Font? = nil) {
        self.text = text
        self.font = font ?? .buttonFontMedium
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(.white)
    }
}
