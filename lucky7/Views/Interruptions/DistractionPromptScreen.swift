//
//  DistractionPromptScreen.swift
//  lucky7
//
//  Created by Andrian on 29/05/26.
//

import SwiftUI

struct DistractionPromptScreen: View {
    let appName: String
    let countToday: Int
    let onBackToSession: () -> Void
    let onBreakWithReason: (String) -> Void

    @State private var step: Step

    enum Step { case ticket, reason }

    // when the break already happened on the shield, jump straight to the reason
    init(
        appName: String,
        countToday: Int,
        startAtReason: Bool = false,
        onBackToSession: @escaping () -> Void,
        onBreakWithReason: @escaping (String) -> Void
    ) {
        self.appName = appName
        self.countToday = countToday
        self.onBackToSession = onBackToSession
        self.onBreakWithReason = onBreakWithReason
        _step = State(initialValue: startAtReason ? .reason : .ticket)
    }

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
