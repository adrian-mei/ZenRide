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

    /// The fallback Apple voice used if Google TTS fails or if an Apple voice is explicitly selected.
    var selectedAppleVoice: AVSpeechSynthesisVoice {
        if let id = selectedVoiceId, !id.starts(with: "google-tts"), let voice = AVSpeechSynthesisVoice(identifier: id) {
            return voice
        }
        // Prefer premium female human voices, fall back to en-US
        return preferredHumanVoice
            ?? availableHumanVoices.first
            ?? AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice()
    }

    /// Try specifically for premium female human voices (excluding Siri).
    private var preferredHumanVoice: AVSpeechSynthesisVoice? {
        let voices = availableHumanVoices
        
        // 1. Look for any premium female English voice
        if let premiumFemale = voices.first(where: { 
            $0.quality == .premium && 
            $0.gender == .female && 
            $0.language.hasPrefix("en") &&
            !$0.name.lowercased().contains("siri") && 
            !$0.identifier.lowercased().contains("siri")
        }) {
            return premiumFemale
        }
        
        // 2. Fallback to any female English voice (excluding Siri)
        if let anyFemale = voices.first(where: { 
            $0.gender == .female && 
            $0.language.hasPrefix("en") &&
            !$0.name.lowercased().contains("siri") && 
            !$0.identifier.lowercased().contains("siri")
        }) {
            return anyFemale
        }
        
        return nil
    }

    /// High-quality voices (English, Mandarin, Cantonese) excluding robotic defaults and Siri.
    var availableHumanVoices: [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let supportedVoices = allVoices.filter { $0.language.hasPrefix("en") || $0.language.hasPrefix("zh") }
        
        var humanVoices = supportedVoices.filter { voice in
            // Exclude Siri voices completely as per request
            guard !voice.name.lowercased().contains("siri") && !voice.identifier.lowercased().contains("siri") else {
                return false
            }
            return voice.quality != .default || voice.identifier == AVSpeechSynthesisVoiceIdentifierAlex
        }
        
        // Safety fallback
        if !humanVoices.contains(where: { $0.language.hasPrefix("en") }) {
            humanVoices.append(contentsOf: supportedVoices.filter { $0.language.hasPrefix("en") && !$0.name.lowercased().contains("siri") })
        }
        if !humanVoices.contains(where: { $0.language == "zh-CN" || $0.language == "zh-TW" }) {
            humanVoices.append(contentsOf: supportedVoices.filter { ($0.language == "zh-CN" || $0.language == "zh-TW") && !$0.name.lowercased().contains("siri") })
        }
        if !humanVoices.contains(where: { $0.language == "zh-HK" }) {
            humanVoices.append(contentsOf: supportedVoices.filter { $0.language == "zh-HK" && !$0.name.lowercased().contains("siri") })
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
        // Default to Google TTS if no voice has been selected yet
        if UserDefaults.standard.string(forKey: voiceIdKey) == nil {
            selectedVoiceId = "google-tts-en-US-Journey-F"
        } else {
            selectedVoiceId = UserDefaults.standard.string(forKey: voiceIdKey)
        }
        
        configureAudioSession()
        Log.info("SpeechService", "Initialized. Selected voice ID: \(selectedVoiceId ?? "none")")
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
        if selectedVoiceId?.starts(with: "google-tts") == true {
            // Use Google TTS
            GoogleTTSClient.shared.speak(text) { [weak self] in
                // Fallback to Apple TTS
                guard let self = self else { return }
                Log.info("SpeechService", "Falling back to Apple TTS for: \(text)")
                self.speakWithApple(text, rate: rate, pitch: pitch)
            }
        } else {
            // Use Apple TTS directly
            speakWithApple(text, rate: rate, pitch: pitch)
        }
    }
    
    private func speakWithApple(_ text: String, rate: Float, pitch: Float) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = self.selectedAppleVoice
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        self.synthesizer.speak(utterance)
    }

    /// Plays a short sample phrase through the given voice ID so the user can preview it.
    func previewVoice(id: String) {
        synthesizer.stopSpeaking(at: .immediate)
        GoogleTTSClient.shared.stopSpeaking()
        
        let sampleText = "This is how your GPS guide will sound on the road."
        
        if id.starts(with: "google-tts") {
            GoogleTTSClient.shared.speak(sampleText) { [weak self] in
                self?.speakWithApple(sampleText, rate: 0.5, pitch: 1.0)
            }
        } else if let voice = AVSpeechSynthesisVoice(identifier: id) {
            let localizedSample: String
            if voice.language.hasPrefix("zh-HK") {
                localizedSample = "這是您的 GPS 語音導航將在路上的聲音。"
            } else if voice.language.hasPrefix("zh") {
                localizedSample = "这是您的 GPS 语音导航将在路上的声音。"
            } else {
                localizedSample = sampleText
            }
            
            let utterance = AVSpeechUtterance(string: localizedSample)
            utterance.voice = voice
            utterance.rate = 0.5
            utterance.pitchMultiplier = 1.0
            synthesizer.speak(utterance)
        }
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        GoogleTTSClient.shared.stopSpeaking()
    }
}
