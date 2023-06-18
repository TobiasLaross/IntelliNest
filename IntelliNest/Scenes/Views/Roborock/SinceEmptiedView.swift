//
//  SinceEmptied.swift
//  IntelliNest
//
//  Created by Tobias on 2022-06-22.
//

import SwiftUI

struct SinceEmptiedView: View {
    var emptiedAtDate: String
    var areaSinceEmpty: String

    var body: some View {
        HStack(alignment: .top) {
            Text("Senaste tömningen: ")
                .foregroundColor(.white)
            VStack(alignment: .trailing) {
                Text("\(emptiedAtDate.components(separatedBy: " ")[0])")
                    .foregroundColor(.white)
                Text("\(areaSinceEmpty.components(separatedBy: ".")[0]) m²")
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .background(bodyColor)
    }
}

struct SinceEmptied_Previews: PreviewProvider {
    static var previews: some View {
        SinceEmptiedView(emptiedAtDate: "", areaSinceEmpty: "")
    }
}
