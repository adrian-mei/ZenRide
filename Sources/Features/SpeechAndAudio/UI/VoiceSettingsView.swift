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
            List {
                // Info banner
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "person.wave.2.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.cyan)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Human Guides")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Only the highest quality, human-sounding voices (Premium & Siri).")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.cyan.opacity(0.08))
                }

                if !englishVoices.isEmpty {
                    Section {
                        ForEach(englishVoices, id: \.identifier) { voice in
                            VoiceRow(
                                voice: voice,
                                isSelected: isSelected(voice),
                                isPreviewing: previewingVoiceId == voice.identifier,
                                onSelect: { select(voice) },
                                onPreview: { preview(voice) }
                            )
                        }
                    } header: {
                        Text("English")
                            .font(.system(size: 12, weight: .bold))
                    } footer: {
                        Text("Missing voices? Download more in Settings › Accessibility › Spoken Content.")
                            .font(.caption2)
                    }
                }

                if !mandarinVoices.isEmpty {
                    Section {
                        ForEach(mandarinVoices, id: \.identifier) { voice in
                            VoiceRow(
                                voice: voice,
                                isSelected: isSelected(voice),
                                isPreviewing: previewingVoiceId == voice.identifier,
                                onSelect: { select(voice) },
                                onPreview: { preview(voice) }
                            )
                        }
                    } header: {
                        Text("Mandarin")
                            .font(.system(size: 12, weight: .bold))
                    }
                }

                if !cantoneseVoices.isEmpty {
                    Section {
                        ForEach(cantoneseVoices, id: \.identifier) { voice in
                            VoiceRow(
                                voice: voice,
                                isSelected: isSelected(voice),
                                isPreviewing: previewingVoiceId == voice.identifier,
                                onSelect: { select(voice) },
                                onPreview: { preview(voice) }
                            )
                        }
                    } header: {
                        Text("Cantonese")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("GPS Voice")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.06, green: 0.06, blue: 0.1))
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers

    private func isSelected(_ voice: AVSpeechSynthesisVoice) -> Bool {
        if let id = speechService.selectedVoiceId {
            return id == voice.identifier
        }
        // If no selection, highlight the voice that would be used as default
        return voice.identifier == speechService.selectedVoice.identifier
    }

    private func select(_ voice: AVSpeechSynthesisVoice) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        speechService.selectedVoiceId = voice.identifier
        Log.info("VoiceSettings", "Voice selected: \(voice.name) (\(voice.language))")
    }

    private func preview(_ voice: AVSpeechSynthesisVoice) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        previewingVoiceId = voice.identifier
        speechService.previewVoice(voice)
        // Clear previewing state after ~4 seconds (ample for the sample phrase)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if previewingVoiceId == voice.identifier {
                previewingVoiceId = nil
            }
        }
    }
}

// MARK: - Voice Row

private struct VoiceRow: View {
    let voice: AVSpeechSynthesisVoice
    let isSelected: Bool
    let isPreviewing: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    private var qualityLabel: String {
        switch voice.quality {
        case .premium:  return "PREMIUM"
        case .enhanced: return "ENHANCED"
        default:        return ""
        }
    }

    private var qualityColor: Color {
        voice.quality == .premium ? .purple : .cyan
    }

    /// Short region tag from the language code, e.g. "en-AU" → "AU"
    private var regionTag: String {
        let parts = voice.language.split(separator: "-")
        return parts.count > 1 ? String(parts[1]) : voice.language.uppercased()
    }

    private var genderText: String? {
        switch voice.gender {
        case .female: return "Female"
        case .male:   return "Male"
        default:      return nil
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Selection circle
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(isSelected ? .cyan : Color(white: 0.35))
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)

            // Name + quality badge + region
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(voice.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    if !qualityLabel.isEmpty {
                        Text(qualityLabel)
                            .font(.system(size: 8, weight: .black))
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
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            }

            Spacer()

            // Preview play button
            Button {
                onPreview()
            } label: {
                ZStack {
                    Circle()
                        .fill(isPreviewing ? Color.green.opacity(0.15) : Color.white.opacity(0.06))
                        .frame(width: 38, height: 38)

                    Image(systemName: isPreviewing ? "waveform" : "play.fill")
                        .font(.system(size: isPreviewing ? 14 : 12, weight: .bold))
                        .foregroundColor(isPreviewing ? .green : .secondary)
                }
                .animation(.easeInOut(duration: 0.2), value: isPreviewing)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .listRowBackground(isSelected ? Color.cyan.opacity(0.07) : Color.clear)
    }
}
