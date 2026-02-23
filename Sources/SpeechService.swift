import Foundation
import AVFoundation

/// Singleton that owns the AVSpeechSynthesizer and AVAudioSession for all GPS announcements.
/// Audio session is configured to duck other apps' audio (e.g. music) during speech,
/// then restore volume automatically when the utterance finishes.
final class SpeechService: NSObject, ObservableObject {

    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    private let voiceIdKey = "SpeechService_voiceId"

    // MARK: - Published State

    @Published var selectedVoiceId: String? {
        didSet { UserDefaults.standard.set(selectedVoiceId, forKey: voiceIdKey) }
    }

    // MARK: - Voice Accessors

    var selectedVoice: AVSpeechSynthesisVoice {
        if let id = selectedVoiceId, let voice = AVSpeechSynthesisVoice(identifier: id) {
            return voice
        }
        // Prefer first enhanced/premium English voice; fall back to en-US
        return enhancedEnglishVoices.first
            ?? AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice()
    }

    /// All English voices sorted: premium → enhanced → standard, then alphabetically by name.
    var availableEnglishVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { lhs, rhs in
                if lhs.quality.rawValue != rhs.quality.rawValue {
                    return lhs.quality.rawValue > rhs.quality.rawValue
                }
                return lhs.name < rhs.name
            }
    }

    private var enhancedEnglishVoices: [AVSpeechSynthesisVoice] {
        availableEnglishVoices.filter { $0.quality != .default }
    }

    // MARK: - Init

    private override init() {
        super.init()
        selectedVoiceId = UserDefaults.standard.string(forKey: voiceIdKey)
        configureAudioSession()
        Log.info("SpeechService", "Initialized. Selected voice: \(selectedVoice.name) (\(selectedVoice.language))")
    }

    // MARK: - Audio Session

    /// Sets the audio session so music from other apps continues playing but ducks
    /// (volume lowers) whenever AVSpeechSynthesizer speaks, then restores automatically.
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .voicePrompt,
                options: [.duckOthers, .mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            Log.info("SpeechService", "Audio session: playback/voicePrompt + duckOthers/mixWithOthers")
        } catch {
            Log.error("SpeechService", "Audio session setup failed: \(error)")
        }
    }

    // MARK: - Speech

    func speak(_ text: String, rate: Float = 0.45, pitch: Float = 1.1) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        synthesizer.speak(utterance)
    }

    /// Plays a short sample phrase through the given voice so the user can preview it.
    func previewVoice(_ voice: AVSpeechSynthesisVoice) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: "This is how your GPS guide will sound on the road.")
        utterance.voice = voice
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.1
        synthesizer.speak(utterance)
        Log.info("SpeechService", "Previewing voice: \(voice.name)")
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
