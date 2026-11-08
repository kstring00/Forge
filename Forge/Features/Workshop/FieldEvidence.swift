import Foundation
import SwiftData
import ForgeCore

/// §0A step 6, the return. What the user brings back from the world (a logged
/// conversation, what happened when a step was done) is saved as a
/// user-verified Source and attached as Evidence to the criterion the step
/// was testing, at the rung the report earns: 3 gave time, 4 gave money,
/// 5 came back. User-verified evidence is not bound by the desk ceiling, so
/// Confidence can rise above 2 here and nowhere else.
enum FieldEvidence {
    struct Report: Equatable {
        var text: String
        /// 0 to 5. Below 3 the words are saved but no rung is claimed.
        var rung: Int
        /// The recording's file name when the report was spoken.
        var audioFileName: String?

        init(text: String, rung: Int, audioFileName: String? = nil) {
            self.text = text
            self.rung = min(max(rung, 0), 5)
            self.audioFileName = audioFileName
        }
    }

    struct Recorded {
        let source: Source
        let evidence: Evidence?
        let criterionKey: String?
        let levelBefore: Int
        let levelAfter: Int
        let confidenceBefore: Int
        let confidenceAfter: Int
    }

    /// Saves the report on the idea and, when it earns a rung, attaches it to
    /// the step's criterion on the latest working version. Returns what moved.
    @discardableResult
    static func record(_ report: Report, kind: String, on idea: Idea, project: Project? = nil, now: Date = .now) -> Recorded {
        let text = report.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = Source(kind: report.audioFileName == nil ? .note : .voice,
                            title: "\(kind): " + String(text.prefix(56)) + (text.count > 56 ? "…" : ""),
                            fullText: text, sourceClass: .userVerified)
        source.fileRef = report.audioFileName
        source.reviewed = true
        source.capturedAt = now
        source.chunks.append(SourceChunk(index: 0, text: text))
        idea.sources.append(source)

        guard let evaluation = idea.latestEvaluation, !evaluation.isFinal else {
            return Recorded(source: source, evidence: nil, criterionKey: nil, levelBefore: 0, levelAfter: 0, confidenceBefore: 0, confidenceAfter: 0)
        }
        let key = project?.nextStepCriterionKey ?? evaluation.ladderKey
        let confidenceBefore = evaluation.confidence
        guard report.rung >= 3, let criterion = evaluation.lens.criterion(key) else {
            return Recorded(source: source, evidence: nil, criterionKey: key, levelBefore: evaluation.criterionScore(for: key)?.evidenceLevel ?? 0,
                            levelAfter: evaluation.criterionScore(for: key)?.evidenceLevel ?? 0, confidenceBefore: confidenceBefore, confidenceAfter: confidenceBefore)
        }

        if evaluation.criterionScore(for: key) == nil {
            try? evaluation.set(key: key, score: 1, evidenceLevel: 0)
        }
        guard let score = evaluation.criterionScore(for: key) else {
            return Recorded(source: source, evidence: nil, criterionKey: key, levelBefore: 0, levelAfter: 0, confidenceBefore: confidenceBefore, confidenceAfter: confidenceBefore)
        }
        let before = score.evidenceLevel
        let evidence = Evidence(criterionKey: key, ladderRung: report.rung, text: text, source: source)
        score.evidence.append(evidence)

        // The ladder moves on what a real person did. One person per report.
        if report.rung > score.evidenceLevel {
            score.evidenceLevel = report.rung
            score.peopleAtRung = 1
        } else if report.rung == score.evidenceLevel {
            score.peopleAtRung += 1
        }
        if criterion.scoreEqualsLadder {
            score.score = Scoring.demandScore(peopleAtRung: [score.evidenceLevel: score.peopleAtRung])
        }
        // The user brought this; it is no longer the panel's proposal.
        score.aiProposed = false
        evaluation.recompute()
        idea.touch()
        return Recorded(source: source, evidence: evidence, criterionKey: key, levelBefore: before, levelAfter: score.evidenceLevel,
                        confidenceBefore: confidenceBefore, confidenceAfter: evaluation.confidence)
    }

    /// One line for the sheet after saving: what moved.
    static func line(for r: Recorded, lens: Lens) -> String {
        guard let key = r.criterionKey, r.evidence != nil else { return "Saved as verified by you." }
        let title = lens.criterion(key)?.title ?? key
        if r.levelAfter > r.levelBefore {
            return "Saved as verified. \(title) moved to rung \(r.levelAfter); Confidence \(r.confidenceBefore) → \(r.confidenceAfter)."
        }
        return "Saved as verified on \(title) at rung \(r.levelAfter)."
    }
}
