import SwiftUI

struct QuestDashboardView: View {
    @EnvironmentObject var questStore: QuestStore
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var locationProvider: LocationProvider
    
    @State private var showingBuilder = false
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("ROUTE BOOK")
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
                Text("No saved routes yet! Build your first daily routine.")
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.acLeaf.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: quest.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Theme.Colors.acLeaf)
                }
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(quest.waypoints.count) stops")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.Colors.acWood)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.acWood.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(quest.title)
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if let first = quest.waypoints.first, let last = quest.waypoints.last {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.acTextMuted)
                        Text("\(first.name) ➔ \(last.name)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.Colors.acTextMuted)
                            .lineLimit(1)
                    }
                }
            }
            
            Button(action: onStart) {
                HStack {
                    Spacer()
                    Image(systemName: "play.fill")
                    Text("Start Route")
                    Spacer()
                }
            }
            .buttonStyle(ACButtonStyle(variant: .primary))
            .padding(.top, 4)
        }
        .frame(width: 260)
        .acCardStyle(padding: 20, interactive: true)
    }
}
