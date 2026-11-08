import SwiftUI
import SwiftData
import ForgeCore

/// The next-step card, the same everywhere it appears (Home, the Formation
/// idea page, the Reality project page). The step in 17 pt sans, never
/// display serif; one 13 pt muted caveat; progress segments; the due date;
/// Questions (the drafted asset) and Log a conversation.
struct NextStepCard: View {
    @Bindable var project: Project
    /// "Your next move" on Home, "Your next step" elsewhere.
    var label = "Your next step"
    /// Shown in the top right when there is no due date: "Reality", "IntroBand".
    var context: String? = nil
    /// Home's card is denser: no Questions button, the idea name in the progress line.
    var compact = false

    @Environment(\.modelContext) private var context
    @State private var logging = false
    @State private var showingAsset = false

    private var idea: Idea? { project.idea }
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
                Text(step)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(ForgeColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let caveat = project.nextStepCaveat, !compact {
                    Text(caveat)
                        .font(.system(size: 13))
                        .foregroundStyle(ForgeColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                progress
                buttons
            }
            .padding(ForgeSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.ember.opacity(0.6)))
            .sheet(isPresented: $logging) {
                OutcomeSheet(title: "Log a conversation", subject: step, prompt: "What did they say or do?",
                             footnote: "One conversation. It counts toward \(target) and lands in the Journal next to what you expected.") { happened, _ in
                    WorkshopActions.logConversation(project, whatHappened: happened, in: context)
                }
            }
            .sheet(isPresented: $showingAsset) {
                if let asset { DraftedAssetSheet(source: asset) }
            }
        }
    }

    private var topRight: String {
        if let due = project.nextStepDueAt {
            return (overdue ? "Was due " : "Due ") + due.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
        return context ?? ""
    }

    private var progress: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<min(target, 12), id: \.self) { i in
                    Capsule()
                        .fill(i < count ? ForgeColor.ember : ForgeColor.line)
                        .frame(width: target > 6 ? 10 : 22, height: 5)
                }
            }
            Text(progressLine).forgeLabelSmall().lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) of \(target) logged")
    }

    private var progressLine: String {
        var parts = ["\(count) of \(target)"]
        if compact, let name = idea?.title { parts.insert(name, at: 0) }
        if let moves = project.nextStepMoves, !compact { parts.append(moves) }
        return parts.joined(separator: " · ")
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            if asset != nil && !compact {
                Button { showingAsset = true } label: {
                    Label("Questions", systemImage: "doc.text")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(ForgeColor.ink)
                        .padding(.horizontal, 16).frame(height: 48)
                        .background(ForgeColor.canvas, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ForgeColor.line))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the drafted questions or script")
            }
            Button { logging = true } label: {
                Label("Log a conversation", systemImage: "plus")
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

/// How many of what the drafted asset asks for, and the one-line caveat, from
/// what the panel wrote. Used when Looks right turns the next move into a step.
enum NextStepPlan {
    static func target(assetTitle: String?, step: String) -> Int {
        let t = (assetTitle ?? "").lowercased() + " " + step.lowercased()
        if t.contains("outreach") || t.contains("twenty") || t.contains("20 ") { return 20 }
        if t.contains("landing") || t.contains("waitlist") { return 1 }
        if t.contains("five") || t.contains("interview") || t.contains("question") || t.contains(" 5 ") { return 5 }
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
}
