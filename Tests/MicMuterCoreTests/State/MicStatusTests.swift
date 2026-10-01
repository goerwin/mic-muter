import XCTest

@testable import MicMuterCore

final class MicStatusTests: XCTestCase {
    func testMutedAndUnmutedStatesUseDistinctGlyphs() {
        XCTAssertTrue(MicStatus.muted.isSlashed)
        XCTAssertFalse(MicStatus.unmuted.isSlashed)
    }

    func testEveryStateHasTitle() {
        for status in MicStatus.allCases {
            XCTAssertFalse(status.title.isEmpty)
        }
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
