import Foundation

public enum TargetBus: String, CaseIterable, Identifiable, Codable, Sendable {
    case bus9007 = "9007"
    case bus602_1A = "602-1A"
    case bus602_1B = "602-1B"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .bus9007: return "9007 (직행)"
        case .bus602_1A: return "602-1A (마을)"
        case .bus602_1B: return "602-1B (마을)"
        }
    }

    public var stopId: String {
        switch self {
        case .bus9007:
            return "BS73663" // SK플래닛·판교디지털센터
        case .bus602_1A, .bus602_1B:
            return "BS73662" // 이노밸리·포스코DX
        }
    }

    public var stopName: String {
        switch self {
        case .bus9007:
            return "SK플래닛·판교디지털센터"
        case .bus602_1A, .bus602_1B:
            return "이노밸리·포스코DX"
        }
    }

    public var directionHint: String {
        switch self {
        case .bus9007:
            return "서울역/고속터미널 방면"
        case .bus602_1A, .bus602_1B:
            return "판교역 방면"
        }
    }

    public func matches(lineName: String) -> Bool {
        let trimmed = lineName.trimmingCharacters(in: .whitespaces)
        switch self {
        case .bus9007:
            return trimmed == "9007"
        case .bus602_1A:
            return trimmed.contains("602-1A")
        case .bus602_1B:
            return trimmed.contains("602-1B")
        }
    }
}

public struct BusStopResponse: Codable, Sendable {
    public let id: String
    public let name: String
    public let lines: [BusLine]

    public init(id: String, name: String, lines: [BusLine]) {
        self.id = id
        self.name = name
        self.lines = lines
    }
}

public struct BusLine: Codable, Sendable {
    public let id: String
    public let name: String
    public let arrival: BusArrivalDetails?

    public init(id: String, name: String, arrival: BusArrivalDetails? = nil) {
        self.id = id
        self.name = name
        self.arrival = arrival
    }
}

public struct BusArrivalDetails: Codable, Sendable {
    public let vehicleNumber: String?
    public let arrivalTime: Int?
    public let busStopCount: Int?
    public let vehicleNumber2: String?
    public let arrivalTime2: Int?
    public let busStopCount2: Int?

    public init(
        vehicleNumber: String? = nil,
        arrivalTime: Int? = nil,
        busStopCount: Int? = nil,
        vehicleNumber2: String? = nil,
        arrivalTime2: Int? = nil,
        busStopCount2: Int? = nil
    ) {
        self.vehicleNumber = vehicleNumber
        self.arrivalTime = arrivalTime
        self.busStopCount = busStopCount
        self.vehicleNumber2 = vehicleNumber2
        self.arrivalTime2 = arrivalTime2
        self.busStopCount2 = busStopCount2
    }
}
