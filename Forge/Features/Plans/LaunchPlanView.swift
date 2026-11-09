import SwiftUI
import SwiftData
import ForgeCore

/// Decision 0041: one idea's launch plan. The sky header, the two meters
/// (Proof names the next step), what's proven and what isn't, who it's for,
/// the first 90 days, the money, when to stop, and Export as PDF: the one
/// orange button.
struct LaunchPlanView: View {
    let idea: Idea
    @State private var pdfURL: URL?

    private var plan: LaunchPlan? { idea.launchPlan }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                VStack(alignment: .leading, spacing: ForgeSpacing.m) {
                    if let plan {
                        CardMeters(idea: idea)
                        changed(plan)
                        provenCard(plan)
                        card("Who it's for") {
                            Text(plan.forWho).font(.body).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
                        }
                        daysCard(plan)
                        moneyCard(plan)
                        stopCard(plan)
                        if let note = plan.stewardNote {
                            card("Your charter") {
                                Text(note).font(.body).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        export
                        Text("Solid dots are things people or sources have shown; hollow dots are still beliefs. Every figure is an estimate until someone pays.")
                            .font(.footnote).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("No plan yet. The panel turns what Hunch knows about this idea into a short plan: what's proven, the first 90 days, the money, and when to stop.")
                            .font(.body).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
                        MakePlanButton(idea: idea, prominent: true)
                    }
                }
                .padding(.horizontal, ForgeSpacing.m)
                .padding(.bottom, ForgeSpacing.xxl)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(ForgeColor.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task(id: idea.launchPlanData) { makePDF() }
    }

    // MARK: Header

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            SkyHeader()
            VStack(alignment: .leading, spacing: 8) {
                Text(plan.map { "Launch plan · updated \(Self.when($0.createdAt))" } ?? "Launch plan")
                    .forgeLabel().foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
                Text(idea.title)
                    .font(ForgeType.ideaTitleHero)
                    .foregroundStyle(ForgeColor.ink)
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 2)
                    .fixedSize(horizontal: false, vertical: true)
                if let plan {
                    Text(plan.oneLine)
                        .font(.subheadline).foregroundStyle(ForgeColor.ink.opacity(0.9))
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, ForgeSpacing.m)
            .padding(.top, 110)
            .padding(.bottom, ForgeSpacing.l)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "today", "yesterday", "Nov 3".
    static func when(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "today" }
        if cal.isDateInYesterday(date) { return "yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: Since the plan

    @ViewBuilder
    private func changed(_ plan: LaunchPlan) -> some View {
        let changes = PlanBuilder.changes(since: plan, for: idea)
        if !changes.isEmpty {
            VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                Text("Since this plan").forgeLabelSmall()
                Text(ProofStage.sentence(changes.joined(separator: ", ")))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
                MakePlanButton(idea: idea)
            }
            .padding(ForgeSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ForgeColor.emberText.opacity(0.08), in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.emberText.opacity(0.35)))
        }
    }

    // MARK: What's proven · what isn't

    private func provenCard(_ plan: LaunchPlan) -> some View {
        card("What's proven · what isn't") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(plan.proven.enumerated()), id: \.offset) { _, claim in
                    claimRow(solid: true, text: claim.text, source: claim.sourceID.flatMap(sourceTitle))
                }
                ForEach(Array(plan.unproven.enumerated()), id: \.offset) { _, text in
                    claimRow(solid: false, text: text, source: nil)
                }
                if !plan.riskiest.isEmpty {
                    (Text("The riskiest belief: ").fontWeight(.semibold) + Text(plan.riskiest))
                        .font(.subheadline).foregroundStyle(ForgeColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
        }
    }

    private func claimRow(solid: Bool, text: String, source: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(solid ? ForgeColor.ink : Color.clear)
                .overlay(Circle().strokeBorder(solid ? ForgeColor.ink : ForgeColor.inkSecondary, lineWidth: 1.5))
                .frame(width: 14, height: 14)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(text).font(.body).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
                if let source { Text(source).font(.footnote).foregroundStyle(ForgeColor.inkSecondary).lineLimit(2) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(solid ? "Shown" : "Still a belief"): \(text)")
    }

    private func sourceTitle(_ id: UUID) -> String? { idea.sources.first { $0.id == id }?.title }

    // MARK: First 90 days

    /// The block the plan is in now, from how long ago it was made.
    private func current(_ plan: LaunchPlan) -> Int {
        let days = Calendar.current.dateComponents([.day], from: plan.createdAt, to: .now).day ?? 0
        return min(2, max(0, days / 30))
    }

    private func daysCard(_ plan: LaunchPlan) -> some View {
        let now = current(plan)
        return card("First 90 days") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(plan.phases.enumerated()), id: \.offset) { i, phase in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle().strokeBorder(i == now ? ForgeColor.emberText : ForgeColor.inkSecondary, lineWidth: 1.5)
                                if i == now { Circle().fill(ForgeColor.emberText).padding(4) }
                            }
                            .frame(width: 18, height: 18)
                            .padding(.top, 2)
                            if i < plan.phases.count - 1 {
                                Rectangle().fill(ForgeColor.line).frame(width: 1.5).frame(maxHeight: .infinity)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(phase.days.uppercased())
                                .font(.system(.caption, design: .monospaced, weight: .medium))
                                .foregroundStyle(ForgeColor.inkSecondary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(ForgeColor.line.opacity(0.6), in: Capsule())
                            Text(phase.title).font(ForgeType.subhead).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
                            Text(phase.detail).font(.subheadline).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
                            (Text("Decide: ").fontWeight(.semibold) + Text(phase.decide))
                                .font(.subheadline).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.bottom, i < plan.phases.count - 1 ? ForgeSpacing.l : 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: The money

    @ViewBuilder
    private func moneyCard(_ plan: LaunchPlan) -> some View {
        if let inputs = idea.latestEvaluation?.estimateInputs, let m = PlanMoney(inputs) {
            card("The money") {
                VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 8) { equation(m, plan) }
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 8) {
                                term(LaunchPlanDocument.dollars(m.price), "price / mo", assumption: m.priceIsAssumption)
                                op("×")
                                term("\(m.customers) \(plan.customerNoun)", "in year one", assumption: m.customersIsAssumption)
                            }
                            HStack(alignment: .top, spacing: 8) {
                                op("×")
                                term(m.sharePercent, "who pay", assumption: m.shareIsAssumption)
                                op("=")
                                term("\(LaunchPlanDocument.dollars(m.monthly)) / mo", "est. monthly", assumption: false)
                            }
                        }
                    }
                    Text("The middle of the panel's estimate, not a promise. Dotted labels are assumptions; the rest rest on a source.")
                        .font(.footnote).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            card("The money") {
                Text(moneyNote).font(.body).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var moneyNote: String {
        if case .tooEarly(let why) = EstimatedReturn.value(for: idea) { return why + ". A price from a real conversation fixes that." }
        return "No figure yet. A price from a real conversation is the first number this plan needs."
    }

    @ViewBuilder
    private func equation(_ m: PlanMoney, _ plan: LaunchPlan) -> some View {
        term(LaunchPlanDocument.dollars(m.price), "price / mo", assumption: m.priceIsAssumption)
        op("×")
        term("\(m.customers) \(plan.customerNoun)", "in year one", assumption: m.customersIsAssumption)
        op("×")
        term(m.sharePercent, "who pay", assumption: m.shareIsAssumption)
        op("=")
        term("\(LaunchPlanDocument.dollars(m.monthly)) / mo", "est. monthly", assumption: false)
    }

    private func term(_ value: String, _ label: String, assumption: Bool) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(Font.custom("Fraunces-SemiBold", size: 22, relativeTo: .title3))
                .foregroundStyle(ForgeColor.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            HStack(spacing: 4) {
                Text(label.uppercased()).font(.system(.caption2, design: .default, weight: .semibold)).foregroundStyle(ForgeColor.inkSecondary)
                if assumption { EvidenceChip(pattern: .dots, size: 8) }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(ForgeColor.line.opacity(0.6), in: Capsule())
        }
        .fixedSize()
    }

    private func op(_ s: String) -> some View {
        Text(s).font(.title3).foregroundStyle(ForgeColor.inkSecondary).padding(.top, 2)
    }

    // MARK: When to stop

    private func stopCard(_ plan: LaunchPlan) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "octagon").font(.title).foregroundStyle(ForgeColor.emberText)
            Rectangle().fill(ForgeColor.line).frame(width: 1).frame(maxHeight: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("When to stop").forgeLabelSmall()
                Text(plan.stopRule).font(.body).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        .accessibilityElement(children: .combine)
    }

    // MARK: Export

    @ViewBuilder
    private var export: some View {
        if let pdfURL {
            ShareLink(item: pdfURL) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export as PDF")
                }
                .font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(minHeight: 52)
                .background(ForgeColor.ember, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, ForgeSpacing.s)
        }
    }

    private func makePDF() {
        guard let plan else { pdfURL = nil; return }
        let e = idea.latestEvaluation
        let stage = ProofStage.of(idea)
        let money = e?.estimateInputs.flatMap(PlanMoney.init)
        let input = LaunchPlanDocument.Input(
            title: idea.title, plan: plan,
            potential: e.flatMap { $0.criteria.isEmpty ? nil : PotentialWord.word($0.potential) },
            proof: stage == .none ? nil : stage.cardWord,
            nextStep: stage.nextStep(for: idea),
            money: money, moneyNote: money == nil ? moneyNote : nil,
            sourceTitles: Dictionary(idea.sources.map { ($0.id, $0.title) }, uniquingKeysWith: { a, _ in a }),
            dateText: plan.createdAt.formatted(date: .long, time: .omitted))
        pdfURL = try? PlanPDF.write(input)
    }

    // MARK: Card

    private func card<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(label).forgeLabel()
            content()
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }
}
