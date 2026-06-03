import SwiftUI

struct NumberScroller: View {

    @Binding var selected: Int
    let range: ClosedRange<Int>
    private let repetitionCount = 120
    @State private var scrollPosition: Int?

    private var values: [Int] {
        Array(range)
    }

    private var totalCount: Int {
        values.count * repetitionCount
    }

    private func value(for index: Int) -> Int {
        values[index % values.count]
    }

    private func initialIndex(for value: Int) -> Int {
        let offset = value - range.lowerBound
        let middle = totalCount / 2
        let base = middle - (middle % values.count)
        return base + offset
    }

    var body: some View {

        ScrollView(.vertical, showsIndicators: false) {

            LazyVStack(spacing: 4) {

                ForEach(0..<totalCount, id: \.self) { index in
                    let number = value(for: index)

                    NumberCell(
                        number: number,
                        isSelected: selected == number
                    )
                    .id(index)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 18)
        }
        .frame(width: 92, height: 106)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPosition)
        .defaultScrollAnchor(.center)
        .scrollClipDisabled()
        .clipped()
        .onAppear {
            if scrollPosition == nil {
                scrollPosition = initialIndex(for: selected)
            }
        }
        .onChange(of: scrollPosition) { _, newValue in
            guard let newValue else { return }
            selected = value(for: newValue)
        }
    }
}

// MARK: - CELL

struct NumberCell: View {

    let number: Int
    let isSelected: Bool

    var body: some View {

        Text(String(format: "%02d", number))
            .font(
                .system(
                    size: isSelected ? 54 : 38,
                    weight: .black,
                    design: .rounded
                )
            )
            .italic()
            .foregroundStyle(
                isSelected
                ? .white
                : .white.opacity(0.18)
            )
            .scaleEffect(isSelected ? 1 : 0.82)
            .animation(
                .smooth(duration: 0.18),
                value: isSelected
            )
            .frame(height: 52)
            .frame(maxWidth: .infinity)
    }
}
