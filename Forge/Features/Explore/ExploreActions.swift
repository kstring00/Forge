import Foundation
import ForgeCore

/// Pure operations on an idea's explorations. One user answer per prompt key,
/// updated in place; AI notes accumulate as separate confirmed records.
enum ExploreActions {
    static func latest(for key: String, on idea: Idea) -> Exploration? {
        idea.explorations.filter { $0.promptKey == key }.max { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    static func answer(_ text: String, promptKey: String, on idea: Idea) -> Exploration {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let exploration: Exploration
        if let existing = latest(for: promptKey, on: idea), !ExplorePrompts.isAIKey(promptKey) {
            existing.userText = trimmed
            exploration = existing
        } else {
            exploration = Exploration(promptKey: promptKey, userText: trimmed)
            idea.explorations.append(exploration)
        }
        if idea.stage == .capture, !trimmed.isEmpty { idea.stage = .explore }
        idea.touch()
        return exploration
    }

    @discardableResult
    static func acceptAI(text: String, promptKey: String, on idea: Idea) -> Exploration {
        let exploration = Exploration(promptKey: promptKey)
        exploration.aiText = text
        exploration.confirmed = true
        idea.explorations.append(exploration)
        if idea.stage == .capture { idea.stage = .explore }
        idea.touch()
        return exploration
    }

    static func answeredCount(on idea: Idea) -> Int {
        ExplorePrompts.keys.filter { key in !(latest(for: key, on: idea)?.userText.isEmpty ?? true) }.count
    }

    static func aiNotes(on idea: Idea) -> [Exploration] {
        idea.explorations
            .filter { ExplorePrompts.isAIKey($0.promptKey) && $0.confirmed && !($0.aiText ?? "").isEmpty }
            .sorted { $0.createdAt < $1.createdAt }
    }
}
