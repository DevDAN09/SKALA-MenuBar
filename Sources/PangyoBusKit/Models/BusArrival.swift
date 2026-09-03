import Foundation

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
    public let busLineType: String?
    public let arrival: BusArrivalDetails?

    public init(id: String, name: String, busLineType: String? = nil, arrival: BusArrivalDetails? = nil) {
        self.id = id
        self.name = name
        self.busLineType = busLineType
        self.arrival = arrival
    }
}

public struct BusArrivalDetails: Codable, Sendable {
    public let direction: String?
    public let nextBusStopName: String?
    public let vehicleNumber: String?
    public let arrivalTime: Int?
    public let busStopCount: Int?
    public let vehicleNumber2: String?
    public let arrivalTime2: Int?
    public let busStopCount2: Int?

    public init(
        direction: String? = nil,
        nextBusStopName: String? = nil,
        vehicleNumber: String? = nil,
        arrivalTime: Int? = nil,
        busStopCount: Int? = nil,
        vehicleNumber2: String? = nil,
        arrivalTime2: Int? = nil,
        busStopCount2: Int? = nil
    ) {
        self.direction = direction
        self.nextBusStopName = nextBusStopName
        self.vehicleNumber = vehicleNumber
        self.arrivalTime = arrivalTime
        self.busStopCount = busStopCount
        self.vehicleNumber2 = vehicleNumber2
        self.arrivalTime2 = arrivalTime2
        self.busStopCount2 = busStopCount2
    }
}
