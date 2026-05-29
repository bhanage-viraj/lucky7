import SwiftUI

struct TrafficTicketView: View {
    let appName: String
    let countToday: Int
    let onBackToSession: () -> Void
    let onBreakIt: () -> Void

    var body: some View {
        ZStack {
            Color("CanvasBlue").ignoresSafeArea()

            VStack(spacing: 16) {
                ticketCard
                buttons
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
    }

    private var ticketCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(appName) has Ruined The Journey")
                .font(.custom("SpecialGothicExpandedOne-Regular", size: 30))
                .foregroundColor(Color("CanvasBlue"))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(countToday)x Today")
                .font(.custom("SpecialGothicExpandedOne-Regular", size: 40))
                .foregroundColor(Color("CanvasBlue"))
                .padding(.top, 4)

            Spacer(minLength: 16)

            copWithStopSign
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28).fill(.white)
        )
    }

    private var copWithStopSign: some View {
        ZStack(alignment: .topLeading) {
            Image("TicketCop")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, alignment: .trailing)

            Image("TicketStopSign")
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 130)
                .offset(x: -10, y: -10)
        }
        .frame(maxWidth: .infinity, maxHeight: 240)
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            Button(action: onBackToSession) {
                Text("BACK TO SESSION")
                    .font(.custom("SpecialGothicExpandedOne-Regular", size: 15))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(.black, in: Capsule())
            }
            Button(action: onBreakIt) {
                Text("BREAK IT")
                    .font(.custom("SpecialGothicExpandedOne-Regular", size: 15))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color("ButtonRed"), in: Capsule())
            }
        }
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
