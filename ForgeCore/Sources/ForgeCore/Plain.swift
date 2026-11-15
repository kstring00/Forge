import Foundation

/// Decision 0029: plain words first, the brand term second, everywhere a new
/// user meets one. Nothing says rung, lens, Formation or Sphere on its own.
public enum Plain {
    public static let confidence = "How sure we are"
    public static let potential = "How big it could be"
    public static let panel = "The panel (five perspectives)"
    public static let step = "Your step"
    public static let ladder = "How strong the proof is"
    public static let lens = "Kind of idea"
    public static let voice = "voice"

    /// "proof level 3 of 5 (rung 3)"
    public static func rung(_ n: Int) -> String { "proof level \(n) of 5" }
    /// "Level 3" for tight spots where the ladder is already on screen.
    public static func level(_ n: Int) -> String { "Level \(n)" }
    /// A brand term with its plain meaning beside it: "Confidence · how sure we are".
    public static func beside(_ term: String, _ plain: String) -> String { "\(term) · \(plain.prefix(1).lowercased() + plain.dropFirst())" }
}
