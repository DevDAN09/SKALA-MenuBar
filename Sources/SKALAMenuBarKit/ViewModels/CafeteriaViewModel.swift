import Foundation
import Combine
import AppKit

@MainActor
public final class CafeteriaViewModel: ObservableObject {
    public static let selectedPlaceStorageKey = "SKALAMenuBar_SelectedCafeteriaPlace"

    @Published public var weeklyMenu: WeeklyMenu?
    @Published public var campusWeeklyMenu: CampusWeeklyMenu?
    @Published public var selectedPlace: CafeteriaPlace {
        didSet {
            UserDefaults.standard.set(selectedPlace.rawValue, forKey: Self.selectedPlaceStorageKey)
        }
    }
    @Published public var selectedWeekday: String
    @Published public var selectedMealType: MealType
    @Published public var selectedCorner: MealCorner = .korean
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?

    private let apiService: CafeteriaAPIService

    public init(apiService: CafeteriaAPIService = CafeteriaAPIService()) {
        self.apiService = apiService
        let savedPlace = UserDefaults.standard.string(forKey: Self.selectedPlaceStorageKey)
        self.selectedPlace = savedPlace.flatMap(CafeteriaPlace.init(rawValue:)) ?? .campus
        self.selectedWeekday = Self.calculateCurrentWeekday()
        self.selectedMealType = Self.calculateCurrentMealType()
    }

    public var currentDayMenu: DailyMenu? {
        weeklyMenu?.menu(for: selectedWeekday)
    }

    public var currentCampusDayMenu: CampusDayMenu? {
        campusWeeklyMenu?.menu(for: selectedWeekday)
    }

    public func refresh(force: Bool = false) async {
        isLoading = true
        errorMessage = nil

        async let campusTask: Result<CampusWeeklyMenu, Error> = Task {
            do {
                return .success(try await apiService.fetchCampusWeeklyMenu(forceRefresh: force))
            } catch {
                return .failure(error)
            }
        }.value

        async let innovalleyTask: Result<WeeklyMenu, Error> = Task {
            do {
                return .success(try await apiService.fetchWeeklyMenu(forceRefresh: force))
            } catch {
                return .failure(error)
            }
        }.value

        let (campusResult, innovalleyResult) = await (campusTask, innovalleyTask)

        var errors: [String] = []

        switch campusResult {
        case .success(let menu):
            self.campusWeeklyMenu = menu
        case .failure(let error):
            errors.append("캠퍼스: \(error.localizedDescription)")
        }

        switch innovalleyResult {
        case .success(let menu):
            self.weeklyMenu = menu
        case .failure(let error):
            errors.append("이노밸리: \(error.localizedDescription)")
        }

        if !errors.isEmpty && (campusWeeklyMenu == nil && weeklyMenu == nil) {
            self.errorMessage = errors.joined(separator: "\n")
        }

        isLoading = false
    }

    public func openCampusWebsite() {
        if let url = URL(string: "https://skala-lunch.ewkimhyunsu11.workers.dev/") {
            NSWorkspace.shared.open(url)
        }
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

        // 14:30(870분) 이후는 석식, 이전은 중식
        if totalMinutes >= 870 {
            return .dinner
        } else {
            return .lunch
        }
    }
}
