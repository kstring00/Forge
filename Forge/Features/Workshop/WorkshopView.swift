import SwiftUI
import SwiftData
import ForgeCore

/// The Reality tab: ideas out in the world. Steps, logging, launch, the Journal.
struct WorkshopView: View {
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    private var active: [Project] { projects.filter { $0.status == .active } }
    private var paused: [Project] { projects.filter { $0.status == .paused } }
    private var done: [Project] { projects.filter { $0.status == .done || $0.status == .archived } }

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    EmptyState(symbol: ForgeTab.reality.symbol,
                               title: "Nothing in reality yet",
                               message: "When the panel checks an idea and you say it looks right, the first step lands here.")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: ForgeSpacing.l) {
                            Text(Track.reality.tagline).font(.system(size: 13)).foregroundStyle(ForgeColor.inkSecondary)
                            group("Active", active)
                            group("Paused", paused)
                            group("Launched", done)
                        }
                        .padding(ForgeSpacing.m)
                        .padding(.bottom, ForgeSpacing.xxl)
                    }
                }
            }
            .background(ForgeColor.canvas)
            .navigationTitle(Track.reality.displayName)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: WorkshopRoute.journal) {
                        Image(systemName: "book.closed").accessibilityLabel("Journal")
                    }
                }
            }
            .forgeDestinations()
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ items: [Project]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                Text(title).forgeLabel()
                ForEach(items) { project in
                    NavigationLink(value: WorkshopRoute.project(project.id)) {
                        RealityRow(project: project)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
