import XCTest

@testable import MicMuterState

final class MicStatusTests: XCTestCase {
    func testMutedAndUnmutedStatesUseDistinctSymbols() {
        XCTAssertEqual(MicStatus.muted.menuBarSymbol, "mic.slash.fill")
        XCTAssertEqual(MicStatus.unmuted.menuBarSymbol, "mic.fill")
    }

    func testOnlyActionableStatesCanToggle() {
        XCTAssertTrue(MicStatus.muted.canToggle)
        XCTAssertTrue(MicStatus.unmuted.canToggle)
        XCTAssertTrue(MicStatus.unknown.canToggle)
        XCTAssertFalse(MicStatus.inputSilent.canToggle)
        XCTAssertFalse(MicStatus.unsupported.canToggle)
        XCTAssertFalse(MicStatus.disconnected.canToggle)
    }

    func testEveryStateHasAnAccessibleDescription() {
        let statuses: [MicStatus] = [
            .muted,
            .unmuted,
            .inputSilent,
            .unknown,
            .unsupported,
            .disconnected,
        ]

        for status in statuses {
            XCTAssertFalse(status.accessibilityDescription.isEmpty)
        }
    }
}
