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
        operatingHours(for: .innovalley)
    }

    public func operatingHours(for place: CafeteriaPlace) -> String {
        switch (place, self) {
        case (.campus, .lunch): return "11:30 - 13:30"
        case (.campus, .dinner): return "17:30 - 19:00"
        case (.innovalley, .lunch): return "11:30 - 14:00"
        case (.innovalley, .dinner): return "17:20 - 18:40"
        }
    }
}

public enum CafeteriaPlace: String, CaseIterable, Codable, Identifiable, Sendable {
    case campus = "캠퍼스"
    case innovalley = "이노밸리"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .campus: return "🏢"
        case .innovalley: return "🥗"
        }
    }

    public var displayName: String {
        switch self {
        case .campus: return "캠퍼스 식당"
        case .innovalley: return "이노밸리 식당"
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

public struct CampusDish: Codable, Identifiable, Sendable, Equatable {
    public var id: String { name }
    public let name: String
    public let isMain: Bool

    public init(name: String, isMain: Bool) {
        self.name = name
        self.isMain = isMain
    }
}

public struct CampusMeal: Codable, Sendable, Equatable {
    public let dishes: [CampusDish]
    public let origin: String?

    public init(dishes: [CampusDish], origin: String? = nil) {
        self.dishes = dishes
        self.origin = origin
    }
}

public struct CampusDayMenu: Codable, Identifiable, Sendable, Equatable {
    public var id: String { weekday }
    public let date: String
    public let weekday: String
    public let lunch: CampusMeal?
    public let dinner: CampusMeal?
    public let dessert: String?

    public init(
        date: String,
        weekday: String,
        lunch: CampusMeal? = nil,
        dinner: CampusMeal? = nil,
        dessert: String? = nil
    ) {
        self.date = date
        self.weekday = weekday
        self.lunch = lunch
        self.dinner = dinner
        self.dessert = dessert
    }

    public func meal(for type: MealType) -> CampusMeal? {
        switch type {
        case .lunch: return lunch
        case .dinner: return dinner
        }
    }
}

public struct CampusWeeklyMenu: Codable, Sendable, Equatable {
    public let weekStart: String
    public let weekEnd: String
    public let days: [CampusDayMenu]
    public let notes: [String]?
    public let fetchedAt: Date

    public init(
        weekStart: String,
        weekEnd: String,
        days: [CampusDayMenu],
        notes: [String]? = nil,
        fetchedAt: Date = Date()
    ) {
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.days = days
        self.notes = notes
        self.fetchedAt = fetchedAt
    }

    public func menu(for weekday: String) -> CampusDayMenu? {
        days.first { $0.weekday == weekday }
    }
}
