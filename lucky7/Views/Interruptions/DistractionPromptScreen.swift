import SwiftUI

struct DistractionPromptScreen: View {
    let appName: String
    let countToday: Int
    let onBackToSession: () -> Void
    let onBreakWithReason: (String) -> Void

    @State private var step: Step = .ticket

    enum Step { case ticket, reason }

    var body: some View {
        ZStack {
            switch step {
            case .ticket:
                TrafficTicketView(
                    appName: appName,
                    countToday: countToday,
                    onBackToSession: onBackToSession,
                    onBreakIt: { withAnimation(.easeInOut(duration: 0.25)) { step = .reason } }
                )
                .transition(.opacity)

            case .reason:
                ReasonFormView(
                    appName: appName,
                    onSubmit: { reason in onBreakWithReason(reason) },
                    onSkip: { onBreakWithReason("") }
                )
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    DistractionPromptScreen(
        appName: "YouTube",
        countToday: 1,
        onBackToSession: {},
        onBreakWithReason: { _ in }
    )
}
