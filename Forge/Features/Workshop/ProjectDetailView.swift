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
    @State private var nextStepDraft = ""

    private var journal: [Decision] { project.decisions.sorted { $0.date > $1.date } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                header
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
                OutcomeSheet(title: "Step done", subject: project.nextStep ?? "", showsNextStep: true) { happened, next in
                    WorkshopActions.completeNextStep(project, whatHappened: happened, nextStep: next, in: context)
                }
            case .pause:
                OutcomeSheet(title: "Pausing", subject: project.name) { happened, _ in
                    WorkshopActions.pause(project, whatHappened: happened, in: context)
                }
            case .launch:
                OutcomeSheet(title: "Launched", subject: project.desiredOutcome.isEmpty ? project.name : project.desiredOutcome) { happened, _ in
                    WorkshopActions.complete(project, whatHappened: happened, in: context)
                }
            case .decision(let d):
                OutcomeSheet(title: "Outcome", subject: d.decision) { happened, _ in
                    d.recordOutcome(happened)
                }
            }
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
                            .font(.caption)
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
        } else if let step = project.nextStep {
            VStack(alignment: .leading, spacing: ForgeSpacing.m) {
                Text("Next step").forgeLabel()
                Text(step)
                    .font(ForgeType.ideaTitle)
                    .foregroundStyle(ForgeColor.ink)
                if project.status == .active {
                    EmberButton(title: "Done", symbol: "checkmark") { outcome = .step }
                }
            }
            .padding(ForgeSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.ember.opacity(0.6), lineWidth: 1))
        } else {
            VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                Text("Next step").forgeLabel()
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
                        .font(.caption)
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
                    .font(.caption)
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
                    .font(.caption2)
                    .foregroundStyle(ForgeColor.inkSecondary)
            }
            Text(decision.decision)
                .font(ForgeType.body)
                .foregroundStyle(ForgeColor.ink)
            if showsContext, let name = decision.project?.name ?? decision.idea?.title {
                Text(name).font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            }
            if !decision.beliefs.isEmpty {
                Text("Believed: \(decision.beliefs)").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            }
            if !decision.expectedResult.isEmpty {
                Text("Expected: \(decision.expectedResult)").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            }
            if let actual = decision.actualResult {
                Text("Actually: \(actual)")
                    .font(.footnote)
                    .foregroundStyle(ForgeColor.ink)
            } else if decision.kind == .commit, let onRecord {
                Button("Record what happened", action: onRecord)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ForgeColor.ink)
            }
        }
        .padding(ForgeSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }
}
