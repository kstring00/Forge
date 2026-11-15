import SwiftUI
import SwiftData
import ForgeCore

/// Decision 0036: the only orange on a card. Full width, 44 pt, verb first,
/// at the bottom of the card. Secondary actions are outlined and neutral.
struct PrimaryButtonLabel: View {
    let title: String
    /// Home pass (decision 0044): inside a Home row the action is tinted, not
    /// filled, so the next-move card holds the only filled orange button.
    @Environment(\.forgeQuietActions) private var quiet

    var body: some View {
        Text(title)
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(quiet ? ForgeColor.emberText : .white)
            .lineLimit(2).minimumScaleFactor(0.85).multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity).frame(minHeight: 44)
            .background(ForgeColor.ember.opacity(quiet ? 0.14 : 1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(ForgeColor.ember.opacity(quiet ? 0.45 : 0)))
            .contentShape(Rectangle())
    }
}

private struct ForgeQuietActionsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True where the main action should be tinted instead of filled.
    var forgeQuietActions: Bool {
        get { self[ForgeQuietActionsKey.self] }
        set { self[ForgeQuietActionsKey.self] = newValue }
    }
}

/// Outlined, neutral, 44 pt.
struct SecondaryButtonLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(.subheadline, weight: .medium))
            .foregroundStyle(ForgeColor.ink)
            .lineLimit(2).minimumScaleFactor(0.85).multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity).frame(minHeight: 44)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(ForgeColor.line))
            .contentShape(Rectangle())
    }
}

/// The card's one primary action, from `CardAction.of(idea)`.
struct CardPrimaryAction: View {
    let idea: Idea
    /// On the idea page the Reality check shows its one-line disclosure under the button.
    var showsDisclosure = false
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var env
    @State private var logging = false
    @State private var reporting = false
    @State private var converting = false

    private var action: CardAction { CardAction.of(idea) }
    private var round: Round? { idea.rounds.max { $0.createdAt < $1.createdAt } }

    var body: some View {
        Group {
            if env.realityChecks.isRunning(idea.id) {
                HStack(spacing: ForgeSpacing.s) {
                    ProgressView().controlSize(.small)
                    Text("The panel is on it").font(.subheadline).foregroundStyle(ForgeColor.inkSecondary)
                    Spacer()
                    StopCheckButton(ideaID: idea.id)
                }
                .frame(minHeight: 44)
            } else {
                switch action {
                case .getTake:
                    RealityCheckButton(idea: idea, showsDisclosure: showsDisclosure)
                case .hearPanel:
                    if let round {
                        NavigationLink(value: LabRoute.round(roundID: round.id)) { PrimaryButtonLabel(title: action.title) }.buttonStyle(.plain)
                    } else {
                        NavigationLink(value: LabRoute.brief(ideaID: idea.id)) { PrimaryButtonLabel(title: action.title) }.buttonStyle(.plain)
                    }
                case .log:
                    Button { logging = true } label: { PrimaryButtonLabel(title: action.title) }.buttonStyle(.plain)
                case .whatHappened:
                    Button { reporting = true } label: { PrimaryButtonLabel(title: action.title) }.buttonStyle(.plain)
                case .setStep:
                    if let project = idea.project {
                        NavigationLink(value: WorkshopRoute.project(project.id)) { PrimaryButtonLabel(title: action.title) }.buttonStyle(.plain)
                    }
                case .makeItReal:
                    Button { converting = true } label: { PrimaryButtonLabel(title: action.title) }.buttonStyle(.plain)
                case .seeSignups, .none:
                    EmptyView()
                }
            }
        }
        .sheet(isPresented: $logging) {
            if let project = idea.project { QuickLogSheet(project: project) }
        }
        .sheet(isPresented: $reporting) {
            if let project = idea.project { WhatHappenedSheet(project: project) }
        }
        .sheet(isPresented: $converting) { ConvertToProjectSheet(idea: idea) }
    }
}

/// "What happened?": the step's outcome when it reached its target, or the
/// open commitment's outcome when there is no step.
struct WhatHappenedSheet: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var context

    var body: some View {
        if let step = project.nextStep {
            OutcomeSheet(title: "What happened?", subject: step, showsNextStep: true) { report, next in
                WorkshopActions.completeNextStep(project, whatHappened: report.text, nextStep: next, rung: report.rung, audioFileName: report.audioFileName, in: context)
            }
        } else if let open = WorkshopActions.openCommitment(project) {
            OutcomeSheet(title: "What happened?", subject: open.decision) { report, _ in
                open.recordOutcome(report.text)
                if let idea = project.idea { FieldEvidence.record(report, kind: "What happened", on: idea, project: project) }
            }
        }
    }
}

extension CaptureDockButton {
    static let diameter: CGFloat = 64
    static let bottomInset: CGFloat = ForgeSpacing.m
}

extension ForgeSpacing {
    /// Decision 0036: lists end this far above the bottom, so the capture button never covers a card.
    static let dockClearance: CGFloat = CaptureDockButton.diameter + CaptureDockButton.bottomInset + 16
}
