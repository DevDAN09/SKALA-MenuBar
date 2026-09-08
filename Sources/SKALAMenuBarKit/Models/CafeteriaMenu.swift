import Foundation

public enum MealType: String, CaseIterable, Codable, Identifiable, Sendable {
    case lunch = "중식"
    case dinner = "석식"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        }
    }

    public var operatingHours: String {
        switch self {
        case .lunch: return "11:30 - 14:00"
        case .dinner: return "17:20 - 18:40"
        }
    }
}

public enum MealCorner: String, CaseIterable, Codable, Identifiable, Sendable {
    case korean = "한식"
    case western = "양식"
    case noodle = "면"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .korean: return "🍚"
        case .western: return "🍳"
        case .noodle: return "🍜"
        }
    }
}

public struct MealCategoryItem: Codable, Identifiable, Sendable, Equatable {
    public var id: String { cornerName }
    public let cornerName: String
    public let items: [String]

    public init(cornerName: String, items: [String]) {
        self.cornerName = cornerName
        self.items = items
    }
}

public struct DailyMenu: Codable, Identifiable, Sendable, Equatable {
    public var id: String { weekday }
    public let weekday: String // "월", "화", "수", "목", "금"
    public let dateString: String // "2026-09-08" 등
    public let breakfast: [MealCategoryItem]
    public let lunch: [MealCategoryItem]
    public let dinner: [MealCategoryItem]

    public init(
        weekday: String,
        dateString: String,
        breakfast: [MealCategoryItem] = [],
        lunch: [MealCategoryItem],
        dinner: [MealCategoryItem]
    ) {
        self.weekday = weekday
        self.dateString = dateString
        self.breakfast = breakfast
        self.lunch = lunch
        self.dinner = dinner
    }

    public func meals(for type: MealType) -> [MealCategoryItem] {
        switch type {
        case .lunch: return lunch
        case .dinner: return dinner
        }
    }
}

public struct WeeklyMenu: Codable, Sendable, Equatable {
    public let title: String
    public let imageUrl: String
    public let postUrl: String
    public let days: [DailyMenu]
    public let fetchedAt: Date

    public init(
        title: String,
        imageUrl: String,
        postUrl: String,
        days: [DailyMenu],
        fetchedAt: Date = Date()
    ) {
        self.title = title
        self.imageUrl = imageUrl
        self.postUrl = postUrl
        self.days = days
        self.fetchedAt = fetchedAt
    }

    public func menu(for weekday: String) -> DailyMenu? {
        days.first { $0.weekday == weekday }
    }
}
