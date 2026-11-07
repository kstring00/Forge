import Foundation

/// Voice capture contract. Phase 1 implements it with the Speech framework
/// and AVFoundation; recordings are stored locally with their transcripts.
public protocol SpeechCapturing: AnyObject {
    var isAvailable: Bool { get }
    func requestAuthorization() async -> Bool
}

public final class UnavailableSpeechCapture: SpeechCapturing {
    public init() {}
    public var isAvailable: Bool { false }
    public func requestAuthorization() async -> Bool { false }
}
