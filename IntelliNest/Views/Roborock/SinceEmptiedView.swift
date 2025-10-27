import SwiftUI

struct SinceEmptiedView: View {
    var emptiedAtDate: String
    var areaSinceEmpty: Double

    var body: some View {
        HStack(alignment: .top) {
            Text("Senaste tömningen: ")
                .foregroundColor(.white)
            VStack(alignment: .trailing) {
                Text("\(emptiedAtDate.components(separatedBy: " ")[0])")
                    .foregroundColor(.white)
                Text("\(Int(areaSinceEmpty)) m²")
                    .foregroundColor(.white)
            }
            Spacer()
        }
    }
}

struct SinceEmptied_Previews: PreviewProvider {
    static var previews: some View {
        SinceEmptiedView(emptiedAtDate: "", areaSinceEmpty: 15)
    }
}
