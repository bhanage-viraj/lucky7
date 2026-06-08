//
//  BarChartConfig.swift
//  lucky7
//
//  Created by Andrian on 08/06/26.
//

import SwiftUI

// MARK: - Config
struct BarChartConfig {
    var primaryColor: Color = .blue
    var secondaryColor: Color = .orange
    var primaryLabel: String = "Focused"
    var secondaryLabel: String = "Distracted"
    var maxValue: Double = 120
    var barWidth: CGFloat = 12
    var gridLines: [Int] = [120, 90, 60, 30, 0]
    var showLegend: Bool = true
    var showYAxis: Bool = true
}
