import Foundation
import Observation
import ForgeCore

/// What the AI proposes. Shown in full and saved only on Accept.
struct AIProposal: Equatable {
    enum Kind: Equatable { case expand, summarize }

    struct Section: Equatable, Identifiable {
        let key: String
        let label: String
        let text: String
        var id: String { key }
    }

    let kind: Kind
    let sections: [Section]
    let rationale: String
}

/// Drives Expand and Summarize for one idea. Offline is a calm state, not an error.
@Observable
@MainActor
final class ExploreAIController {
    enum State: Equatable {
        case idle
        case running(AIAction)
        case offline(String)
        case failed(String)
        case proposal(AIProposal)
    }

    private(set) var state: State = .idle
    private let client: any AIClient

    static let offlineMessage = "AI isn't connected yet. Your notes are safe here; this works once the proxy is set up."

    init(client: any AIClient) {
        self.client = client
    }

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    func expand(_ idea: Idea) async {
        await run(.expand, idea) { (r: ExpandResult, rationale: String) in
            var sections = [AIProposal.Section(key: "ai.expand", label: "Clarified", text: r.clarifiedText)]
            if !r.openQuestions.isEmpty {
                sections.append(.init(key: "ai.openQuestions", label: "Open questions",
                                      text: r.openQuestions.map { "• \($0)" }.joined(separator: "\n")))
            }
            if let s = r.proposedSummary, !s.isEmpty {
                sections.append(.init(key: "ai.summary", label: "One-line summary", text: s))
            }
            return AIProposal(kind: .expand, sections: sections, rationale: rationale)
        }
    }

    func summarize(_ idea: Idea) async {
        await run(.summarize, idea) { (r: SummarizeResult, rationale: String) in
            var sections: [AIProposal.Section] = []
            if !r.notes.isEmpty {
                sections.append(.init(key: "ai.summary.notes", label: "Notes", text: r.notes.map { "• \($0)" }.joined(separator: "\n")))
            }
            if !r.decisions.isEmpty {
                sections.append(.init(key: "ai.summary.decisions", label: "Decisions", text: r.decisions.map { "• \($0)" }.joined(separator: "\n")))
            }
            if !r.openQuestions.isEmpty {
                sections.append(.init(key: "ai.summary.openQuestions", label: "Open questions", text: r.openQuestions.map { "• \($0)" }.joined(separator: "\n")))
            }
            return AIProposal(kind: .summarize, sections: sections, rationale: rationale)
        }
    }

    /// Writes every proposed section as a confirmed AI exploration. Never touches user text.
    @discardableResult
    func accept(into idea: Idea) -> [Exploration] {
        guard case .proposal(let proposal) = state else { return [] }
        let saved = proposal.sections.map { ExploreActions.acceptAI(text: $0.text, promptKey: $0.key, on: idea) }
        state = .idle
        return saved
    }

    func discard() { state = .idle }
    func dismissMessage() { state = .idle }

    private func run<R: Codable & Sendable>(_ action: AIAction, _ idea: Idea, build: (R, String) -> AIProposal) async {
        guard !isRunning else { return }
        state = .running(action)
        do {
            let envelope = try await client.perform(action, context: AIContext.make(for: idea), expecting: R.self)
            let proposal = build(envelope.payload, envelope.rationale)
            state = proposal.sections.isEmpty ? .failed("The AI returned nothing usable.") : .proposal(proposal)
        } catch let error as AIError {
            switch error {
            case .offline, .notConfigured: state = .offline(Self.offlineMessage)
            case .rateLimited: state = .failed("The proxy is rate limiting. Try again in a minute.")
            case .invalidResponse(let detail): state = .failed("The AI's answer didn't match the contract: \(detail)")
            case .server(let status): state = .failed("The proxy answered with status \(status).")
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
