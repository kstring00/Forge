import SwiftUI
import SwiftData
import ForgeCore

/// The next-step card, the same wherever it appears. The step in sans, never
/// display serif; one 13 pt muted caveat; progress segments; the due date;
/// Questions (the drafted asset) and Log a conversation.
///
/// On Home ("Home · leveled up") it is the next-move card: a 3 pt gradient top
/// edge, the idea's title in serif, the step in 16 pt, full-width segments,
/// and the "What's riding on it" panel with the rings, the Projection or
/// Impact, and one line tying the step to the evidence it raises.
struct NextStepCard: View {
    enum Style { case page, home }

    @Bindable var project: Project
    var style: Style = .page
    /// "Your next move" on Home, "Your next step" elsewhere.
    var label = "Your next step"
    /// Shown in the top right beside the due date: "Reality".
    var context: String? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var logging = false
    @State private var showingAsset = false

    private var idea: Idea? { project.idea }
    private var evaluation: Evaluation? { idea?.latestEvaluation }
    private var asset: Source? {
        idea?.latestRealityCheck?.draftedAssetSourceID.flatMap { id in idea?.sources.first { $0.id == id } }
    }
    private var target: Int { max(1, project.nextStepTarget) }
    private var count: Int { min(project.nextStepCount, target) }
    private var overdue: Bool { project.nextStepDueAt.map { $0 < .now } ?? false }

    var body: some View {
        if let step = project.nextStep {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(label).forgeLabel().foregroundStyle(ForgeColor.emberText)
                    Spacer()
                    Text(topRight).forgeLabel().foregroundStyle(overdue ? ForgeColor.emberText : ForgeColor.inkSecondary)
                }
                if style == .home, let idea {
                    Text(idea.title).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink).lineLimit(2)
                }
                Text(step)
                    .font(.system(size: style == .home ? 16 : 17, weight: .medium))
                    .foregroundStyle(ForgeColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let caveat = project.nextStepCaveat, style == .page {
                    Text(caveat)
                        .font(.system(size: 13))
                        .foregroundStyle(ForgeColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                progress
                if style == .home, let evaluation { StakesPanel(evaluation: evaluation, project: project) }
                buttons
            }
            .padding(ForgeSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.ember.opacity(0.6)))
            .overlay(alignment: .top) {
                if style == .home {
                    // The 3 pt gradient top edge.
                    LinearGradient(colors: [ForgeColor.lavender, ForgeColor.ember], startPoint: .leading, endPoint: .trailing)
                        .frame(height: 3)
                        .padding(.horizontal, ForgeSpacing.cardRadius)
                        .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
            .sheet(isPresented: $logging) {
                OutcomeSheet(title: "Log a conversation", subject: step, prompt: "What did they say or do?",
                             footnote: "One conversation. It counts toward \(target) and lands in the Journal next to what you expected.") { happened, _ in
                    WorkshopActions.logConversation(project, whatHappened: happened, in: modelContext)
                }
            }
            .sheet(isPresented: $showingAsset) {
                if let asset { DraftedAssetSheet(source: asset) }
            }
        }
    }

    private var topRight: String {
        var parts: [String] = []
        if let context { parts.append(context) }
        if let due = project.nextStepDueAt {
            parts.append((overdue ? "was due " : "due ") + due.formatted(.dateTime.weekday(.abbreviated)))
        }
        return parts.joined(separator: " · ")
    }

    private var progress: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<min(target, 12), id: \.self) { i in
                    Capsule()
                        .fill(i < count ? ForgeColor.ember : ForgeColor.line)
                        .frame(maxWidth: style == .home ? .infinity : nil)
                        .frame(width: style == .home ? nil : (target > 6 ? 10 : 22), height: 5)
                }
            }
            Text(progressLine).forgeLabelSmall().lineLimit(1).fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) of \(target) logged")
    }

    private var progressLine: String {
        var parts = ["\(count) of \(target)"]
        if let moves = project.nextStepMoves, style == .page { parts.append(moves) }
        return parts.joined(separator: " · ")
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            if asset != nil {
                Button { showingAsset = true } label: {
                    Text("Questions")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(ForgeColor.ink)
                        .padding(.horizontal, 18).frame(height: 48)
                        .background(ForgeColor.canvas, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ForgeColor.line))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the drafted questions or script")
            }
            Button { logging = true } label: {
                Text("Log a conversation")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(ForgeColor.ember, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(project.status != .active)
        }
    }
}

/// "What's riding on it": Potential and Confidence at 56 pt, the Projection
/// ("$X / mo if it works") with its verified-vs-estimate bar on Business
/// ideas or the Impact line on Growth and Creative, and one line tying the
/// step to the evidence it raises. Hidden when there is no evaluation.
struct StakesPanel: View {
    let evaluation: Evaluation
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What's riding on it").forgeLabelSmall()
            HStack(alignment: .center, spacing: 14) {
                smallRing(evaluation.potential, ForgeColor.ink)
                smallRing(evaluation.confidence, ForgeColor.ember)
                VStack(alignment: .leading, spacing: 4) {
                    if evaluation.lensType == .business {
                        Stake.projectionLine(evaluation).map { line in
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(line.figure).font(ForgeType.numeralMedium).foregroundStyle(ForgeColor.emberText)
                                Text(line.suffix).font(.system(size: 12)).foregroundStyle(ForgeColor.inkSecondary)
                            }
                        }
                        bar(verified: evaluation.projection.verifiedFraction)
                        Text(["Potential", "Confidence", Stake.projectionLine(evaluation)?.kind ?? "No figures yet"].joined(separator: " · ")).forgeLabelSmall()
                    } else {
                        Text(Stake.impactLine(evaluation) ?? "Say who this helps and how you'd know.")
                            .font(.system(size: 13)).foregroundStyle(ForgeColor.ink).lineLimit(3)
                        Text("Potential · Confidence · Impact").forgeLabelSmall()
                    }
                }
            }
            Text(NextStepPlan.ridingLine(confidence: evaluation.confidence, target: project.nextStepTarget, moves: project.nextStepMoves))
                .font(.system(size: 13)).foregroundStyle(ForgeColor.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(ForgeColor.canvas, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ForgeColor.line))
    }

    private func smallRing(_ value: Int, _ tint: Color) -> some View {
        ZStack {
            Circle().stroke(ForgeColor.line, lineWidth: 4)
            Circle().trim(from: 0, to: Double(min(max(value, 0), 100)) / 100)
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(value)").font(ForgeType.numeralSmall).foregroundStyle(ForgeColor.ink).monospacedDigit()
        }
        .frame(width: 56, height: 56)
        .accessibilityLabel("\(tint == ForgeColor.ember ? "Confidence" : "Potential") \(value)")
    }

    private func bar(verified: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(ForgeColor.line)
                HStack(spacing: 0) {
                    Rectangle().fill(ForgeColor.ink).frame(width: geo.size.width * verified)
                    EvidenceFill(pattern: .stripes, color: ForgeColor.inkSecondary)
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
        .frame(height: 4)
        .accessibilityLabel("\(Int((verified * 100).rounded())) percent verified")
    }
}

/// What an idea has riding on it, in one figure or one line.
enum Stake {
    struct Line { let figure: String; let suffix: String; let kind: String }

    /// The user's own projection first; the panel's estimate when there is none.
    static func projectionLine(_ e: Evaluation) -> Line? {
        if let recurring = e.projection.recurringPerMonth {
            return Line(figure: Projection.compact(recurring), suffix: "/ mo if it works", kind: e.projection.verifiedUnits > 0 ? "Partly verified" : "Yours, unverified")
        }
        if let s = e.projectionSuggestion, let figure = estimateFigure(from: s) {
            return Line(figure: figure, suffix: "/ mo est.", kind: "Estimate")
        }
        return nil
    }

    /// The impact in one line: who, or the signal.
    static func impactLine(_ e: Evaluation) -> String? {
        let who = e.impactWho?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let changes = e.impactWhatChanges?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !who.isEmpty && !changes.isEmpty { return "\(who): \(changes)" }
        if !who.isEmpty { return who }
        if !changes.isEmpty { return changes }
        return e.impactSignal?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    /// "$99–$199 per unit · 8–15 units in year one. …" → the low end of price × units, monthly.
    static func estimateFigure(from suggestion: String) -> String? {
        let numbers = suggestion
            .replacingOccurrences(of: ",", with: "")
            .split(whereSeparator: { !$0.isNumber && $0 != "." })
            .compactMap { Double($0) }
        guard numbers.count >= 3 else { return nil }
        let price = numbers[0], units = numbers[2]
        guard price > 0, units > 0 else { return nil }
        return Projection.compact(price * units)
    }

    /// For sorting "by stakes": the monthly figure, else nil.
    static func monthly(_ e: Evaluation?) -> Double? {
        guard let e else { return nil }
        if let r = e.projection.recurringPerMonth { return r }
        if let s = e.projectionSuggestion {
            let numbers = s.replacingOccurrences(of: ",", with: "").split(whereSeparator: { !$0.isNumber && $0 != "." }).compactMap { Double($0) }
            if numbers.count >= 3, numbers[0] > 0, numbers[2] > 0 { return numbers[0] * numbers[2] }
        }
        return nil
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

/// How many of what the drafted asset asks for, the one-line caveat, and the
/// line that ties the step to the evidence. Used when Looks right turns the
/// next move into a step, and on the Home card.
enum NextStepPlan {
    /// The count in the step itself first ("Talk to five parents"), then the
    /// drafted asset's kind, then one.
    static func target(assetTitle: String?, step: String) -> Int {
        if let n = NumberWords.firstNumber(in: step), (1...50).contains(n) { return n }
        let t = (assetTitle ?? "").lowercased()
        if t.contains("outreach") || t.contains("twenty") { return 20 }
        if t.contains("landing") || t.contains("waitlist") { return 1 }
        if t.contains("five") || t.contains("interview") || t.contains("question") { return 5 }
        return 1
    }

    /// The experiment's test if it adds to the step; nothing if it repeats it.
    static func caveat(step: String, experimentTest: String?) -> String? {
        guard let test = experimentTest?.trimmingCharacters(in: .whitespacesAndNewlines), !test.isEmpty else { return nil }
        let a = step.lowercased().trimmingCharacters(in: .punctuationCharacters)
        let b = test.lowercased().trimmingCharacters(in: .punctuationCharacters)
        if a == b || a.contains(b) || b.contains(a) { return nil }
        return test
    }

    /// "This step is how 33 becomes a real number. Five conversations move Demand to rung 3."
    static func ridingLine(confidence: Int, target: Int, moves: String?) -> String {
        let first = "This step is how \(confidence) becomes a real number."
        let countWord = spelled(target)
        let unit = target == 1 ? "conversation" : "conversations"
        if let moves = moves?.trimmingCharacters(in: .whitespacesAndNewlines), !moves.isEmpty {
            var m = moves
            if let r = m.range(of: #"^(moves|reaching|reach|raises|raise)\s+"#, options: [.regularExpression, .caseInsensitive]) { m.removeSubrange(r) }
            let lowered = m.prefix(1).lowercased() + m.dropFirst()
            let verb = target == 1 ? "moves" : "move"
            return "\(first) \(countWord.capitalized) \(unit) \(verb) \(lowered.hasSuffix(".") ? String(lowered.dropLast()) : lowered)."
        }
        return "\(first) \(countWord.capitalized) \(unit) and Confidence can move."
    }

    static func spelled(_ n: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
                     "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty"]
        return (0...20).contains(n) ? words[n] : "\(n)"
    }
}
