//
//  LegendItem.swift
//  lucky7
//
//  Created by Andrian on 08/06/26.
//



import SwiftUI

struct LegendItemView: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 14))
        }
    }
}
