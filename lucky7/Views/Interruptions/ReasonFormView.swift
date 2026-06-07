//
//  ReasonFormView.swift
//  lucky7
//
//  Created by Andrian on 30/05/26.
//

import SwiftUI

struct ReasonFormView: View {
    let appName: String
    @State private var reason: String = ""
    let onSubmit: (String) -> Void
    let onSkip: () -> Void

    @FocusState private var fieldFocused: Bool

    // straight off the figma — navy sheet gradient + dark navy "Reason" title
    private let sheetTop = Color(red: 0x00/255.0, green: 0x32/255.0, blue: 0x61/255.0)
    private let sheetBottom = Color(red: 0x0B/255.0, green: 0x1F/255.0, blue: 0x32/255.0)
    private let titleNavy = Color(red: 0x02/255.0, green: 0x2B/255.0, blue: 0x54/255.0)

    var body: some View {
        GeometryReader { geo in
            // card grows with the screen but stays sane on the small ones (lands ~420 on a normal phone)
            let cardHeight = min(420, max(geo.size.height * 0.50, 300))

            ZStack(alignment: .bottom) {
                // dimmed session behind the sheet (the figma dims the recording screen ~80% black)
                Color.black.opacity(0.82)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { fieldFocused = false }

                sheet(cardHeight: cardHeight)
            }
            // keep the sheet pinned to the bottom — don't let the keyboard shove it up and expose the scrim
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }

    private func sheet(cardHeight: CGFloat) -> some View {
        VStack(spacing: 20) {
            grabber
            reasonCard(height: cardHeight)
            buttons
        }
        .padding(.top, 14)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity)
        // navy panel, only the top corners rounded, runs off the bottom edge
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40)
                .fill(LinearGradient(colors: [sheetTop, sheetBottom], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: -8)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        // stop sign / 😩 / 🚧 cluster sits BEHIND the sheet and peeks over the top edge
        .background(alignment: .top) {
            Image("ReasonFormHeader")
                .resizable()
                .scaledToFit()
                .frame(width: 272)
                .offset(y: -140)
        }
    }

    private var grabber: some View {
        Capsule()
            .fill(.white.opacity(0.7))
            .frame(width: 56, height: 6)
    }

    private func reasonCard(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 36)
            .fill(.white)
            .frame(height: height)
            // faint swirl baked into the figma card
            .overlay {
                Image("Vector16")
                    .resizable()
                    .scaledToFill()
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reason")
                        .font(.custom("SpecialGothicExpandedOne-Regular", size: 32))
                        .foregroundStyle(titleNavy)

                    ZStack(alignment: .topLeading) {
                        if reason.isEmpty {
                            Text("I open this because….")
                                .font(.system(size: 22))
                                .foregroundStyle(.black.opacity(0.30))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)   // taps fall through to the editor + its caret
                        }
                        TextEditor(text: $reason)
                            .font(.system(size: 22))
                            .foregroundStyle(.black)   // card is always white, keep text black in both modes
                            .tint(.black)              // native blinking caret, black so it shows on white
                            .scrollContentBackground(.hidden)
                            .focused($fieldFocused)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") { fieldFocused = false }
                                }
                            }
                    }
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
            .clipShape(RoundedRectangle(cornerRadius: 36))
            .overlay {
                RoundedRectangle(cornerRadius: 36).strokeBorder(.black, lineWidth: 1.5)
            }
    }

    private var buttons: some View {
        // faded + disabled until they actually write something (matches the figma)
        let canSubmit = !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(spacing: 10) {
            Button {
                onSubmit(reason)
            } label: {
                pill(title: "SUBMIT & UNLOCK", bordered: false)
                    .opacity(canSubmit ? 1 : 0.5)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)

            Button(action: onSkip) {
                pill(title: "CANCEL", bordered: true)
            }
            .buttonStyle(.plain)
        }
    }

    private func pill(title: String, bordered: Bool) -> some View {
        Text(title)
            .font(.custom("SpecialGothicExpandedOne-Regular", size: 14))
            .tracking(0.5)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Capsule().fill(.white))
            .overlay {
                if bordered {
                    Capsule().strokeBorder(.black, lineWidth: 1.5)
                }
            }
    }
}

#Preview {
    ZStack {
        Color.gray
        ReasonFormView(
            appName: "Instagram",
            onSubmit: { _ in },
            onSkip: {}
        )
    }
}
