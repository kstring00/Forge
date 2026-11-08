import SwiftUI
import SwiftData
import ForgeCore

/// A project. Always answers "what should I work on next?" with one action.
struct ProjectDetailView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var context

    private enum OutcomeRequest: Identifiable {
        case step, pause, launch, decision(Decision)
        var id: String {
            switch self {
            case .step: "step"
            case .pause: "pause"
            case .launch: "launch"
            case .decision(let d): d.id.uuidString
            }
        }
    }

    @State private var outcome: OutcomeRequest?
    @State private var settling: String?
    @State private var nextStepDraft = ""

    private var journal: [Decision] { project.decisions.sorted { $0.date > $1.date } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                header
                if let idea = project.idea, idea.latestRealityCheck != nil {
                    PanelsTakeCard(idea: idea, compact: true)
                }
                nextStepCard
                outcomeSection
                journalSection
            }
            .padding(ForgeSpacing.m)
            .padding(.bottom, ForgeSpacing.xxl)
        }
        .background(ForgeColor.canvas)
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    switch project.status {
                    case .active:
                        Button { outcome = .pause } label: { Label("Pause", systemImage: "pause") }
                        Button { outcome = .launch } label: { Label("Mark launched", systemImage: "flag") }
                    case .paused:
                        Button { WorkshopActions.resume(project) } label: { Label("Resume", systemImage: "play") }
                        Button { outcome = .launch } label: { Label("Mark launched", systemImage: "flag") }
                    case .done, .archived:
                        EmptyView()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").accessibilityLabel("More")
                }
            }
        }
        .sheet(item: $outcome) { request in
            switch request {
            case .step:
                OutcomeSheet(title: "Step done", subject: project.nextStep ?? "", showsNextStep: true) { report, next in
                    WorkshopActions.completeNextStep(project, whatHappened: report.text, nextStep: next, rung: report.rung, audioFileName: report.audioFileName, in: context)
                    settleAfter(report.text)
                }
            case .pause:
                OutcomeSheet(title: "Pausing", subject: project.name, asksRung: false) { report, _ in
                    WorkshopActions.pause(project, whatHappened: report.text, in: context)
                    settleAfter(report.text)
                }
            case .launch:
                OutcomeSheet(title: "Launched", subject: project.desiredOutcome.isEmpty ? project.name : project.desiredOutcome) { report, _ in
                    WorkshopActions.complete(project, whatHappened: report.text, in: context)
                    if let idea = project.idea { FieldEvidence.record(report, kind: "Launched", on: idea, project: project) }
                    settleAfter(report.text)
                }
            case .decision(let d):
                OutcomeSheet(title: "Outcome", subject: d.decision) { report, _ in
                    d.recordOutcome(report.text)
                    if let idea = project.idea { FieldEvidence.record(report, kind: "What happened", on: idea, project: project) }
                    settleAfter(report.text)
                }
            }
        }
        .sheet(item: $settling) { happened in
            if let idea = project.idea { SettleRulingsSheet(idea: idea, whatHappened: happened) }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text(project.name)
                .font(ForgeType.ideaTitleHero)
                .foregroundStyle(ForgeColor.ink)
            HStack(spacing: ForgeSpacing.m) {
                Text(statusLabel).forgeLabel()
                if let idea = project.idea {
                    NavigationLink(value: VaultRoute.idea(idea.id)) {
                        Text("From: \(idea.title)")
                            .font(.footnote)
                            .foregroundStyle(ForgeColor.inkSecondary)
                            .lineLimit(1)
                    }
                }
            }
            if !project.desiredOutcome.isEmpty {
                VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                    Text("Launched means").forgeLabel()
                    Text(project.desiredOutcome)
                        .font(ForgeType.body)
                        .foregroundStyle(ForgeColor.ink)
                }
            }
        }
    }

    private var statusLabel: String {
        switch project.status {
        case .active: "Active"
        case .paused: "Paused"
        case .done: "Launched"
        case .archived: "Archived"
        }
    }

    @ViewBuilder
    private var nextStepCard: some View {
        if project.status == .done {
            EmptyView()
        } else if project.nextStep != nil {
            VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                NextStepCard(project: project, context: Track.reality.displayName)
                if project.status == .active {
                    Button { outcome = .step } label: {
                        Text(WorkshopActions.targetReached(project) ? "Step done · set the next one" : "Mark the step done")
                            .frame(maxWidth: .infinity)
                            .modifier(SecondaryButtonChrome())
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                Text(Plain.step).forgeLabel()
                TextField("What's the one next thing?", text: $nextStepDraft, axis: .vertical)
                    .lineLimit(1...4)
                    .font(ForgeType.body)
                    .padding(ForgeSpacing.m)
                    .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
                    .onSubmit(setNextStep)
                    .accessibilityLabel("Next step")
                if !nextStepDraft.trimmingCharacters(in: .whitespaces).isEmpty {
                    EmberButton(title: "Set next step", symbol: nil, action: setNextStep)
                }
            }
        }
    }

    /// §5: what happened may settle the panel's points. Only when there are any left to settle.
    private func settleAfter(_ happened: String) {
        guard let idea = project.idea, !RulingActions.unsettled(on: idea).isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { settling = happened }
    }

    private func setNextStep() {
        WorkshopActions.setNextStep(project, nextStepDraft)
        nextStepDraft = ""
    }

    @ViewBuilder
    private var outcomeSection: some View {
        if let open = WorkshopActions.openCommitment(project), !open.expectedResult.isEmpty {
            VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                Text("You expected").forgeLabel()
                Text(open.expectedResult)
                    .font(ForgeType.body)
                    .foregroundStyle(ForgeColor.ink)
                if let by = open.expectedBy {
                    Text("by \(by.formatted(date: .abbreviated, time: .omitted))")
                        .font(.footnote)
                        .foregroundStyle(ForgeColor.inkSecondary)
                }
                Button("Record what happened") { outcome = .decision(open) }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ForgeColor.ink)
                    .padding(.top, ForgeSpacing.xs)
            }
        }
    }

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("Journal").forgeLabel()
            if journal.isEmpty {
                Text("Commitments and outcomes land here.")
                    .font(.footnote)
                    .foregroundStyle(ForgeColor.inkSecondary)
            }
            ForEach(journal) { d in
                JournalRow(decision: d) { outcome = .decision(d) }
            }
        }
    }
}

/// One Journal entry: the decision, what was expected, what happened.
struct JournalRow: View {
    let decision: Decision
    var showsContext = false
    var onRecord: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
            HStack {
                Text(decision.kind.displayName).forgeLabel()
                Spacer()
                Text(decision.decidedAt, style: .date)
                    .font(.footnote)
                    .foregroundStyle(ForgeColor.inkSecondary)
            }
            Text(decision.decision)
                .font(ForgeType.body)
                .foregroundStyle(ForgeColor.ink)
            if showsContext, let name = decision.project?.name ?? decision.idea?.title {
                Text(name).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            }
            if !decision.beliefs.isEmpty {
                Text("Believed: \(decision.beliefs)").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            }
            if !decision.expectedResult.isEmpty {
                Text("Expected: \(decision.expectedResult)\(decision.expectedBy.map { " · by \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "")")
                    .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            }
            if let ruling = decision.ruling, let line = RulingActions.outcomeLine(ruling) {
                Text(line).font(.footnote.weight(.medium)).foregroundStyle(ForgeColor.ink)
            }
            if let actual = decision.actualResult {
                Text("Actually: \(actual)")
                    .font(.footnote)
                    .foregroundStyle(ForgeColor.ink)
            } else if decision.kind == .commit || (decision.kind == .ruling && !decision.expectedResult.isEmpty), let onRecord {
                Button("Record what happened", action: onRecord)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(ForgeColor.ink)
            }
        }
        .padding(ForgeSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}
