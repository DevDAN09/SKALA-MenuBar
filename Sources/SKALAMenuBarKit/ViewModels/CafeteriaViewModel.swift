import Foundation
import Combine
import AppKit

@MainActor
public final class CafeteriaViewModel: ObservableObject {
    @Published public var weeklyMenu: WeeklyMenu?
    @Published public var selectedWeekday: String
    @Published public var selectedMealType: MealType
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?

    private let apiService = CafeteriaAPIService()

    public init() {
        self.selectedWeekday = Self.calculateCurrentWeekday()
        self.selectedMealType = Self.calculateCurrentMealType()
    }

    public var currentDayMenu: DailyMenu? {
        weeklyMenu?.menu(for: selectedWeekday)
    }

    public func refresh(force: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            let menu = try await apiService.fetchWeeklyMenu(forceRefresh: force)
            self.weeklyMenu = menu
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
        let weekdays = ["월", "화", "수", "목", "금"]
        return (2...6).contains(weekdayIndex) ? weekdays[weekdayIndex - 2] : "월"
    }

    public static func calculateCurrentMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        let minute = Calendar.current.component(.minute, from: Date())
        let totalMinutes = hour * 60 + minute

        if totalMinutes < 570 {
            return .breakfast
        } else if totalMinutes < 870 {
            return .lunch
        } else {
            return .dinner
        }
    }
}
