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

/// A project on the Reality tab: name, the step, how far, when due.
struct RealityRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(project.name).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink).lineLimit(1)
                Spacer()
                Text(statusLabel).forgeLabelSmall()
            }
            if let step = project.nextStep {
                Text(step).font(.system(size: 15)).foregroundStyle(ForgeColor.ink).lineLimit(2)
                Text(progressLine).forgeLabelSmall()
            } else if project.status == .active {
                Text("No next step set.").font(.system(size: 13)).foregroundStyle(ForgeColor.inkSecondary)
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        .accessibilityElement(children: .combine)
    }

    private var statusLabel: String {
        switch project.status {
        case .active: "Active"
        case .paused: "Paused"
        case .done: "Launched"
        case .archived: "Archived"
        }
    }

    private var progressLine: String {
        var parts = ["\(min(project.nextStepCount, project.effectiveTarget)) of \(project.effectiveTarget)"]
        if let due = project.nextStepDueAt {
            parts.append((due < .now ? "was due " : "due ") + due.formatted(.dateTime.weekday(.abbreviated)))
        }
        return parts.joined(separator: " · ")
    }
}
