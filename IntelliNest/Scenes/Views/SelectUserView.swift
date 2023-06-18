//
//  SelectUserView.swift
//  IntelliNest
//
//  Created by Tobias on 2023-06-17.
//

import SwiftUI

struct SelectUserView: View {
    @State private var showingAlert = false

    var body: some View {
        VStack {}
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Select User"), primaryButton: .default(Text("TL")) {
                    UserDefaults.standard.set("TL", forKey: UserManager.storageKey)
                }, secondaryButton: .default(Text("SL")) {
                    UserDefaults.standard.set("SL", forKey: UserManager.storageKey)
                })
            }
    }
}

struct SelectUserView_Previews: PreviewProvider {
    static var previews: some View {
        SelectUserView()
    }
}
