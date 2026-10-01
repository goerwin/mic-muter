import XCTest

@testable import MicMuterCore

final class MicStatusMapperTests: XCTestCase {
    func testMapsDirectStatuses() {
        XCTAssertEqual(MicStatusMapper.map(.muted, canControl: true), .muted)
        XCTAssertEqual(MicStatusMapper.map(.muted, canControl: false), .muted)
        XCTAssertEqual(MicStatusMapper.map(.unmuted, canControl: true), .unmuted)
        XCTAssertEqual(MicStatusMapper.map(.inputSilent, canControl: true), .inputSilent)
    }

    func testUnknownSplitsOnControllability() {
        XCTAssertEqual(MicStatusMapper.map(.unknown, canControl: true), .unknown)
        XCTAssertEqual(MicStatusMapper.map(.unknown, canControl: false), .unsupported)
    }
}
