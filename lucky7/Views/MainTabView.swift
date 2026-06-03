//
//  MainTabView.swift
//  lucky7
//
//  Created by Andrian on 02/06/26.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomePage()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            BreakRecordsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
}
