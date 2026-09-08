import Foundation

public protocol BusAPIServiceProtocol: Sendable {
    func fetchStop(stopId: String) async throws -> BusStopResponse
    func fetch9007Arrival(stopId: String) async throws -> BusArrivalDetails?
    func fetchTargetBusesArrival() async throws -> [TargetBus: BusArrivalDetails]
}

public final class BusAPIService: BusAPIServiceProtocol, @unchecked Sendable {
    public static let shared = BusAPIService()
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchStop(stopId: String) async throws -> BusStopResponse {
        guard let url = URL(string: "https://map.kakao.com/bus/stop.json?busstopid=\(stopId)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(BusStopResponse.self, from: data)
    }

    public func fetch9007Arrival(stopId: String = "BS73663") async throws -> BusArrivalDetails? {
        let stopInfo = try await fetchStop(stopId: stopId)
        guard let line9007 = stopInfo.lines.first(where: { TargetBus.bus9007.matches(lineName: $0.name) }) else {
            return nil
        }
        return line9007.arrival
    }

    public func fetchTargetBusesArrival() async throws -> [TargetBus: BusArrivalDetails] {
        // Collect unique stop IDs needed by TargetBus (e.g. BS73663 for 9007, BS73662 for 602-1A/B)
        let uniqueStopIds = Array(Set(TargetBus.allCases.map(\.stopId)))

        // Fetch all stops concurrently
        var stopResponses: [String: BusStopResponse] = [:]
        try await withThrowingTaskGroup(of: (String, BusStopResponse).self) { group in
            for stopId in uniqueStopIds {
                group.addTask {
                    let response = try await self.fetchStop(stopId: stopId)
                    return (stopId, response)
                }
            }
            for try await (stopId, response) in group {
                stopResponses[stopId] = response
            }
        }

        var results: [TargetBus: BusArrivalDetails] = [:]
        for target in TargetBus.allCases {
            if let stop = stopResponses[target.stopId],
               let line = stop.lines.first(where: { target.matches(lineName: $0.name) }),
               let arrival = line.arrival {
                results[target] = arrival
            }
        }

        return results
    }
}
