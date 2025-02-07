import SwiftUI

struct INText: View {
    let text: String
    let foregroundStyle: Color
    let font: Font
    let lineLimit: Int
    let minimumScaleFactor: CGFloat
    let multilineTextAlignment: TextAlignment
    let maxWidth: CGFloat?
    let maxHeight: CGFloat?
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    var trimmedText: String {
        text.removeDoubleSpaces
    }

    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    var attributedText: AttributedString {
        (try? AttributedString(markdown: trimmedText, options: options)) ?? AttributedString(trimmedText)
    }

    var body: some View {
        Text(attributedText)
            .multilineTextAlignment(multilineTextAlignment)
            .minimumScaleFactor(minimumScaleFactor)
            .font(font)
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .lineLimit(lineLimit)
            .frame(maxWidth: maxWidth, maxHeight: maxHeight)
            .truncationMode(.tail)
    }

    init(_ text: String,
         foregroundStyle: Color = .white,
         font: Font = .body,
         lineLimit: Int = .max,
         multilineTextAlignment: TextAlignment = .center,
         minimumScaleFactor: CGFloat = 0.1,
         maxWidth: CGFloat? = nil,
         maxHeight: CGFloat? = nil,
         horizontalPadding: CGFloat = 0,
         verticalPadding: CGFloat = 0) {
        self.text = text
        self.font = font
        self.foregroundStyle = foregroundStyle
        self.lineLimit = lineLimit
        self.multilineTextAlignment = multilineTextAlignment
        self.minimumScaleFactor = minimumScaleFactor
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }
}
