import Foundation
import SwiftUI
import AppKit

@MainActor
public final class CafeteriaViewModel: ObservableObject {
    @Published public var weeklyMenu: WeeklyMenu?
    @Published public var selectedWeekday: String
    @Published public var selectedMealType: MealType
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var lastUpdated: Date?

    private let apiService: CafeteriaAPIServiceProtocol

    public init(apiService: CafeteriaAPIServiceProtocol = CafeteriaAPIService()) {
        self.apiService = apiService
        self.selectedWeekday = Self.calculateCurrentWeekday()
        self.selectedMealType = Self.calculateCurrentMealType()
    }

    public var currentDayMenu: DailyMenu? {
        weeklyMenu?.menu(for: selectedWeekday)
    }

    public var isTodaySelected: Bool {
        selectedWeekday == Self.calculateCurrentWeekday()
    }

    public func selectToday() {
        selectedWeekday = Self.calculateCurrentWeekday()
        selectedMealType = Self.calculateCurrentMealType()
    }

    public func refresh(force: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            let menu = try await apiService.fetchWeeklyMenu(forceRefresh: force)
            self.weeklyMenu = menu
            self.lastUpdated = Date()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    public func openKakaoChannel() {
        if let url = URL(string: weeklyMenu?.postUrl ?? "https://pf.kakao.com/_LCxlxlxb") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openOriginalImage() {
        if let urlStr = weeklyMenu?.imageUrl, let url = URL(string: urlStr) {
            NSWorkspace.shared.open(url)
        }
    }

    public static func calculateCurrentWeekday() -> String {
        let weekdayIndex = Calendar.current.component(.weekday, from: Date())
        // 1: Sunday, 2: Monday, 3: Tuesday, 4: Wednesday, 5: Thursday, 6: Friday, 7: Saturday
        switch weekdayIndex {
        case 2: return "월"
        case 3: return "화"
        case 4: return "수"
        case 5: return "목"
        case 6: return "금"
        default: return "월" // Weekend defaults to Monday
        }
    }

    public static func calculateCurrentMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        let minute = Calendar.current.component(.minute, from: Date())
        let totalMinutes = hour * 60 + minute

        // Breakfast: up to 09:30 (570 mins)
        // Lunch: 09:30 to 14:30 (870 mins)
        // Dinner: after 14:30
        if totalMinutes < 570 {
            return .breakfast
        } else if totalMinutes < 870 {
            return .lunch
        } else {
            return .dinner
        }
    }
}
