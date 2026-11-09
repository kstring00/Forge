import Foundation
import SwiftData
import ForgeCore

/// The minimal Workshop (Phase 2): commit an idea to a project with one next
/// step, complete steps, record what happened, pause and launch. Every
/// commitment and outcome lands in the Decision Journal.
enum WorkshopActions {
    struct Commitment {
        var name: String
        var desiredOutcome: String
        var nextStep: String
        var beliefs: String = ""
        var reasoning: String = ""
        var expectedResult: String = ""
        var expectedBy: Date? = nil
    }

    /// Converts an idea to a project and writes the commit entry. Returns the
    /// existing project if the idea already has one.
    @discardableResult
    static func convert(_ idea: Idea, with c: Commitment, in context: ModelContext) -> Project {
        if let existing = idea.project { return existing }
        let project = Project(name: c.name.trimmingCharacters(in: .whitespacesAndNewlines),
                              desiredOutcome: c.desiredOutcome.trimmingCharacters(in: .whitespacesAndNewlines))
        project.nextStep = clean(c.nextStep)
        idea.project = project
        idea.stage = .build

        let decision = Decision(kind: .commit,
                                decision: "Committed to \(project.name)",
                                beliefs: c.beliefs,
                                reasoning: c.reasoning,
                                expectedResult: c.expectedResult,
                                expectedBy: c.expectedBy)
        decision.idea = idea
        decision.project = project
        context.insert(decision)
        return project
    }

    static func setNextStep(_ project: Project, _ text: String, caveat: String? = nil, target: Int = 1,
                            dueAt: Date? = nil, moves: String? = nil, criterionKey: String? = nil) {
        project.nextStep = clean(text)
        project.nextStepCaveat = caveat.flatMap(clean)
        project.nextStepTarget = max(1, target)
        project.nextStepCount = 0
        project.nextStepDueAt = dueAt
        project.nextStepMoves = moves.flatMap(clean)
        project.nextStepCriterionKey = criterionKey
        project.idea?.touch()
    }

    /// One conversation (or message, or signup) done against the current step.
    /// Records what was learned as an outcome entry, advances the count, and
    /// saves the report as a user-verified Source attached to the step's
    /// criterion at the rung it earns (§0A step 6). The step itself stays until
    /// the user marks it done; reaching the target is a nudge, not a close.
    @discardableResult
    static func logConversation(_ project: Project, whatHappened: String, rung: Int? = nil, audioFileName: String? = nil,
                                from: String? = nil, in context: ModelContext, now: Date = .now) -> Decision? {
        guard let step = project.nextStep else { return nil }
        let text = whatHappened.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        project.nextStepCount += 1
        let n = project.nextStepCount, of = project.effectiveTarget
        let d = Decision(kind: .outcome, decision: "Logged \(n) of \(of) · \(step)", decidedAt: now)
        d.recordOutcome(text, at: now)
        d.idea = project.idea
        d.project = project
        context.insert(d)
        if let idea = project.idea {
            let earned = max(RungInference.rungForConversation(text), rung ?? 0)
            FieldEvidence.record(.init(text: text, rung: earned, audioFileName: audioFileName), kind: "Conversation", on: idea, project: project, from: from, now: now)
        }
        project.idea?.touch()
        return d
    }

    // MARK: Interviews (decision 0030)

    /// The project's question list, seeded once from the panel's drafted asset.
    static func interviewQuestions(for project: Project) -> [String] {
        if let q = project.interviewQuestions, !q.isEmpty { return q }
        let idea = project.idea
        let asset = idea?.latestRealityCheck?.draftedAssetSourceID.flatMap { id in idea?.sources.first { $0.id == id } }
        let parsed = asset.map { InterviewQuestions.parse($0.fullText) } ?? InterviewQuestions.fallback
        project.interviewQuestions = parsed
        return parsed
    }

    static func setInterviewQuestions(_ project: Project, _ questions: [String]) {
        let cleaned = questions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        project.interviewQuestions = cleaned.isEmpty ? InterviewQuestions.fallback : cleaned
    }

    /// The open draft, or a new one on the current questions.
    static func currentDraft(for project: Project) -> Interview {
        if let d = project.interviews.last(where: { $0.isDraft }) { return d }
        return Interview(questions: interviewQuestions(for: project))
    }

    /// Drafts save as you type. Empty drafts are not kept.
    static func saveDraft(_ interview: Interview, on project: Project) {
        var i = interview
        i.updatedAt = .now
        if let idx = project.interviews.firstIndex(where: { $0.id == i.id }) {
            if i.hasContent { project.interviews[idx] = i } else { project.interviews.remove(at: idx) }
        } else if i.hasContent {
            project.interviews.append(i)
        }
    }

    static func discardDraft(_ interview: Interview, on project: Project) {
        project.interviews.removeAll { $0.id == interview.id && $0.isDraft }
    }

    /// Done: one logged conversation. The transcript becomes a user-verified
    /// Source on the step's criterion at the confirmed rung, the count advances,
    /// the Journal gets its entry, and the interview is kept under the step.
    @discardableResult
    static func finishInterview(_ interview: Interview, rung: Int, on project: Project, in context: ModelContext, now: Date = .now) -> Decision? {
        var i = interview
        guard i.hasContent, project.nextStep != nil else { return nil }
        let who = i.who.trimmingCharacters(in: .whitespacesAndNewlines)
        let decision = logConversation(project, whatHappened: i.transcript, rung: max(3, rung), from: who.isEmpty ? nil : who, in: context, now: now)
        i.status = .done
        i.rung = max(3, rung)
        i.updatedAt = now
        i.sourceID = project.idea?.sources.filter { $0.sourceClass == .userVerified }.max { $0.capturedAt < $1.capturedAt }?.id
        if let idx = project.interviews.firstIndex(where: { $0.id == i.id }) { project.interviews[idx] = i } else { project.interviews.append(i) }
        return decision
    }

    static func targetReached(_ project: Project) -> Bool {
        project.nextStep != nil && project.nextStepCount >= project.effectiveTarget
    }

    /// Marks the current next step done, records what happened as an outcome
    /// entry, and sets the following step (or leaves it empty).
    @discardableResult
    static func completeNextStep(_ project: Project, whatHappened: String, nextStep: String?, rung: Int = 0, audioFileName: String? = nil,
                                 in context: ModelContext) -> Decision? {
        guard let step = project.nextStep else { return nil }
        let text = whatHappened.trimmingCharacters(in: .whitespacesAndNewlines)
        let outcome = Decision(kind: .outcome, decision: "Did: \(step)")
        outcome.recordOutcome(text)
        outcome.idea = project.idea
        outcome.project = project
        context.insert(outcome)
        if let idea = project.idea, !text.isEmpty {
            FieldEvidence.record(.init(text: text, rung: rung, audioFileName: audioFileName), kind: "What happened", on: idea, project: project)
        }
        project.nextStep = nextStep.flatMap(clean)
        project.nextStepCaveat = nil
        project.nextStepTarget = 1
        project.nextStepCount = 0
        project.nextStepDueAt = nil
        project.nextStepMoves = nil
        project.idea?.touch()
        return outcome
    }

    /// The latest commitment without a recorded outcome, if any.
    static func openCommitment(_ project: Project) -> Decision? {
        project.decisions
            .filter { $0.kind == .commit && !$0.hasOutcome }
            .max { $0.date < $1.date }
    }

    static func pause(_ project: Project, whatHappened: String?, in context: ModelContext) {
        guard project.status == .active else { return }
        project.status = .paused
        project.pausedAt = Date()
        recordStatusOutcome(project, label: "Paused", whatHappened: whatHappened, in: context)
    }

    static func resume(_ project: Project) {
        guard project.status == .paused else { return }
        project.status = .active
        project.pausedAt = nil
        project.idea?.touch()
    }

    /// "Launched": what done means for this idea was reached.
    static func complete(_ project: Project, whatHappened: String?, in context: ModelContext) {
        guard project.status != .done else { return }
        project.status = .done
        project.completedAt = Date()
        project.idea?.stage = .launch
        recordStatusOutcome(project, label: "Launched", whatHappened: whatHappened, in: context)
    }

    /// Records an outcome against the open commitment when there is one, so the
    /// prediction and the result sit side by side; otherwise as its own entry.
    private static func recordStatusOutcome(_ project: Project, label: String, whatHappened: String?, in context: ModelContext) {
        let text = (whatHappened ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { project.idea?.touch(); return }
        if let open = openCommitment(project) {
            open.recordOutcome("\(label). \(text)")
        } else {
            let d = Decision(kind: .outcome, decision: label)
            d.recordOutcome(text)
            d.idea = project.idea
            d.project = project
            context.insert(d)
        }
        project.idea?.touch()
    }

    private static func clean(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
