import SwiftUI
import SwiftData
import ForgeCore

/// What an idea has riding on it, in one labelled row. The user's own figure
/// when they have entered one ("your numbers"); otherwise the Investor's range
/// from the prefill, striped as AI-found, with what it rests on; Impact on
/// Growth and Creative ideas; and, before any check, the way to get a number.
enum EstimatedReturn {
    enum Value: Equatable {
        /// The user typed price and units, or a payment is attached.
        case yours(monthly: Double, verified: Bool)
        /// The Investor's monthly range and its basis.
        case estimate(low: Double, high: Double, basis: String?)
        /// Growth or Creative: who it helps and what changes.
        case impact(lead: String, rest: String?)
        /// Growth or Creative with nothing written yet.
        case impactMissing
        /// No check yet: send it to the panel.
        case unchecked
        /// Checked, but nothing in the Library supported a figure.
        case none

        var label: String {
            switch self {
            case .impact, .impactMissing: "Impact"
            default: "Est. return"
            }
        }
    }

    static func value(for idea: Idea) -> Value {
        guard let e = idea.latestEvaluation else {
            return RealityCheckPolicy.isOffered(for: idea.lensType) ? .unchecked : impact(nil)
        }
        if e.lensType != .business { return impact(e) }
        if let monthly = e.projection.recurringPerMonth {
            return .yours(monthly: monthly, verified: e.projection.verifiedUnits > 0)
        }
        if let low = e.projectionEstimateLow, let high = e.projectionEstimateHigh, high > 0 {
            return .estimate(low: low, high: high, basis: e.projectionEstimateBasis)
        }
        return idea.latestRealityCheck == nil ? .unchecked : .none
    }

    private static func impact(_ e: Evaluation?) -> Value {
        let who = e?.impactWho?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let changes = e?.impactWhatChanges?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !who.isEmpty { return .impact(lead: who, rest: changes.isEmpty ? nil : changes) }
        if !changes.isEmpty { return .impact(lead: changes, rest: nil) }
        return .impactMissing
    }

    /// "$900–$2.4k"
    static func range(_ low: Double, _ high: Double) -> String {
        low == high ? Projection.compact(low) : "\(Projection.compact(low))–\(Projection.compact(high))"
    }

    /// A number to sort by: the user's figure, else the middle of the range.
    static func sortKey(for idea: Idea) -> Double? {
        switch value(for: idea) {
        case .yours(let m, _): m
        case .estimate(let l, let h, _): (l + h) / 2
        default: nil
        }
    }
}

/// The row itself. Tapping it opens the estimate with its sources (or, with no
/// evaluation yet, nothing: the card's title opens the idea).
struct EstimatedReturnRow: View {
    let idea: Idea
    /// Dense, for the stakes cards; full, for the next-move panel.
    var compact = true
    /// Leading on the cards, trailing in the next-move panel.
    var alignment: HorizontalAlignment = .leading
    /// The verdict word, shown before the figure on cards ("Go ask people · …").
    var prefix: String? = nil
    @State private var showing = false

    private var value: EstimatedReturn.Value { EstimatedReturn.value(for: idea) }
    private var opens: Bool { idea.latestEvaluation != nil && idea.latestEvaluation?.lensType == .business }

    var body: some View {
        Button { if opens { showing = true } } label: {
            VStack(alignment: alignment, spacing: 3) {
                HStack(spacing: 6) {
                    Text(value.label).forgeLabelSmall()
                    if let prefix { Text("\(prefix) ·").forgeLabelSmall() }
                    if case .estimate = value { EvidenceChip(pattern: .stripes, size: 9) }
                    if case .yours(_, let verified) = value { EvidenceChip(pattern: verified ? .solid : .dots, size: 9) }
                    figure
                }
                if let basis {
                    Text(basis).font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary).lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!opens)
        .accessibilityLabel(accessibility)
        .accessibilityHint(opens ? "Opens the estimate and where it came from" : "")
        .sheet(isPresented: $showing) {
            if let e = idea.latestEvaluation { ProjectionEstimateSheet(idea: idea, evaluation: e) }
        }
    }

    @ViewBuilder
    private var figure: some View {
        switch value {
        case .yours(let monthly, _):
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(Projection.compact(monthly)).font(ForgeType.numeralSmall).foregroundStyle(ForgeColor.ink)
                Text("/ mo").font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
            }
        case .estimate(let low, let high, _):
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(EstimatedReturn.range(low, high)).font(ForgeType.numeralSmall).foregroundStyle(ForgeColor.ink)
                Text("/ mo").font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
            }
        case .impact(let lead, let rest):
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(lead).font(ForgeType.numeralSmall).foregroundStyle(Color(hex: 0x7CCB9F)).lineLimit(1)
                if let rest { Text(rest).font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary).lineLimit(1) }
            }
        case .impactMissing:
            placeholder("Add who it helps")
        case .unchecked:
            placeholder("Get the panel's take to estimate")
        case .none:
            placeholder("No price found yet")
        }
    }

    /// Placeholders are 13 pt muted sans, never display serif or colour.
    private func placeholder(_ text: String) -> some View {
        Text(text).font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary).lineLimit(1)
    }

    private var basis: String? {
        switch value {
        case .yours(_, let verified): verified ? "your numbers · partly verified" : "your numbers"
        case .estimate(_, _, let basis): "from " + (basis ?? "the desk research")
        default: nil
        }
    }

    private var accessibility: String {
        switch value {
        case .yours(let m, _): "Estimated return \(Projection.compact(m)) a month, your numbers"
        case .estimate(let l, let h, let b): "Estimated return \(EstimatedReturn.range(l, h)) a month, from \(b ?? "the desk research")"
        case .impact(let lead, let rest): "Impact: \(lead) \(rest ?? "")"
        case .impactMissing: "Impact: add who it helps"
        case .unchecked: "No estimate yet. Get the panel's take to estimate."
        case .none: "No price found yet."
        }
    }
}

/// The Investor's estimate, where it came from, and the way to replace it with
/// the user's own numbers. Reached from any Est. return row.
struct ProjectionEstimateSheet: View {
    let idea: Idea
    @Bindable var evaluation: Evaluation
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false

    private var competitors: [Competitor] { idea.latestRealityCheck?.competitors.filter { !$0.pricing.isEmpty } ?? [] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Est. return").forgeLabel()
                        switch EstimatedReturn.value(for: idea) {
                        case .yours(let m, let verified):
                            Text("\(Projection.compact(m)) / mo").font(ForgeType.numeral).foregroundStyle(ForgeColor.ink)
                            Text(verified ? "Your numbers, partly verified by a real payment." : "Your numbers. Drawn as an assumption until a payment is attached as evidence at proof level 4 (a real payment).")
                                .font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
                        case .estimate(let low, let high, let basis):
                            HStack(spacing: 8) {
                                EvidenceChip(pattern: .stripes, size: 12)
                                Text("\(EstimatedReturn.range(low, high)) / mo").font(ForgeType.numeral).foregroundStyle(ForgeColor.ink)
                            }
                            Text("The Investor's estimate, from \(basis ?? "the desk research"). It is AI-found: a range the desk supports, not a projection you made. Nothing is yours until you type it.")
                                .font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
                        default:
                            Text("No estimate").font(ForgeType.numeral).foregroundStyle(ForgeColor.inkSecondary)
                            Text("The desk found no price to go on. Enter your own figures below.").font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary)
                        }
                    }

                    ProjectionCard(evaluation: evaluation)

                    if !competitors.isEmpty {
                        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                            Text("Where the estimate came from").forgeSubhead()
                            ForEach(competitors) { c in
                                HStack(alignment: .top, spacing: ForgeSpacing.s) {
                                    EvidenceChip(pattern: c.source.map { EvidencePattern($0.sourceClass) } ?? .stripes, size: 12).padding(.top, 3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(c.name) · \(c.pricing)").font(.system(.subheadline)).foregroundStyle(ForgeColor.ink)
                                        if let s = c.source { Text(s.title).font(.footnote).foregroundStyle(ForgeColor.inkSecondary).lineLimit(1) }
                                    }
                                }
                            }
                            Text("A competitor's price proves the market exists (proof level 2 of 5 at most). It never proves demand for this idea.")
                                .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                        }
                    }

                    if let s = evaluation.projectionSuggestion, !s.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("The panel's reasoning").forgeLabel()
                            AIText(text: s)
                        }
                    }
                }
                .padding(ForgeSpacing.m)
                .padding(.bottom, ForgeSpacing.xxl)
            }
            .background(ForgeColor.canvas)
            .navigationTitle("Estimated return")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.large])
    }
}
