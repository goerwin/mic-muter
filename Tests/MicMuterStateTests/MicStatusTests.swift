import XCTest

@testable import MicMuterState

final class MicStatusTests: XCTestCase {
    func testMutedAndUnmutedStatesUseDistinctGlyphs() {
        XCTAssertTrue(MicStatus.muted.isSlashed)
        XCTAssertFalse(MicStatus.unmuted.isSlashed)
        XCTAssertTrue(MicStatus.unmuted.tintsMenuBarIcon)
        XCTAssertFalse(MicStatus.muted.tintsMenuBarIcon)
    }

    func testEveryStateHasTitleAndTint() {
        for status in MicStatus.allCases {
            XCTAssertFalse(status.title.isEmpty)
        }
        XCTAssertTrue(MicStatus.unmuted.tintsMenuBarIcon)
        XCTAssertFalse(MicStatus.muted.tintsMenuBarIcon)
        XCTAssertFalse(MicStatus.unknown.tintsMenuBarIcon)
    }

    func testSlashOnlyForMutedAndInputSilent() {
        XCTAssertTrue(MicStatus.muted.isSlashed)
        XCTAssertTrue(MicStatus.inputSilent.isSlashed)
        XCTAssertFalse(MicStatus.unmuted.isSlashed)
        XCTAssertFalse(MicStatus.unknown.isSlashed)
        XCTAssertFalse(MicStatus.unsupported.isSlashed)
        XCTAssertFalse(MicStatus.disconnected.isSlashed)
    }

    func testInputSilentSharesMutedGlyph() {
        XCTAssertEqual(MicStatus.inputSilent.isSlashed, MicStatus.muted.isSlashed)
        XCTAssertEqual(MicStatus.unsupported.isSlashed, MicStatus.unmuted.isSlashed)
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
        for status in MicStatus.allCases {
            XCTAssertFalse(status.accessibilityDescription.isEmpty)
        }
    }
}

extension MicStatus {
    fileprivate static var allCases: [MicStatus] {
        [.muted, .unmuted, .inputSilent, .unknown, .unsupported, .disconnected]
    }
}
