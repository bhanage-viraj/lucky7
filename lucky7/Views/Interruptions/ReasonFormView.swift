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

    private let reasonRed = Color(red: 0xE0/255.0, green: 0x2D/255.0, blue: 0x38/255.0)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color("CanvasRed")

                Image("TicketCardPattern")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.18)
                    .clipped()

                VStack(spacing: 0) {
                    Spacer(minLength: 50)

                    Image("ReasonFormHeader")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 70)
                        .offset(y: 40)
                        .zIndex(2)

                    reasonCard
                        .zIndex(1)

                    buttons
                        .padding(.top, 16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { fieldFocused = false }
    }

    private var reasonCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32).fill(.black).offset(y: 6)
            RoundedRectangle(cornerRadius: 32)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: 32).strokeBorder(.black, lineWidth: 2))

            VStack(alignment: .leading, spacing: 12) {
                Text("Reason")
                    .font(.custom("SpecialGothicExpandedOne-Regular", size: 30))
                    .foregroundStyle(reasonRed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                ZStack(alignment: .topLeading) {
                    if reason.isEmpty {
                        Text("I open this because….")
                            .font(.system(size: 18))
                            .foregroundStyle(.black.opacity(0.35))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                    TextEditor(text: $reason)
                        .font(.system(size: 18))
                        .foregroundColor(.black)   // card is always white, so keep text black in both modes
                        .tint(.black)
                        .scrollContentBackground(.hidden)
                        .focused($fieldFocused)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 180)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 32))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var buttons: some View {
        VStack(spacing: 6) {
            Button {
                onSubmit(reason)
            } label: {
                Text("SUBMIT")
                    .font(.custom("SpecialGothicExpandedOne-Regular", size: 16))
                    .tracking(1.0)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Capsule()
                            .fill(.black)
                            .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                    )
                    .shadow(color: .black, radius: 0, x: 1, y: 4)
            }
            .buttonStyle(.plain)

            Button(action: onSkip) {
                Text("SKIP")
                    .font(.custom("SpecialGothicExpandedOne-Regular", size: 16))
                    .tracking(1.4)
                    .foregroundStyle(.white)
                    .padding(.vertical, 14)
            }
        }
    }
}

#Preview {
    ReasonFormView(
        appName: "Instagram",
        onSubmit: { _ in },
        onSkip: {}
    )
}
