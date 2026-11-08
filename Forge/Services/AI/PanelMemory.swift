import Foundation
import ForgeCore

/// "FORGE remembers your track record and shares it with the panel. The AI
/// itself doesn't change." The about-you note: generated from the user's
/// settled rulings once there are enough, read, edited and reset in Settings,
/// and sent with every Sphere call as `aboutUser`.
enum PanelMemory {
    static let noteKey = "panel.memory.note"
    static let editedKey = "panel.memory.edited"
    static let generatedAtKey = "panel.memory.generatedAt"
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    static let label = "FORGE remembers your track record and shares it with the panel. The AI itself doesn't change."

    static var note: String {
        get { defaults.string(forKey: noteKey) ?? "" }
        set { defaults.set(newValue, forKey: noteKey) }
    }

    /// True once the user has edited the note; generation then leaves it alone.
    static var edited: Bool {
        get { defaults.bool(forKey: editedKey) }
        set { defaults.set(newValue, forKey: editedKey) }
    }

    static var generatedAt: Date? {
        let t = defaults.double(forKey: generatedAtKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    /// Regenerates from the record unless the user has taken the note over.
    /// Writes nothing until there are enough outcomes.
    static func refresh(from patterns: Patterns, lens: Lens) {
        guard !edited else { return }
        let fresh = patterns.aboutNote(lens: lens)
        guard fresh != note else { return }
        note = fresh
        defaults.set(Date.now.timeIntervalSince1970, forKey: generatedAtKey)
    }

    static func edit(_ text: String) {
        note = String(text.split(separator: " ").prefix(80).joined(separator: " ")).trimmingCharacters(in: .whitespacesAndNewlines)
        edited = !note.isEmpty
    }

    /// Back to the generated note on the next refresh; empty until then.
    static func reset() {
        note = ""
        edited = false
        defaults.removeObject(forKey: generatedAtKey)
    }
}
