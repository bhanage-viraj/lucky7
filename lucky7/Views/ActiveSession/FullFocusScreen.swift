// Views/ActiveSession/FullFocusScreen.swift
//
// The full-focus layout is now rendered *inline* inside RecordingPage
// (see expandedSessionOverlay). This file retains the MarqueeText utility
// in case it's needed elsewhere.

import SwiftUI

// MARK: - MarqueeText

struct MarqueeText: View {
    let text: String
    @State private var animate = false
    @State private var ready = false

    private let maxWidth: CGFloat = 180
    private let font = UIFont.systemFont(ofSize: 17)

    var textWidth: CGFloat {
        text.size(withAttributes: [.font: font]).width
    }

    var width: CGFloat {
        min(textWidth, maxWidth)
    }

    var body: some View {
        let shouldAnimate = textWidth > width

        ZStack(alignment: .leading) {
            if shouldAnimate {
                HStack(spacing: 40) {
                    Text(text)
                        .foregroundColor(.white)
                        .fixedSize()
                    Text(text)
                        .foregroundColor(.white)
                        .fixedSize()
                }
                .offset(x: animate ? -(textWidth + 40) : 0)
                .opacity(ready ? 1 : 0)
                .onAppear {
                    DispatchQueue.main.async {
                        ready = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(
                                .linear(duration: Double(textWidth) / 25)
                                .repeatForever(autoreverses: false)
                            ) {
                                animate = true
                            }
                        }
                    }
                }
            } else {
                Text(text)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(width: width, alignment: .leading)
        .clipped()
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color("CanvasDarkGrey"))
        )
    }
}
