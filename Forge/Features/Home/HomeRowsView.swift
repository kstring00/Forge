import SwiftUI
import SwiftData
import ForgeCore

/// Home usability pass, part (b), decision 0044: Home's ideas as compact rows
/// that open in place, and one "Your next move" card that holds the only
/// filled orange button. What each row says and which one is open is decided
/// by `HomeRows` and `HomeRowState` in ForgeCore.

extension HomeRowState {
    /// Where an idea stands, read from the saved records.
    static func of(_ idea: Idea, checking: Bool = false, failed: Bool = false, offline: Bool = false, unseenBrief: Bool = false) -> HomeRowState {
        if checking { return .checking }
        if let project = idea.project {
            switch project.status {
            case .done: return .launched
            case .paused, .archived: return .paused
            case .active: break
            }
            if project.nextStep != nil {
                let target = project.effectiveTarget
                if WorkshopActions.targetReached(project) { return .stepReached(of: target) }
                return .stepInProgress(done: min(project.nextStepCount, target), of: target)
            }
            return WorkshopActions.openCommitment(project) != nil ? .awaitingOutcome : .noStep
        }
        if idea.latestRealityCheck != nil {
            if unseenBrief { return .takeReady }
            if let round = idea.rounds.max(by: { $0.createdAt < $1.createdAt }), !round.verdicts.isEmpty {
                let tally = RoundTally(round.verdicts.map { ($0.sphere, $0.kind, $0.ruling?.choice) })
                return tally.isComplete ? .decided : .deciding(answered: tally.ruled, of: tally.total)
            }
            return idea.hasRuling ? .decided : .deciding(answered: 0, of: 0)
        }
        if !RealityCheckPolicy.isOffered(for: idea.lensType) { return .personal }
        if offline { return .offline }
        if failed { return .checkFailed }
        return .notChecked
    }
}

extension Idea {
    /// The person's own first line, when it says more than the title.
    var homeDescription: String {
        let words = originalText.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? ""
        return words == title ? "" : words
    }
}

// MARK: The row

/// One idea on Home. Collapsed: the stage orb, the title, one plain status
/// line, a chevron; the whole row is the button. Open: the details under it.
struct HomeIdeaRow: View {
    let idea: Idea
    let state: HomeRowState
    let isNext: Bool
    let isOpen: Bool
    let onTap: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    private var track: Track { idea.track ?? .idea }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) { summary }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(HomeRows.spoken(title: idea.title, track: track, state: state, isNext: isNext, isOpen: isOpen))
                .accessibilityHint(isOpen ? "Closes the details." : "Shows the details.")
                .accessibilityAddTraits(.isButton)
            if isOpen {
                HomeRowDetail(idea: idea, state: state)
                    .padding(.horizontal, ForgeSpacing.cardPadding)
                    .padding(.bottom, ForgeSpacing.cardPadding)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }

    private var summary: some View {
        HStack(alignment: .center, spacing: 12) {
            IdeaSpark(idea: idea, size: typeSize.isAccessibilitySize ? 28 : 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if isNext {
                    Text("Next")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(ForgeColor.emberText)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .overlay(Capsule().strokeBorder(ForgeColor.ember.opacity(0.5)))
                }
                Text(idea.title)
                    .font(Font.custom("Fraunces-SemiBold", size: 18, relativeTo: .headline))
                    .foregroundStyle(ForgeColor.ink)
                    .lineLimit(typeSize.isAccessibilitySize ? 4 : 2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                statusLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(ForgeColor.inkSecondary)
                .rotationEffect(.degrees(isOpen ? 180 : 0))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, ForgeSpacing.cardPadding)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// "Reality · Talked to 1 of 5 people": the stage in words, never by colour alone.
    private var statusLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if state.isWorking {
                ProgressView().controlSize(.mini)
            } else if state.needsAttention {
                Image(systemName: "exclamationmark.circle").font(.footnote).foregroundStyle(ForgeColor.ink)
            }
            Text("\(track.displayName) · \(state.line)")
                .font(.subheadline)
                .foregroundStyle(state.needsAttention ? ForgeColor.ink : ForgeColor.inkSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: The open row

/// What an open row shows: the person's own words, Potential and Proof in
/// plain lines (no empty boxes), the estimate only when there is one, the
/// panel's What-if, the idea's action (tinted, never filled) and "Open idea".
struct HomeRowDetail: View {
    let idea: Idea
    let state: HomeRowState
    @State private var explaining: MeterExplainerSheet.Focus?

    private var potential: Int? { idea.latestEvaluation.flatMap { $0.criteria.isEmpty ? nil : $0.potential } }
    private var proof: ProofStage { ProofStage.of(idea) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle().fill(ForgeColor.line).frame(height: 1).accessibilityHidden(true)
            if !idea.homeDescription.isEmpty {
                Text(idea.homeDescription)
                    .font(.subheadline).foregroundStyle(ForgeColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if idea.latestRealityCheck != nil {
                facts
                estimate
                WhatIfTeaser(idea: idea, plain: true)
            } else {
                Text(Self.missingLine(state))
                    .font(.subheadline).foregroundStyle(ForgeColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            CardPrimaryAction(idea: idea)
                .environment(\.forgeQuietActions, true)
            openLink
        }
        .sheet(item: $explaining) { MeterExplainerSheet(idea: idea, focus: $0) }
    }

    /// With no result yet: what is missing and the step that fills it.
    static func missingLine(_ state: HomeRowState) -> String {
        switch state {
        case .checking: "The panel is looking this up now. Its take lands here when it's done."
        case .checkFailed: "No scores yet: the last check didn't finish. Try it again below."
        case .offline: "No scores yet: the last check couldn't get online. Try again when you're connected."
        case .personal: "This one isn't scored. It's judged by what it changes for you."
        case .stepInProgress, .stepReached, .awaitingOutcome, .noStep, .paused, .launched:
            "The panel hasn't looked at this one, so there are no scores. What you learn from real people still counts."
        default: "No scores yet. Get the panel's take to see how big this could be and what to test first."
        }
    }

    @ViewBuilder
    private var facts: some View {
        if let potential {
            fact(label: "Potential", value: PotentialWord.word(potential), note: "The panel's view of how big this could be.", focus: .potential,
                 spoken: "Potential: \(PotentialWord.word(potential)). Opens what it rests on.")
        } else {
            Text("No Potential score yet. Hear the panel to get one.")
                .font(.subheadline).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
        }
        fact(label: "Proof", value: proof.cardWord, note: "Next: \(ProofStage.sentence(proof.nextStep(for: idea)))", focus: .proof,
             ladder: proof.ladderIndex, spoken: "Proof: \(proof.label), \(proof.stepOfFour). Next: \(proof.nextStep(for: idea)). Opens the four steps.")
    }

    private func fact(label: String, value: String, note: String, focus: MeterExplainerSheet.Focus, ladder: Int? = nil, spoken: String) -> some View {
        Button { explaining = focus } label: {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    (Text("\(label): ").foregroundStyle(ForgeColor.inkSecondary) + Text(value).fontWeight(.semibold).foregroundStyle(ForgeColor.ink))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    if let ladder { ProofLadder(reached: ladder).frame(maxWidth: 150) }
                    Text(note).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "info.circle").font(.footnote).foregroundStyle(ForgeColor.inkSecondary).padding(.top, 2)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    /// Only a real estimate (or, for a personal idea, who it helps) is shown.
    @ViewBuilder
    private var estimate: some View {
        switch EstimatedReturn.value(for: idea) {
        case .yours, .estimate, .impact:
            EstimatedReturnRow(idea: idea)
        case .tooEarly, .none:
            Text("Too early to estimate what it could earn. A real price from a real person changes that.")
                .font(.footnote).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
        case .impactMissing, .unchecked:
            EmptyView()
        }
    }

    private var openLink: some View {
        Group {
            if let project = idea.project {
                NavigationLink(value: WorkshopRoute.project(project.id)) { openLabel }
            } else {
                NavigationLink(value: VaultRoute.idea(idea.id)) { openLabel }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open idea: \(idea.title)")
    }

    private var openLabel: some View {
        HStack(spacing: 4) {
            Text("Open idea").font(.system(.subheadline, weight: .medium))
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
        }
        .foregroundStyle(ForgeColor.ink)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

// MARK: Your next move

/// The one most useful action across all ideas: what it is, one line on why,
/// how far along it is, and the only filled orange button on Home.
struct HomeNextMoveCard: View {
    let idea: Idea
    let state: HomeRowState
    /// The move in plain words: the step's own text, or "Get the panel's take".
    let move: String
    /// Just captured: the card offers "Later".
    var justCaptured = false
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your next move")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(ForgeColor.inkSecondary)
            Group {
                if let project = idea.project {
                    NavigationLink(value: WorkshopRoute.project(project.id)) { heading }
                } else {
                    NavigationLink(value: VaultRoute.idea(idea.id)) { heading }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(idea.title). \(move). Opens the idea.")
            if let why = state.why {
                Text(why).font(.subheadline).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
            }
            if let progress = state.progress, let fraction = state.fraction {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: fraction).tint(ForgeColor.ink)
                    Text(progress).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(progress)
            }
            // The only filled orange button on Home.
            CardPrimaryAction(idea: idea)
            if justCaptured && !env.realityChecks.isRunning(idea.id) {
                Button("Later") { env.justCapturedIdeaID = nil }
                    .font(.system(.subheadline, weight: .medium)).foregroundStyle(ForgeColor.inkSecondary)
                    .frame(minHeight: 44)
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        .onChange(of: env.realityChecks.isRunning(idea.id)) { _, running in
            if running && justCaptured { env.justCapturedIdeaID = nil }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(idea.title)
                .font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                .lineLimit(3).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            Text(move)
                .font(.system(.body, weight: .medium)).foregroundStyle(ForgeColor.ink)
                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// The move in plain words for an idea in a state.
    static func moveLine(for idea: Idea, state: HomeRowState) -> String {
        switch state {
        case .stepInProgress, .stepReached:
            let step = idea.project?.nextStep?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return step.isEmpty ? "Take your next step" : ProofStage.sentence(step)
        case .awaitingOutcome: return "Say what happened."
        case .noStep: return "Set one small next step."
        case .takeReady, .deciding, .decided: return "Hear what the panel said."
        case .checking: return "The panel is checking it."
        case .checkFailed, .offline: return "Run the check again."
        case .personal: return "Make it real."
        case .notChecked, .paused, .launched: return "Get the panel's take."
        }
    }
}

// MARK: No ideas yet

/// A friendly first Home: the panel, one line, and where to tap.
struct HomeEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.l) {
            EmptyPanel()
            VStack(alignment: .leading, spacing: 6) {
                Text("Catch your first idea")
                    .font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                Text("Tap the orange mic button at the bottom right. Say it or type it, in your own words. Half an idea is fine.")
                    .font(.body).foregroundStyle(ForgeColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Spacer()
                Text("The mic is down here").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                Image(systemName: "arrow.down.right").font(.footnote.weight(.semibold)).foregroundStyle(ForgeColor.emberText)
            }
            .padding(.trailing, CaptureDockButton.diameter + ForgeSpacing.m)
            .accessibilityHidden(true)
        }
    }
}

// MARK: Previews

#Preview("Rows: every state") {
    let container = try! ModelContainer.forge(inMemory: true)
    let idea = Idea(originalText: "Weekend website care for RV parks along one highway. Most owners only have a Facebook page.")
    container.mainContext.insert(idea)
    let states: [HomeRowState] = [
        .stepInProgress(done: 1, of: 5), .notChecked, .checking, .checkFailed, .offline, .personal, .takeReady,
        .deciding(answered: 0, of: 5), .deciding(answered: 2, of: 5), .decided, .stepInProgress(done: 0, of: 1),
        .stepReached(of: 5), .awaitingOutcome, .noStep, .paused, .launched,
    ]
    return NavigationStack {
        ScrollView {
            VStack(spacing: ForgeSpacing.s) {
                ForEach(Array(states.enumerated()), id: \.offset) { i, state in
                    HomeIdeaRow(idea: idea, state: state, isNext: i == 0, isOpen: false) {}
                }
            }
            .padding(ForgeSpacing.m)
        }
        .background(ForgeColor.canvas)
    }
    .environment(AppEnvironment.live)
    .modelContainer(container)
    .preferredColorScheme(.dark)
}

#Preview("Row open, not checked") {
    let container = try! ModelContainer.forge(inMemory: true)
    let idea = Idea(originalText: "Meal prep for night-shift nurses who get home at 8am and have no energy to cook")
    container.mainContext.insert(idea)
    return NavigationStack {
        ScrollView {
            HomeIdeaRow(idea: idea, state: .notChecked, isNext: false, isOpen: true) {}
                .padding(ForgeSpacing.m)
        }
        .background(ForgeColor.canvas)
    }
    .environment(AppEnvironment.live)
    .modelContainer(container)
    .preferredColorScheme(.dark)
}

#Preview("Rows at the largest text size") {
    let container = try! ModelContainer.forge(inMemory: true)
    let idea = Idea(originalText: "Voice notes turned into estimates for small roofing crews")
    container.mainContext.insert(idea)
    return NavigationStack {
        ScrollView {
            VStack(spacing: ForgeSpacing.s) {
                HomeIdeaRow(idea: idea, state: .stepInProgress(done: 1, of: 5), isNext: true, isOpen: false) {}
                HomeIdeaRow(idea: idea, state: .offline, isNext: false, isOpen: true) {}
            }
            .padding(ForgeSpacing.m)
        }
        .background(ForgeColor.canvas)
    }
    .environment(AppEnvironment.live)
    .modelContainer(container)
    .environment(\.dynamicTypeSize, .accessibility5)
    .preferredColorScheme(.dark)
}

#Preview("Next move, and no ideas yet") {
    let container = try! ModelContainer.forge(inMemory: true)
    let idea = Idea(originalText: "A booking page for fishing charters on the Texas coast")
    container.mainContext.insert(idea)
    return NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                HomeNextMoveCard(idea: idea, state: .notChecked, move: HomeNextMoveCard.moveLine(for: idea, state: .notChecked))
                HomeEmptyState()
            }
            .padding(ForgeSpacing.m)
        }
        .background(ForgeColor.canvas)
    }
    .environment(AppEnvironment.live)
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
