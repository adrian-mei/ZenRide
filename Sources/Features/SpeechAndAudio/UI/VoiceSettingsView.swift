import SwiftUI
import AVFoundation

// MARK: - Voice Settings View

struct VoiceSettingsView: View {
    @ObservedObject private var speechService = SpeechService.shared
    @State private var previewingVoiceId: String?

    private var englishVoices: [AVSpeechSynthesisVoice] {
        speechService.availableHumanVoices.filter { $0.language.hasPrefix("en") }
    }

    private var mandarinVoices: [AVSpeechSynthesisVoice] {
        speechService.availableHumanVoices.filter { $0.language == "zh-CN" || $0.language == "zh-TW" }
    }

    private var cantoneseVoices: [AVSpeechSynthesisVoice] {
        speechService.availableHumanVoices.filter { $0.language == "zh-HK" }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()

                List {
                    // Info banner
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "person.wave.2.fill")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.acSky)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Camp Guides")
                                    .font(Theme.Typography.headline)
                                    .foregroundColor(Theme.Colors.acTextDark)
                                Text("Only the highest quality voices for your roadtrip.")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.acTextMuted)
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Theme.Colors.acCream)
                    }

                    // AI Cloud Voice
                    Section {
                        VoiceRow(
                            voice: nil, // Indicates Google TTS
                            customName: "Camp Guide (Cloud AI)",
                            customIdentifier: "google-tts-en-US-Journey-F",
                            customQuality: "ULTRA REALISTIC",
                            customRegion: "US",
                            customGender: "Female",
                            isSelected: isSelected(id: "google-tts-en-US-Journey-F"),
                            isPreviewing: previewingVoiceId == "google-tts-en-US-Journey-F",
                            onSelect: { select(id: "google-tts-en-US-Journey-F") },
                            onPreview: { preview(id: "google-tts-en-US-Journey-F") }
                        )
                    } header: {
                        Text("Cloud Voices")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.acWood)
                    }

                    if !englishVoices.isEmpty {
                        Section {
                            ForEach(englishVoices, id: \.identifier) { voice in
                                VoiceRow(
                                    voice: voice,
                                    customName: nil,
                                    customIdentifier: nil,
                                    customQuality: nil,
                                    customRegion: nil,
                                    customGender: nil,
                                    isSelected: isSelected(id: voice.identifier),
                                    isPreviewing: previewingVoiceId == voice.identifier,
                                    onSelect: { select(id: voice.identifier) },
                                    onPreview: { preview(id: voice.identifier) }
                                )
                            }
                        } header: {
                            Text("English")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.acWood)
                        } footer: {
                            Text("Missing voices? Download more in Settings › Accessibility › Spoken Content.")
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.acTextMuted)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Copilot Voice")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Helpers

    private func isSelected(id: String) -> Bool {
        if let currentId = speechService.selectedVoiceId {
            return currentId == id
        }
        if id.starts(with: "google") { return true } // now default
        return false
    }

    private func select(id: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        speechService.selectedVoiceId = id
        Log.info("VoiceSettings", "Voice selected: \(id)")
    }

    private func preview(id: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        previewingVoiceId = id
        speechService.previewVoice(id: id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if previewingVoiceId == id {
                previewingVoiceId = nil
            }
        }
    }
}
