import Foundation

public protocol BusAPIServiceProtocol: Sendable {
    func fetchStop(stopId: String) async throws -> BusStopResponse
    func fetch9007Arrival(stopId: String) async throws -> BusArrivalDetails?
    func fetchTargetBusesArrival(stopId: String) async throws -> [TargetBus: BusArrivalDetails]
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

    public func fetchTargetBusesArrival(stopId: String = "BS73663") async throws -> [TargetBus: BusArrivalDetails] {
        let stopInfo = try await fetchStop(stopId: stopId)
        var results: [TargetBus: BusArrivalDetails] = [:]

        for target in TargetBus.allCases {
            if let line = stopInfo.lines.first(where: { target.matches(lineName: $0.name) }),
               let arrival = line.arrival {
                results[target] = arrival
            }
        }

        return results
    }
}
