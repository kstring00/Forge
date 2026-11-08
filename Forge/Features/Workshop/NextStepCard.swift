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
    private var target: Int { project.effectiveTarget }
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

    /// The count stays on one line; what counts as a conversation is a
    /// sentence of its own underneath, so it wraps instead of widening the page.
    private var progress: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(0..<min(target, 12), id: \.self) { i in
                        Capsule()
                            .fill(i < count ? ForgeColor.ember : ForgeColor.line)
                            .frame(maxWidth: style == .home ? .infinity : nil)
                            .frame(width: style == .home ? nil : (target > 6 ? 10 : 22), height: 5)
                    }
                }
                Text("\(count) of \(target)").forgeLabelSmall().lineLimit(1).fixedSize()
            }
            if style == .page, let moves = project.nextStepMoves {
                Text("Counts: \(moves)")
                    .font(.system(size: 13))
                    .foregroundStyle(ForgeColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) of \(target) logged" + (style == .page ? project.nextStepMoves.map { ". Counts: \($0)" } ?? "" : ""))
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

/// "What's riding on it": Potential and Confidence at 56 pt with their names,
/// the Est. return row (the user's figure, or the Investor's range with its
/// basis) with the verified-vs-estimate bar on Business ideas or the Impact
/// row on Growth and Creative, and one line tying the step to the evidence it
/// raises. Hidden when there is no evaluation.
struct StakesPanel: View {
    let evaluation: Evaluation
    let project: Project

    private var idea: Idea? { project.idea }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What's riding on it").forgeLabelSmall()
            HStack(alignment: .top, spacing: 14) {
                if let idea {
                    NavigationLink(value: LabRoute.criteria(ideaID: idea.id)) {
                        HStack(spacing: 14) {
                            smallRing(evaluation.potential, "Potential", ForgeColor.ink)
                            smallRing(evaluation.confidence, "Confidence", ForgeColor.ember)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the criteria with their evidence")
                }
                VStack(alignment: .trailing, spacing: 6) {
                    if let idea { EstimatedReturnRow(idea: idea, compact: false, alignment: .trailing) }
                    if evaluation.lensType == .business { bar(verified: evaluation.projection.verifiedFraction) }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            Text(NextStepPlan.ridingLine(confidence: evaluation.confidence, target: project.effectiveTarget, moves: project.nextStepMoves))
                .font(.system(size: 13)).foregroundStyle(ForgeColor.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(ForgeColor.canvas, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ForgeColor.line))
    }

    private func smallRing(_ value: Int, _ name: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(ForgeColor.line, lineWidth: 4)
                Circle().trim(from: 0, to: Double(min(max(value, 0), 100)) / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(value)").font(ForgeType.numeralSmall).foregroundStyle(ForgeColor.ink).monospacedDigit()
            }
            .frame(width: 56, height: 56)
            Text(name).forgeLabelSmall()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) \(value) out of 100")
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
