import SwiftUI
import CoreImage.CIFilterBuiltins

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var vehicleStore: VehicleStore
    @EnvironmentObject var driveStore: DriveStore
    @EnvironmentObject var playerStore: PlayerStore

    @State private var email = "rider@zenride.app"
    @State private var name = "Zen Rider"
    @State private var subscription = "Pro Rider"

    @State private var showGarage = false
    @State private var showDriveHistory = false
    @State private var showExperiences = false
    @State private var showPrivacyAlert = false
    @State private var showSignOutAlert = false
    @State private var showAvatarSelection = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // User Header
                    Button {
                        showAvatarSelection = true
                    } label: {
                        UserHeaderView(name: name, email: email, subscription: subscription)
                            .environmentObject(playerStore)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.top, 16)

                    // Bike Cards Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Garage")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.acTextDark)
                            Spacer()
                            Button("Manage") { showGarage = true }
                                .font(.subheadline.bold())
                                .foregroundColor(Theme.Colors.acLeaf)
                        }
                        .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(vehicleStore.vehicles) { vehicle in
                                    Button { showGarage = true } label: { BikePassCard(vehicle: vehicle) }
                                        .buttonStyle(.plain)
                                }
                                Button { showGarage = true } label: { AddBikeCard() }
                                    .buttonStyle(.plain)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                    }

                    // Settings List
                    VStack(spacing: 0) {
                        NavigationLink(destination: VoiceSettingsView()) {
                            SettingsRow(icon: "speaker.wave.2.fill", title: "Voice Settings", color: Theme.Colors.acSky)
                        }
                        ACSectionDivider(leadingInset: 50)
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showExperiences = true
                        } label: {
                            SettingsRow(icon: "star.fill", title: "San Francisco Experiences", color: Theme.Colors.acWood)
                        }
                        ACSectionDivider(leadingInset: 50)
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showDriveHistory = true
                        } label: {
                            SettingsRow(icon: "clock.arrow.circlepath", title: "Drive History", color: Theme.Colors.acLeaf)
                        }
                        ACSectionDivider(leadingInset: 50)
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            SettingsRow(icon: "bell.badge.fill", title: "Notifications", color: Theme.Colors.acCoral)
                        }
                        ACSectionDivider(leadingInset: 50)
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showPrivacyAlert = true
                        } label: {
                            SettingsRow(icon: "lock.fill", title: "Privacy", color: Theme.Colors.acWood)
                        }
                    }
                    .acCardStyle(padding: 0)
                    .padding(.horizontal)
                    .buttonStyle(.plain)

                    // Sign out
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showSignOutAlert = true
                    } label: {
                        Text("Sign Out")
                            .font(.body.bold())
                            .foregroundColor(Theme.Colors.acCoral)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .acCardStyle()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("NookPhone Profile")
            .navigationBarTitleDisplayMode(.inline)
            .background(Theme.Colors.acField.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.body.bold())
                        .foregroundColor(Theme.Colors.acLeaf)
                }
            }
            .sheet(isPresented: $showGarage) { VehicleGarageView() }
            .sheet(isPresented: $showDriveHistory) {
                DriveHistoryView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showExperiences) {
                ExperiencesCatalogView { _ in
                    // In a profile view context, we might just dismiss or we could inject it
                    // For now, selecting it from the profile could just dismiss the catalog.
                    // Typically, you'd navigate back to the map and load it.
                    dismiss()
                }
            }
            .sheet(isPresented: $showAvatarSelection) {
                AvatarSelectionView()
                    .environmentObject(playerStore)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .alert("Privacy", isPresented: $showPrivacyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("ZenMap stores all your data privately on this device. Nothing is sent to external servers. Your routes, trips, and preferences never leave your iPhone.")
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset App Data", role: .destructive) {
                    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.hasCompletedOnboarding)
                    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.questsV2)
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    dismiss()
                }
            } message: {
                Text("Your data is stored locally on this device. 'Reset App Data' will clear your saved quests and restart onboarding on next launch.")
            }
            .preferredColorScheme(.light)
        }
    }
}

// MARK: - Subviews


