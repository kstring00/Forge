import Foundation
import ForgeCore

/// The AI Idea Partner. Every action is distinct and typed; there is no free-form chat.
/// Phase 0 ships only the contract and an offline implementation.
public enum AIAction: String, Codable, CaseIterable, Sendable {
    case expand
    case runRound          // §6C: replaces "challenge"
    case compare
    case designExperiment
    case plan
    case nextStep
    case summarize
    case explainCriterion
    case pivot
    case pitch
    case realityCheck      // §6D: desk research with four verdicts; the costliest action
    case prefill           // §0A: five Spheres pre-fill the whole Lab from the Library
    case launchPlan        // decision 0041: a short launch plan from what Hunch knows
}

public enum AIError: Error, Equatable, Sendable {
    case offline
    case notConfigured
    case rateLimited
    case invalidResponse(String)
    case server(status: Int)
}

/// Everything the model is allowed to see for one call. Built by the feature,
/// serialised by the client. Never includes anything outside the idea.
public struct AIContext: Codable, Sendable {
    public var ideaID: UUID
    public var originalText: String
    public var title: String
    public var lens: LensType?
    public var explorations: [String] = []
    public var scores: [ScoredCriterionSnapshot] = []
    public var sources: [SourceSnapshot] = []
    public var milestones: [String] = []
    public var decisions: [String] = []
    public var openQuestions: [String] = []
    public var advantages: [String] = []
    public var constraints: [String] = []
    public var stewardCharter: String?
    /// The user's own track record against the panel, kept by FORGE (§5).
    /// Under 80 words; the user reads, edits and resets it in Settings.
    public var aboutUser: String?
    /// Decision 0042: the check's shared research, findings tied to Library sources.
    public var packet: PacketSnapshot?
    public var spheres: [Sphere] = Sphere.phase3Panel

    public init(ideaID: UUID, originalText: String, title: String, lens: LensType? = nil) {
        self.ideaID = ideaID
        self.originalText = originalText
        self.title = title
        self.lens = lens
    }
}

/// The research packet as the proxy reads it: each finding with the id of
/// the Library source for its page (nil when no source has that address).
public struct PacketSnapshot: Codable, Sendable {
    public struct Finding: Codable, Sendable {
        public var section: ResearchPacket.Section
        public var text: String
        public var url: String
        public var sourceID: UUID?
    }
    public var researchedAt: String?
    public var findings: [Finding]
    public var gaps: [String]
}

public struct ScoredCriterionSnapshot: Codable, Sendable {
    public var key: String
    public var score: Int
    public var evidenceLevel: Int
    public var note: String
}

public struct SourceSnapshot: Codable, Sendable {
    public var id: UUID
    public var title: String
    public var sourceClass: SourceClass
    public var reviewed: Bool
    public var chunks: [ChunkSnapshot]
}

public struct ChunkSnapshot: Codable, Sendable {
    public var id: UUID
    public var index: Int
    public var text: String
}

/// Every action returns a typed payload plus a short plain-text rationale.
public struct AIEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    public struct Usage: Codable, Sendable {
        public var inputTokens: Int
        public var outputTokens: Int
        public var cacheReadTokens: Int
        public var cacheWriteTokens: Int
        public var webSearches: Int
    }
    public var payload: Payload
    /// List items the proxy removed for failing the contract or lacking a source, by list.
    public var dropped: [String: Int]?
    public var rationale: String
    public var model: String?
    /// Filled by the proxy; absent from canned and offline clients.
    public var usage: Usage?
    public var costUSD: Double?

    public init(payload: Payload, rationale: String, model: String? = nil, usage: Usage? = nil, costUSD: Double? = nil) {
        self.payload = payload
        self.rationale = rationale
        self.model = model
        self.usage = usage
        self.costUSD = costUSD
    }
}

public protocol AIClient: Sendable {
    var isAvailable: Bool { get }
    func perform<Payload: Codable & Sendable>(
        _ action: AIAction, context: AIContext, expecting: Payload.Type
    ) async throws -> AIEnvelope<Payload>
}
