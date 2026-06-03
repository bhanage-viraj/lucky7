
import SwiftUI

// MARK: - Data Model
struct BarChartData: Identifiable {
    let id = UUID()
    let label: String
    let primary: Double    
    let secondary: Double
}

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

// MARK: - Main Chart View
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
            LegendItem(color: config.primaryColor, label: config.primaryLabel)
            LegendItem(color: config.secondaryColor, label: config.secondaryLabel)
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

// MARK: - Legend Item
struct LegendItem: View {
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
