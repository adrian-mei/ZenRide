import SwiftUI
import AVFoundation

struct VoiceRow: View {
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
                .font(Theme.Typography.headline)
                .foregroundColor(isSelected ? Theme.Colors.acLeaf : Theme.Colors.acBorder)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(voiceName)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextDark)

                    if !qualityLabel.isEmpty {
                        Text(qualityLabel)
                            .font(Theme.Typography.label)
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
                .font(Theme.Typography.caption)
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
