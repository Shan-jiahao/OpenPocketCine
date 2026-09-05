import XCTest

@testable import OpenPocketCine

final class HeadphoneMotionStartupPolicyTests: XCTestCase {
    func testRestartsWhenActiveStreamProducesNoFirstSample() {
        XCTAssertTrue(
            HeadphoneMotionStartupPolicy.shouldRestart(
                startedAt: 10,
                now: 10 + HeadphoneMotionStartupPolicy.firstSampleTimeout,
                hasSample: false,
                restartCount: 0
            ))
    }

    func testDoesNotRestartBeforeFirstSampleTimeout() {
        XCTAssertFalse(
            HeadphoneMotionStartupPolicy.shouldRestart(
                startedAt: 10,
                now: 10 + HeadphoneMotionStartupPolicy.firstSampleTimeout - 0.01,
                hasSample: false,
                restartCount: 0
            ))
    }

    func testDoesNotRestartAfterSampleArrives() {
        XCTAssertFalse(
            HeadphoneMotionStartupPolicy.shouldRestart(
                startedAt: 10,
                now: 20,
                hasSample: true,
                restartCount: 0
            ))
    }

    func testAutomaticRestartsAreBounded() {
        XCTAssertFalse(
            HeadphoneMotionStartupPolicy.shouldRestart(
                startedAt: 10,
                now: 20,
                hasSample: false,
                restartCount: HeadphoneMotionStartupPolicy.maxAutomaticRestarts
            ))
    }

    func testPullFallbackStartsAfterPushRestartsAreExhausted() {
        XCTAssertTrue(
            HeadphoneMotionStartupPolicy.shouldUsePullFallback(
                hasSample: false,
                restartCount: HeadphoneMotionStartupPolicy.maxAutomaticRestarts,
                alreadyUsingFallback: false
            ))
    }

    func testPullFallbackIsNotStartedTwice() {
        XCTAssertFalse(
            HeadphoneMotionStartupPolicy.shouldUsePullFallback(
                hasSample: false,
                restartCount: HeadphoneMotionStartupPolicy.maxAutomaticRestarts,
                alreadyUsingFallback: true
            ))
    }
}
