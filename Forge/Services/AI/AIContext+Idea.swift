import Foundation
import ForgeCore

extension AIContext {
    /// Everything the model may see for one idea, and nothing else.
    @MainActor
    static func make(for idea: Idea) -> AIContext {
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
            SourceSnapshot(id: s.id, title: s.title, sourceClass: s.sourceClass, reviewed: s.reviewed,
                           chunks: s.chunks.sorted { $0.index < $1.index }.map { ChunkSnapshot(id: $0.id, index: $0.index, text: $0.text) })
        }
        ctx.aboutUser = PanelMemory.note.isEmpty ? nil : PanelMemory.note
        if let project = idea.project {
            ctx.milestones = project.orderedMilestones.map(\.title)
            ctx.decisions = project.decisions.sorted { $0.date < $1.date }.map(\.text)
            if let next = project.nextStep { ctx.openQuestions.append("Current next step: \(next)") }
        }
        return ctx
    }
}
