import Foundation

// Shared vocabulary. Raw values are stable strings so SwiftData and the
// proxy's JSON contracts can use them without a mapping layer.

public enum LensType: String, Codable, CaseIterable, Sendable, Identifiable {
    case business
    case growth
    case creative

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .business: "Business"
        case .growth: "Personal Growth"
        case .creative: "Creative Experiment"
        }
    }
}

public enum Stage: String, Codable, CaseIterable, Sendable {
    case capture, explore, evaluate, build, launch, archived

    public var displayName: String { rawValue.capitalized }
}

public enum IdeaOrigin: String, Codable, Sendable {
    case captured, pitched, pivoted
}

public enum PivotType: String, Codable, CaseIterable, Sendable {
    case zoomIn, zoomOut, customerSegment, customerNeed, channel, businessModel, technology

    public var displayName: String {
        switch self {
        case .zoomIn: "Zoom-in"
        case .zoomOut: "Zoom-out"
        case .customerSegment: "Customer segment"
        case .customerNeed: "Customer need"
        case .channel: "Channel"
        case .businessModel: "Business model"
        case .technology: "Technology / delivery"
        }
    }
}

/// The advisory next move at the end of every evaluation. Never automatic.
public enum Recommendation: String, Codable, CaseIterable, Sendable {
    case exploreFurther
    case testRiskiestAssumption
    case buildSmallPrototype
    case startBuilding
    case revisitLater
    case archive

    public var displayName: String {
        switch self {
        case .exploreFurther: "Explore further"
        case .testRiskiestAssumption: "Test the riskiest assumption"
        case .buildSmallPrototype: "Build a small prototype"
        case .startBuilding: "Start building"
        case .revisitLater: "Revisit later"
        case .archive: "Archive"
        }
    }
}

public enum SourceKind: String, Codable, CaseIterable, Sendable {
    case web, pdf, text, voice, image, note
}

/// Who vouches for a source. Only `userVerified` evidence raises Confidence
/// without further action; `aiFound` must be reviewed first; `assumption` never does.
public enum SourceClass: String, Codable, CaseIterable, Sendable {
    case userVerified
    case aiFound
    case assumption

    public var displayName: String {
        switch self {
        case .userVerified: "Verified by me"
        case .aiFound: "Found by AI"
        case .assumption: "Assumption"
        }
    }
}

public enum ArtifactKind: String, Codable, CaseIterable, Sendable {
    case brief, audioBriefing, studyGuide, evidenceTable
}

public enum ProjectStatus: String, Codable, CaseIterable, Sendable {
    case active, paused, done, archived
}

public enum PitchCluster: String, Codable, CaseIterable, Sendable {
    case fastCash, recurring, asset, creative, growth

    public var displayName: String {
        switch self {
        case .fastCash: "Fastest cash"
        case .recurring: "Recurring revenue"
        case .asset: "Product / asset"
        case .creative: "Creative"
        case .growth: "Personal growth"
        }
    }
}

public enum PitchStatus: String, Codable, Sendable {
    case open, saved, rejected
}

public enum AdvantageKind: String, Codable, CaseIterable, Sendable {
    case skill, audience, relationship, asset
}

/// Answer to one Opportunity Filter question.
public enum TriageAnswer: String, Codable, CaseIterable, Sendable {
    case yes, no, unsure
}

// MARK: - §6C Spheres

public enum Sphere: String, Codable, CaseIterable, Sendable, Identifiable {
    case investor, customer, builder, strategist, skeptic, steward

    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }

    /// Spheres available before the Steward arrives in Phase 5.
    public static let phase3Panel: [Sphere] = [.investor, .customer, .builder, .strategist, .skeptic]
}

public enum VerdictKind: String, Codable, CaseIterable, Sendable {
    case onTrack, offTrack, cantTell

    public var displayName: String {
        switch self {
        case .onTrack: "On track"
        case .offTrack: "Off track"
        case .cantTell: "Can't tell"
        }
    }
}

public enum RulingChoice: String, Codable, CaseIterable, Sendable {
    case agree, disagree, findOut

    public var displayName: String {
        switch self {
        case .agree: "Agree"
        case .disagree: "Disagree"
        case .findOut: "Find out"
        }
    }
}
