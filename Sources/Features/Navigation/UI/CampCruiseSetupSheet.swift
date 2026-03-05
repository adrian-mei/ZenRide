import SwiftUI
import MapKit

// MARK: - CampCruiseSetupSheet

struct CampCruiseSetupSheet: View {
    @EnvironmentObject var multiplayerService: MultiplayerService
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var savedRoutes: SavedRoutesStore

    @Environment(\.dismiss) private var dismiss

    /// Called when the user confirms and wants to start cruising.
    var onStartCruise: () -> Void

    @State private var waypoints: [QuestWaypoint] = []
    @State private var saveOffline: Bool = false
    @State private var showAddStop = false
    @State private var showInviteSheet = false

    var body: some View {
        NavigationStack {
            setupContent
                .navigationTitle("Camp & Cruise")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(Theme.Colors.acWood)
                    }
                }
        }
        .sheet(isPresented: $showAddStop) {
            DestinationSearchView { name, coord in
                let waypoint = QuestWaypoint(name: name, coordinate: coord, icon: "mappin.circle.fill")
                waypoints.append(waypoint)
                showAddStop = false
            }


        }
        .sheet(isPresented: $showInviteSheet) {
            InviteCrewSheet()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var setupContent: some View {
        ZStack {
            Theme.Colors.acField.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    routePlannerCard
                    optionsCard
                    startButton
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private var routePlannerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ACSectionHeader(title: "ROUTE STOPS", icon: "map.fill", color: Theme.Colors.acLeaf)
                Spacer()
                Text("optional")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.acTextMuted)
            }

            if waypoints.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.Colors.acSky)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Free Cruise")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.acTextDark)
                        Text("Just drive — add stops to plan a shared route")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.acTextMuted)
                    }
                }
                .padding()
                .background(Theme.Colors.acCream)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.acBorder, lineWidth: 1.5))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(waypoints.enumerated()), id: \.element.id) { index, wp in
                        cruiseStopRow(index: index, wp: wp)
                    }
                }
            }

            Button {
                showAddStop = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 16))
                    Text("Add a Stop").font(Theme.Typography.button)
                }
            }
            .buttonStyle(ACButtonStyle(variant: .secondary))
        }
        .acCardStyle(padding: 20)
    }

    @ViewBuilder
    private func cruiseStopRow(index: Int, wp: QuestWaypoint) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "\(index + 1).circle.fill")
                .foregroundColor(Theme.Colors.acLeaf)
                .font(.system(size: 18))
            Image(systemName: wp.icon)
                .foregroundColor(Theme.Colors.acTextDark)
            Text(wp.name)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.acTextDark)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button {
                _ = waypoints.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.Colors.acTextMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Theme.Colors.acCream)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.acBorder, lineWidth: 1))
    }

    @ViewBuilder
    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.Colors.acSky.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Colors.acSky)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save for Offline")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.acTextDark)
                    Text("Download route for areas with no signal")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextMuted)
                }
                Spacer()
                Toggle("", isOn: $saveOffline)
                    .labelsHidden()
                    .tint(Theme.Colors.acLeaf)
            }
            .padding(16)

            if saveOffline {
                ACSectionDivider(leadingInset: 16)
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Colors.acLeaf)
                    Text("Route will be saved to your device before you start.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextMuted)
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.Colors.acCream)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.acBorder, lineWidth: 2))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: saveOffline)
    }

    @ViewBuilder
    private var crewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            ACSectionHeader(title: "INVITE CREW", icon: "person.2.fill")

            Text("Share your route and cruise together. Friends join using your invite code after you start.")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.acTextMuted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showInviteSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "link.badge.plus").font(.system(size: 16))
                    Text("Invite Friends").font(Theme.Typography.button)
                }
                .foregroundColor(Theme.Colors.acWood)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.Colors.acWood.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.Colors.acWood, lineWidth: 2))
            }
            .buttonStyle(.plain)
        }
        .acCardStyle(padding: 20)
    }

    @ViewBuilder
    private var startButton: some View {
        Button {
            beginCruise()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "tent.fill").font(.system(size: 18))
                Text("Start Cruise").font(Theme.Typography.button)
            }
        }
        .buttonStyle(ACButtonStyle(variant: .primary))
        .padding(.bottom, 20)
    }

    // MARK: - Actions

    private func beginCruise() {
        let destName: String
        let destCoord: CLLocationCoordinate2D

        if let last = waypoints.last {
            destName = last.name
            destCoord = last.coordinate
        } else {
            destName = "Free Cruise"
            destCoord = locationProvider.currentLocation?.coordinate
                ?? Constants.sfCenter
        }

        if saveOffline && !waypoints.isEmpty {
            _ = waypoints.map { $0.coordinate }
            savedRoutes.savePlace(name: destName, coordinate: destCoord)
            Log.info("CampCruise", "Route saved for offline: \(waypoints.count) stops")
        }

        // multiplayerService.startHostingSession(…) ← TBD for crew mode

        dismiss()
        onStartCruise()
    }
}

// MARK: - CruiseStopPickerSheet

// MARK: - InviteCrewSheet
