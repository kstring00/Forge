import Foundation
import SwiftData
import ForgeCore

/// §6C step 4. The user rules on one verdict and the ruling lands in the
/// Journal, always. What else it makes depends on the choice:
///
/// - Agree: a Decision. If the Sphere cited a source, that source is attached
///   to the verdict's criterion as Evidence, at the rung the criterion already
///   holds and never above what the source can prove (rung 2 for desk finds).
///   No score or rung changes: the user changes scores, never a ruling.
/// - Disagree: a Decision and an Assumption source holding the user's belief.
/// - Find out: a Decision and an Experiment card built from the criterion's
///   playbook, due when its timebox ends.
///
/// Ruling again on the same verdict replaces the earlier ruling and removes
/// what it made, so a mis-tap never stays in the Journal.
@MainActor
enum RulingActions {
    @discardableResult
    static func rule(_ verdict: Verdict, _ choice: RulingChoice, on idea: Idea, in context: ModelContext,
                     note: String? = nil, now: Date = .now) -> Ruling {
        if let old = verdict.ruling { undo(old, on: idea, in: context) }

        let ruling = Ruling(choice: choice, note: note)
        ruling.createdAt = now
        context.insert(ruling)
        verdict.ruling = ruling

        let lens = idea.latestEvaluation?.lens ?? Lenses.lens(for: idea.lensType ?? .business)
        let criterion = lens.criterion(verdict.criterionKey)
        let about = criterion.map { "\($0.title) (\($0.key))" } ?? verdict.criterionKey
        let sphere = verdict.sphere.displayName

        let decision: Decision
        switch choice {
        case .agree:
            decision = Decision(kind: .ruling,
                                decision: "Agreed with the \(sphere) on \(about): \(verdict.kind.displayName.lowercased()).",
                                beliefs: verdict.reason,
                                reasoning: verdict.sources.isEmpty ? "No source cited." : "Cited: " + verdict.sources.prefix(3).map(\.title).joined(separator: "; "),
                                decidedAt: now)
            ruling.resultingEvidence = attachEvidence(for: verdict, on: idea)

        case .disagree:
            let belief = note.flatMap { $0.isEmpty ? nil : $0 }
                ?? "I disagree with the \(sphere)'s \"\(verdict.kind.displayName.lowercased())\" on \(about)."
            let source = Source(kind: .note, title: "My view on \(criterion?.title ?? verdict.criterionKey)", fullText: belief, sourceClass: .assumption)
            source.capturedAt = now
            source.chunks.append(SourceChunk(index: 0, text: belief))
            idea.sources.append(source)
            ruling.resultingAssumption = source
            decision = Decision(kind: .ruling,
                                decision: "Disagreed with the \(sphere) on \(about): they said \(verdict.kind.displayName.lowercased()).",
                                beliefs: belief,
                                reasoning: "The \(sphere)'s reason: \(verdict.reason)",
                                decidedAt: now)

        case .findOut:
            let x = experiment(for: verdict, criterion: criterion, on: idea)
            ruling.resultingExperiment = x
            decision = Decision(kind: .ruling,
                                decision: "Will find out: \(about), where the \(sphere) said \(verdict.kind.displayName.lowercased()).",
                                beliefs: verdict.evidenceNeeded ?? verdict.reason,
                                reasoning: "Test: \(x.test)",
                                expectedResult: x.decisionRule,
                                expectedBy: Calendar.current.date(byAdding: .day, value: x.timeboxDays, to: now),
                                decidedAt: now)
            if let project = idea.project {
                project.notes.append(projectNote(about: about, test: x.test))
            }
        }
        decision.idea = idea
        context.insert(decision)
        ruling.resultingDecision = decision
        idea.touch()
        try? context.save()
        return ruling
    }

    /// The user's own words on a ruling. On a disagreement they become the belief on record.
    static func setNote(_ note: String, on ruling: Ruling) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        ruling.note = trimmed.isEmpty ? nil : trimmed
        guard !trimmed.isEmpty else { return }
        if ruling.choice == .disagree {
            ruling.resultingAssumption?.fullText = trimmed
            if let chunk = ruling.resultingAssumption?.chunks.first { chunk.text = trimmed }
        }
        ruling.resultingDecision?.beliefs = trimmed
    }

    /// Removes a ruling and everything it made.
    static func undo(_ ruling: Ruling, on idea: Idea, in context: ModelContext) {
        if let d = ruling.resultingDecision {
            idea.decisions.removeAll { $0.id == d.id }
            context.delete(d)
        }
        if let e = ruling.resultingEvidence {
            e.criterionScore?.evidence.removeAll { $0.id == e.id }
            context.delete(e)
        }
        if let s = ruling.resultingAssumption {
            idea.sources.removeAll { $0.id == s.id }
            context.delete(s)
        }
        if let x = ruling.resultingExperiment {
            if let project = idea.project {
                project.notes.removeAll { $0.hasSuffix(x.test) && $0.hasPrefix("To find out") }
            }
            context.delete(x)
        }
        ruling.verdict?.ruling = nil
        context.delete(ruling)
    }

    // MARK: Pieces

    /// The Sphere's first cited source, attached to its criterion on the latest
    /// working version. Nil if nothing was cited, the version is final, or the
    /// source is already attached there.
    private static func attachEvidence(for verdict: Verdict, on idea: Idea) -> Evidence? {
        guard let evaluation = idea.latestEvaluation, !evaluation.isFinal,
              let score = evaluation.criterionScore(for: verdict.criterionKey) else { return nil }
        let attached = Set(score.evidence.compactMap { $0.source?.id })
        guard let source = verdict.sources.first(where: { !attached.contains($0.id) }) else { return nil }
        let rung = min(score.evidenceLevel, ceiling(for: source))
        let ev = Evidence(criterionKey: verdict.criterionKey, ladderRung: rung,
                          text: "Agreed with the \(verdict.sphere.displayName): \(verdict.reason)", source: source)
        score.evidence.append(ev)
        return ev
    }

    /// What a source can prove. Desk finds stop at rung 2; the user's own
    /// assumptions prove nothing; what the user verified stands at the
    /// criterion's own rung.
    static func ceiling(for source: Source) -> Int {
        switch source.sourceClass {
        case .aiFound: Scoring.deskResearchRungCeiling
        case .assumption: 0
        case .userVerified: 5
        }
    }

    private static func experiment(for verdict: Verdict, criterion: Criterion?, on idea: Idea) -> Experiment {
        let current = idea.latestEvaluation?.criterionScore(for: verdict.criterionKey)?.evidenceLevel ?? 0
        let step = criterion?.playbook.first { $0.reachesRung > current } ?? criterion?.playbook.first
        let title = criterion?.title ?? verdict.criterionKey
        let next = criterion?.ladder.first { $0.level > current }
        return Experiment(
            hypothesis: verdict.evidenceNeeded.map { "Finding out: \($0)" }
                ?? "The \(verdict.sphere.displayName) is right that \(title.lowercased()) is \(verdict.kind.displayName.lowercased()): \(verdict.reason)",
            test: step.map { "\($0.title). \($0.body)" } ?? "Find one real person this applies to and ask about what they did last time.",
            metric: next.map { "Reaching rung \($0.level) on \(title): \($0.label)" } ?? "What you saw people do, in their words",
            cost: "Your time",
            timeboxDays: 7,
            decisionRule: "If what you find holds, record it on the Brief with I know something you don't; if it doesn't, record that too.")
    }

    static func projectNote(about: String, test: String) -> String {
        "To find out (\(about)): \(test)"
    }
}
