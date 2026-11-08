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

    /// One line under the section title on Home.
    public var tagline: String {
        switch self {
        case .idea: "Caught, not looked at yet."
        case .formation: "The panel weighs in. You rule."
        case .reality: "Out in the world, being tested."
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
