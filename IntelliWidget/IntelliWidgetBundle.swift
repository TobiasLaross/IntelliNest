//
//  IntelliWidgetBundle.swift
//  IntelliWidget
//
//  Created by Tobias on 2024-01-12.
//

import SwiftUI
import WidgetKit

@main
struct IntelliWidgetBundle: WidgetBundle {
    var body: some Widget {
        HomeWidget()
        CarHeaterWidget()
    }
}
