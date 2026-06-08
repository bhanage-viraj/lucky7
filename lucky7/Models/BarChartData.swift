//
//  BarChartData.swift
//  lucky7
//
//  Created by Andrian on 08/06/26.
//

import Foundation

struct BarChartData: Identifiable {
    let id = UUID()
    let label: String
    let primary: Double    
    let secondary: Double
}
