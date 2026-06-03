//
//  TrafficTicketView.swift
//  lucky7
//
//  Created by Andrian on 30/05/26.
//

import SwiftUI

struct TrafficTicketView: View {
    let appName: String
    let countToday: Int
    let onBackToSession: () -> Void
    let onBreakIt: () -> Void

    private let primaryBlue = Color(red: 0x18/255.0, green: 0x80/255.0, blue: 0xE5/255.0)
    private let titleBlue = Color(red: 0x46/255.0, green: 0x99/255.0, blue: 0xEA/255.0)
    private let buttonRed = Color(red: 0xEA/255.0, green: 0x43/255.0, blue: 0x4D/255.0)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color("CanvasBlue").ignoresSafeArea()

                Image("TicketCardPattern")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width)
                    .opacity(0.22)
                    .clipped()
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ticketCard
                    buttons
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    private var ticketCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32).fill(.black).offset(y: 6)
            RoundedRectangle(cornerRadius: 32).fill(.white)

            VStack(alignment: .leading, spacing: 0) {
                titleBlock
                Spacer(minLength: 0)
                illustration
            }
            .padding(.horizontal, 28)
            .padding(.top, 32)
            .padding(.bottom, 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 32))

            // Border drawn last so the illustration sits behind it
            RoundedRectangle(cornerRadius: 32).strokeBorder(.black, lineWidth: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(appName)
                .font(.custom("SpecialGothicExpandedOne-Regular", size: 30))
                .foregroundColor(titleBlue)
            Text("has Ruined")
                .font(.custom("SpecialGothicExpandedOne-Regular", size: 30))
                .foregroundColor(titleBlue)
            Text("The Journey")
                .font(.custom("SpecialGothicExpandedOne-Regular", size: 30))
                .foregroundColor(titleBlue)
            Text("\(countToday)x Today")
                .font(.custom("SpecialGothicExpandedOne-Regular", size: 42))
                .foregroundColor(primaryBlue)
                .padding(.top, 8)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var illustration: some View {
        Image("TicketIllustration")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, alignment: .trailing)
            .frame(maxHeight: 300)
            .padding(.trailing, -20)
    }

    private var buttons: some View {
        VStack(spacing: 14) {
            chunkyButton(title: "BACK TO SESSION", background: .black, action: onBackToSession)
            chunkyButton(title: "BREAK IT", background: buttonRed, action: onBreakIt)
        }
    }

    private func chunkyButton(title: String, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("SpecialGothicExpandedOne-Regular", size: 16))
                .tracking(1.0)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(background)
                        .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                )
                .shadow(color: .black, radius: 0, x: 1, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TrafficTicketView(
        appName: "YouTube",
        countToday: 1,
        onBackToSession: {},
        onBreakIt: {}
    )
}
