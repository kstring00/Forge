import SwiftUI
import SwiftData
import ForgeCore

/// Where a chosen idea becomes a project. Phase 2: list, next step, Journal.
struct WorkshopView: View {
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    private var active: [Project] { projects.filter { $0.status == .active } }
    private var paused: [Project] { projects.filter { $0.status == .paused } }
    private var done: [Project] { projects.filter { $0.status == .done || $0.status == .archived } }

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    EmptyState(symbol: "hammer",
                               title: "No project yet",
                               message: "When the panel checks an idea and you say it looks right, the first step lands here.")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: ForgeSpacing.l) {
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
            .navigationTitle("Workshop")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { JournalView() } label: {
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
                        ProjectCard(project: project)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ProjectCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text(project.name)
                .font(ForgeType.ideaTitle)
                .foregroundStyle(ForgeColor.ink)
            if project.status == .active {
                Text("Next step").forgeLabel()
                Text(project.nextStep ?? "Not set yet.")
                    .font(ForgeType.body)
                    .foregroundStyle(project.nextStep == nil ? ForgeColor.inkSecondary : ForgeColor.ink)
                    .lineLimit(2)
            } else if !project.desiredOutcome.isEmpty {
                Text(project.desiredOutcome)
                    .font(ForgeType.secondary)
                    .foregroundStyle(ForgeColor.inkSecondary)
                    .lineLimit(2)
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        .accessibilityElement(children: .combine)
    }
}
