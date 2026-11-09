import Foundation
import ForgeCore

extension AIContext {
    /// Everything the model may see for one idea, and nothing else. With a
    /// research packet (decision 0042) the panel reads the packet: web pages go
    /// by title only (still citable by id), the person's own sources in full.
    @MainActor
    static func make(for idea: Idea, packet: ResearchPacket? = nil, researchedAt: Date? = nil) -> AIContext {
        var ctx = AIContext(ideaID: idea.id, originalText: idea.originalText, title: idea.title, lens: idea.lensType)
        ctx.explorations = idea.explorations
            .filter { !ExplorePrompts.isAIKey($0.promptKey) && !$0.userText.isEmpty }
            .sorted { $0.createdAt < $1.createdAt }
            .map { e in
                let question = ExplorePrompts.prompt(for: e.promptKey)?.question ?? e.promptKey
                return "\(question) \(e.userText)"
            }
        let notes = idea.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { ctx.explorations.append("Notes: \(notes)") }
        ctx.sources = idea.sources.sorted { $0.capturedAt < $1.capturedAt }.map { s in
            let lean = packet != nil && s.sourceClass != .userVerified
            return SourceSnapshot(id: s.id, title: s.title, sourceClass: s.sourceClass, reviewed: s.reviewed,
                                  chunks: lean ? [] : s.chunks.sorted { $0.index < $1.index }.map { ChunkSnapshot(id: $0.id, index: $0.index, text: $0.text) })
        }
        if let packet { ctx.packet = snapshot(packet, researchedAt: researchedAt, sources: idea.sources) }
        ctx.aboutUser = PanelMemory.note.isEmpty ? nil : PanelMemory.note
        if let project = idea.project {
            ctx.milestones = project.orderedMilestones.map(\.title)
            ctx.decisions = project.decisions.sorted { $0.date < $1.date }.map(\.text)
            if let next = project.nextStep { ctx.openQuestions.append("Current next step: \(next)") }
        }
        return ctx
    }

    /// Each finding's page matched to the Library source with that address.
    @MainActor
    static func snapshot(_ packet: ResearchPacket, researchedAt: Date?, sources: [Source]) -> PacketSnapshot {
        var byURL: [String: UUID] = [:]
        for s in sources { if let u = s.url, byURL[u] == nil { byURL[u] = s.id } }
        let findings = packet.findings.map { f in
            PacketSnapshot.Finding(section: f.section, text: f.text, url: f.url,
                                   sourceID: ([f.url] + f.alsoURLs).lazy.compactMap { byURL[$0] }.first)
        }
        return PacketSnapshot(researchedAt: researchedAt.map { ISO8601DateFormatter().string(from: $0) }, findings: findings, gaps: packet.gaps)
    }
}
