//
//  TabbarView.swift
//  feather
//
//  Created by samara on 23.03.2025.
//

import SwiftUI

struct TabbarView: View {
	@Environment(\.scenePhase) private var scenePhase
	@State private var selectedTab: TabEnum = .new

	var body: some View {
		TabView(selection: $selectedTab) {
			ForEach(TabEnum.defaultTabs, id: \.hashValue) { tab in
				TabEnum.view(for: tab)
					.tabItem {
						Label(tab.title, systemImage: tab.icon)
					}
					.tag(tab)
			}
		}
		.onChange(of: scenePhase) { phase in
			if phase == .active {
				selectedTab = .new
			}
		}
	}
}
