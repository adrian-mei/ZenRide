import Foundation
import AVFoundation

/// Client for interacting with Google Cloud Text-to-Speech API
/// and caching the resulting audio files locally.
final class GoogleTTSClient: NSObject, AVAudioPlayerDelegate {
    static let shared = GoogleTTSClient()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private var audioPlayer: AVAudioPlayer?
    
    // Voice selection. E.g., "en-US-Journey-F" is a very realistic female voice.
    var voiceName: String = "en-US-Journey-F"
    var languageCode: String = "en-US"
    
    override private init() {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = urls[0].appendingPathComponent("TTSCache")
        
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        super.init()
    }
    
    /// Speaks the given text using Google TTS or local cache.
    /// - Parameter text: The text to speak
    /// - Parameter fallback: A closure called if Google TTS fails (so we can fallback to Apple TTS)
    func speak(_ text: String, fallback: @escaping () -> Void) {
        guard !text.isEmpty else { return }
        
        // Return fallback if API key is missing
        guard !Secrets.googleTTSAPIKey.isEmpty else {
            Log.error("GoogleTTS", "Missing API Key")
            fallback()
            return
        }
        
        let safeFilename = text.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        let fileURL = cacheDirectory.appendingPathComponent("\(safeFilename)-\(voiceName).mp3")
        
        if fileManager.fileExists(atPath: fileURL.path) {
            Log.info("GoogleTTS", "Playing cached audio for text: \(text)")
            playAudio(url: fileURL)
        } else {
            Log.info("GoogleTTS", "Synthesizing audio from Google for text: \(text)")
            synthesizeAndCache(text: text, fileURL: fileURL, fallback: fallback)
        }
    }
    
    private func synthesizeAndCache(text: String, fileURL: URL, fallback: @escaping () -> Void) {
        let urlString = "https://texttospeech.googleapis.com/v1/text:synthesize?key=\(Secrets.googleTTSAPIKey)"
        guard let url = URL(string: urlString) else {
            fallback()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "input": ["text": text],
            "voice": [
                "languageCode": languageCode,
                "name": voiceName
            ],
            "audioConfig": [
                "audioEncoding": "MP3"
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            Log.error("GoogleTTS", "Failed to encode payload: \(error)")
            fallback()
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                Log.error("GoogleTTS", "Network error: \(error)")
                DispatchQueue.main.async { fallback() }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { fallback() }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let audioContentBase64 = json["audioContent"] as? String,
                   let audioData = Data(base64Encoded: audioContentBase64) {
                    
                    try audioData.write(to: fileURL)
                    DispatchQueue.main.async {
                        self.playAudio(url: fileURL)
                    }
                } else {
                    Log.error("GoogleTTS", "Failed to parse Google TTS response")
                    DispatchQueue.main.async { fallback() }
                }
            } catch {
                Log.error("GoogleTTS", "JSON/File error: \(error)")
                DispatchQueue.main.async { fallback() }
            }
        }
        task.resume()
    }
    
    private func playAudio(url: URL) {
        do {
            // Re-assert audio session is active
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
        } catch {
            Log.error("GoogleTTS", "Failed to play audio file: \(error)")
        }
    }
    
    func stopSpeaking() {
        audioPlayer?.stop()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Optional: deactivate audio session if needed, but SpeechService handles the category
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Ignore
        }
    }
}
