import Foundation
import PangyoBusKit

func testDecodeKakaoStopJson() throws {
    let sampleJson = """
    {
      "id": "BS73663",
      "name": "SK플래닛.판교디지털센터",
      "lines": [
        {
          "id": "B1001",
          "name": "9007",
          "busLineType": "DIRECT",
          "arrival": {
            "direction": "유라코퍼레이션.SK케미칼 방향",
            "nextBusStopName": "유라코퍼레이션.SK케미칼",
            "vehicleNumber": "경기70아6229",
            "arrivalTime": 716,
            "busStopCount": 8,
            "vehicleNumber2": "경기70아1234",
            "arrivalTime2": 1500,
            "busStopCount2": 15
          }
        }
      ]
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    let response = try decoder.decode(BusStopResponse.self, from: sampleJson)
    assert(response.name == "SK플래닛.판교디지털센터", "name should match")
    assert(response.lines.count == 1, "lines count should be 1")

    let line = response.lines.first!
    assert(line.name == "9007", "line name should be 9007")
    assert(line.arrival?.arrivalTime == 716, "arrival time should be 716")
    assert(line.arrival?.busStopCount == 8, "bus stop count should be 8")
    assert(line.arrival?.vehicleNumber == "경기70아6229", "vehicle number should match")
    print("✅ testDecodeKakaoStopJson passed")
}

do {
    try testDecodeKakaoStopJson()
    print("🎉 All PangyoBusKit tests passed!")
} catch {
    print("❌ Test failed with error: \(error)")
    exit(1)
}
