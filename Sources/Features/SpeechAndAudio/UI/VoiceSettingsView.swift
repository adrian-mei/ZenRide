import SwiftUI
import AVFoundation

// MARK: - Voice Settings View

struct VoiceSettingsView: View {
    @ObservedObject private var speechService = SpeechService.shared
    @State private var previewingVoiceId: String? = nil

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
                                .font(.system(size: 22))
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
                            .font(.system(size: 12, weight: .bold, design: .rounded))
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
                                .font(.system(size: 12, weight: .bold, design: .rounded))
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

// MARK: - Voice Row

private struct VoiceRow: View {
    let voice: AVSpeechSynthesisVoice?
    let customName: String?
    let customIdentifier: String?
    let customQuality: String?
    let customRegion: String?
    let customGender: String?
    
    let isSelected: Bool
    let isPreviewing: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    private var voiceName: String {
        if let customName = customName { return customName }
        if let voice = voice { return voice.name }
        return "Unknown"
    }

    private var qualityLabel: String {
        if let cq = customQuality { return cq }
        guard let voice = voice else { return "" }
        switch voice.quality {
        case .premium:  return "PREMIUM"
        case .enhanced: return "ENHANCED"
        default:        return ""
        }
    }

    private var qualityColor: Color {
        if customQuality != nil { return Theme.Colors.acCoral }
        return voice?.quality == .premium ? Theme.Colors.acGold : Theme.Colors.acSky
    }

    private var regionTag: String {
        if let cr = customRegion { return cr }
        guard let voice = voice else { return "" }
        let parts = voice.language.split(separator: "-")
        return parts.count > 1 ? String(parts[1]) : voice.language.uppercased()
    }

    private var genderText: String? {
        if let cg = customGender { return cg }
        guard let voice = voice else { return nil }
        switch voice.gender {
        case .female: return "Female"
        case .male:   return "Male"
        default:      return nil
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(isSelected ? Theme.Colors.acLeaf : Theme.Colors.acBorder)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(voiceName)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextDark)

                    if !qualityLabel.isEmpty {
                        Text(qualityLabel)
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundColor(qualityColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(qualityColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 4) {
                    Text(regionTag)
                    if let gender = genderText {
                        Text("•")
                        Text(gender)
                    }
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.acTextMuted)
            }

            Spacer()

            Button {
                onPreview()
            } label: {
                ZStack {
                    Circle()
                        .fill(isPreviewing ? Theme.Colors.acLeaf.opacity(0.2) : Theme.Colors.acField)
                        .frame(width: 38, height: 38)
                        .overlay(Circle().stroke(Theme.Colors.acBorder.opacity(0.5), lineWidth: 1))

                    Image(systemName: isPreviewing ? "waveform" : "play.fill")
                        .font(.system(size: isPreviewing ? 14 : 12, weight: .bold))
                        .foregroundColor(isPreviewing ? Theme.Colors.acLeaf : Theme.Colors.acTextMuted)
                }
                .animation(.easeInOut(duration: 0.2), value: isPreviewing)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .listRowBackground(isSelected ? Theme.Colors.acLeaf.opacity(0.05) : Theme.Colors.acCream)
    }
}
