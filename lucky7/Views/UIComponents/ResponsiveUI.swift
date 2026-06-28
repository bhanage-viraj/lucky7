import SwiftUI

struct ResponsiveMetrics {
    let size: CGSize
    let safeArea: EdgeInsets
    let horizontalSizeClass: UserInterfaceSizeClass?
    let verticalSizeClass: UserInterfaceSizeClass?

    var width: CGFloat { size.width }
    var height: CGFloat { size.height }
    var isLandscape: Bool { width > height }
    var isNarrow: Bool { width < 390 }
    var isShort: Bool { height < 720 }
    var isWide: Bool { width >= 700 }
    var isPad: Bool { horizontalSizeClass == .regular && width >= 700 }
    var prefersTwoColumns: Bool { isPad && isLandscape && width >= 900 }

    var horizontalPadding: CGFloat {
        if isPad { return prefersTwoColumns ? 36 : 32 }
        return isNarrow ? 16 : 20
    }

    var verticalPadding: CGFloat {
        if isPad { return 28 }
        return isShort ? 16 : 24
    }

    var contentMaxWidth: CGFloat {
        if prefersTwoColumns { return 1120 }
        if isPad { return 720 }
        return .infinity
    }

    var cardMaxWidth: CGFloat {
        if prefersTwoColumns { return 540 }
        if isPad { return 680 }
        return .infinity
    }

    var compactScale: CGFloat {
        let widthScale = width / 402
        let heightScale = height / 874
        return min(widthScale, heightScale)
            .clamped(to: (isPad ? 0.98 : 0.82)...(isPad ? 1.22 : 1.0))
    }

    func scaled(_ value: CGFloat, min minValue: CGFloat? = nil, max maxValue: CGFloat? = nil) -> CGFloat {
        var result = value * compactScale
        if let minValue { result = Swift.max(result, minValue) }
        if let maxValue { result = Swift.min(result, maxValue) }
        return result
    }

    func portraitMediaWidth(maxPhone: CGFloat = 340, maxPad: CGFloat = 430, reservedHeight: CGFloat = 180) -> CGFloat {
        let usableWidth = max(width - horizontalPadding * 2, 1)
        let usableHeight = max(height - safeArea.top - safeArea.bottom - reservedHeight, 220)
        let widthFromHeight = usableHeight * 9 / 16
        return min(usableWidth, widthFromHeight, isPad ? maxPad : maxPhone)
    }
}

struct ResponsiveReader<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var content: (ResponsiveMetrics) -> Content

    init(@ViewBuilder content: @escaping (ResponsiveMetrics) -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            content(
                ResponsiveMetrics(
                    size: proxy.size,
                    safeArea: proxy.safeAreaInsets,
                    horizontalSizeClass: horizontalSizeClass,
                    verticalSizeClass: verticalSizeClass
                )
            )
        }
    }
}

struct AdaptivePatternBackground: View {
    var smallPattern = false
    var yOffset: CGFloat = -30

    var body: some View {
        ZStack {
            Color("CanvasBlue").ignoresSafeArea()
            Image(smallPattern ? "PatternBackgroundSmall" : "PatternBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .offset(y: yOffset)
                .accessibilityDecorative()
        }
    }
}

struct AdaptiveScrollContent<Content: View>: View {
    let metrics: ResponsiveMetrics
    var topPadding: CGFloat?
    var bottomPadding: CGFloat = 40
    var maxWidth: CGFloat?
    var showsIndicators = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(showsIndicators: showsIndicators) {
            content()
                .frame(maxWidth: maxWidth ?? metrics.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.top, topPadding ?? metrics.verticalPadding)
                .padding(.bottom, bottomPadding + metrics.safeArea.bottom)
        }
    }
}

struct AdaptiveIconButton: View {
    let systemName: String
    var foreground: Color = .white
    var fontSize: CGFloat = 20
    var weight: Font.Weight = .bold
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: fontSize, weight: weight))
                .foregroundColor(foreground)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct AdaptivePrimaryButton<Label: View>: View {
    var isDisabled = false
    var background: Color = .black
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .padding(.vertical, 2)
                .foregroundColor(.white.opacity(isDisabled ? 0.72 : 1))
                .background(Capsule().fill(background))
                .contentShape(Capsule())
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.75 : 1)
    }
}

struct AdaptiveEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct AdaptiveLoadingOverlay: View {
    let title: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)
                Text(title)
                    .font(.custom("Special Gothic Expanded One", size: 16))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

extension View {
    func adaptiveReadableFrame(_ metrics: ResponsiveMetrics, maxWidth: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        self
            .frame(maxWidth: maxWidth ?? metrics.contentMaxWidth, alignment: alignment)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
