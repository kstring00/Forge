import Foundation

/// Brief v4.2 §2: three stages replace the five-stage pipeline on every
/// screen. The stored `Stage` stays finer-grained so no record migrates;
/// each maps onto one track.
public enum Track: String, CaseIterable, Sendable, Identifiable {
    /// Captured, not yet checked. The Vault.
    case idea
    /// Checked. The panel weighs in and the user rules: the Brief, Hear the
    /// panel, the Lab and pivots.
    case formation
    /// Out in the world: steps, logging, launch, and the Journal.
    case reality

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .idea: "Idea"
        case .formation: "Formation"
        case .reality: "Reality"
        }
    }

    /// One line under the section title (decision 0025).
    public var tagline: String {
        switch self {
        case .idea: "Caught. The panel hasn't looked yet."
        case .formation: "The panel has spoken. You're deciding."
        case .reality: "You're out testing it."
        }
    }

    /// Shown in an empty section: how an idea gets here.
    public var howIdeasArrive: String {
        switch self {
        case .idea: "Catch one with the ember button, or say it out loud."
        case .formation: "Send an idea to the panel. It comes back here with a verdict."
        case .reality: "Say Looks right on a Brief, or Make it real on any idea. Its first step lands here."
        }
    }

    /// The stage an idea takes when the user moves it to this track by hand.
    public var entryStage: Stage {
        switch self {
        case .idea: .capture
        case .formation: .evaluate
        case .reality: .build
        }
    }

    public var next: Track? {
        switch self {
        case .idea: .formation
        case .formation: .reality
        case .reality: nil
        }
    }
}

public extension Stage {
    /// capture and explore → Idea; evaluate → Formation; build and launch →
    /// Reality. Archived ideas sit on no track.
    var track: Track? {
        switch self {
        case .capture, .explore: .idea
        case .evaluate: .formation
        case .build, .launch: .reality
        case .archived: nil
        }
    }
}
