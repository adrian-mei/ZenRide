import Testing
import Foundation
@testable import ZenMap

// MARK: - Helpers

private func makeVisitRecord(weekday: Int, hour: Int, month: Int) -> VisitRecord {
    VisitRecord(date: Date(), hour: hour, weekday: weekday, month: month)
}

// MARK: - Tests

struct RoutineIntelligenceEngineTests {

    // MARK: - calculateTemporalScore

    @Test func temporalScore_emptyHistory_returnsZero() {
        let score = RoutineIntelligenceEngine.calculateTemporalScore(history: [], hour: 9, weekday: 2)
        #expect(score == 0.0)
    }

    @Test func temporalScore_allMatchingWeekdayAndHour_returnsOne() {
        let records = (0..<5).map { _ in makeVisitRecord(weekday: 3, hour: 9, month: 6) }
        // weekdayRatio=1.0, hourRatio=1.0 → (0.4×1.0)+(0.6×1.0) = 1.0
        let score = RoutineIntelligenceEngine.calculateTemporalScore(history: records, hour: 9, weekday: 3)
        #expect(abs(score - 1.0) < 0.001)
    }

    @Test func temporalScore_weekdayMatchOnly_returns0_4() {
        // Weekday matches, hour is far enough away (> ±1) to not match
        let records = (0..<5).map { _ in makeVisitRecord(weekday: 3, hour: 3, month: 6) }
        // weekdayRatio=1.0, hourRatio=0.0 → 0.4×1.0 + 0.6×0.0 = 0.4
        let score = RoutineIntelligenceEngine.calculateTemporalScore(history: records, hour: 9, weekday: 3)
        #expect(abs(score - 0.4) < 0.001)
    }

    @Test func temporalScore_hourMatchOnly_returns0_6() {
        // Hour matches within ±1, weekday does not match
        let records = (0..<5).map { _ in makeVisitRecord(weekday: 6, hour: 9, month: 6) }
        // weekdayRatio=0.0, hourRatio=1.0 → 0.4×0.0 + 0.6×1.0 = 0.6
        let score = RoutineIntelligenceEngine.calculateTemporalScore(history: records, hour: 9, weekday: 2)
        #expect(abs(score - 0.6) < 0.001)
    }

    @Test func temporalScore_noMatch_returnsZero() {
        let records = (0..<4).map { _ in makeVisitRecord(weekday: 6, hour: 3, month: 6) }
        // weekday 6≠2, hour 3 outside ±1 of 9 → 0.0
        let score = RoutineIntelligenceEngine.calculateTemporalScore(history: records, hour: 9, weekday: 2)
        #expect(score == 0.0)
    }

    // MARK: - calculateSeasonalScore

    @Test func seasonalScore_emptyHistory_returnsZero() {
        let score = RoutineIntelligenceEngine.calculateSeasonalScore(history: [], month: 6)
        #expect(score == 0.0)
    }

    @Test func seasonalScore_allSameMonth_returnsOne() {
        let records = (0..<4).map { _ in makeVisitRecord(weekday: 2, hour: 9, month: 6) }
        let score = RoutineIntelligenceEngine.calculateSeasonalScore(history: records, month: 6)
        #expect(abs(score - 1.0) < 0.001)
    }

    @Test func seasonalScore_halfMatch_returnsHalf() {
        let matching = (0..<2).map { _ in makeVisitRecord(weekday: 2, hour: 9, month: 6) }
        let nonMatching = (0..<2).map { _ in makeVisitRecord(weekday: 2, hour: 9, month: 12) }
        let score = RoutineIntelligenceEngine.calculateSeasonalScore(history: matching + nonMatching, month: 6)
        #expect(abs(score - 0.5) < 0.001)
    }

    @Test func seasonalScore_noMatch_returnsZero() {
        let records = (0..<3).map { _ in makeVisitRecord(weekday: 2, hour: 9, month: 12) }
        let score = RoutineIntelligenceEngine.calculateSeasonalScore(history: records, month: 6)
        #expect(score == 0.0)
    }
}
