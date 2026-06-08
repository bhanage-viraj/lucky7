//
//  BarChartView 2.swift
//  lucky7
//
//  Created by Andrian on 08/06/26.
//

import SwiftUI

struct BarChartView: View {
    let data: [BarChartData]
    var config: BarChartConfig = BarChartConfig()

    var body: some View {
        VStack(spacing: 0) {
            if config.showLegend {
                legendView
                    .padding(.bottom, 16)
            }

            HStack(alignment: .bottom, spacing: 0) {
                if config.showYAxis {
                    yAxisView
                        .padding(.bottom, 24)
                }

                GeometryReader { geo in
                    let chartHeight = geo.size.height - 24

                    ZStack(alignment: .bottomLeading) {
                        gridLinesView(height: chartHeight)
                        barsView(height: chartHeight)
                    }
                }
            }
        }
    }

    // MARK: - Subviews
    private var legendView: some View {
        HStack(spacing: 24) {
            LegendItemView(color: config.primaryColor, label: config.primaryLabel)
            LegendItemView(color: config.secondaryColor, label: config.secondaryLabel)
            Spacer()
        }
    }

    private var yAxisView: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(config.gridLines, id: \.self) { val in
                Text("\(val)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(width: 40)
    }

    private func gridLinesView(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(config.gridLines, id: \.self) { _ in
                Divider()
                    .background(Color.gray.opacity(0.3))
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }

    private func barsView(height: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(data) { item in
                VStack(spacing: 4) {
                    ZStack(alignment: .bottom) {
                        // Primary bar
                        if item.primary > 0 {
                            Capsule()
                                .fill(config.primaryColor)
                                .frame(
                                    width: config.barWidth,
                                    height: CGFloat(item.primary / config.maxValue) * height
                                )
                        }

                        // Secondary bar (stacked on top)
                        if item.secondary > 0 {
                            let totalHeight = CGFloat((item.primary + item.secondary) / config.maxValue) * height
                            let secondaryHeight = CGFloat(item.secondary / config.maxValue) * height

                            Capsule()
                                .fill(config.secondaryColor)
                                .frame(width: config.barWidth, height: totalHeight)
                                .mask(
                                    VStack(spacing: 0) {
                                        Capsule()
                                            .frame(width: config.barWidth, height: secondaryHeight)
                                        Spacer(minLength: 0)
                                    }
                                    .frame(height: totalHeight)
                                )
                        }
                    }
                    .frame(height: height, alignment: .bottom)

                    Text(item.label)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .frame(height: 24)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
