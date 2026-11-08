import SwiftUI
import SwiftData
import ForgeCore

/// Decision 0025: Idea → Formation → Reality on the idea page, with "you are
/// here" and the one action that moves it forward.
struct JourneyBar: View {
    let idea: Idea
    @Environment(AppEnvironment.self) private var env
    @State private var converting = false

    private var current: Track? { idea.track }
    private var offersCheck: Bool { RealityCheckPolicy.isOffered(for: idea.lensType) }

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            HStack(spacing: 0) {
                ForEach(Array(Track.allCases.enumerated()), id: \.element) { i, track in
                    node(track)
                    if i < Track.allCases.count - 1 {
                        Rectangle()
                            .fill(reached(Track.allCases[i + 1]) ? StakeCard.color(Track.allCases[i + 1]) : ForgeColor.line)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 18)
                    }
                }
            }
            action
        }
        .padding(ForgeSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        .sheet(isPresented: $converting) { ConvertToProjectSheet(idea: idea) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(current.map { "You are here: \($0.displayName). \($0.tagline)" } ?? "Archived")
    }

    private func reached(_ track: Track) -> Bool {
        guard let current, let c = Track.allCases.firstIndex(of: current), let t = Track.allCases.firstIndex(of: track) else { return false }
        return t <= c
    }

    private func node(_ track: Track) -> some View {
        let here = track == current
        return VStack(spacing: 6) {
            ZStack {
                Circle().fill(reached(track) ? StakeCard.color(track) : ForgeColor.surface).frame(width: here ? 18 : 12, height: here ? 18 : 12)
                    .shadow(color: here ? StakeCard.color(track).opacity(0.6) : .clear, radius: 8)
                if !reached(track) { Circle().strokeBorder(ForgeColor.line, lineWidth: 1.5).frame(width: 12, height: 12) }
            }
            .frame(height: 18)
            Text(track.displayName).forgeLabelSmall().foregroundStyle(here ? StakeCard.color(track) : ForgeColor.inkSecondary)
            Text(here ? "You are here" : " ").font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
        }
        .frame(width: 84)
    }

    /// The one thing that moves the idea on from where it is.
    @ViewBuilder
    private var action: some View {
        if idea.isArchived {
            Text("Archived. Bring it back from the menu to pick up where it was.").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
        } else if let project = idea.project {
            NavigationLink(value: WorkshopRoute.project(project.id)) {
                forwardRow("Open your step", detail: project.nextStep ?? "Set the next step")
            }
            .buttonStyle(.plain)
        } else if current == .idea {
            if offersCheck {
                HStack(alignment: .center, spacing: ForgeSpacing.m) {
                    Text(env.realityChecks.isRunning(idea.id) ? "The panel is on it." : "Next: send it to the panel.").font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
                    Spacer()
                    if env.realityChecks.isRunning(idea.id) { StopCheckButton(ideaID: idea.id) } else { RealityCheckButton(idea: idea, pill: true) }
                }
            } else {
                Button { converting = true } label: { forwardRow("Make it real", detail: "This kind of idea is judged by impact; commit to a first step.") }
                    .buttonStyle(.plain)
            }
        } else if current == .formation {
            if idea.latestRealityCheck != nil {
                NavigationLink(value: LabRoute.brief(ideaID: idea.id)) {
                    forwardRow("Open the Brief", detail: "Rule on the panel, then Looks right starts your first step.")
                }
                .buttonStyle(.plain)
            } else {
                Button { converting = true } label: { forwardRow("Make it real", detail: "Commit to one next step and say what launched means.") }
                    .buttonStyle(.plain)
            }
        } else {
            Button { converting = true } label: { forwardRow("Make it real", detail: "In Reality without a step yet. Commit to one.") }
                .buttonStyle(.plain)
        }
    }

    private func forwardRow(_ title: String, detail: String) -> some View {
        HStack(spacing: ForgeSpacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.subheadline, weight: .medium)).foregroundStyle(ForgeColor.ink)
                Text(detail).font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary).lineLimit(2)
            }
            Spacer()
            Image(systemName: "arrow.right").font(.footnote.weight(.semibold)).foregroundStyle(ForgeColor.emberText)
        }
        .contentShape(Rectangle())
    }
}
