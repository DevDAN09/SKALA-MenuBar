import Foundation

public final class BusAPIService: @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchTargetBusesArrival() async throws -> [TargetBus: BusArrivalDetails] {
        let planetId = TargetBus.bus9007.stopId
        let innovalId = TargetBus.bus602_1A.stopId
        async let planet = fetchStop(stopId: planetId)
        async let innoval = fetchStop(stopId: innovalId)
        let stopResponses = [planetId: try await planet, innovalId: try await innoval]

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

    private func fetchStop(stopId: String) async throws -> BusStopResponse {
        guard let url = URL(string: "https://map.kakao.com/bus/stop.json?busstopid=\(stopId)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(BusStopResponse.self, from: data)
    }
}
