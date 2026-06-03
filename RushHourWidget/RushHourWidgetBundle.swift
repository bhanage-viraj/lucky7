//
//  RushHourWidgetBundle.swift
//  RushHourWidget
//
//  Created by Andrian on 02/06/26.
//

import WidgetKit
import SwiftUI

@main
struct RushHourWidgetBundle: WidgetBundle {
    var body: some Widget {
        RushHourWidget()
        RushHourWidgetControl()
        RushHourWidgetLiveActivity()
    }
}
