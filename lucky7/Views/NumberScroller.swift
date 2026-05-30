import SwiftUI

struct NumberScroller: View {

    @Binding var selected: Int?

    var body: some View {

        ScrollView(.vertical, showsIndicators: false) {

            LazyVStack(spacing: 4) {

                ForEach(0..<60, id: \.self) { number in

                    NumberCell(
                        number: number,
                        isSelected: selected == number
                    )
                    .id(number)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 18)
        }
        .frame(width: 92, height: 106)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $selected)
        .defaultScrollAnchor(.center)
        .scrollClipDisabled()
        .clipped()
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
