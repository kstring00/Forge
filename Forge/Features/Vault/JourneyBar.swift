import SwiftUI
import SwiftData
import ForgeCore

/// Decision 0025: Idea → Formation → Reality on the idea page, with "you are
/// here" and the one action that moves it forward.
struct JourneyBar: View {
    let idea: Idea
    @Environment(AppEnvironment.self) private var env

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

    /// Decision 0036: the idea page's one primary action, the same as its card's.
    @ViewBuilder
    private var action: some View {
        if idea.isArchived {
            Text("Archived. Bring it back from the menu to pick up where it was.").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
        } else if CardAction.of(idea) == .none, let project = idea.project {
            NavigationLink(value: WorkshopRoute.project(project.id)) { SecondaryButtonLabel(title: "Open the project") }
                .buttonStyle(.plain)
        } else {
            CardPrimaryAction(idea: idea, showsDisclosure: true)
        }
    }
}
