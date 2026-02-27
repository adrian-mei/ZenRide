import SwiftUI

struct QuestDashboardView: View {
    @EnvironmentObject var questStore: QuestStore
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var locationProvider: LocationProvider
    
    @State private var showingBuilder = false
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("DAILY QUESTS")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(Theme.Colors.acWood)
                    .kerning(1.5)
                Spacer()
                Button {
                    showingBuilder = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                }
                .buttonStyle(ACButtonStyle(variant: .secondary))
                .frame(width: 44, height: 44)
            }
            .padding(.horizontal)
            
            if questStore.quests.isEmpty {
                Text("No quests yet! Build your first daily routine.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.acTextMuted)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .acCardStyle()
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(questStore.quests) { quest in
                            QuestCard(quest: quest) {
                                routingService.startQuest(quest, currentLocation: locationProvider.currentLocation?.coordinate)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
        .sheet(isPresented: $showingBuilder) {
            QuestBuilderView()
        }
    }
}

struct QuestCard: View {
    let quest: DailyQuest
    let onStart: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.acSky.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: quest.icon)
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Colors.acSky)
                }
                Spacer()
                Text("\(quest.waypoints.count) stops")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.acTextMuted)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(quest.title)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)
                
                if let first = quest.waypoints.first, let last = quest.waypoints.last {
                    Text("\(first.name) ➔ \(last.name)")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextMuted)
                        .lineLimit(1)
                }
            }
            
            Button("Start Quest") {
                onStart()
            }
            .buttonStyle(ACButtonStyle(variant: .primary))
            .padding(.top, 8)
        }
        .frame(width: 240)
        .acCardStyle(padding: 16, interactive: true)
    }
}
