import SwiftUI
import SwiftData
import ForgeCore

/// What the card needs that a test can check without a view: the orb states
/// and the order of takes. Decision 0023.
enum PanelsTake {
    /// Every take the panel has given, newest first. The first is the current one.
    static func history(for idea: Idea) -> [RealityCheck] {
        idea.realityChecks.sorted { $0.createdAt > $1.createdAt }
    }

    /// The same reading as the council arc, without the tap states: the Steward
    /// is dormant until Phase 5, a running re-check lights the working orbs,
    /// otherwise each orb holds its verdict.
    static func orbState(for sphere: Sphere, verdicts: [(Sphere, VerdictKind)], working: Set<Sphere>, isWorking: Bool) -> OrbState {
        if sphere == .steward { return .dormant }
        if isWorking { return working.contains(sphere) ? .working : .idle }
        if let v = verdicts.first(where: { $0.0 == sphere }) { return .verdict(v.1) }
        return .idle
    }
}

/// "The panel's take": the one card every checked idea shows at the top of
/// its page, in Formation and in Reality. The verdict word and its line, the
/// six orbs in their states, Confidence, and the way to the full Brief. A
/// re-check replaces what it shows; the earlier takes stay in History.
struct PanelsTakeCard: View {
    let idea: Idea
    /// The one-row form for a Reality project page.
    var compact = false
    @Environment(AppEnvironment.self) private var env

    private var check: RealityCheck? { idea.latestRealityCheck }
    private var evaluation: Evaluation? { idea.latestEvaluation }
    private var round: Round? { idea.rounds.max { $0.createdAt < $1.createdAt } }
    private var verdicts: [(Sphere, VerdictKind)] { (round?.verdicts ?? []).map { ($0.sphere, $0.kind) } }
    private var runner: RealityCheckRunner { env.realityChecks.runner(for: idea.id) }
    private var isWorking: Bool { env.realityChecks.isRunning(idea.id) }
    private var working: Set<Sphere> { RealityCheckCenter.working(for: runner.phase, lit: runner.litSpheres) }
    private var allProposed: Bool { evaluation?.criteria.allSatisfy(\.aiProposed) ?? false }
    private var takes: Int { idea.realityChecks.count }

    var body: some View {
        if let check {
            if compact { row(check) } else { card(check) }
        }
    }

    // MARK: Full card

    private func card(_ check: RealityCheck) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            NavigationLink(value: LabRoute.brief(ideaID: idea.id)) {
                VStack(alignment: .leading, spacing: ForgeSpacing.m) {
                    HStack {
                        Text("The panel's take").forgeLabel()
                        Spacer()
                        Text(check.createdAt.formatted(date: .abbreviated, time: .omitted)).forgeLabel()
                    }
                    HStack(alignment: .top, spacing: ForgeSpacing.m) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(check.verdict.displayName).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                            Text(check.verdict.explanation)
                                .font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: ForgeSpacing.m)
                        if let evaluation { confidence(evaluation) }
                    }
                    orbs(size: 30, spacing: 10)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("The panel's take: \(check.verdict.displayName). \(check.verdict.explanation) Opens the Brief.")

            footer
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }

    private func confidence(_ e: Evaluation) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                if allProposed { EvidenceChip(pattern: .stripes, size: 9) }
                Text("\(e.confidence)").font(ForgeType.numeralSmall).foregroundStyle(ForgeColor.ink).monospacedDigit()
            }
            Text(Plain.beside("Confidence", "how sure")).forgeLabelSmall()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Confidence \(e.confidence) out of 100\(allProposed ? ", as proposed by the panel" : "")")
    }

    private func orbs(size: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(Panel.order) { s in
                OrbView(sphere: s, state: PanelsTake.orbState(for: s, verdicts: verdicts, working: working, isWorking: isWorking), size: size)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var footer: some View {
        HStack(alignment: .center) {
            if isWorking {
                Text("The panel is on it").font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
                StopCheckButton(ideaID: idea.id)
            } else if RealityCheckPolicy.isOffered(for: idea.lensType) && !idea.isArchived {
                RealityCheckButton(idea: idea, pill: true, pillTitle: "Check again")
            }
            Spacer()
            NavigationLink(value: LabRoute.brief(ideaID: idea.id)) {
                HStack(spacing: 4) {
                    Text("Open the Brief").font(.system(.subheadline, weight: .medium)).foregroundStyle(ForgeColor.ink)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(ForgeColor.inkSecondary)
                }
            }
            .buttonStyle(.plain)
        }
        if takes > 1 {
            NavigationLink(value: LabRoute.history(ideaID: idea.id)) {
                Text("Checked \(takes) times · earlier takes in History")
                    .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Compact row

    /// The row to the Brief, and under it the same Check again / Stop the full card has,
    /// so a project page never sends the user hunting for the idea page.
    private func row(_ check: RealityCheck) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            briefRow(check)
            HStack {
                if isWorking {
                    Text("The panel is on it").font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
                    StopCheckButton(ideaID: idea.id)
                } else if RealityCheckPolicy.isOffered(for: idea.lensType) && !idea.isArchived {
                    RealityCheckButton(idea: idea, pill: true, pillTitle: "Check again")
                }
                Spacer()
                NavigationLink(value: VaultRoute.idea(idea.id)) {
                    Text("The idea").font(.system(.footnote, weight: .medium)).foregroundStyle(ForgeColor.inkSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func briefRow(_ check: RealityCheck) -> some View {
        NavigationLink(value: LabRoute.brief(ideaID: idea.id)) {
            HStack(spacing: ForgeSpacing.m) {
                orbs(size: 20, spacing: 5)
                VStack(alignment: .leading, spacing: 2) {
                    Text("The panel's take").forgeLabelSmall()
                    Text(check.verdict.displayName).font(.system(.subheadline, weight: .medium)).foregroundStyle(ForgeColor.ink)
                }
                Spacer(minLength: ForgeSpacing.s)
                if let evaluation {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(evaluation.confidence)").font(ForgeType.numeralSmall).foregroundStyle(ForgeColor.ink).monospacedDigit()
                        Text(Plain.beside("Confidence", "how sure")).forgeLabelSmall()
                    }
                }
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(ForgeColor.inkSecondary)
            }
            .padding(ForgeSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("The panel's take: \(check.verdict.displayName)\(evaluation.map { ", Confidence \($0.confidence)" } ?? ""). Opens the Brief.")
    }
}
