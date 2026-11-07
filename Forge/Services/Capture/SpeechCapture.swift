import Foundation
import AVFoundation
import Speech
import Observation

public enum CaptureError: LocalizedError {
    case recognizerUnavailable
    case notAuthorized

    public var errorDescription: String? {
        switch self {
        case .recognizerUnavailable: "Speech recognition isn't available on this device right now."
        case .notAuthorized: "Microphone or speech access is off. You can turn it on in Settings."
        }
    }
}

/// Voice capture: records audio to a local file and streams a live transcript
/// from the Speech framework. On-device recognition is used when the device
/// supports it, so capture works offline. One recording at a time.
@Observable
@MainActor
public final class SpeechCapture {
    public private(set) var transcript: String = ""
    public private(set) var isRecording = false
    /// 0...1 input level, for a soft meter. Not a waveform.
    public private(set) var level: Float = 0
    public private(set) var lastError: String?
    /// Where the current or most recent recording was written.
    public private(set) var recordingURL: URL?

    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var file: AVAudioFile?

    public init() {}

    public var isAvailable: Bool { recognizer?.isAvailable ?? false }

    public var isAuthorized: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
            && AVAudioApplication.shared.recordPermission == .granted
    }

    public func requestAuthorization() async -> Bool {
        let speech: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speech == .authorized else {
            lastError = CaptureError.notAuthorized.errorDescription
            return false
        }
        let mic = await AVAudioApplication.requestRecordPermission()
        if !mic { lastError = CaptureError.notAuthorized.errorDescription }
        return mic
    }

    /// Starts recording and live transcription. Any previous recording file is removed.
    public func start() throws {
        guard !isRecording else { return }
        guard let recognizer, recognizer.isAvailable else { throw CaptureError.recognizerUnavailable }
        guard isAuthorized else { throw CaptureError.notAuthorized }

        if let old = recordingURL { try? FileManager.default.removeItem(at: old) }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let url = RecordingStore.newRecordingURL()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let file = try AVAudioFile(forWriting: url, settings: format.settings)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.taskHint = .dictation

        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            try? file.write(from: buffer)
            let level = SpeechCapture.inputLevel(buffer)
            Task { @MainActor [weak self] in self?.level = level }
        }
        engine.prepare()
        try engine.start()

        transcript = ""
        lastError = nil
        recordingURL = url
        self.file = file
        self.request = request
        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result { self.transcript = result.bestTranscription.formattedString }
                // Errors after stop() are the normal end of a task; only report live ones.
                if let error, self.isRecording {
                    self.lastError = error.localizedDescription
                    self.stop()
                }
            }
        }
    }

    /// Stops recording. The final transcript may still arrive a moment later.
    public func stop() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        request?.endAudio()
        task?.finish()
        isRecording = false
        level = 0
        file = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Stops and deletes the recording. Used when a capture is cancelled.
    public func discardRecording() {
        stop()
        task?.cancel()
        task = nil
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        recordingURL = nil
        transcript = ""
    }

    /// Forgets the recording without deleting it. Used after the file has been attached to an Idea.
    public func reset() {
        stop()
        task = nil
        recordingURL = nil
        transcript = ""
        lastError = nil
    }

    nonisolated private static func inputLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        let rms = (sum / Float(n)).squareRoot()
        let db = 20 * log10(max(rms, 1e-7))
        return min(max((db + 50) / 50, 0), 1)
    }
}
