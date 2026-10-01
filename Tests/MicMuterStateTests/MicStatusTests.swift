import XCTest

@testable import MicMuterState

final class MicStatusTests: XCTestCase {
    func testMutedAndUnmutedStatesUseDistinctSymbols() {
        XCTAssertEqual(MicStatus.muted.menuBarSymbol, "mic.slash.fill")
        XCTAssertEqual(MicStatus.unmuted.menuBarSymbol, "mic.fill")
        XCTAssertTrue(MicStatus.muted.usesSlashSymbol)
        XCTAssertFalse(MicStatus.unmuted.usesSlashSymbol)
        XCTAssertTrue(MicStatus.unmuted.tintsMenuBarIcon)
        XCTAssertFalse(MicStatus.muted.tintsMenuBarIcon)
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
