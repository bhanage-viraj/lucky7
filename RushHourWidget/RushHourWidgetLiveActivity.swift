//
//  RushHourWidgetLiveActivity.swift
//  RushHourWidget
//
//  Created by Andrian on 02/06/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

private let rushRed = Color(red: 224.0 / 255, green: 45.0 / 255, blue: 56.0 / 255)

struct RushHourWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BreakActivityAttributes.self) { context in
            // lock screen / banner card — they're on a distraction break
            ZStack {
                Image("NotificationBlockedApp")
                    .resizable()
                    .scaledToFill()

                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text(timerInterval: context.state.startedAt...context.state.endsAt,
                             countsDown: true)
                            .font(.system(size: 46, weight: .heavy))
                            .monospacedDigit()
                            .foregroundColor(.white)

                        Spacer(minLength: 16)

                        Text(context.state.statusText)
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Image("RushHourLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 56)
                }
                .padding(20)
            }
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image("RushHourLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startedAt...context.state.endsAt,
                         countsDown: true)
                        .font(.system(size: 22, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .frame(maxWidth: 78)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.statusText)
                        .font(.headline)
                        .foregroundColor(.white)
                }
            } compactLeading: {
                Image("RushHourLogo")
                    .resizable()
                    .scaledToFit()
            } compactTrailing: {
                Text(timerInterval: context.state.startedAt...context.state.endsAt,
                     countsDown: true)
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .frame(maxWidth: 44)
            } minimal: {
                Image("RushHourLogo")
                    .resizable()
                    .scaledToFit()
            }
            .keylineTint(rushRed)
        }
    }
}

extension BreakActivityAttributes {
    fileprivate static var preview: BreakActivityAttributes {
        BreakActivityAttributes(appName: "Instagram")
    }
}

extension BreakActivityAttributes.ContentState {
    fileprivate static var sample: BreakActivityAttributes.ContentState {
        BreakActivityAttributes.ContentState(
            startedAt: Date(),
            endsAt: Date().addingTimeInterval(15 * 60),
            statusText: "Opening Distracted App"
        )
    }
}

#Preview("Lock Screen", as: .content, using: BreakActivityAttributes.preview) {
    RushHourWidgetLiveActivity()
} contentStates: {
    BreakActivityAttributes.ContentState.sample
}
