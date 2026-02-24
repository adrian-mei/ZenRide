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
        // Prefer female premium human voices, fall back to en-US
        return preferredHumanVoice
            ?? availableHumanVoices.first
            ?? AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice()
    }

    /// Try specifically for female human voices (e.g. Siri or premium voices).
    private var preferredHumanVoice: AVSpeechSynthesisVoice? {
        let voices = availableHumanVoices
        
        // 1. Look for female Siri voices (if available/unlocked)
        if let siri = voices.first(where: { 
            ($0.name.lowercased().contains("siri") || $0.identifier.lowercased().contains("siri")) && 
            $0.gender == .female && 
            $0.language.hasPrefix("en") 
        }) {
            return siri
        }
        
        // 2. Look for any premium female English voice
        if let premiumFemale = voices.first(where: { 
            $0.quality == .premium && 
            $0.gender == .female && 
            $0.language.hasPrefix("en")
        }) {
            return premiumFemale
        }
        
        // 3. Fallback to any female English voice
        if let anyFemale = voices.first(where: { 
            $0.gender == .female && 
            $0.language.hasPrefix("en")
        }) {
            return anyFemale
        }
        
        return nil
    }

    /// High-quality voices (English, Mandarin, Cantonese) excluding robotic defaults.
    var availableHumanVoices: [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let supportedVoices = allVoices.filter { $0.language.hasPrefix("en") || $0.language.hasPrefix("zh") }
        
        var humanVoices = supportedVoices.filter { voice in
            voice.quality != .default || 
            voice.name.lowercased().contains("siri") || 
            voice.identifier == AVSpeechSynthesisVoiceIdentifierAlex
        }
        
        // Safety fallback: if no premium voices for a specific language group, add the standard ones back
        // so the user has at least one option to select from.
        if !humanVoices.contains(where: { $0.language.hasPrefix("en") }) {
            humanVoices.append(contentsOf: supportedVoices.filter { $0.language.hasPrefix("en") })
        }
        if !humanVoices.contains(where: { $0.language == "zh-CN" || $0.language == "zh-TW" }) {
            humanVoices.append(contentsOf: supportedVoices.filter { $0.language == "zh-CN" || $0.language == "zh-TW" })
        }
        if !humanVoices.contains(where: { $0.language == "zh-HK" }) {
            humanVoices.append(contentsOf: supportedVoices.filter { $0.language == "zh-HK" })
        }
        
        // Deduplicate in case of overlap
        let uniqueDict = Dictionary(grouping: humanVoices, by: { $0.identifier }).compactMapValues { $0.first }
        
        return Array(uniqueDict.values).sorted { lhs, rhs in
            if lhs.quality.rawValue != rhs.quality.rawValue {
                return lhs.quality.rawValue > rhs.quality.rawValue
            }
            return lhs.name < rhs.name
        }
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

    func speak(_ text: String, rate: Float = 0.5, pitch: Float = 1.0) {
        // Try Google TTS first
        GoogleTTSClient.shared.speak(text) { [weak self] in
            // Fallback to Apple TTS
            guard let self = self else { return }
            Log.info("SpeechService", "Falling back to Apple TTS for: \(text)")
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = self.selectedVoice
            utterance.rate = rate
            utterance.pitchMultiplier = pitch
            self.synthesizer.speak(utterance)
        }
    }

    /// Plays a short sample phrase through the given voice so the user can preview it.
    func previewVoice(_ voice: AVSpeechSynthesisVoice) {
        synthesizer.stopSpeaking(at: .immediate)
        GoogleTTSClient.shared.stopSpeaking()
        
        let sampleText: String
        if voice.language.hasPrefix("zh-HK") {
            sampleText = "這是您的 GPS 語音導航將在路上的聲音。"
        } else if voice.language.hasPrefix("zh") {
            sampleText = "这是您的 GPS 语音导航将在路上的声音。"
        } else {
            sampleText = "This is how your GPS guide will sound on the road."
        }
        
        let utterance = AVSpeechUtterance(string: sampleText)
        utterance.voice = voice
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        GoogleTTSClient.shared.stopSpeaking()
    }
}
