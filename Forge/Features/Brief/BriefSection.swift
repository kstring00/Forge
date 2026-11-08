import SwiftUI
import SwiftData
import ForgeCore

/// §0A step 3: the single screen an idea opens on once a Reality Check has
/// run. Led by the council arc; everything proposed is visibly AI-found.
/// Once a step exists, the next-step card sits here too.
struct BriefSection: View {
    @Bindable var idea: Idea
    var onNotQuite: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var env

    @State private var speaking: Sphere?
    @State private var crossfirePair: SpherePair?
    @State private var hearing: Round?
    @State private var showingAssets = false
    @State private var knowing = false
    @State private var confirmingLooksRight = false
    @State private var navigateToProject = false

    private var check: RealityCheck? { idea.latestRealityCheck }
    private var evaluation: Evaluation? { idea.latestEvaluation }
    private var round: Round? { idea.rounds.max { $0.createdAt < $1.createdAt } }
    private var assetSource: Source? { check?.draftedAssetSourceID.flatMap { id in idea.sources.first { $0.id == id } } }
    private var allProposed: Bool { evaluation?.criteria.allSatisfy(\.aiProposed) ?? false }

    var body: some View {
        if let check, let evaluation {
            VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                CouncilArc(verdicts: round?.verdicts ?? [], title: idea.title, verdict: check.verdict, speaking: $speaking,
                           onHear: round.map { r in { hearing = r } },
                           onCrossfire: { crossfirePair = $0 },
                           onRule: { v, choice in withAnimation(ForgeMotion.settle) { RulingActions.rule(v, choice, on: idea, in: context) } })
                FirstRunCallout(step: .orbs, text: "The six voices. Tap any one to hear it; a dashed line between two is an argument you can open.")
                verdictRow(check)
                FirstRunCallout(step: .verdict, text: "The verdict is the panel's call on the idea as stated. It's advice. Your call comes next, one voice at a time.")
                if let round { roundLine(round) }
                if let project = idea.project {
                    NextStepCard(project: project, context: Track.reality.displayName)
                }
                whatWeFound(check)
                rings(evaluation)
                theOneThing(evaluation, check)
                FirstRunCallout(step: .nextStep, text: "Your next step: the one thing nobody can tell from a desk. Looks right makes it your task; Not quite opens the Lab.")
                if WhatIfPolicy.shows(confidence: evaluation.confidence, verdict: check.verdict) && !check.pivots.isEmpty {
                    if env.entitlements.has(.whatIf) {
                        WhatIfCards(idea: idea, check: check, evaluation: evaluation)
                    } else {
                        WhatIfLocked(count: check.pivots.count)
                    }
                }
                buttons
            }
            .sheet(item: $crossfirePair) { pair in
                if let round { CrossfireSheet(round: round, pair: pair, idea: idea) }
            }
            .sheet(isPresented: $showingAssets) {
                if let assetSource { DraftedAssetSheet(source: assetSource) }
            }
            .sheet(isPresented: $knowing) {
                KnowSomethingSheet(idea: idea)
            }
            .confirmationDialog("Accept the panel's pass as proposed?", isPresented: $confirmingLooksRight, titleVisibility: .visible) {
                Button("Looks right, start the task") { looksRight() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Everything stays marked AI-found and Confidence stays where it is. The next move becomes your one task in the Workshop, with the drafted assets attached.")
            }
            .navigationDestination(isPresented: $navigateToProject) {
                if let project = idea.project { ProjectDetailView(project: project) }
            }
            .navigationDestination(item: $hearing) { round in
                HearThePanelView(round: round)
            }
        }
    }

    // MARK: Pieces

    private func verdictRow(_ check: RealityCheck) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
            HStack {
                Text("Reality check").forgeLabel()
                Spacer()
                Text(check.createdAt.formatted(date: .abbreviated, time: .omitted)).forgeLabel()
            }
            Text(check.verdict.explanation).font(.system(.footnote, weight: .medium)).foregroundStyle(ForgeColor.ink)
            Text(check.summary)
                .font(ForgeType.body)
                .foregroundStyle(ForgeColor.ink.opacity(0.85))
        }
    }

    /// §6C: the Round behind the orbs, with how far the rulings have got.
    private func roundLine(_ round: Round) -> some View {
        let tally = RoundTally(round.verdicts.map { ($0.sphere, $0.kind, $0.ruling?.choice) })
        return NavigationLink(value: LabRoute.round(roundID: round.id)) {
            HStack(spacing: ForgeSpacing.s) {
                Text(tally.ruled == 0 ? "Hear the panel" : tally.rulingsLine)
                    .font(.system(.footnote, weight: .medium)).foregroundStyle(ForgeColor.ink)
                if !tally.splits.isEmpty && tally.ruled == 0 {
                    Text("· \(tally.splits.count == 1 ? "one split" : "\(tally.splits.count) splits")").font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hear the panel and rule on each voice")
    }

    private func whatWeFound(_ check: RealityCheck) -> some View {
        let lines: [(String, Source?)] =
            check.competitors.prefix(3).map { ("\($0.name)\($0.pricing.isEmpty ? "" : ", \($0.pricing)"). \($0.positioning)", $0.source) }
            + check.demandSignals.prefix(2).map { d in (d.text, d.sourceID.flatMap { id in idea.sources.first { $0.id == id } }) }
        return VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("What we found").forgeLabel()
            if lines.isEmpty {
                Text("Nothing the desk could stand behind. The panel says so below.")
                    .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: ForgeSpacing.s) {
                    EvidenceChip(pattern: line.1.map { EvidencePattern($0.sourceClass) } ?? .dots, size: 12).padding(.top, 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.0).font(.system(.subheadline)).foregroundStyle(ForgeColor.ink)
                        if let s = line.1 { Text(s.title).font(.footnote).foregroundStyle(ForgeColor.inkSecondary).lineLimit(1) }
                    }
                }
            }
            if check.droppedFindings > 0 {
                Text("\(check.droppedFindings) \(check.droppedFindings == 1 ? "finding the panel offered had no source and was" : "findings the panel offered had no source and were") left out.")
                    .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            }
            Text(check.limitsNote).font(.footnote).foregroundStyle(ForgeColor.inkSecondary).padding(.top, ForgeSpacing.xs)
        }
    }

    private func rings(_ e: Evaluation) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack(alignment: .top, spacing: ForgeSpacing.m - 4) {
                StripedRingCard(value: e.potential, label: "Potential", tint: ForgeColor.ink, striped: allProposed,
                                caption: Plain.potential + ". " + (allProposed ? "As proposed by the panel. Yours once you touch it." : "Your structured assessment."))
                StripedRingCard(value: e.confidence, label: "Confidence", tint: ForgeColor.ember, striped: allProposed,
                                caption: Plain.confidence + ". Desk research only. Rises when you bring something back from the world.")
            }
            PatternLegend(breakdown: e.confidenceBreakdown)
        }
    }

    private func theOneThing(_ e: Evaluation, _ check: RealityCheck) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("The one thing nobody can tell from a desk").forgeSubhead()
            Text(e.riskiestAssumption.isEmpty ? "The panel did not name a riskiest assumption." : e.riskiestAssumption)
                .font(ForgeType.statement).foregroundStyle(ForgeColor.ink)
            if let why = e.riskiestAssumptionConsequence, !why.isEmpty {
                Text(why).font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
            }
            VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                Text("The human action · \(NextMove.shortLabel(e.effectiveMove))").forgeLabel()
                Text(e.effectiveStep).font(.system(.subheadline)).foregroundStyle(ForgeColor.ink)
                if let assetSource {
                    Button { showingAssets = true } label: {
                        HStack(spacing: ForgeSpacing.xs) {
                            SparkGlyph()
                            Text("Drafted: \(assetSource.title)").font(.footnote.weight(.medium)).foregroundStyle(ForgeColor.ink)
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(ForgeSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.ember.opacity(0.6)))
        }
    }

    private var buttons: some View {
        VStack(spacing: ForgeSpacing.s) {
            if let project = idea.project {
                NavigationLink(value: WorkshopRoute.project(project.id)) {
                    HStack {
                        Text("Open in \(Track.reality.displayName)").font(.system(.subheadline, weight: .medium)).foregroundStyle(ForgeColor.ink)
                        Spacer()
                        Image(systemName: "arrow.right").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                    }
                    .modifier(SecondaryButtonChrome())
                }
                .buttonStyle(.plain)
            } else {
                EmberButton(title: "Looks right", symbol: "checkmark") { confirmingLooksRight = true }
                    .frame(maxWidth: .infinity)
            }
            HStack(spacing: 10) {
                Button { onNotQuite() } label: { Text("Not quite").frame(maxWidth: .infinity).modifier(SecondaryButtonChrome()) }
                    .buttonStyle(.plain)
                Button { knowing = true } label: { Text("I know something you don't").frame(maxWidth: .infinity).modifier(SecondaryButtonChrome()) }
                    .buttonStyle(.plain)
            }
            Text("Looks right accepts the pass as-is and the next move becomes your step in \(Track.reality.displayName). Not quite opens the full Lab, one tap per correction. The third saves what you know as verified and re-scores only what it touches.")
                .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            if check?.wasFree == true || env.firstRun.replaying {
                // Decision 0028: one calm line after the first Brief. No pop-up.
                Text("That was your free check. Want to keep going? Your next ones come from your weekly allowance.")
                    .font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
                    .padding(.top, ForgeSpacing.s)
            }
        }
    }

    // MARK: Actions

    /// Three taps to a task: the next move becomes the Workshop's one step,
    /// the drafted asset rides along, and the Journal records what was believed.
    private func looksRight() {
        guard let evaluation, let check else { return }
        for e in idea.explorations where ExplorePrompts.prompt(for: e.promptKey) != nil && e.userText.isEmpty && e.aiText != nil {
            e.confirmed = true
        }
        let decision = Decision(kind: .ruling,
                                decision: "Accepted the panel's pass: \(check.verdict.displayName.lowercased())",
                                beliefs: evaluation.riskiestAssumption,
                                reasoning: check.rationale ?? "",
                                expectedResult: evaluation.effectiveStep)
        decision.idea = idea
        context.insert(decision)
        // Looks right is moving on: every voice left untouched counts as agreed.
        if let round { RulingActions.settleUnruled(round, in: context) }

        if idea.project == nil {
            let project = WorkshopActions.convert(idea, with: .init(
                name: idea.title, desiredOutcome: "", nextStep: evaluation.effectiveStep,
                beliefs: evaluation.riskiestAssumption, reasoning: "From the Reality Check",
                expectedResult: evaluation.experiment?.decisionRule ?? ""), in: context)
            WorkshopActions.setNextStep(project, evaluation.effectiveStep,
                                        caveat: NextStepPlan.caveat(step: evaluation.effectiveStep, experimentTest: evaluation.experiment?.test),
                                        target: NextStepPlan.target(assetTitle: assetSource?.title, step: evaluation.effectiveStep),
                                        dueAt: Calendar.current.date(byAdding: .day, value: evaluation.experiment?.timeboxDays ?? 7, to: .now),
                                        moves: evaluation.experiment?.metric,
                                        criterionKey: evaluation.ladderKey)
            if let assetSource {
                project.notes.append("\(assetSource.title)\n\n\(assetSource.fullText)")
            }
            if let x = evaluation.experiment {
                project.notes.append("Experiment · \(x.hypothesis)\nTest: \(x.test)\nMetric: \(x.metric)\nTimebox: \(x.timeboxDays) days\nDecision rule: \(x.decisionRule)")
            }
            idea.stage = .build
        }
        try? context.save()
        navigateToProject = true
    }
}

/// A ring whose arc is dashed while the value is still the panel's proposal.
struct StripedRingCard: View {
    let value: Int
    let label: String
    let tint: Color
    let striped: Bool
    let caption: String

    private var fraction: Double { Double(min(max(value, 0), 100)) / 100 }

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s + 2) {
            HStack(spacing: 6) {
                Text(label).forgeLabel()
                if striped { EvidenceChip(pattern: .stripes, size: 10) }
            }
            ZStack {
                Circle().stroke(ForgeColor.line, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: striped ? .butt : .round, dash: striped ? [3, 3] : []))
                    .rotationEffect(.degrees(-90))
                Text("\(value)").font(ForgeType.numeral).foregroundStyle(ForgeColor.ink).monospacedDigit()
            }
            .frame(width: 84, height: 84)
            Text(caption).font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value) out of 100\(striped ? ", proposed by the panel" : ""). \(caption)")
    }
}

struct DraftedAssetSheet: View {
    let source: Source
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.m) {
                    HStack(spacing: ForgeSpacing.xs) { SparkGlyph(); Text("Drafted by the panel · edit freely before you use it").forgeSubhead() }
                    Text(source.fullText)
                        .font(ForgeType.body)
                        .foregroundStyle(ForgeColor.ink)
                        .textSelection(.enabled)
                }
                .padding(ForgeSpacing.m)
            }
            .background(ForgeColor.canvas)
            .navigationTitle(source.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) { ShareLink(item: source.fullText) { Image(systemName: "square.and.arrow.up") } }
            }
        }
    }
}
