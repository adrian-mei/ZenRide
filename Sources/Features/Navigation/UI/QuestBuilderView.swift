import SwiftUI
import MapKit

struct QuestBuilderView: View {
    @EnvironmentObject var questStore: QuestStore
    @EnvironmentObject var routingService: RoutingService
    @Environment(\.dismiss) private var dismiss
    
    @State private var questName = "My Cozy Commute"
    @State private var waypoints: [QuestWaypoint] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Title Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quest Name")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.acTextDark)
                            
                            TextField("e.g. Morning Run", text: $questName)
                                .font(Theme.Typography.body)
                                .padding()
                                .background(Theme.Colors.acCream)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.acBorder, lineWidth: 2))
                        }
                        .acCardStyle(padding: 20)
                        
                        // Waypoints List
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "map.fill")
                                    .foregroundColor(Theme.Colors.acWood)
                                Text("YOUR STOPS")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundColor(Theme.Colors.acWood)
                                    .kerning(1.5)
                            }
                            
                            if waypoints.isEmpty {
                                Text("Add stops to build your route.")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.acTextMuted)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                ForEach(Array(waypoints.enumerated()), id: \.element.id) { index, wp in
                                    HStack {
                                        Image(systemName: "\(index + 1).circle.fill")
                                            .foregroundColor(Theme.Colors.acLeaf)
                                        Image(systemName: wp.icon)
                                            .foregroundColor(Theme.Colors.acTextDark)
                                        Text(wp.name)
                                            .font(Theme.Typography.body)
                                            .foregroundColor(Theme.Colors.acTextDark)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Theme.Colors.acCream)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.acBorder, lineWidth: 1))
                                }
                            }
                            
                            // Mock adding waypoints for MVP (in a real app this opens a map search)
                            Button("Add Stop (Mock)") {
                                let icons = ["house.fill", "cup.and.saucer.fill", "building.2.fill"]
                                let names = ["Home", "Coffee", "Office"]
                                let idx = waypoints.count % 3
                                let lat = 37.7749 + (Double(idx) * 0.005)
                                let lng = -122.4194 + (Double(idx) * 0.005)
                                waypoints.append(QuestWaypoint(
                                    name: names[idx],
                                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                                    icon: icons[idx]
                                ))
                            }
                            .buttonStyle(ACButtonStyle(variant: .secondary))
                        }
                        .acCardStyle(padding: 20)
                        
                        Button("Save & Drive") {
                            let quest = DailyQuest(title: questName, waypoints: waypoints)
                            questStore.addQuest(quest)
                            routingService.startQuest(quest, currentLocation: nil)
                            dismiss()
                        }
                        .buttonStyle(ACButtonStyle(variant: .primary))
                        .disabled(waypoints.count < 2)
                        .opacity(waypoints.count < 2 ? 0.5 : 1)
                    }
                    .padding()
                }
            }
            .navigationTitle("New Daily Quest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.acWood)
                }
            }
        }
    }
}
