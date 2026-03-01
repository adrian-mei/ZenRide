import Foundation
import CoreLocation

struct RoutineIntelligenceEngine {
    
    struct Prediction: Identifiable {
        let id = UUID()
        let route: SavedRoute
        let confidence: Double
        let narrativePrompt: String
    }
    
    @MainActor
    static func predictNextAdventure(from store: SavedRoutesStore, at location: CLLocationCoordinate2D?) -> Prediction? {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentWeekday = calendar.component(.weekday, from: now)
        let currentMonth = calendar.component(.month, from: now)
        
        var bestPrediction: Prediction? = nil
        var highestScore: Double = -1.0
        
        for route in store.routes {
            guard route.category != nil || route.isPinned else { continue }
            
            var score: Double = 0.0
            
            // 1. Temporal Match (60%)
            let temporalScore = calculateTemporalScore(history: route.visitHistory, hour: currentHour, weekday: currentWeekday)
            score += temporalScore * 0.6
            
            // 2. Recency Bias (10%)
            let timeSinceLastUsed = now.timeIntervalSince(route.lastUsedDate)
            let recencyScore = max(0, 1.0 - (timeSinceLastUsed / (86400 * 7))) // Decays over a week
            score += recencyScore * 0.1
            
            // 3. Frequency Score (20%)
            let frequencyScore = min(1.0, Double(route.useCount) / 10.0)
            score += frequencyScore * 0.2
            
            // 4. Seasonal/Month Awareness (10%)
            let seasonalScore = calculateSeasonalScore(history: route.visitHistory, month: currentMonth)
            score += seasonalScore * 0.1
            
            if score > highestScore && score > 0.3 {
                highestScore = score
                bestPrediction = Prediction(
                    route: route,
                    confidence: score,
                    narrativePrompt: generateNarrative(for: route, hour: currentHour)
                )
            }
        }
        
        return bestPrediction
    }
    
    private static func calculateTemporalScore(history: [VisitRecord], hour: Int, weekday: Int) -> Double {
        guard !history.isEmpty else { return 0.0 }
        
        let sameWeekdayCount = history.filter { $0.weekday == weekday }.count
        let sameHourCount = history.filter { abs($0.hour - hour) <= 1 }.count
        
        let weekdayRatio = Double(sameWeekdayCount) / Double(history.count)
        let hourRatio = Double(sameHourCount) / Double(history.count)
        
        return (weekdayRatio * 0.4) + (hourRatio * 0.6)
    }
    
    private static func calculateSeasonalScore(history: [VisitRecord], month: Int) -> Double {
        guard !history.isEmpty else { return 0.0 }
        let sameMonthCount = history.filter { $0.month == month }.count
        return Double(sameMonthCount) / Double(history.count)
    }
    
    private static func generateNarrative(for route: SavedRoute, hour: Int) -> String {
        let category = route.category ?? .holySpot
        let name = route.destinationName
        
        switch category {
        case .home:
            return hour >= 17 ? "Time to head back to the nest?" : "Heading home early?"
        case .work:
            return "Duty calls at \(name)!"
        case .gym:
            return "Ready to break a sweat?"
        case .partyMember:
            return "\(name) would love a visit!"
        case .holySpot:
            return "The aura at \(name) is perfect right now."
        case .dayCare:
            return hour < 12 ? "Time for drop off?" : "Ready to pick up the little ones?"
        case .school:
            return (7...9).contains(hour) ? "Morning school run!" : "School's out! Time to pick up?"
        case .afterSchool:
            return "Time for the afternoon program!"
        case .dateSpot:
            return "How about a nice date at \(name)?"
        }
    }
}
