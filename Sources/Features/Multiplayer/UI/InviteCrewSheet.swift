import SwiftUI

struct InviteCrewSheet: View {
    @EnvironmentObject var multiplayerService: MultiplayerService
    @Environment(\.dismiss) private var dismiss
    @State private var codeCopied = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()
                VStack(spacing: 32) {
                    Spacer()

                    // Invite code display
                    VStack(spacing: 12) {
                        Text("YOUR INVITE CODE")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(Theme.Colors.acTextMuted)
                            .kerning(2)

                        if let code = multiplayerService.inviteCode {
                            Text(code)
                                .font(.system(size: 52, weight: .black, design: .rounded))
                                .foregroundColor(Theme.Colors.acLeaf)
                                .tracking(8)

                            Button {
                                UIPasteboard.general.string = code
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation { codeCopied = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation { codeCopied = false }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: codeCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                        .font(.system(size: 15))
                                    Text(codeCopied ? "Copied!" : "Copy Code")
                                        .font(Theme.Typography.button)
                                }
                                .foregroundColor(codeCopied ? Theme.Colors.acLeaf : Theme.Colors.acWood)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background((codeCopied ? Theme.Colors.acLeaf : Theme.Colors.acWood).opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(codeCopied ? Theme.Colors.acLeaf : Theme.Colors.acWood, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: codeCopied)
                        } else {
                            Text("Start a cruise to generate your code")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.acTextMuted)
                        }
                    }
                    .padding(28)
                    .background(Theme.Colors.acCream)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.Colors.acBorder, lineWidth: 3))
                    .shadow(color: Theme.Colors.acBorder.opacity(0.8), radius: 0, x: 0, y: 6)
                    .padding(.horizontal)

                    // System share
                    if let code = multiplayerService.inviteCode {
                        ShareLink(item: "Join my Crew! Code: \(code)") {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up").font(.system(size: 16))
                                Text("Share Invite").font(Theme.Typography.button)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.Colors.acLeaf)
                            .clipShape(Capsule())
                            .shadow(color: Color(hex: "388E3C").opacity(0.8), radius: 0, x: 0, y: 5)
                        }
                        .padding(.horizontal)
                    }

                    Text("Friends open the app and enter this code\nto join your crew")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Invite Crew")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.Colors.acWood)
                }
            }
        }
    }
}
